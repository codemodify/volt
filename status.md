# volt — implementation status

_Last updated: 2026-06-03 (pass 764). Branch: `dev`._

**volt** is a systems language with **Go-flavored syntax** and a **Rust-style
ownership/borrow memory model**. It compiles to **LLVM IR**, targets **Linux
amd64 + arm64**, and ships **no libc** — the runtime is a self-contained
`runtime.c` + hand-written `_start` assembly.

Health snapshot: **762 buildable regression programs**, **50 expected-negative
(intentional compile-fail) tests**, **0 runtime crashes**, **719/719
correctness-asserting tests** returning their success sentinel, and **`volt fmt`
round-trips all 762 with 0 behavior changes**.

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
- Declarations: `var x T = v`, `x := v` (no spaces), `const`; Go-style grouped
  blocks `import ( … )` / `const ( … )` / `var ( … )` (`volt fmt` auto-groups
  adjacent decls into aligned blocks).
- Composite literals: `new {…}` (no size), `new(N) T {…}` (sized), `T{a: 1}`.
- Control flow: `if/else`, `for` (C-style + `for k, v := range`), `switch`,
  `break`/`continue`, bare blocks `{ … }`, `ret`.
- `def` (deferred calls), `import`, `package`.
- Comments: `//` line, `/* … */` block, and `#` line (shell-style).
- **Scriptable:** a `#!/usr/bin/env volt` shebang + `chmod +x` runs a file
  directly; `volt <file|dir>` with no subcommand defaults to `run` (build to a
  temp binary + execute, args forwarded); a single file that needs siblings
  falls back to building its directory as a package.
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
- **Reborrow:** `&mut *b`, `&*b`, `&mut s.field`, `&mut a[i]` (partial borrows).
- **Disjoint field borrows:** `&mut s.x` and `&mut s.y` simultaneously
  (per-field tracking); whole-`s` borrow while a field is live still rejected.
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
  file I/O syscalls; argv/envp capture; per-thread TLS block (`arch_prctl`
  on amd64 / `tpidr_el0` on arm64), set up per thread in `_start`/`volt_spawn`.

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

- **Slice-valued map leak (open).** `map[string][]T` values are heap-boxed and
  not freed on delete/`map_free`, and clone is value-shallow for them. (String
  values are now fully owned — see below.) Leak only, no corruption. Needs a
  `value_kind=2` per-value drop + deep-copy.
- **Transient string-temp leak (open).** Intermediate `strconv.Itoa(...)` /
  concat temporaries that feed another call aren't always A3-freed. Bounded;
  surfaced while measuring the map-value leak.

### Recently fixed (pass 760–761)
- **Map KEY lifetime bug — FIXED (760).** Maps copy + own keys; delete/free/
  clone handle them (clone deep-copies). Cured silent wrong answers in
  `slices.Intersect/Union/Difference/IsSet/SameMultiset` + `maps.*`.
- **Map string-VALUE ownership — FIXED (761).** `map[string]string` now owns +
  frees its boxed values (delete/free/overwrite); clone deep-copies; map-get
  deep-copies so the map stays sole owner (fixes a double-free / use-after-free
  where a read-out value aliased the map's backing).
- **A3 drop-depth bug — FIXED (761).** A heap string/slice declared with a
  non-heap initializer then built in a loop was freed every iteration (drop
  bound to loop-body scope instead of declaration scope). Surfaced by the new
  correctness harness via `strconv` pad functions.
- **`os.Args()` / `os.GetenvOr()` — FIXED (761).** They called the
  `os.Argc/ArgAt/Getenv` intrinsics intra-package and hit zero-returning stubs
  (`os.Args()` silently returned an empty slice).

---

## 6. TODO — not yet implemented

### High priority (correctness)
- **Slice-valued map ownership** (§5) — extend the string-value work (done) to
  `map[string][]T` (`value_kind=2`: free `[]T` box+backing, clone deep-copy).
- **Transient string-temp frees** (§5) — A3-free `strconv.Itoa`/concat
  intermediates that feed another call.
- _Done pass 761:_ correctness harness (`scripts/correctness.sh`, asserts the
  `ret 42` sentinel across 713 tests) — already caught + fixed 2 codegen bugs.

### Borrow / ownership polish
- **Disjoint field borrows** — `&mut s.x` currently freezes all of `s`;
  allow simultaneous `&mut s.x` + `&mut s.y`.

### Profiling polish
- **Symbolized memprofile** — annotate hot lines with source text.

### Platform
- **macOS port (D.3, READY)** — Darwin syscall ABI for amd64+arm64. Both
  `start_*.s` entry paths are currently parallel, lowering friction.
- _Done pass 761:_ **TLS** — per-thread storage via `arch_prctl(ARCH_SET_FS)`
  (amd64) / `tpidr_el0` (arm64); the memprofile current-line is now exact
  per-thread. amd64 verified; arm64 mirrored but untested on hardware. General
  C `__thread` support could build on this if needed.

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
