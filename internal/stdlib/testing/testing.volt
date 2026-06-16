// Package testing: lightweight unit-test scaffolding.
//
// Surface (v1):
//   type T          — per-test failure-tracking handle
//   (t *T).Name()                 — test name
//   (t *T).Error(msg string)      — record a failure (test continues)
//   (t *T).Errorf(msg string)     — alias of Error (caller pre-formats
//                                   via fmt.Sprintf — volt doesn't yet
//                                   expose varargs to user code)
//   (t *T).Fatal(msg string)      — record a failure + sets `fatal`
//                                   (caller should `ret` from the test)
//   (t *T).Failed() bool          — true if any Error/Fatal fired
//   Run(name string, fn fun(t *T)) bool  — run one test, return pass/fail
//
// Subtests, benchmarks, table-driven helpers, parallel execution and
// the -race flag are all deferred — they need richer machinery
// (subtest registry, benchmark loop, race-instrumentation runtime).
//
// Usage pattern: each test file has a `main` that calls `testing.Run`
// once per test function. Exit 42 means all tests passed; anything
// else means at least one failed. Matches the existing convention
// for `tests-internal/*.volt`.

package testing

import "log"
import "time"
import "os"
import "bytes"
import "strconv"

type T struct {
    name     string
    failed   bool
    fatal    bool
    parallel bool
}

fun NewT(name string) *T {
    var t *T = new T {name: name, failed: false, fatal: false, parallel: false}
    ret t
}

fun (t *T) Name() string  { ret t.name }
fun (t *T) Failed() bool  { ret t.failed }
fun (t *T) Fatal_() bool  { ret t.fatal }

fun (t *T) Error(msg string) {
    t.failed = true
    log.Println("FAIL %s: %s", t.name, msg)
}

fun (t *T) Errorf(msg string) {
    t.Error(msg)
}

fun (t *T) Fatal(msg string) {
    t.failed = true
    t.fatal = true
    log.Println("FATAL %s: %s", t.name, msg)
}

// Run invokes fn against a fresh T and reports whether it passed
// (no Error/Fatal calls). Prints a one-line PASS/FAIL summary.
fun Run(name string, fn fun(t *T)) bool {
    var t *T = NewT(name)
    fn(t)
    if t.failed {
        log.Println("--- FAIL: %s", name)
        ret false
    }
    log.Println("--- PASS: %s", name)
    ret true
}

// Parallel marks the current test as parallel-safe. Today this is a
// marker only — actual parallel execution is opt-in via the harness
// using `RunParallel([]NamedTest{...})`. Calling Parallel from inside
// a test invoked via plain `Run` is a no-op.
fun (t *T) Parallel() {
    t.parallel = true
}

fun (t *T) IsParallel() bool { ret t.parallel }

// NamedTest pairs a name with a test function. Used by RunParallel
// to dispatch a batch.
type NamedTest struct {
    name string
    fn   fun(t *T)
}

fun NewNamedTest(name string, fn fun(t *T)) NamedTest {
    ret new NamedTest {name: name, fn: fn}
}

// runOneParallel is the per-thread worker used by RunParallel. Each
// thread builds its own T, invokes fn, prints PASS/FAIL, increments
// the shared `passed` counter on success, and signals Done.
fun runOneParallel(name string, fn fun(t *T), passed atomic int, wg waitgroup) {
    var t *T = NewT(name)
    fn(t)
    if t.failed {
        log.Println("--- FAIL: %s", name)
    } else {
        log.Println("--- PASS: %s", name)
        passed.Add(1)
    }
    wg.Done()
}

// RunParallel runs every test in `tests` on its own OS thread,
// waits for them all to finish, and returns the count that passed.
// Tests share no implicit state — each gets a fresh *T. Use this
// only for tests you've verified are parallel-safe (no shared
// mutable globals beyond what's wrapped in atomic / mutex).
fun RunParallel(tests []NamedTest) int {
    var passed atomic int = new {}
    var wg waitgroup = new()
    var n int = len(tests)
    for i:=0; i < n; i++ {
        wg.Add(1)
        run runOneParallel(tests[i].name, tests[i].fn, passed, wg)
    }
    wg.Wait()
    ret passed.Read()
}

// (t *T).Run is the subtest helper. The sub-test gets its own fresh T
// with name "parent/sub" and runs fn against it. If the subtest fails,
// the parent is also marked failed so a top-level harness check picks
// it up. Subtests can nest arbitrarily (each level adds "/name").
fun (t *T) Run(subname string, fn fun(t *T)) bool {
    var fullName string = t.name + "/" + subname
    var sub *T = NewT(fullName)
    fn(sub)
    if sub.failed {
        t.failed = true
        log.Println("    --- FAIL: %s", fullName)
        ret false
    }
    log.Println("    --- PASS: %s", fullName)
    ret true
}

// ---- Benchmarks ----------------------------------------------------
//
// B carries the iteration count `N` the harness wants the benchmark
// to run. The harness picks an N that takes roughly `BenchTimeNs`
// nanoseconds (1 sec default). A benchmark body looks like:
//
//   fun BenchmarkAdd(b *B) {
//       for i := 0; i < b.N; i++ { ... }
//   }
//
// The harness measures via `time.Mono()` and reports `ns/op`.

