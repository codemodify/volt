// volt — the volt compiler driver.
//
// Usage:
//
//	volt build <file>           compile a .volt source file to an executable
//	volt run   <file>           compile and run a .volt source file
//	volt dump-ir <file>         print emitted LLVM IR to stdout (debugging)
//	volt dump-tokens <file>     print the token stream (debugging)
package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"

	"github.com/codemodify/volt/internal/ast"
	"github.com/codemodify/volt/internal/check"
	"github.com/codemodify/volt/internal/codegen"
	"github.com/codemodify/volt/internal/lex"
	"github.com/codemodify/volt/internal/parse"
	"github.com/codemodify/volt/internal/printer"
	"github.com/codemodify/volt/internal/runtime"
	"github.com/codemodify/volt/internal/stdlib"
)

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(2)
	}
	cmd, args := os.Args[1], os.Args[2:]
	switch cmd {
	case "build":
		runBuild(args, false)
	case "run":
		runBuild(args, true)
	case "dump-ir":
		runDumpIR(args)
	case "dump-tokens":
		runDumpTokens(args)
	case "fmt":
		runFmt(args)
	case "test":
		runTest(args)
	default:
		fmt.Fprintf(os.Stderr, "volt: unknown command %q\n", cmd)
		usage()
		os.Exit(2)
	}
}

func usage() {
	fmt.Fprintln(os.Stderr, "usage: volt <command> <file>")
	fmt.Fprintln(os.Stderr, "commands: build, run, dump-ir, dump-tokens")
}

// ---------------------------------------------------------------------
// Pipeline: parse all (user + transitively imported stdlib) → borrow-check
// each with cross-package context → codegen each.
// ---------------------------------------------------------------------

type parsedUnit struct {
	pkg     string
	name    string
	file    *ast.File
	imports []string
}

type compiledUnit struct {
	pkg     string
	ir      string
	imports []string
}

func parseSource(name string, src []byte) (*parsedUnit, error) {
	l := lex.New(name, src)
	p := parse.New(l)
	file, err := p.ParseFile()
	if err != nil {
		return nil, err
	}
	var imps []string
	for _, im := range file.Imports {
		imps = append(imps, im.Path)
	}
	return &parsedUnit{pkg: file.Package, name: name, file: file, imports: imps}, nil
}

func resolveAndCompile(srcPath string) ([]*compiledUnit, error) {
	src, err := os.ReadFile(srcPath)
	if err != nil {
		return nil, fmt.Errorf("volt: %w", err)
	}
	root, err := parseSource(srcPath, src)
	if err != nil {
		return nil, err
	}
	parsed := []*parsedUnit{root}
	seen := map[string]bool{root.pkg: true}

	queue := append([]string(nil), root.imports...)
	for len(queue) > 0 {
		path := queue[0]
		queue = queue[1:]
		if seen[path] {
			continue
		}
		seen[path] = true
		src, ok := stdlib.Source(path)
		if !ok {
			return nil, fmt.Errorf("volt: unknown package %q", path)
		}
		u, err := parseSource(path+"/"+path+".volt", src)
		if err != nil {
			return nil, err
		}
		parsed = append(parsed, u)
		queue = append(queue, u.imports...)
	}

	// Per-package file index used to give the checker cross-package signatures.
	pkgFiles := make(map[string]*ast.File, len(parsed))
	for _, u := range parsed {
		pkgFiles[u.pkg] = u.file
	}

	for _, u := range parsed {
		checker := check.New()
		for pkg, f := range pkgFiles {
			if pkg == u.pkg {
				continue
			}
			checker.AddExternal(pkg, f)
		}
		if err := checker.Check(u.file); err != nil {
			return nil, err
		}
	}

	out := make([]*compiledUnit, 0, len(parsed))
	for _, u := range parsed {
		g := codegen.New()
		ir, err := g.Emit(u.file)
		if err != nil {
			return nil, err
		}
		out = append(out, &compiledUnit{pkg: u.pkg, ir: ir, imports: u.imports})
	}
	return out, nil
}

// ---------------------------------------------------------------------
// build / run
// ---------------------------------------------------------------------

func runBuild(args []string, andRun bool) {
	if len(args) < 1 {
		fmt.Fprintln(os.Stderr, "volt: missing source file")
		os.Exit(2)
	}
	srcPath := args[0]

	units, err := resolveAndCompile(srcPath)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}

	outPath := defaultOutputPath(srcPath)
	if err := assembleAndLink(units, outPath); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}

	if andRun {
		if err := syscall.Exec(outPath, append([]string{outPath}, args[1:]...), os.Environ()); err != nil {
			fmt.Fprintf(os.Stderr, "volt run: %v\n", err)
			os.Exit(1)
		}
	}
}

