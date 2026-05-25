package main_test

import (
	"bytes"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"testing"
)

// projectRoot resolves the module root from this test file's location.
func projectRoot(t *testing.T) string {
	t.Helper()
	_, file, _, ok := runtime.Caller(0)
	if !ok {
		t.Fatal("can't locate test file")
	}
	return filepath.Dir(filepath.Dir(filepath.Dir(file)))
}

// buildCompiler builds the volt binary into tempdir and returns the path.
func buildCompiler(t *testing.T) string {
	t.Helper()
	root := projectRoot(t)
	out := filepath.Join(t.TempDir(), "volt")
	cmd := exec.Command("go", "build", "-o", out, "./cmd/volt")
	cmd.Dir = root
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		t.Fatalf("build volt: %v", err)
	}
	return out
}

// runCase compiles tests-internal/<name>.volt and runs the resulting binary,
// returning its exit code, stdout, and stderr.
func runCase(t *testing.T, volt, name string) (exit int, stdout, stderr string) {
	t.Helper()
	root := projectRoot(t)
	dir := t.TempDir()
	src := filepath.Join(root, "tests-internal", name+".volt")

	build := exec.Command(volt, "build", src)
	build.Dir = dir
	var buildErr bytes.Buffer
	build.Stderr = &buildErr
	if err := build.Run(); err != nil {
		t.Fatalf("volt build %s: %v\nstderr:\n%s", name, err, buildErr.String())
	}

	bin := filepath.Join(dir, name)
	run := exec.Command(bin)
	var outBuf, errBuf bytes.Buffer
	run.Stdout = &outBuf
	run.Stderr = &errBuf
	err := run.Run()
	if exitErr, ok := err.(*exec.ExitError); ok {
		exit = exitErr.ExitCode()
	} else if err == nil {
		exit = 0
	} else {
		t.Fatalf("./%s: %v", name, err)
	}
	return exit, outBuf.String(), errBuf.String()
}

func TestEmptyMain(t *testing.T) {
	volt := buildCompiler(t)
	exit, stdout, stderr := runCase(t, volt, "empty")
	if exit != 0 || stdout != "" || stderr != "" {
		t.Errorf("empty: got exit=%d stdout=%q stderr=%q; want exit=0 no output", exit, stdout, stderr)
	}
}

func TestHelloWorld(t *testing.T) {
	volt := buildCompiler(t)
	exit, stdout, stderr := runCase(t, volt, "hello")
	if exit != 0 {
		t.Errorf("hello: exit=%d, want 0", exit)
	}
	if stderr != "hello, world\n" {
		t.Errorf("hello: stderr=%q, want %q", stderr, "hello, world\n")
	}
	if stdout != "" {
		t.Errorf("hello: unexpected stdout=%q", stdout)
	}
}

// Table-driven test for v0.2 programs that observe correctness via exit code.
func TestExitCodes(t *testing.T) {
	volt := buildCompiler(t)
	cases := []struct {
		name     string
		wantExit int
	}{
		{"exit42", 42},
		{"square", 49}, // 7*7
		{"arith", 42},  // 10 + 5*2 + 7 + 15
		{"branch", 12}, // max(7,12)
		{"loop", 55},   // sum 1..10
		{"cfor", 55},   // sum 1..10 (C-style for)
		{"fib", 55},    // fib(10)
		{"borrow", 42},       // triple(14) via &int param
		{"borrow_ok", 0},     // borrow doesn't move; reusable
		{"struct_basic", 42}, // Point{x:30, y:12} → x+y
		{"struct_pass", 42},  // sum(&Counter{15,27})
		{"defer_basic", 3},   // 3 deferred Println in LIFO order
		{"methods", 42},      // c.total() via &Counter method
		{"field_assign", 42}, // 3 bumps on Counter{39}
		{"switch_basic", 42}, // 100+200+300-558
		{"slice_basic", 42},  // sum + len
		{"numeric", 42},      // i8+i16+i32+i64 widening
		{"run_sync", 42},     // run greet(): real-thread spawn; main returns 42
		{"chan_basic", 42},   // push 1..6, drain+sum, *2
		{"concurrent", 42},   // 2 OS threads + blocking chan + done signal
		{"multireturn", 42},  // divmod(17,5) → q + r*20 - 1
		{"breakcontinue", 42},// sum odd 1..15 with continue, break > 15
		{"const_basic", 42},  // FORTY + TWO
		{"maps", 42},         // map[string]int set/get/len
		{"chan_close", 42},   // close() + v,ok recv
		{"select_basic", 42}, // select picks ready case
		{"select_default", 42}, // select with default
		{"drop", 42},               // automatic Drop() at scope exit
		{"return_param_borrow", 42}, // returning a borrow of a param is OK
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			exit, _, _ := runCase(t, volt, c.name)
			if exit != c.wantExit {
				t.Errorf("%s: exit=%d, want %d", c.name, exit, c.wantExit)
			}
		})
	}
}

// Greet exercises strings flowing through user functions, then into
// log.Println across the multi-package boundary.
func TestGreet(t *testing.T) {
	volt := buildCompiler(t)
	exit, _, stderr := runCase(t, volt, "greet")
	if exit != 0 {
		t.Errorf("greet: exit=%d, want 0", exit)
	}
	if stderr != "Alice\nBob\n" {
		t.Errorf("greet: stderr=%q, want %q", stderr, "Alice\nBob\n")
	}
}

// TestBorrowCheckerRejects asserts the borrow checker catches a clear
// use-after-move at compile time (build fails, no binary produced).
func TestBorrowCheckerRejects(t *testing.T) {
	volt := buildCompiler(t)
	root := projectRoot(t)
	src := filepath.Join(root, "tests-internal", "use_after_move.volt")
	cmd := exec.Command(volt, "build", src)
	cmd.Dir = t.TempDir()
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err := cmd.Run(); err == nil {
		t.Fatalf("expected build to fail for use_after_move, but it succeeded")
	}
	if !bytes.Contains(stderr.Bytes(), []byte("use of moved value")) {
		t.Errorf("expected diagnostic about moved value; got:\n%s", stderr.String())
	}
}

// TestBorrowCheckerNegatives covers other compile-time rejections.
func TestBorrowCheckerNegatives(t *testing.T) {
	volt := buildCompiler(t)
	root := projectRoot(t)
	cases := []struct {
		name, expect string
	}{
		{"aliasing", "multiple read/write accesses in the same call"},
		{"move_xpkg", "use of moved value"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			src := filepath.Join(root, "tests-internal", c.name+".volt")
			cmd := exec.Command(volt, "build", src)
			cmd.Dir = t.TempDir()
			var stderr bytes.Buffer
			cmd.Stderr = &stderr
			if err := cmd.Run(); err == nil {
				t.Fatalf("%s: expected build to fail but it succeeded", c.name)
			}
			if !bytes.Contains(stderr.Bytes(), []byte(c.expect)) {
				t.Errorf("%s: expected %q in stderr, got:\n%s", c.name, c.expect, stderr.String())
			}
		})
	}
}