type B struct {
    name      string
    N         int        // iteration count
    nsElapsed int
}

fun (b *B) Name() string  { ret b.name }
fun (b *B) NsElapsed() int { ret b.nsElapsed }

// Default budget for a single benchmark: ~1 second total wall time.
fun BenchTimeNs() int { ret 1000000000 }

// BenchResult is the per-bench payload returned by RunBenchmark and
// consumed by WriteBenchResultsJSON. Stable across passes so CI
// tooling can parse the JSON file without re-discovery.
type BenchResult struct {
    Name      string
    Iters     int
    PsPerOp   int
    NsElapsed int
}

// RunBenchmark calibrates N (ramping by 10x) until wall time crosses
// BenchTimeNs, then reports `ns/op`. Reasonable for cheap operations;
// slow ops finish their first iteration past the budget and just
// report whatever they got. Returns the recorded BenchResult so the
// caller (synthesized harness or hand-written main) can collect
// results for downstream JSON aggregation.
fun RunBenchmark(name string, fn fun(b *B)) BenchResult {
    var n int = 1
    var budget int = BenchTimeNs()
    var cap int = 10000000000              // 10B iterations ceiling
    for n <= cap {
        var b *B = new B {name: name, N: n, nsElapsed: 0}
        var t0 int = time.Mono()
        fn(b)
        var t1 int = time.Mono()
        var elapsed int = t1 - t0
        if elapsed >= budget {
            // Report ps/op so sub-nanosecond ops don't truncate to 0.
            // ns/op = ps_per_op / 1000.
            var psPerOp int = (elapsed * 1000) / n
            log.Println("BENCH %s: %d iters, %d ps/op (%d ns total)",
                name, n, psPerOp, elapsed)
            ret new BenchResult {
                Name: name, Iters: n, PsPerOp: psPerOp, NsElapsed: elapsed,
            }
        }
        if n == cap { break }              // last iteration done; report what we got
        n = n * 10
        if n > cap { n = cap }
    }
    log.Println("BENCH %s: hit cap %d iters without reaching budget", name, cap)
    ret new BenchResult { Name: name, Iters: cap, PsPerOp: 0, NsElapsed: 0 }
}

// WriteBenchResultsJSON dumps `results` to `path` as a JSON array of
// {"name","iters","ps_per_op","ns_elapsed"} objects. Returns 0 on
// success and a non-zero errno on file-write failure. Intentionally
// stable + minimal so CI tools can:
//   * compare two runs by name
//   * gate on ps_per_op regression
//   * track historical trends
fun WriteBenchResultsJSON(results []BenchResult, path string) int {
    var buf bytes.Builder = new bytes.Builder{}
    buf.WriteByte(91)        // '['
    var n int = len(results)
    for i := 0; i < n; i++ {
        if i > 0 { buf.WriteByte(44) }   // ','
        buf.WriteString("{\"name\":\"")
        buf.WriteString(results[i].Name)
        buf.WriteString("\",\"iters\":")
        buf.WriteString(strconv.Itoa(results[i].Iters))
        buf.WriteString(",\"ps_per_op\":")
        buf.WriteString(strconv.Itoa(results[i].PsPerOp))
        buf.WriteString(",\"ns_elapsed\":")
        buf.WriteString(strconv.Itoa(results[i].NsElapsed))
        buf.WriteByte(125)               // '}'
    }
    buf.WriteByte(93)        // ']'
    buf.WriteByte(10)        // '\n'
    var data string = buf.String()
    var err error = os.WriteFile(path, data, 420)      // 0644
    if err != nil { ret 1 }
    ret 0
}

// AssertEqInt fails the test t with a descriptive message if got
// != want. Returns true on equal, false on failure (so callers can
// short-circuit further checks).
fun AssertEqInt(t *T, got int, want int) bool {
    if got == want { ret true }
    t.Error("AssertEqInt failed")
    ret false
}

// AssertEqString fails t if got != want (byte-equal compare).
fun AssertEqString(t *T, got string, want string) bool {
    if got == want { ret true }
    t.Error("AssertEqString failed")
    ret false
}

// AssertTrue fails t if cond is false.
fun AssertTrue(t *T, cond bool) bool {
    if cond { ret true }
    t.Error("AssertTrue: condition was false")
    ret false
}

// AssertFalse fails t if cond is true.
fun AssertFalse(t *T, cond bool) bool {
    if !cond { ret true }
    t.Error("AssertFalse: condition was true")
    ret false
}

// AssertNil fails t if err is not nil.
fun AssertNil(t *T, err error) bool {
    if err == nil { ret true }
    t.Error("AssertNil: error was not nil")
    ret false
}

// AssertNotNil fails t if err is nil.
fun AssertNotNil(t *T, err error) bool {
    if err != nil { ret true }
    t.Error("AssertNotNil: error was nil")
    ret false
}