// assembleAndLink writes each unit's IR + the runtime asm to temp files,
// then invokes clang to compile+link into outPath.
func assembleAndLink(units []*compiledUnit, outPath string) error {
	tmp, err := os.MkdirTemp("", "volt-*")
	if err != nil {
		return fmt.Errorf("volt: create tempdir: %w", err)
	}
	defer os.RemoveAll(tmp)

	var inputs []string
	for _, u := range units {
		path := filepath.Join(tmp, u.pkg+".ll")
		if err := os.WriteFile(path, []byte(u.ir), 0o644); err != nil {
			return fmt.Errorf("volt: write IR for %s: %w", u.pkg, err)
		}
		inputs = append(inputs, path)
	}
	rtPath := filepath.Join(tmp, "runtime.s")
	if err := os.WriteFile(rtPath, runtime.StartAmd64Asm, 0o644); err != nil {
		return fmt.Errorf("volt: write runtime: %w", err)
	}
	inputs = append(inputs, rtPath)

	rtcPath := filepath.Join(tmp, "runtime.c")
	if err := os.WriteFile(rtcPath, runtime.RuntimeC, 0o644); err != nil {
		return fmt.Errorf("volt: write runtime.c: %w", err)
	}
	inputs = append(inputs, rtcPath)

	clangArgs := []string{"-nostdlib", "-nostartfiles", "-static"}
	// Use mold if available — 5-10x faster linking than ld on large binaries.
	if _, err := exec.LookPath("mold"); err == nil {
		clangArgs = append(clangArgs, "-fuse-ld=mold")
	}
	clangArgs = append(clangArgs, "-o", outPath)
	clangArgs = append(clangArgs, inputs...)
	cmd := exec.Command("clang", clangArgs...)
	cmd.Stderr = os.Stderr
	cmd.Stdout = os.Stdout
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("volt: clang failed: %w", err)
	}
	return nil
}

func defaultOutputPath(srcPath string) string {
	base := filepath.Base(srcPath)
	if ext := filepath.Ext(base); ext != "" {
		base = strings.TrimSuffix(base, ext)
	}
	return "./" + base
}

// ---------------------------------------------------------------------
// dump helpers (debugging)
// ---------------------------------------------------------------------

func runDumpIR(args []string) {
	if len(args) < 1 {
		fmt.Fprintln(os.Stderr, "volt: missing source file")
		os.Exit(2)
	}
	units, err := resolveAndCompile(args[0])
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	for _, u := range units {
		fmt.Printf("; ===== package %s =====\n", u.pkg)
		fmt.Print(u.ir)
		fmt.Println()
	}
}

func runDumpTokens(args []string) {
	if len(args) < 1 {
		fmt.Fprintln(os.Stderr, "volt: missing source file")
		os.Exit(2)
	}
	src, err := os.ReadFile(args[0])
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	l := lex.New(args[0], src)
	for {
		t := l.Next()
		fmt.Println(t)
		if t.Kind == lex.EOF {
			return
		}
	}
}

// ---------------------------------------------------------------------
// volt fmt — parse a .volt file and print canonical formatted source.
// Use `-w` to rewrite in place.
// ---------------------------------------------------------------------

func runFmt(args []string) {
	write := false
	files := args
	if len(args) >= 1 && args[0] == "-w" {
		write = true
		files = args[1:]
	}
	if len(files) == 0 {
		fmt.Fprintln(os.Stderr, "volt: missing source file")
		os.Exit(2)
	}
	for _, path := range files {
		src, err := os.ReadFile(path)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		l := lex.New(path, src)
		p := parse.New(l)
		file, err := p.ParseFile()
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		formatted := printer.Format(file)
		if write {
			if err := os.WriteFile(path, []byte(formatted), 0o644); err != nil {
				fmt.Fprintln(os.Stderr, err)
				os.Exit(1)
			}
		} else {
			fmt.Print(formatted)
		}
	}
}

// ---------------------------------------------------------------------
// volt test — compile a .volt file and run it. Tests are written as
// `fun main() int` that returns 0 on success or non-zero on failure;
// `volt test` reports PASS/FAIL based on the exit code.
//
// Test-function discovery + a synthesized harness is on the roadmap;
// for v0.4 this is the basic "build and report" form.
// ---------------------------------------------------------------------

func runTest(args []string) {
	if len(args) < 1 {
		fmt.Fprintln(os.Stderr, "volt: missing test file")
		os.Exit(2)
	}
	srcPath := args[0]
	units, err := resolveAndCompile(srcPath)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		fmt.Fprintf(os.Stderr, "FAIL  %s (compile error)\n", srcPath)
		os.Exit(1)
	}

	tmp, err := os.MkdirTemp("", "volt-test-*")
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	defer os.RemoveAll(tmp)
	outPath := filepath.Join(tmp, "test.bin")
	if err := assembleAndLink(units, outPath); err != nil {
		fmt.Fprintln(os.Stderr, err)
		fmt.Fprintf(os.Stderr, "FAIL  %s (link error)\n", srcPath)
		os.Exit(1)
	}
	cmd := exec.Command(outPath)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	err = cmd.Run()
	if err == nil {
		fmt.Fprintf(os.Stderr, "PASS  %s\n", srcPath)
		return
	}
	if exitErr, ok := err.(*exec.ExitError); ok {
		fmt.Fprintf(os.Stderr, "FAIL  %s (exit %d)\n", srcPath, exitErr.ExitCode())
		os.Exit(1)
	}
	fmt.Fprintf(os.Stderr, "FAIL  %s (%v)\n", srcPath, err)
	os.Exit(1)
}
