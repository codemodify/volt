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
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	goruntime "runtime"
	"sort"
	"strconv"
	"strings"
	"syscall"

	"github.com/codemodify/volt/internal/ast"
	"github.com/codemodify/volt/internal/check"
	"github.com/codemodify/volt/internal/codegen"
	"github.com/codemodify/volt/internal/lex"
	"github.com/codemodify/volt/internal/modfile"
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
	case "memprofile":
		runMemProfile(args)
	case "mod":
		runMod(args)
	case "doc":
		runDoc(args)
	case "lsp":
		runLSP(args)
	case "version", "--version", "-v":
		runVersion()
	case "env":
		runEnv()
	case "help", "--help", "-h":
		usage()
	default:
		fmt.Fprintf(os.Stderr, "volt: unknown command %q\n", cmd)
		usage()
		os.Exit(2)
	}
}

// voltVersion is the user-facing release tag. Bump alongside the
// `volt 0.X` directive in `volt mod init`.
const voltVersion = "0.5"

func runVersion() {
	fmt.Printf("volt %s\n", voltVersion)
	if c := exec.Command("clang", "--version"); c != nil {
		out, err := c.Output()
		if err == nil {
			// First line of `clang --version` is the most relevant.
			if line, _, _ := strings.Cut(string(out), "\n"); line != "" {
				fmt.Printf("using %s\n", strings.TrimSpace(line))
			}
		}
	}
}

// runEnv prints the toolchain's view of the environment — version,
// host arch, where the package cache lives, the in-tree stdlib
// packages we know about, and (when present) the local module's
// volt.mod summary. Diagnostics-oriented; not parsed by other tools.
func runEnv() {
	fmt.Printf("volt version:       %s\n", voltVersion)
	host := runtimePkgHostArch()
	fmt.Printf("host arch:          %s\n", host)
	fmt.Printf("default --target:   amd64\n")
	if path, err := exec.LookPath("clang"); err == nil {
		fmt.Printf("clang:              %s\n", path)
	} else {
		fmt.Printf("clang:              (not found in PATH)\n")
	}
	if path, err := exec.LookPath("mold"); err == nil {
		fmt.Printf("mold (linker):      %s\n", path)
	} else {
		fmt.Printf("mold (linker):      (not found; falling back to default ld)\n")
	}
	if home, err := os.UserHomeDir(); err == nil {
		cache := filepath.Join(home, ".volt", "pkg")
		fmt.Printf("package cache:      %s\n", cache)
		if entries, err := os.ReadDir(cache); err == nil {
			fmt.Printf("packages cached:    %d\n", len(entries))
		}
	}
	// stdlib package list derived from the embedded FS (single source
	// of truth — adding a new go:embed entry shows up here automatically).
	stdlibList := stdlib.List()
	sort.Strings(stdlibList)
	fmt.Printf("stdlib packages:    %d total\n", len(stdlibList))
	for _, p := range stdlibList {
		fmt.Printf("                    %s\n", p)
	}
	if data, err := os.ReadFile("volt.mod"); err == nil {
		fmt.Println("local volt.mod:")
		mf, err := modfile.Parse(data)
		if err != nil {
			fmt.Printf("  (parse error: %v)\n", err)
		} else {
			fmt.Printf("  module:           %s\n", mf.Module)
			if mf.VoltVersion != "" {
				fmt.Printf("  volt directive:   %s\n", mf.VoltVersion)
			}
			if len(mf.Require) > 0 {
				fmt.Printf("  requires:         %d\n", len(mf.Require))
				for _, r := range mf.Require {
					fmt.Printf("    %s %s\n", r.Path, r.Version)
				}
			}
			if len(mf.Replace) > 0 {
				fmt.Printf("  replaces:         %d\n", len(mf.Replace))
				for _, r := range mf.Replace {
					fmt.Printf("    %s => %s\n", r.From, r.To)
				}
			}
		}
	}
}

// runtimePkgHostArch reports the host architecture for the `env`
// listing. Uses GOARCH (the runtime/std lib package); volt itself
// only supports amd64 and arm64 today.
func runtimePkgHostArch() string {
	return goruntime.GOARCH
}

