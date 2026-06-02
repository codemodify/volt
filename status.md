# volt — implementation status

_Last updated: 2026-06-02 (pass 759). Branch: `dev`._

**volt** is a systems language with **Go-flavored syntax** and a **Rust-style
ownership/borrow memory model**. It compiles to **LLVM IR**, targets **Linux
amd64 + arm64**, and ships **no libc** — the runtime is a self-contained
`runtime.c` + hand-written `_start` assembly.

Health snapshot: **749 buildable regression programs**, **50 expected-negative
(intentional compile-fail) tests**, **0 runtime crashes**.

---

## 1. Language features — implemented

### Types & values
- Primitives: `int`, sized ints (`int8/16/32/64`), `bool`, `byte`, `string`.
- Composite: `struct`, slices (`[]T`), maps (`map[K]V`), arrays-with-size.
- Pointers `*T`; borrows `&T` (shared) / `&mut T` (exclusive).
- Interfaces (structural, vtable-dispatched) + the `any` type.
- First-class function values + closures (capture by move/copy; env synthesis;
  `%fn_value` fat pointers).
- `nil`, `true`, `false`; sentinel `error` values.

### Syntax / surface
- `fun name(params) ret { ... }`; method receivers `fun (r *T) M()`.
- Declarations: `var x T = v`, `x := v` (no spaces), `const`.
- Composite literals: `new {…}` (no size), `new(N) T {…}` (sized), `T{a: 1}`.
- Control flow: `if/else`, `for` (C-style + `for k, v := range`), `switch`,
  `break`/`continue`, bare blocks `{ … }`, `ret`.
- `def` (deferred calls), `import`, `package`.
- Unary `&` / `&mut` / `*`; `i++` / `i--`.
- Keywords: `atomic break case chan condvar const continue def default else
  false for fun if import interface map mut mutex new nil once package range
  ret run rwmutex select struct switch true type var waitgroup`.

### Memory model & ownership (Rust-style, no GC)
- **Move semantics** with per-type detection: Copy primitives copy; movables
  move; reference handles (chan/mutex) share.
- **Use-after-move** rejection; field/index move tracking.
- **A3 — auto-free on Drop** for owned slice/map/string locals; recursive Drop;
  literal-safe (heap-range tracker distinguishes heap vs `.rodata`).
- **Borrow checker (C8) phases 1–6:**
  - `&T` (many shared) vs `&mut T` (exclusive) — mutually exclusive.
  - Block-scoped borrow release; source frozen for the borrow's lifetime.
  - Cross-function call-site lifetime tracking.
  - Cross-statement alias tracking (`var b2 = b1`).
- **Reborrow:** `&mut *b`, `&*b`, `&mut s.field`, `&mut a[i]` (partial borrows;
  conservative whole-container freeze).
- **Cross-package borrow checks:** free-function args, method **receivers**, and
  method **arguments**.
- **C13 closure-capture escape proofs:** a closure capturing a borrow can't
  escape via return, `run`, struct field, slice/map element, or indexed assign.
- Drop-auto-close on files; RAII mutex guards.

### Concurrency
- `run f(args)` — real OS threads (up to 6 args, heap-boxed thunks for more).
- **Channels:** unbuffered/rendezvous by default (`new()`); directional
  `chan read T` / `chan write T`; multiplicity contracts `chan11 / chan1N /
  chanN1 / chanNN` (compile-time discipline); mutex-backed **and** Vyukov
  lock-free MPMC backends (`--channels mutex|lockfree`).
- **Sync primitives:** `mutex`, `rwmutex` (both Drop-releasing guards),
  `atomic` (i64/i32/i16/i8/bool/ptr — `Read`/`Write`/`Add`/`CompSwap`),
  `waitgroup`, `once.Do(fn)`, `condvar`.
- Borrows cannot cross thread boundaries (`run` rejects borrow args).
- **Race detector (`-race`):** vector clocks per thread, per-message
  happens-before on channels, sync-op + heap-data instrumentation (struct
  fields, slice/map elements, **and pointer derefs**), source-line reports,
  cumulative violation counter.

### Errors
- Simple sentinels (`errors.New(msg)`), compared with `==`. No
  `Unwrap`/`errors.Is`/`errors.As` (locked v1 decision).

---

## 2. Compiler & tooling — implemented

### Subcommands (`volt <cmd>`)
| Command | Purpose |
|---|---|
| `build` | compile a `.volt` file to an executable |
| `run` | compile + run |
| `test` | discover + run `TestX` / `BenchmarkX`; legacy `main`-returns-42 form |
| `fmt` | format source (honors `// volt:noformat` guard; `--force` to override) |
| `memprofile` | summarize / diff allocation profiles |
| `mod` | `init` / `get` / `tidy` / `verify` (git-URL package management) |
| `doc` | extract package docs |
| `lsp` | language server |
| `dump-ir` | print emitted LLVM IR (accepts `-race` / `-g`) |
| `dump-tokens` | print the token stream |
| `env` / `version` | toolchain info |

### Build / test flags
- `-g` (DWARF debug info), `-strict` (volt.sum hash mismatch → error),
  `-race`, `--target amd64|arm64`, `--channels mutex|lockfree`,
  `--memprofile <path>` (per-source-line allocation profile, dumped at exit).
- `volt test --race` (asserts `RaceViolations()==0`), `--bench`,
  `--bench-json <path>`, `--bench-compare <baseline.json>`
  (`--bench-tolerance N`, default 20%).

### Runtime observability (`runtime` package)
- `Compact()`, `HeapBytes()`, `NumSizeClasses()`, `FreelistCount()`,
  `ThreadCount()`, `SetArenaChunkSize()`.
