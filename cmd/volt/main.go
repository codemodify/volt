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
	case "mod":
		runMod(args)
	case "doc":
		runDoc(args)
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

// Debug-info flag: when true, codegen adds clang `-g` to embed DWARF
// debug information, allowing gdb/lldb to break by source line.
var buildEmitDebug bool

func runBuild(args []string, andRun bool) {
	buildEmitDebug = false
	for len(args) > 0 && len(args[0]) > 0 && args[0][0] == '-' {
		switch args[0] {
		case "-g":
			buildEmitDebug = true
			args = args[1:]
		case "--":
			args = args[1:]
			goto done
		default:
			fmt.Fprintf(os.Stderr, "volt: unknown flag %q\n", args[0])
			os.Exit(2)
		}
	}
done:
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
	if _, err := exec.LookPath("mold"); err == nil {
		clangArgs = append(clangArgs, "-fuse-ld=mold")
	}
	if buildEmitDebug {
		clangArgs = append(clangArgs, "-g")
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

	// Discover TestX functions in the source.
	src, err := os.ReadFile(srcPath)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	probe, err := parseSource(srcPath, src)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	var tests []string
	hasMain := false
	hasLogImport := false
	for _, im := range probe.file.Imports {
		if im.Path == "log" {
			hasLogImport = true
		}
	}
	for _, d := range probe.file.Decls {
		fd, ok := d.(*ast.FuncDecl)
		if !ok {
			continue
		}
		if fd.Name == "main" && fd.Receiver == nil {
			hasMain = true
		}
		if fd.Receiver == nil && len(fd.Params) == 0 &&
			strings.HasPrefix(fd.Name, "Test") &&
			len(fd.Results) == 1 {
			tests = append(tests, fd.Name)
		}
	}

	// If the source has a main and no TestX functions, just build+run as before.
	if len(tests) == 0 {
		if !hasMain {
			fmt.Fprintf(os.Stderr, "volt test: %s has no TestX functions and no main\n", srcPath)
			os.Exit(1)
		}
		buildAndRun(srcPath, "")
		return
	}

	// Synthesize a wrapper main that calls every TestX and tallies failures.
	// `import "log"` must precede top-level decls, so insert it right after
	// the package line rather than at end-of-file.
	var wrap strings.Builder
	if hasLogImport {
		wrap.Write(src)
	} else {
		lines := strings.SplitAfter(string(src), "\n")
		inserted := false
		for _, line := range lines {
			wrap.WriteString(line)
			if !inserted && strings.HasPrefix(strings.TrimSpace(line), "package ") {
				wrap.WriteString(`import "log"` + "\n")
				inserted = true
			}
		}
	}
	wrap.WriteString("\n// ---- synthesized by `volt test` ----\n")
	wrap.WriteString("fun main() int {\n")
	wrap.WriteString("\tvar failed int = 0\n")
	for _, name := range tests {
		fmt.Fprintf(&wrap, "\tif %s() != 0 {\n", name)
		fmt.Fprintf(&wrap, "\t\tlog.Println(\"FAIL  %s\")\n", name)
		wrap.WriteString("\t\tfailed = failed + 1\n")
		wrap.WriteString("\t} else {\n")
		fmt.Fprintf(&wrap, "\t\tlog.Println(\"PASS  %s\")\n", name)
		wrap.WriteString("\t}\n")
	}
	wrap.WriteString("\tret failed\n")
	wrap.WriteString("}\n")

	// Write the augmented source to a tempfile and build it.
	tmp, err := os.MkdirTemp("", "volt-test-*")
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	defer os.RemoveAll(tmp)
	augPath := filepath.Join(tmp, "_test.volt")
	if err := os.WriteFile(augPath, []byte(wrap.String()), 0o644); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	buildAndRun(augPath, srcPath)
}

// ---------------------------------------------------------------------
// volt mod — manage the volt.mod file (module declaration).
//
// `volt mod init <module-path>` writes a minimal volt.mod in the CWD.
// ---------------------------------------------------------------------

func runMod(args []string) {
	if len(args) < 1 {
		fmt.Fprintln(os.Stderr, "usage: volt mod init <module-path>")
		os.Exit(2)
	}
	switch args[0] {
	case "init":
		if len(args) < 2 {
			fmt.Fprintln(os.Stderr, "volt mod init: missing module path")
			os.Exit(2)
		}
		mod := args[1]
		path := "volt.mod"
		if _, err := os.Stat(path); err == nil {
			fmt.Fprintf(os.Stderr, "volt mod init: %s already exists\n", path)
			os.Exit(1)
		}
		body := fmt.Sprintf("module %s\n\nvolt 0.5\n", mod)
		if err := os.WriteFile(path, []byte(body), 0o644); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		fmt.Printf("created volt.mod (module %s)\n", mod)
	default:
		fmt.Fprintf(os.Stderr, "volt mod: unknown subcommand %q\n", args[0])
		os.Exit(2)
	}
}

// ---------------------------------------------------------------------
// volt doc — list exported (Capitalized) top-level declarations.
// ---------------------------------------------------------------------

func runDoc(args []string) {
	if len(args) < 1 {
		fmt.Fprintln(os.Stderr, "usage: volt doc <file>")
		os.Exit(2)
	}
	srcPath := args[0]
	src, err := os.ReadFile(srcPath)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	u, err := parseSource(srcPath, src)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	fmt.Printf("package %s\n\n", u.pkg)
	for _, d := range u.file.Decls {
		switch d := d.(type) {
		case *ast.FuncDecl:
			if !isExported(d.Name) || d.Receiver != nil {
				continue
			}
			fmt.Printf("fun %s%s\n", d.Name, formatSignature(d))
		case *ast.TypeDecl:
			if !isExported(d.Name) {
				continue
			}
			if _, ok := d.Type.(*ast.StructType); ok {
				fmt.Printf("type %s struct { ... }\n", d.Name)
			} else {
				fmt.Printf("type %s\n", d.Name)
			}
		case *ast.ConstDecl:
			if !isExported(d.Name) {
				continue
			}
			fmt.Printf("const %s\n", d.Name)
		}
	}
	// Methods on exported types (also exported if Capitalized).
	for _, d := range u.file.Decls {
		fd, ok := d.(*ast.FuncDecl)
		if !ok || fd.Receiver == nil {
			continue
		}
		if !isExported(fd.Name) {
			continue
		}
		recvTypeName := fd.ReceiverTypeName()
		if !isExported(recvTypeName) {
			continue
		}
		fmt.Printf("fun (r %s) %s%s\n", typeStr(fd.Receiver.Type), fd.Name, formatSignature(fd))
	}
}

func isExported(name string) bool {
	if name == "" {
		return false
	}
	c := name[0]
	return c >= 'A' && c <= 'Z'
}

func formatSignature(fd *ast.FuncDecl) string {
	var sb strings.Builder
	sb.WriteByte('(')
	for i, p := range fd.Params {
		if i > 0 {
			sb.WriteString(", ")
		}
		sb.WriteString(p.Name + " " + typeStr(p.Type))
	}
	sb.WriteByte(')')
	switch len(fd.Results) {
	case 0:
		// void
	case 1:
		sb.WriteString(" " + typeStr(fd.Results[0]))
	default:
		sb.WriteString(" (")
		for i, r := range fd.Results {
			if i > 0 {
				sb.WriteString(", ")
			}
			sb.WriteString(typeStr(r))
		}
		sb.WriteByte(')')
	}
	return sb.String()
}

func typeStr(t ast.Type) string {
	switch t := t.(type) {
	case *ast.NamedType:
		return t.Name
	case *ast.BorrowType:
		return "&" + typeStr(t.Elem)
	case *ast.PointerType:
		return "*" + typeStr(t.Elem)
	case *ast.SliceType:
		return "[]" + typeStr(t.Elem)
	case *ast.ChanType:
		return "chan " + typeStr(t.Elem)
	case *ast.MapType:
		return "map[" + typeStr(t.Key) + "]" + typeStr(t.Value)
	}
	return "<?>"
}

// buildAndRun compiles `src` (using `label` for status output), runs it,
// and exits the volt-test process with non-zero on any failure.
func buildAndRun(src, label string) {
	if label == "" {
		label = src
	}
	units, err := resolveAndCompile(src)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		fmt.Fprintf(os.Stderr, "FAIL  %s (compile error)\n", label)
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
		fmt.Fprintf(os.Stderr, "FAIL  %s (link error)\n", label)
		os.Exit(1)
	}
	cmd := exec.Command(outPath)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	err = cmd.Run()
	if err == nil {
		fmt.Fprintf(os.Stderr, "ok    %s\n", label)
		return
	}
	if exitErr, ok := err.(*exec.ExitError); ok {
		fmt.Fprintf(os.Stderr, "FAIL  %s (%d failed)\n", label, exitErr.ExitCode())
		os.Exit(1)
	}
	fmt.Fprintf(os.Stderr, "FAIL  %s (%v)\n", label, err)
	os.Exit(1)
}