func usage() {
	fmt.Fprintln(os.Stderr, "usage: volt <command> [args...]")
	fmt.Fprintln(os.Stderr, "")
	fmt.Fprintln(os.Stderr, "Build & run:")
	fmt.Fprintln(os.Stderr, "  build [-g] [-strict] [-race] [--target arch] [--channels mutex|lockfree] <file>")
	fmt.Fprintln(os.Stderr, "                                                compile to executable")
	fmt.Fprintln(os.Stderr, "  run   [-g] [-strict] [-race] [--target arch] [--channels mutex|lockfree] <file>")
	fmt.Fprintln(os.Stderr, "                                                build + execute")
	fmt.Fprintln(os.Stderr, "  test  <file>                                  build + run as a test")
	fmt.Fprintln(os.Stderr, "")
	fmt.Fprintln(os.Stderr, "Source tools:")
	fmt.Fprintln(os.Stderr, "  fmt   [-w] <file>...                          format (stdout, or -w in place)")
	fmt.Fprintln(os.Stderr, "  doc   <file|stdlib-pkg>                       print exported declarations")
	fmt.Fprintln(os.Stderr, "  dump-ir     <file>                            print LLVM IR")
	fmt.Fprintln(os.Stderr, "  dump-tokens <file>                            print lex stream")
	fmt.Fprintln(os.Stderr, "")
	fmt.Fprintln(os.Stderr, "Modules:")
	fmt.Fprintln(os.Stderr, "  mod init   <module-path>                      create volt.mod")
	fmt.Fprintln(os.Stderr, "  mod get    <import-path>                      fetch into ~/.volt/pkg, update volt.mod/volt.sum")
	fmt.Fprintln(os.Stderr, "  mod tidy   <entry-file>                       sync requires + sums to actual imports")
	fmt.Fprintln(os.Stderr, "  mod verify                                    check ~/.volt/pkg matches volt.sum")
	fmt.Fprintln(os.Stderr, "")
	fmt.Fprintln(os.Stderr, "Editor / misc:")
	fmt.Fprintln(os.Stderr, "  lsp                                           run language server on stdio")
	fmt.Fprintln(os.Stderr, "  env                                           print toolchain + module info")
	fmt.Fprintln(os.Stderr, "  version                                       print volt + clang version")
	fmt.Fprintln(os.Stderr, "  help                                          this message")
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

// loadExternalPackage reads the source for a non-stdlib import path.
// Looks first in the current module (./<path>/<lastseg>.volt) then in
// the user package cache (~/.volt/pkg/<path>/<lastseg>.volt). Returns
// (source, file-name-for-errors, err). When the import isn't found in
// either location, the error message hints at `volt mod get`.
//
// `replace` directive: if `./volt.mod` redirects the import path, the
// lookup uses the redirect target (a literal directory) and skips the
// cache + sum verification — replace points at code under development.
//
// Cache-resolved packages get their content hash verified against any
// matching entry in `./volt.sum`. Mismatches print a warning by default;
// the `-strict` build flag escalates to a hard error.
func loadExternalPackage(importPath string) ([]byte, string, error) {
	last := importPath
	if i := strings.LastIndex(importPath, "/"); i >= 0 {
		last = importPath[i+1:]
	}

	// 0. Replace directive: if the project's volt.mod redirects this
	// path, resolve against the target directory and skip cache/sum
	// (a replace target is "trust me, use what's on disk").
	if target := replaceTarget(importPath); target != "" {
		for _, name := range []string{last + ".volt", importPath + ".volt"} {
			c := filepath.Join(target, name)
			if data, err := os.ReadFile(c); err == nil {
				return data, c, nil
			}
		}
		return nil, "", fmt.Errorf(
			"volt: %q replaced to %q but no .volt source found there",
			importPath, target)
	}

	// 1. Local module: relative to CWD.
	localCandidates := []string{
		filepath.Join(importPath, last+".volt"),
		filepath.Join(importPath, importPath+".volt"),
	}
	for _, c := range localCandidates {
		if data, err := os.ReadFile(c); err == nil {
			return data, c, nil
		}
	}

	// 2. User package cache.
	home, _ := os.UserHomeDir()
	cacheRoots := []string{}
	if home != "" {
		cacheRoots = append(cacheRoots, filepath.Join(home, ".volt", "pkg"))
	}
	for _, root := range cacheRoots {
		base := filepath.Join(root, importPath)
		for _, name := range []string{last + ".volt", importPath + ".volt"} {
			c := filepath.Join(base, name)
			if data, err := os.ReadFile(c); err == nil {
				verifyAgainstSum(importPath, base)
				return data, c, nil
			}
		}
	}

	if guess := suggestStdlibImport(importPath); guess != "" {
		return nil, "", fmt.Errorf(
			"volt: unknown package %q (did you mean %q? — or try: volt mod get %s)",
			importPath, guess, importPath)
	}
	return nil, "", fmt.Errorf(
		"volt: unknown package %q (try: volt mod get %s)",
		importPath, importPath)
}

// suggestStdlibImport returns the stdlib package path closest to
// `name` by edit distance, or "" when no candidate is within a tight
// threshold. Matches both full paths ("encoding/hex") and short names
// ("hex") so users hit the typo correction whether they wrote
// `import "hxx"` or `import "encoding/hxx"`.
func suggestStdlibImport(name string) string {
	cands := stdlib.List()
	cands = append(cands, []string{}...) // grow capacity for short names
	for short := range stdlib.ShortNameToPath() {
		cands = append(cands, short)
	}
	return closestImportName(name, cands)
}

// closestImportName picks the candidate with smallest edit distance.
// Tight threshold: accept ≤ 2 edits unconditionally, or when
// `dist*3 <= longest-length` for longer paths.
func closestImportName(name string, cands []string) string {
	best := ""
	bestDist := 1 << 30
	for _, cand := range cands {
		if cand == name || cand == "" {
			continue
		}
		d := levenshtein(name, cand)
		if d < bestDist {
			bestDist = d
			best = cand
		}
	}
	longest := len(name)
	if len(best) > longest {
		longest = len(best)
	}
	if best == "" || bestDist > 2 && bestDist*3 > longest {
		return ""
	}
	return best
}

// loadedModReplaces / loadedModRequires cache the parsed `replace` +
// `require` lists from `./volt.mod`. nil = not yet loaded; empty =
// nothing to replace / require.
var (
	loadedModReplaces []modfile.Replace
	loadedModRequires map[string]string // path → version
	loadedModSet      bool
)

func loadModOnce() {
	if loadedModSet {
		return
	}
	loadedModSet = true
	data, err := os.ReadFile("volt.mod")
	if err != nil {
		return
	}
	mf, err := modfile.Parse(data)
	if err != nil {
		return
	}
	loadedModReplaces = mf.Replace
	loadedModRequires = make(map[string]string, len(mf.Require))
	for _, r := range mf.Require {
		loadedModRequires[r.Path] = r.Version
	}
}

// replaceTarget returns the on-disk directory the project's volt.mod
// has redirected `importPath` to, or "" when no replace applies.
// Version-aware: a `replace foo v1.0.0 => …` entry matches only when
// the workspace's `require foo v1.0.0` also pins the same version;
// `replace foo => …` (no version) matches any version. Multiple
// entries with the same `from` resolve via MatchReplace — pinned
// entries beat catch-all. The target path is interpreted relative
// to the directory containing volt.mod (the project root).
func replaceTarget(importPath string) string {
	loadModOnce()
	return pickReplaceTarget(loadedModReplaces, loadedModRequires, importPath)
}

// pickReplaceTarget is the testable inner form of replaceTarget. Given
// pre-parsed Replace + Require data, returns the redirect target for
// importPath or "" if none applies.
func pickReplaceTarget(replaces []modfile.Replace, requires map[string]string, importPath string) string {
	rep, ok := modfile.MatchReplace(replaces, importPath, requires[importPath])
	if !ok {
		return ""
	}
	return rep.To
}

// loadedSums caches the parsed ./volt.sum for this process so we
// don't re-read it per package.
var (
	loadedSums     []modfile.SumEntry
	loadedSumsRead bool
	verifiedPkgs   = map[string]bool{}
)

// verifyAgainstSum compares the actual on-disk hash of `pkgDir`
// against the entry in `./volt.sum` for `importPath`. Each (path,
// hash) pair is checked at most once per process. No-op if there's no
// volt.sum or no matching entry.
func verifyAgainstSum(importPath, pkgDir string) {
	if verifiedPkgs[importPath] {
		return
	}
	verifiedPkgs[importPath] = true
	if !loadedSumsRead {
		loadedSumsRead = true
		if data, err := os.ReadFile("volt.sum"); err == nil {
			if entries, err := modfile.ParseSum(data); err == nil {
				loadedSums = entries
			}
		}
	}
	var expectedHash, expectedVer string
	for _, e := range loadedSums {
		if e.Path == importPath {
			expectedHash = e.Hash
			expectedVer = e.Version
			break
		}
	}
	if expectedHash == "" {
		return // no volt.sum entry — silent
	}
	actual, err := modfile.HashPackageDir(pkgDir)
	if err != nil {
		fmt.Fprintf(os.Stderr,
			"volt: warning: could not hash %s for sum verification: %v\n",
			importPath, err)
		return
	}
	if actual != expectedHash {
		label := "warning"
		if buildStrict {
			label = "error"
		}
		fmt.Fprintf(os.Stderr,
			"volt: %s: %s %s on-disk hash %s doesn't match volt.sum %s\n",
			label, importPath, expectedVer,
			actual[:min(12, len(actual))],
			expectedHash[:min(12, len(expectedHash))])
		if buildStrict {
			os.Exit(1)
		}
	}
}

func resolveAndCompile(srcPath string) ([]*compiledUnit, error) {
	src, err := os.ReadFile(srcPath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, fmt.Errorf("volt: source file %q does not exist", srcPath)
		}
		return nil, fmt.Errorf("volt: cannot read %q: %v", srcPath, err)
	}
	// Catch a common mistake: the user passed something that doesn't
	// end in `.volt`. Hint at the expected extension rather than
	// letting the parser stumble through random bytes.
	if !strings.HasSuffix(srcPath, ".volt") {
		return nil, fmt.Errorf("volt: %q does not have a .volt extension — expected a volt source file", srcPath)
	}
	root, err := parseSource(srcPath, src)
	if err != nil {
		return nil, err
	}
	// A `package main` file is a binary entry-point — it must declare
	// `fun main() int` (or no return, defaulting to exit 0). Surface
	// shape problems here so the user sees a friendly error instead
	// of the mold linker's `undefined symbol: main` or a misleading
	// downstream type-mismatch.
	if root.pkg == "main" {
		var mainFn *ast.FuncDecl
		for _, d := range root.file.Decls {
			fd, ok := d.(*ast.FuncDecl)
			if !ok || fd.Receiver != nil {
				continue
			}
			if fd.Name == "main" {
				mainFn = fd
				break
			}
		}
		if mainFn == nil {
			return nil, fmt.Errorf("volt: %s: package main has no `fun main()` — add an entry-point or change the package name", srcPath)
		}
		if len(mainFn.Params) != 0 {
			return nil, fmt.Errorf("%s: `fun main` cannot take parameters — use os.Argc / os.ArgAt to read argv", mainFn.P)
		}
		// Allow `fun main()` (no return = exit 0) or `fun main() int`.
		if len(mainFn.Results) > 1 {
			return nil, fmt.Errorf("%s: `fun main` returns at most one value (the exit code)", mainFn.P)
		}
		if len(mainFn.Results) == 1 {
			nt, ok := mainFn.Results[0].(*ast.NamedType)
			if !ok || nt.Name != "int" {
				return nil, fmt.Errorf("%s: `fun main` must return `int` (the exit code), not another type", mainFn.P)
			}
		}
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
		// Lookup order:
		//   1. Embedded stdlib (bufio, fmt, log, ...).
		//   2. Local module: ./<path>/<lastseg>.volt — for packages
		//      defined inside the user's own module.
		//   3. Package cache: ~/.volt/pkg/<path>/<lastseg>.volt —
		//      populated by `volt mod get`.
		// We use the last path segment as the file basename, matching
		// the stdlib convention.
		src, ok := stdlib.Source(path)
		filePath := path + "/" + path + ".volt"
		if !ok {
			s, p, err := loadExternalPackage(path)
			if err != nil {
				return nil, err
			}
			src = s
			filePath = p
		}
		u, err := parseSource(filePath, src)
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

	triple := ""
	switch buildTarget {
	case "amd64":
		triple = "x86_64-pc-linux-gnu"
	case "arm64":
		triple = "aarch64-unknown-linux-gnu"
	}

	out := make([]*compiledUnit, 0, len(parsed))
	for _, u := range parsed {
		g := codegen.New()
		g.SetTarget(triple)
		g.SetSourceFile(u.name)
		g.SetRaceEnabled(buildRace)
		g.SetChannelsBackend(buildChannels)
		g.SetMemProfilePath(buildMemProfile)
		// Give codegen cross-package signature visibility so it can
		// produce correct shapes for `os.Open(...)` style calls that
		// return multiple values.
		for pkg, f := range pkgFiles {
			if pkg == u.pkg {
				continue
			}
			g.AddExternal(pkg, f)
		}
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

// buildTarget selects the target arch. Defaults to the host arch.
// Supported: "amd64" (Linux x86_64), "arm64" (Linux aarch64).
var buildTarget string

// buildStrict elevates volt.sum hash-mismatch warnings to errors. The
// resolver (verifyAgainstSum) reads this when deciding what to do.
var buildStrict bool

// buildRace enables compile-time race-detector instrumentation. When
// true, codegen emits calls into the runtime's `volt_race_*` shim
// (see internal/runtime/asm/runtime.c). The shim is currently a
// no-op suite of stubs; the actual happens-before tracker is D.1
// on the roadmap. The flag is wired up now so user code can be
// built with `-race` against future runtime upgrades without a
// recompile of the volt driver.
var buildRace bool

// buildChannels selects the channel-queue backend: "mutex" (default,
// current implementation) or "lockfree" (D.2 on the roadmap — an
// MPMC ring/Michael-Scott queue). Any other value is rejected at
// flag parse time. Like -race, the value is plumbed to codegen now
// so the choice can be honored once the lock-free backend lands.
var buildChannels string

// buildMemProfile, when non-empty, enables memory-profile auto-dump:
// codegen injects a path-register call at main entry and the runtime
// flushes an allocation profile (JSON) to this path at process exit.
// Set by `volt build --memprofile <path>`.
var buildMemProfile string

func runBuild(args []string, andRun bool) {
	buildEmitDebug = false
	buildTarget = "amd64"
	buildStrict = false
	buildRace = false
	buildChannels = "mutex"
	buildMemProfile = ""
	for len(args) > 0 && len(args[0]) > 0 && args[0][0] == '-' {
		switch args[0] {
		case "-g":
			buildEmitDebug = true
			args = args[1:]
		case "-strict":
			buildStrict = true
			args = args[1:]
		case "-race":
			buildRace = true
			args = args[1:]
		case "--target":
			if len(args) < 2 {
				fmt.Fprintln(os.Stderr, "volt: --target needs a value")
				os.Exit(2)
			}
			buildTarget = args[1]
			args = args[2:]
		case "--channels":
			if len(args) < 2 {
				fmt.Fprintln(os.Stderr, "volt: --channels needs a value (mutex|lockfree)")
				os.Exit(2)
			}
			switch args[1] {
			case "mutex", "lockfree":
				buildChannels = args[1]
			default:
				fmt.Fprintf(os.Stderr, "volt: --channels=%q is not one of: mutex, lockfree\n", args[1])
				os.Exit(2)
			}
			args = args[2:]
		case "--memprofile":
			if len(args) < 2 {
				fmt.Fprintln(os.Stderr, "volt: --memprofile needs a path")
				os.Exit(2)
			}
			buildMemProfile = args[1]
			args = args[2:]
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
	var rtAsm []byte
	switch buildTarget {
	case "amd64":
		rtAsm = runtime.StartAmd64Asm
	case "arm64":
		rtAsm = runtime.StartArm64Asm
	default:
		return fmt.Errorf("volt: unsupported --target %q (want amd64 or arm64)", buildTarget)
	}
	if err := os.WriteFile(rtPath, rtAsm, 0o644); err != nil {
		return fmt.Errorf("volt: write runtime: %w", err)
	}
	inputs = append(inputs, rtPath)

	rtcPath := filepath.Join(tmp, "runtime.c")
	if err := os.WriteFile(rtcPath, runtime.RuntimeC, 0o644); err != nil {
		return fmt.Errorf("volt: write runtime.c: %w", err)
	}
	inputs = append(inputs, rtcPath)

	clangArgs := []string{
		"-nostdlib",
		"-nostartfiles",
		"-static",
		// We have no libc → no __stack_chk_fail symbol — disable the
		// stack protector clang would otherwise insert for fn locals.
		"-fno-stack-protector",
	}
	if buildTarget == "arm64" {
		clangArgs = append(clangArgs, "--target=aarch64-linux-gnu")
	}
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
	// Honor a few build flags so the dumped IR reflects instrumentation
	// (-race) and debug info (-g) — handy for inspecting codegen output.
	buildRace = false
	buildEmitDebug = false
	buildTarget = "amd64"
	buildChannels = "mutex"
	buildMemProfile = ""
	for len(args) > 0 && len(args[0]) > 0 && args[0][0] == '-' {
		switch args[0] {
		case "-race":
			buildRace = true
		case "-g":
			buildEmitDebug = true
		default:
			fmt.Fprintf(os.Stderr, "volt: unknown flag %q for dump-ir\n", args[0])
			os.Exit(2)
		}
		args = args[1:]
	}
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
	force := false
	files := args
	// Strip flags from the front. `-w` writes back; `--force` lets the
	// caller override a `// volt:noformat` magic comment guard (only
	// makes sense together with `-w`).
	for len(files) > 0 {
		switch files[0] {
		case "-w":
			write = true
			files = files[1:]
		case "--force":
			force = true
			files = files[1:]
		default:
			goto done
		}
	}
done:
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
		// Magic-comment guard: if any of the first 10 lines contains
		// `// volt:noformat` (case-sensitive) the file is treated as
		// hand-aligned — refuse to write unless --force was given.
		// Preview (no -w) still works since it doesn't damage the file.
		if write && !force && hasNoFormatHeader(src) {
			fmt.Fprintf(os.Stderr,
				"volt: %s has a `// volt:noformat` header — refusing to overwrite hand-aligned spec.\n"+
					"      Pass --force to override (or remove the header).\n", path)
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

// hasNoFormatHeader reports whether the file's first 10 lines contain
// the `// volt:noformat` opt-out marker.
func hasNoFormatHeader(src []byte) bool {
	limit := 10
	line := 0
	start := 0
	for i := 0; i <= len(src); i++ {
		if i == len(src) || src[i] == '\n' {
			if strings.Contains(string(src[start:i]), "// volt:noformat") {
				return true
			}
			line++
			if line >= limit {
				return false
			}
			start = i + 1
		}
	}
	return false
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
	// Pass 755: `volt test --race <file>` enables the race detector
	// for the test run AND asserts runtime.RaceViolations() == 0 at
	// the end. Any detected race fails the test even if individual
	// TestX functions all passed.
	buildRace = false
	// Pass 756: --bench enables benchmark discovery + execution. Tests
	// still run too; benches print "ps/op" results via testing.RunBenchmark.
	// Without --bench, BenchmarkX functions in the source are skipped
	// even when discovered (the synthesized main omits the calls).
	runBenchmarks := false
	// --bench-json <path> dumps every BenchResult to a JSON file so CI
	// pipelines can diff runs. Implies --bench. Empty path => disabled.
	benchJSONPath := ""
	// --bench-compare <old.json> runs the benches, then compares the
	// fresh ps/op against a baseline JSON (a prior --bench-json dump).
	// Any bench whose ps/op exceeds baseline*(1+tolerance/100) fails the
	// run. Implies --bench. Tolerance defaults to 20%, overridable with
	// --bench-tolerance.
	benchComparePath := ""
	benchTolerancePct := 20
	for len(args) > 0 && len(args[0]) > 0 && args[0][0] == '-' {
		switch args[0] {
		case "-race", "--race":
			buildRace = true
			args = args[1:]
		case "-bench", "--bench":
			runBenchmarks = true
			args = args[1:]
		case "-bench-json", "--bench-json":
			if len(args) < 2 {
				fmt.Fprintln(os.Stderr, "volt: --bench-json requires a path argument")
				os.Exit(2)
			}
			runBenchmarks = true
			benchJSONPath = args[1]
			args = args[2:]
		case "-bench-compare", "--bench-compare":
			if len(args) < 2 {
				fmt.Fprintln(os.Stderr, "volt: --bench-compare requires a baseline JSON path")
				os.Exit(2)
			}
			runBenchmarks = true
			benchComparePath = args[1]
			args = args[2:]
		case "-bench-tolerance", "--bench-tolerance":
			if len(args) < 2 {
				fmt.Fprintln(os.Stderr, "volt: --bench-tolerance requires a percentage")
				os.Exit(2)
			}
			n, err := strconv.Atoi(args[1])
			if err != nil || n < 0 {
				fmt.Fprintf(os.Stderr, "volt: --bench-tolerance needs a non-negative integer, got %q\n", args[1])
				os.Exit(2)
			}
			benchTolerancePct = n
			args = args[2:]
		default:
			fmt.Fprintf(os.Stderr, "volt: unknown flag %q for test\n", args[0])
			os.Exit(2)
		}
	}
	// --bench-compare needs a fresh dump to diff against the baseline.
	// If the user didn't also pass --bench-json, route the new results
	// to a temp file we clean up after comparing.
	var benchCompareTmp string
	if benchComparePath != "" && benchJSONPath == "" {
		f, err := os.CreateTemp("", "volt-bench-*.json")
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		benchCompareTmp = f.Name()
		f.Close()
		benchJSONPath = benchCompareTmp
	}
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
	// Two test conventions:
	//   - Legacy:   `fun TestX() int { ret 0_on_pass }`
	//   - Harness:  `fun TestX(t *T)` — runs via `testing.Run`
	type discoveredTest struct {
		name    string
		harness bool
	}
	var tests []discoveredTest
	var benchmarks []string
	hasMain := false
	hasLogImport := false
	hasTestingImport := false
	for _, im := range probe.file.Imports {
		if im.Path == "log" {
			hasLogImport = true
		}
		if im.Path == "testing" {
			hasTestingImport = true
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
		if fd.Receiver != nil {
			continue
		}
		// Benchmark: `fun BenchmarkX(b *B)` — runs via testing.RunBenchmark.
		if strings.HasPrefix(fd.Name, "Benchmark") &&
			len(fd.Params) == 1 && len(fd.Results) == 0 {
			if pt, ok := fd.Params[0].Type.(*ast.PointerType); ok {
				if nt, ok := pt.Elem.(*ast.NamedType); ok && nt.Name == "B" {
					benchmarks = append(benchmarks, fd.Name)
					continue
				}
			}
		}
		if !strings.HasPrefix(fd.Name, "Test") {
			continue
		}
		// Legacy: no params, single return.
		if len(fd.Params) == 0 && len(fd.Results) == 1 {
			tests = append(tests, discoveredTest{name: fd.Name, harness: false})
			continue
		}
		// Harness: one `*T` param, no return.
		if len(fd.Params) == 1 && len(fd.Results) == 0 {
			if pt, ok := fd.Params[0].Type.(*ast.PointerType); ok {
				if nt, ok := pt.Elem.(*ast.NamedType); ok && nt.Name == "T" {
					tests = append(tests, discoveredTest{name: fd.Name, harness: true})
					continue
				}
			}
		}
	}

	// If the source has its own main, run it as-is — the user is
	// orchestrating the tests themselves (e.g. via direct testing.Run
	// calls). Synthesizing a second main would conflict at link time.
	if hasMain {
		buildAndRun(srcPath, "")
		return
	}
	if len(tests) == 0 && len(benchmarks) == 0 {
		fmt.Fprintf(os.Stderr, "volt test: %s has no TestX / BenchmarkX functions and no main\n", srcPath)
		os.Exit(1)
	}

	// Need `testing` if any harness test exists OR benchmarks will run.
	// Benchmarks are skipped without --bench, so don't drag in the
	// testing import for nothing.
	anyHarness := runBenchmarks && len(benchmarks) > 0
	for _, t := range tests {
		if t.harness {
			anyHarness = true
			break
		}
	}

	// Synthesize a wrapper main that calls every TestX and tallies failures.
	// `import "log"` (+ optional `import "testing"`) must precede top-level
	// decls — insert them right after the `package` line.
	var wrap strings.Builder
	insertImports := []string{}
	if !hasLogImport {
		insertImports = append(insertImports, `import "log"`)
	}
	if anyHarness && !hasTestingImport {
		insertImports = append(insertImports, `import "testing"`)
	}
	if buildRace {
		insertImports = append(insertImports, `import "runtime"`)
	}
	if len(insertImports) == 0 {
		wrap.Write(src)
	} else {
		lines := strings.SplitAfter(string(src), "\n")
		inserted := false
		for _, line := range lines {
			wrap.WriteString(line)
			if !inserted && strings.HasPrefix(strings.TrimSpace(line), "package ") {
				for _, im := range insertImports {
					wrap.WriteString(im + "\n")
				}
				inserted = true
			}
		}
	}
	wrap.WriteString("\n// ---- synthesized by `volt test` ----\n")
	wrap.WriteString("fun main() int {\n")
	wrap.WriteString("\tvar failed int = 0\n")
	for _, t := range tests {
		if t.harness {
			fmt.Fprintf(&wrap, "\tif !testing.Run(\"%s\", %s) { failed = failed + 1 }\n", t.name, t.name)
			continue
		}
		fmt.Fprintf(&wrap, "\tif %s() != 0 {\n", t.name)
		fmt.Fprintf(&wrap, "\t\tlog.Println(\"FAIL  %s\")\n", t.name)
		wrap.WriteString("\t\tfailed = failed + 1\n")
		wrap.WriteString("\t} else {\n")
		fmt.Fprintf(&wrap, "\t\tlog.Println(\"PASS  %s\")\n", t.name)
		wrap.WriteString("\t}\n")
	}
	if runBenchmarks {
		if benchJSONPath != "" && len(benchmarks) > 0 {
			// Collect each result so we can emit a JSON manifest at the
			// end. Pre-allocated slice keeps the synthesized code simple
			// (volt's `append` works on owned slices).
			fmt.Fprintf(&wrap, "\tvar __benchResults []testing.BenchResult = new(%d) []testing.BenchResult {}\n", len(benchmarks))
			for i, name := range benchmarks {
				fmt.Fprintf(&wrap, "\t__benchResults[%d] = testing.RunBenchmark(\"%s\", %s)\n", i, name, name)
			}
			fmt.Fprintf(&wrap, "\tvar __benchJSONErr int = testing.WriteBenchResultsJSON(__benchResults, %q)\n", benchJSONPath)
			wrap.WriteString("\tif __benchJSONErr != 0 {\n")
			fmt.Fprintf(&wrap, "\t\tlog.Println(\"FAIL  could not write bench JSON to %s\")\n", benchJSONPath)
			wrap.WriteString("\t\tfailed = failed + 1\n")
			wrap.WriteString("\t}\n")
		} else {
			for _, name := range benchmarks {
				fmt.Fprintf(&wrap, "\ttesting.RunBenchmark(\"%s\", %s)\n", name, name)
			}
		}
	}
	if buildRace {
		// After all tests/benches run, check the race detector's
		// cumulative violation count. Any race (even one that didn't
		// affect a test's correctness) fails the run as a whole.
		wrap.WriteString("\tvar races int = runtime.RaceViolations()\n")
		wrap.WriteString("\tif races != 0 {\n")
		wrap.WriteString("\t\tlog.Println(\"FAIL  %d data races detected\", races)\n")
		wrap.WriteString("\t\tfailed = failed + 1\n")
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
	// buildAndRun os.Exit(1)s on a failing test, so reaching the line
	// after it means every test/bench passed and the fresh bench JSON
	// (if any) was written.
	buildAndRun(augPath, srcPath)

	if benchComparePath != "" {
		if benchCompareTmp != "" {
			defer os.Remove(benchCompareTmp)
		}
		compareBenchJSON(benchComparePath, benchJSONPath, benchTolerancePct)
	}
}

// benchRecord mirrors testing.BenchResult's JSON encoding (the array
// element written by WriteBenchResultsJSON).
type benchRecord struct {
	Name      string `json:"name"`
	Iters     int64  `json:"iters"`
	PsPerOp   int64  `json:"ps_per_op"`
	NsElapsed int64  `json:"ns_elapsed"`
}

// readBenchJSON parses a bench-result JSON array from `path`.
func readBenchJSON(path string) ([]benchRecord, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var recs []benchRecord
	if err := json.Unmarshal(data, &recs); err != nil {
		return nil, fmt.Errorf("parse %s: %w", path, err)
	}
	return recs, nil
}

// compareBenchJSON diffs fresh bench results (newPath) against a
// baseline (oldPath). Any benchmark whose ps/op exceeds
// baseline*(1+tolerancePct/100) is a regression; benches present in
// the baseline but missing from the new run are reported as warnings.
// Exits non-zero if any regression is found.
func compareBenchJSON(oldPath, newPath string, tolerancePct int) {
	oldRecs, err := readBenchJSON(oldPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "volt: --bench-compare baseline: %v\n", err)
		os.Exit(1)
	}
	newRecs, err := readBenchJSON(newPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "volt: --bench-compare results: %v\n", err)
		os.Exit(1)
	}
	oldByName := make(map[string]benchRecord, len(oldRecs))
	for _, r := range oldRecs {
		oldByName[r.Name] = r
	}
	regressions := 0
	for _, nr := range newRecs {
		or, ok := oldByName[nr.Name]
		if !ok {
			fmt.Fprintf(os.Stderr, "bench %-24s NEW   %d ps/op (no baseline)\n", nr.Name, nr.PsPerOp)
			continue
		}
		// Allowed ceiling = baseline * (100 + tol) / 100.
		ceiling := or.PsPerOp * int64(100+tolerancePct) / 100
		deltaPct := 0.0
		if or.PsPerOp > 0 {
			deltaPct = float64(nr.PsPerOp-or.PsPerOp) * 100 / float64(or.PsPerOp)
		}
		if nr.PsPerOp > ceiling {
			regressions++
			fmt.Fprintf(os.Stderr, "bench %-24s REGRESS %d → %d ps/op (%+.1f%%, tol %d%%)\n",
				nr.Name, or.PsPerOp, nr.PsPerOp, deltaPct, tolerancePct)
		} else {
			fmt.Fprintf(os.Stderr, "bench %-24s ok      %d → %d ps/op (%+.1f%%)\n",
				nr.Name, or.PsPerOp, nr.PsPerOp, deltaPct)
		}
	}
	if regressions > 0 {
		fmt.Fprintf(os.Stderr, "FAIL  %d benchmark regression(s) over %d%% tolerance\n", regressions, tolerancePct)
		os.Exit(1)
	}
	fmt.Fprintf(os.Stderr, "ok    no benchmark regressions (tolerance %d%%)\n", tolerancePct)
}

// ---------------------------------------------------------------------
// volt memprofile — inspect / diff allocation profiles produced by
// `volt build --memprofile <path>` (or runtime.MemProfileDump).
//
//	volt memprofile <profile.json>            summarize one profile
//	volt memprofile <old.json> <new.json>     diff two profiles
//	  --top N        in summary mode, show the N hottest lines (default 10)
//	  --fail-on-growth   in diff mode, exit 1 if total alloc_bytes grew
// ---------------------------------------------------------------------

type mpClass struct {
	Bytes      int64 `json:"bytes"`
	Live       int64 `json:"live"`
	AllocCount int64 `json:"alloc_count"`
	AllocBytes int64 `json:"alloc_bytes"`
}

type mpLine struct {
	Line       int64 `json:"line"`
	AllocCount int64 `json:"alloc_count"`
	AllocBytes int64 `json:"alloc_bytes"`
}

type mpTotals struct {
	AllocCount int64 `json:"alloc_count"`
	FreeCount  int64 `json:"free_count"`
	LiveBytes  int64 `json:"live_bytes"`
}

type memProfile struct {
	SizeClasses []mpClass `json:"size_classes"`
	Huge        mpClass   `json:"huge"`
	ByLine      []mpLine  `json:"by_line"`
	Totals      mpTotals  `json:"totals"`
}

func readMemProfile(path string) (*memProfile, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var p memProfile
	if err := json.Unmarshal(data, &p); err != nil {
		return nil, fmt.Errorf("parse %s: %w", path, err)
	}
	return &p, nil
}

func runMemProfile(args []string) {
	topN := 10
	failOnGrowth := false
	var files []string
	for i := 0; i < len(args); i++ {
		switch args[i] {
		case "--top":
			if i+1 >= len(args) {
				fmt.Fprintln(os.Stderr, "volt memprofile: --top needs a number")
				os.Exit(2)
			}
			n, err := strconv.Atoi(args[i+1])
			if err != nil || n < 0 {
				fmt.Fprintf(os.Stderr, "volt memprofile: --top needs a non-negative integer, got %q\n", args[i+1])
				os.Exit(2)
			}
			topN = n
			i++
		case "--fail-on-growth":
			failOnGrowth = true
		default:
			files = append(files, args[i])
		}
	}
	switch len(files) {
	case 1:
		memProfileSummary(files[0], topN)
	case 2:
		memProfileDiff(files[0], files[1], failOnGrowth)
	default:
		fmt.Fprintln(os.Stderr, "usage: volt memprofile <profile.json> [--top N]")
		fmt.Fprintln(os.Stderr, "       volt memprofile <old.json> <new.json> [--fail-on-growth]")
		os.Exit(2)
	}
}

func memProfileSummary(path string, topN int) {
	p, err := readMemProfile(path)
	if err != nil {
		fmt.Fprintf(os.Stderr, "volt memprofile: %v\n", err)
		os.Exit(1)
	}
	fmt.Printf("profile %s\n", path)
	fmt.Printf("  totals: alloc=%d free=%d live_bytes=%d\n",
		p.Totals.AllocCount, p.Totals.FreeCount, p.Totals.LiveBytes)
	// Hottest lines by alloc_bytes.
	lines := append([]mpLine(nil), p.ByLine...)
	sort.Slice(lines, func(i, j int) bool { return lines[i].AllocBytes > lines[j].AllocBytes })
	fmt.Printf("  hottest %d line(s) by alloc_bytes:\n", topN)
	for i, l := range lines {
		if i >= topN {
			break
		}
		label := fmt.Sprintf("line %d", l.Line)
		if l.Line == 0 {
			label = "runtime/internal"
		}
		fmt.Printf("    %-18s %8d bytes  %6d allocs\n", label, l.AllocBytes, l.AllocCount)
	}
}

func memProfileDiff(oldPath, newPath string, failOnGrowth bool) {
	oldP, err := readMemProfile(oldPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "volt memprofile: baseline: %v\n", err)
		os.Exit(1)
	}
	newP, err := readMemProfile(newPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "volt memprofile: %v\n", err)
		os.Exit(1)
	}
	oldByLine := make(map[int64]mpLine, len(oldP.ByLine))
	for _, l := range oldP.ByLine {
		oldByLine[l.Line] = l
	}
	// Union of line keys, sorted by absolute byte delta (largest first).
	seen := make(map[int64]bool)
	type lineDelta struct {
		line          int64
		oldB, newB    int64
		oldC, newC    int64
	}
	var deltas []lineDelta
	for _, nl := range newP.ByLine {
		ol := oldByLine[nl.Line]
		deltas = append(deltas, lineDelta{nl.Line, ol.AllocBytes, nl.AllocBytes, ol.AllocCount, nl.AllocCount})
		seen[nl.Line] = true
	}
	for _, ol := range oldP.ByLine {
		if !seen[ol.Line] {
			deltas = append(deltas, lineDelta{ol.Line, ol.AllocBytes, 0, ol.AllocCount, 0})
		}
	}
	sort.Slice(deltas, func(i, j int) bool {
		return absI64(deltas[i].newB-deltas[i].oldB) > absI64(deltas[j].newB-deltas[j].oldB)
	})
	fmt.Printf("memprofile diff %s → %s\n", oldPath, newPath)
	fmt.Printf("  totals: alloc %d→%d  live_bytes %d→%d (%+d)\n",
		oldP.Totals.AllocCount, newP.Totals.AllocCount,
		oldP.Totals.LiveBytes, newP.Totals.LiveBytes,
		newP.Totals.LiveBytes-oldP.Totals.LiveBytes)
	for _, d := range deltas {
		db := d.newB - d.oldB
		if db == 0 {
			continue
		}
		label := fmt.Sprintf("line %d", d.line)
		if d.line == 0 {
			label = "runtime/internal"
		}
		tag := "  "
		if db > 0 {
			tag = "+ "
		}
		fmt.Printf("  %s%-18s %d→%d bytes (%+d), allocs %d→%d\n",
			tag, label, d.oldB, d.newB, db, d.oldC, d.newC)
	}
	if failOnGrowth && newP.Totals.LiveBytes > oldP.Totals.LiveBytes {
		fmt.Fprintf(os.Stderr, "FAIL  live_bytes grew %d → %d\n", oldP.Totals.LiveBytes, newP.Totals.LiveBytes)
		os.Exit(1)
	}
}

func absI64(x int64) int64 {
	if x < 0 {
		return -x
	}
	return x
}

// ---------------------------------------------------------------------
// volt mod — manage the volt.mod file (module declaration).
//
// `volt mod init <module-path>` writes a minimal volt.mod in the CWD.
// ---------------------------------------------------------------------

func runMod(args []string) {
	if len(args) < 1 {
		fmt.Fprintln(os.Stderr, "usage: volt mod init <module-path>")
		fmt.Fprintln(os.Stderr, "       volt mod get  <module-path>")
		fmt.Fprintln(os.Stderr, "       volt mod tidy <entry-file>")
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
	case "get":
		if len(args) < 2 {
			fmt.Fprintln(os.Stderr, "volt mod get: missing module path")
			os.Exit(2)
		}
		mod := args[1]
		if err := modGet(mod); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
	case "tidy":
		if len(args) < 2 {
			fmt.Fprintln(os.Stderr, "volt mod tidy: missing entry file (e.g. main.volt)")
			os.Exit(2)
		}
		if err := modTidy(args[1]); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
	case "verify":
		if err := modVerify(); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
	default:
		fmt.Fprintf(os.Stderr, "volt mod: unknown subcommand %q\n", args[0])
		os.Exit(2)
	}
}

// modGet clones the import-path's git repo into ~/.volt/pkg/<path>,
// then recursively fetches every package listed in the cloned repo's
// own `volt.mod` (if any). Convention: the import path is also the
// host+path component of the clone URL (e.g. "github.com/owner/repo"
// → "https://github.com/owner/repo.git"). If a directory already
// exists at the target, `git pull` is run to refresh it. The clone
// is shallow (depth=1) to keep the cache small.
func modGet(mod string) error {
	versions := map[string][]string{}
	if err := modGetWithSeen(mod, map[string]bool{}, versions); err != nil {
		return err
	}
	// MVS summary: when transitive walks surfaced multiple version
	// constraints for the same path, print the resolved (max) version.
	// Silent when each path was required at a single version (no
	// conflict to report).
	for path, vs := range versions {
		if len(vs) < 2 {
			continue
		}
		picked := modfile.SelectVersion(vs)
		fmt.Printf("volt mod get: %s resolved to %s (from %d requirements: %s)\n",
			path, picked, len(vs), strings.Join(vs, ", "))
	}
	return nil
}

// modGetWithSeen is modGet's internal recursive form, tracking
// already-fetched paths to break dependency cycles and accumulating
// the set of version constraints seen for each transitively-required
// path. `versions` is path → list of required version strings.
func modGetWithSeen(mod string, seen map[string]bool, versions map[string][]string) error {
	if seen[mod] {
		return nil
	}
	seen[mod] = true
	if !strings.Contains(mod, "/") || strings.Contains(mod, "..") {
		return fmt.Errorf("volt mod get: %q doesn't look like an import path (need host/owner/repo)", mod)
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("volt mod get: cannot find HOME: %w", err)
	}
	dst := filepath.Join(home, ".volt", "pkg", mod)
	existed := false
	if info, err := os.Stat(dst); err == nil && info.IsDir() {
		existed = true
	}
	if existed {
		fmt.Printf("volt mod get: refreshing %s\n", dst)
		// Only attempt git-pull if the cache dir is actually a checkout.
		// User-placed fixtures (no .git) just get re-hashed.
		if _, err := os.Stat(filepath.Join(dst, ".git")); err == nil {
			cmd := exec.Command("git", "-C", dst, "pull", "--ff-only")
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
			if err := cmd.Run(); err != nil {
				return fmt.Errorf("volt mod get: git pull failed: %w", err)
			}
		}
	} else {
		if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
			return fmt.Errorf("volt mod get: %w", err)
		}
		url := "https://" + mod + ".git"
		fmt.Printf("volt mod get: cloning %s into %s\n", url, dst)
		cmd := exec.Command("git", "clone", "--depth=1", url, dst)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err != nil {
			return fmt.Errorf("volt mod get: git clone failed: %w", err)
		}
	}

	// Update volt.mod (if it exists) and volt.sum with this dependency.
	if err := updateModManifest(mod, dst); err != nil {
		// Non-fatal: the cache is populated even if manifest update
		// fails (e.g. no volt.mod in cwd). Print a hint.
		fmt.Fprintf(os.Stderr, "volt mod get: %v\n", err)
	}
	// Pin to the workspace's required version, if any. The pin is a
	// best-effort `git checkout <tag>` — missing tags / unsynced repos
	// emit a warning but don't error (the user can `volt mod get`
	// again after fixing the tag).
	loadModOnce()
	if v := loadedModRequires[mod]; v != "" {
		if err := gitCheckoutTagAt(dst, v); err != nil {
			fmt.Fprintf(os.Stderr, "volt mod get: %s pinned to %s but checkout failed: %v\n", mod, v, err)
		}
	}
	// Transitive fetch: walk the cloned repo's own volt.mod (if any)
	// and recursively fetch its `require` entries. Failures here are
	// non-fatal — print a warning and continue, since the immediate
	// dep is already on disk and the user can `volt mod get` the
	// missing transitive deps explicitly.
	if reqs, err := readDepRequiresFull(dst); err == nil {
		for _, r := range reqs {
			if r.Path == mod {
				continue
			}
			if r.Version != "" {
				versions[r.Path] = append(versions[r.Path], r.Version)
			}
			if seen[r.Path] {
				continue
			}
			if err := modGetWithSeen(r.Path, seen, versions); err != nil {
				fmt.Fprintf(os.Stderr, "volt mod get: transitive %s: %v\n", r.Path, err)
			}
		}
	}
	return nil
}

// readDepRequires loads `<dir>/volt.mod` and returns its require
// paths, or (nil, nil) if no manifest is present. Errors only on a
// malformed manifest.
func readDepRequires(dir string) ([]string, error) {
	reqs, err := readDepRequiresFull(dir)
	if err != nil || reqs == nil {
		return nil, err
	}
	out := make([]string, 0, len(reqs))
	for _, r := range reqs {
		out = append(out, r.Path)
	}
	return out, nil
}

// gitCheckoutTagAt switches the repo at `dir` to the tag `version`.
// Strategy: try a direct `git checkout <version>` first — for repos
// that already have all tags (typical when the user has cloned with
// full history) this is the fastest path. If that fails, do a
// shallow tag fetch (`git fetch --depth=1 origin tag <version>`) and
// retry the checkout. The function is best-effort: it returns the
// LAST error it saw so callers can warn but proceed.
//
// Skipped silently when `dir` is not a git checkout (no `.git`) —
// user-placed fixtures stay as-is.
func gitCheckoutTagAt(dir, version string) error {
	if _, err := os.Stat(filepath.Join(dir, ".git")); err != nil {
		return nil
	}
	co := func() error {
		cmd := exec.Command("git", "-C", dir, "-c", "advice.detachedHead=false", "checkout", "--quiet", version)
		cmd.Stderr = nil
		return cmd.Run()
	}
	if err := co(); err == nil {
		return nil
	}
	// Tag not present locally — shallow-fetch it then retry.
	fetch := exec.Command("git", "-C", dir, "fetch", "--depth=1", "origin", "tag", version, "--quiet")
	fetch.Stderr = nil
	_ = fetch.Run()
	return co()
}

// readDepRequiresFull returns the parsed require entries (path +
// version) from `<dir>/volt.mod`, or (nil, nil) if no manifest.
func readDepRequiresFull(dir string) ([]modfile.Require, error) {
	data, err := os.ReadFile(filepath.Join(dir, "volt.mod"))
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil
		}
		return nil, err
	}
	mf, err := modfile.Parse(data)
	if err != nil {
		return nil, err
	}
	return mf.Require, nil
}

// modVerify re-hashes every package listed in `./volt.sum` and exits
// non-zero on any mismatch. Useful as a CI gate after `volt mod tidy`
// to ensure the cache hasn't been tampered with.
func modVerify() error {
	data, err := os.ReadFile("volt.sum")
	if err != nil {
		if os.IsNotExist(err) {
			fmt.Println("volt mod verify: no volt.sum — nothing to verify")
			return nil
		}
		return err
	}
	sums, err := modfile.ParseSum(data)
	if err != nil {
		return err
	}
	home, _ := os.UserHomeDir()
	if home == "" {
		return fmt.Errorf("volt mod verify: cannot find HOME")
	}
	bad := 0
	for _, e := range sums {
		base := filepath.Join(home, ".volt", "pkg", e.Path)
		if _, err := os.Stat(base); err != nil {
			fmt.Fprintf(os.Stderr, "MISSING %s %s — run `volt mod get %s`\n",
				e.Path, e.Version, e.Path)
			bad++
			continue
		}
		got, err := modfile.HashPackageDir(base)
		if err != nil {
			fmt.Fprintf(os.Stderr, "ERROR   %s: %v\n", e.Path, err)
			bad++
			continue
		}
		if got != e.Hash {
			fmt.Fprintf(os.Stderr,
				"MISMATCH %s %s: on-disk h1:%s, volt.sum h1:%s\n",
				e.Path, e.Version,
				got[:min(12, len(got))], e.Hash[:min(12, len(e.Hash))])
			bad++
			continue
		}
		fmt.Printf("ok      %s %s\n", e.Path, e.Version)
	}
	if bad > 0 {
		return fmt.Errorf("volt mod verify: %d package(s) failed verification", bad)
	}
	return nil
}

// modTidy walks the import graph rooted at `entry` and reconciles
// `./volt.mod`'s `require` list against the actual non-stdlib imports.
// Missing requires are added; orphaned ones are dropped. `./volt.sum`
// is regenerated from the surviving requires by hashing their cache
// directories. Stdlib packages (resolvable via `stdlib.Source`) and
// local sub-packages (resolvable via `./<path>/...`) don't generate
// require entries — only externally-fetched packages do.
func modTidy(entry string) error {
	modData, err := os.ReadFile("volt.mod")
	if err != nil {
		if os.IsNotExist(err) {
			return fmt.Errorf("volt mod tidy: no volt.mod in current directory (run `volt mod init`)")
		}
		return err
	}
	mf, err := modfile.Parse(modData)
	if err != nil {
		return err
	}

	// Walk imports from `entry`, recording every non-stdlib + non-local
	// package path we touch.
	external := map[string]bool{}
	seen := map[string]bool{}
	src, err := os.ReadFile(entry)
	if err != nil {
		return fmt.Errorf("volt mod tidy: %w", err)
	}
	root, err := parseSource(entry, src)
	if err != nil {
		return err
	}
	queue := append([]string(nil), root.imports...)
	for len(queue) > 0 {
		path := queue[0]
		queue = queue[1:]
		if seen[path] {
			continue
		}
		seen[path] = true
		if _, ok := stdlib.Source(path); ok {
			continue
		}
		// Try local first; if found, follow its imports but don't
		// require it.
		isLocal := false
		last := path
		if i := strings.LastIndex(path, "/"); i >= 0 {
			last = path[i+1:]
		}
		for _, c := range []string{filepath.Join(path, last+".volt"), filepath.Join(path, path+".volt")} {
			if data, err := os.ReadFile(c); err == nil {
				u, err := parseSource(c, data)
				if err == nil {
					queue = append(queue, u.imports...)
				}
				isLocal = true
				break
			}
		}
		if isLocal {
			continue
		}
		external[path] = true
		// Recurse into the cache copy to pull its transitive imports.
		home, _ := os.UserHomeDir()
		if home != "" {
			base := filepath.Join(home, ".volt", "pkg", path)
			for _, name := range []string{last + ".volt", path + ".volt"} {
				c := filepath.Join(base, name)
				if data, err := os.ReadFile(c); err == nil {
					u, err := parseSource(c, data)
					if err == nil {
						queue = append(queue, u.imports...)
					}
					break
				}
			}
		}
	}

	// Preserve existing version pins where the require is still needed;
	// fall back to v0.0.0-local for newly-added ones.
	oldVer := map[string]string{}
	for _, r := range mf.Require {
		oldVer[r.Path] = r.Version
	}
	mf.Require = mf.Require[:0]
	var paths []string
	for p := range external {
		paths = append(paths, p)
	}
	sort.Strings(paths)
	for _, p := range paths {
		ver := oldVer[p]
		if ver == "" {
			ver = "v0.0.0-local"
		}
		mf.Require = append(mf.Require, modfile.Require{Path: p, Version: ver})
	}
	if err := os.WriteFile("volt.mod", mf.Format(), 0o644); err != nil {
		return err
	}

	// Rebuild volt.sum from the surviving requires.
	var sums []modfile.SumEntry
	home, _ := os.UserHomeDir()
	for _, r := range mf.Require {
		if home == "" {
			break
		}
		base := filepath.Join(home, ".volt", "pkg", r.Path)
		if _, err := os.Stat(base); err != nil {
			fmt.Fprintf(os.Stderr,
				"volt mod tidy: warning: %s not in cache; run `volt mod get %s`\n",
				r.Path, r.Path)
			continue
		}
		hash, err := modfile.HashPackageDir(base)
		if err != nil {
			return err
		}
		sums = append(sums, modfile.SumEntry{
			Path: r.Path, Version: r.Version, Hash: hash,
		})
	}
	if len(sums) == 0 {
		// Remove a stale volt.sum so the directory matches the empty
		// require list.
		_ = os.Remove("volt.sum")
	} else {
		if err := os.WriteFile("volt.sum", modfile.FormatSum(sums), 0o644); err != nil {
			return err
		}
	}
	fmt.Printf("volt mod tidy: %d external require(s)\n", len(mf.Require))
	return nil
}

// updateModManifest reads ./volt.mod (creating one isn't this command's
// job — that's `volt mod init`), adds/updates a `require` line for
// `mod` pinned to the version derived from the cache directory (a git
// HEAD sha or "v0.0.0-local" for hand-placed fixtures), and updates
// ./volt.sum with the package's content hash.
func updateModManifest(mod, pkgDir string) error {
	modPath := "volt.mod"
	modData, err := os.ReadFile(modPath)
	if err != nil {
		if os.IsNotExist(err) {
			return fmt.Errorf("no volt.mod in current directory (run `volt mod init`)")
		}
		return err
	}
	mf, err := modfile.Parse(modData)
	if err != nil {
		return err
	}

	// Derive a pin: git rev-parse HEAD when available, else a sentinel.
	version := "v0.0.0-local"
	if _, statErr := os.Stat(filepath.Join(pkgDir, ".git")); statErr == nil {
		out, gerr := exec.Command("git", "-C", pkgDir, "rev-parse", "--short", "HEAD").Output()
		if gerr == nil {
			version = "v0.0.0-" + strings.TrimSpace(string(out))
		}
	}
	mf.AddRequire(mod, version)
	if err := os.WriteFile(modPath, mf.Format(), 0o644); err != nil {
		return err
	}

	// Hash the package directory and upsert into volt.sum.
	hash, err := modfile.HashPackageDir(pkgDir)
	if err != nil {
		return err
	}
	sumPath := "volt.sum"
	var sums []modfile.SumEntry
	if data, err := os.ReadFile(sumPath); err == nil {
		sums, err = modfile.ParseSum(data)
		if err != nil {
			return err
		}
	} else if !os.IsNotExist(err) {
		return err
	}
	sums = modfile.UpsertSum(sums, modfile.SumEntry{
		Path: mod, Version: version, Hash: hash,
	})
	if err := os.WriteFile(sumPath, modfile.FormatSum(sums), 0o644); err != nil {
		return err
	}
	fmt.Printf("volt mod get: %s %s in volt.mod / volt.sum (h1:%s…)\n",
		mod, version, hash[:min(12, len(hash))])
	return nil
}

// ---------------------------------------------------------------------
// volt doc — list exported (Capitalized) top-level declarations.
// ---------------------------------------------------------------------

func runDoc(args []string) {
	if len(args) < 1 {
		fmt.Fprintln(os.Stderr, "usage: volt doc <file|stdlib-pkg>")
		os.Exit(2)
	}
	srcPath := args[0]
	// First try: stdlib lookup. If arg doesn't end in .volt and
	// resolves via stdlib.Source (directly or via shortname), use
	// the embedded source.
	var src []byte
	var resolved string
	if !strings.HasSuffix(srcPath, ".volt") {
		if data, ok := stdlib.Source(srcPath); ok {
			src = data
			resolved = srcPath + " (stdlib)"
		} else if full, ok := docStdlibShortName(srcPath); ok {
			if data, ok := stdlib.Source(full); ok {
				src = data
				resolved = full + " (stdlib)"
			}
		}
	}
	if src == nil {
		var err error
		src, err = os.ReadFile(srcPath)
		if err != nil {
			// If the user clearly meant a stdlib package (no .volt
			// extension, no slash) but it didn't resolve, surface a
			// friendly error with a did-you-mean hint when possible.
			if !strings.HasSuffix(srcPath, ".volt") && !strings.Contains(srcPath, "/") {
				if guess := suggestStdlibImport(srcPath); guess != "" {
					fmt.Fprintf(os.Stderr, "volt doc: no stdlib package %q (did you mean %q?)\n", srcPath, guess)
				} else {
					fmt.Fprintf(os.Stderr, "volt doc: no stdlib package %q (and no file %s)\n", srcPath, srcPath)
				}
				os.Exit(1)
			}
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		resolved = srcPath
	}
	u, err := parseSource(resolved, src)
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

// docStdlibShortName resolves a stdlib package short-name to its
// full path via the embedded FS — single source of truth lives in
// internal/stdlib (avoids hardcoded duplication across files).
func docStdlibShortName(short string) (string, bool) {
	if full, ok := stdlib.ShortNameToPath()[short]; ok {
		return full, true
	}
	return "", false
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
	if buildTarget == "" {
		buildTarget = "amd64"
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
		// Project convention: tests-internal/*.volt mains return 42 on
		// pass (the smoke scripts grep for it). Treat 42 as pass too so
		// `volt test` works on legacy-style test files unchanged.
		if exitErr.ExitCode() == 42 {
			fmt.Fprintf(os.Stderr, "ok    %s\n", label)
			return
		}
		fmt.Fprintf(os.Stderr, "FAIL  %s (%d failed)\n", label, exitErr.ExitCode())
		os.Exit(1)
	}
	fmt.Fprintf(os.Stderr, "FAIL  %s (%v)\n", label, err)
	os.Exit(1)
}