- `AllocCount()`, `FreeCount()`, `LiveBytes()`,
  `LiveCountClass()`/`AllocCountClass()`/`AllocBytesClass()`/`SizeClassBytes()`,
  `HeapSnapshot()` (structured per-size-class view).
- `MemProfileReset()` / `MemProfileDump(path)`.
- `RaceViolations()` / `ResetRaceViolations()`.

### Allocator / runtime
- mmap-backed bump + freelist allocator with iterative compaction; tunable
  per-arena chunk size; 12 size classes (16 B … 32 KiB) + mmap-direct huge.
- futex-based mutex/condvar; `clone()`-based thread spawn; TCP sockets;
  file I/O syscalls; argv/envp capture. **No TLS** (bare `_start`).

---

## 3. Standard library — implemented

~1,440 helper functions across 24 top-level packages (plus nested
`crypto/*`, `encoding/*`, `hash/*`, `path/filepath`):

| Package | ~fns | Notes |
|---|---|---|
| `slices` | 398 | rich type-paired (`Int`/`String`) helpers; map-free set ops |
| `strings` | 249 | search, case, wrap/justify, formatting, sparkline/histogram |
| `time` | 217 | calendar math, formatting, durations, business days |
| `math` | 107 | number theory, bit ops, statistics, geometry |
| `bytes` | 106 | `Builder`, search, split/join, hex dump, classifiers |
| `runtime` | 37 | observability + control surface (see §2) |
| `maps` | 33 | keys/values, merge, filter, aggregates, top-N |
| `os` | 26 | files (Drop-close), env, args, mkdir, temp dirs |
| `testing` | 25 | `T`/`B`, asserts, `Run`, `RunBenchmark`, bench JSON |
| `json` | 24 | encode/decode, pretty-print |
| `sort` | 22 | by key/len/abs, case-insensitive, merge, predicates |
| `strconv` | 22 | parse/format, bases, quoting, padding, `…Or` defaults |
| `unicode` | 16 | classifiers, case, digit value |
| `syscall` | 15 | open/close/read/write/all, TCP |
| `net` | 11 | TCP, IPv4 parsing |
| `bufio` | 10 | buffered reader/writer, split lines |
| `fmt` | 6 | Sprintf/Fprintf (stdout/stderr split with `log`) |
| `log` | 2 | Println to stderr |
| `io` | 1 | Copy + interfaces |
| `errors` | 1 | `New` (sentinel) |
| `crypto/*` | 57 | `hmac`, `sha256`, `sha1`, `md5`, `rand` |
| `encoding/*` | 14 | `hex`, `base64` |
| `hash/*` | 11 | `fnv`, `crc32`, `adler32` |
| `path/filepath` | 27 | join/split/match/rel/ext, normalization |

Packaging: git-URL imports (Go-style), `volt.mod` + `volt.sum`, `volt mod
init/get/tidy/verify`.

---

## 4. Testing & docs

- `tests-internal/*.volt` — 799 programs (749 build+run clean; 50 are
  intentional compile-fail negatives listed in `CLAUDE.md`).
- Smoke scripts: build-every-test + run-no-crash regression.
- `docs/design/*.volt` + `*.md` — canonical, hand-formatted syntax/semantics
  spec (`0-intent`, `2-ownership`, `3-concurrency`, etc.).

---

## 5. Known issues

- **Map-key lifetime bug (open, fix queued).** String-keyed maps with
  loop-local heap keys (`var k = strconv.Itoa(x); m[k]=…` in a loop) corrupt
  under A3 auto-free: the key buffer is freed while the map still references it,
  then freelist-reused. Silently affects existing `slices.IntersectInt` /
  `UnionInt` / `DifferenceInt` / `IsSetInt`. Proper fix = map insertion must
  **copy** keys (and `volt_map_free` free them). New set-style helpers are
  written map-free to avoid it.

---

## 6. TODO — not yet implemented

### High priority (correctness)
- **Fix the map-key lifetime bug** (§5) — map owns its keys.
- **Audit stdlib** for the same `m[loop-local-key]` pattern; add
  correctness (not just crash) tests for affected set operations.

### Borrow / ownership polish
- **Disjoint field borrows** — `&mut s.x` currently freezes all of `s`;
  allow simultaneous `&mut s.x` + `&mut s.y`.

### Profiling polish
- **Symbolized memprofile** — annotate hot lines with source text.

### Platform
- **macOS port (D.3, READY)** — Darwin syscall ABI for amd64+arm64. Both
  `start_*.s` entry paths are currently parallel, lowering friction.
- **TLS support** — minimal thread-local storage setup (`arch_prctl`) to unlock
  per-thread state (e.g. precise per-thread memprofile line attribution).

### Major architectural items (strategic)
- **Async / lightweight tasks** — M:N scheduling on top of OS threads;
  stackful (Go-style) vs stackless (Rust async/await) is an open design fork.
- **Self-hosting compiler (D.5, READY)** — port the Go compiler to volt itself.
- **Generics ergonomics** — better inference, where-clause constraints,
  friendlier monomorphization errors (current stdlib uses `Int`/`String`
  type-paired helpers in lieu of generics).

### Lower priority / deferred
- Small-string optimization (SSO) for `string`.
- Struct field auto-reordering to minimize padding (`repr(volt)` vs `repr(c)`).
- Bit-packed `bool` arrays / `bitset` type.
- Open-addressing hash maps (if chaining becomes a hotspot).
- Broader `-race` heap-data instrumentation (generic loads/stores beyond
  fields/elements/pointer-derefs).

---

_Status reflects the codebase at pass 759. The two BLOCKED items in the legacy
`TODO.md` table (A.3 auto-free, A.5 held borrows) have since shipped — that
table is partly stale; this file is the current source of truth._
