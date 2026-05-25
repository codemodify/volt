# TODO — implementation gaps

The design under `docs/design/` is the **spec**: it describes the
language as it's supposed to be, not as it's currently built. This
file tracks where the implementation differs from that spec, plus
planned features whose design is fixed but whose code hasn't landed.

When a design file describes a feature, the assumption is "this
works." When it doesn't, look here.

---

## Ownership / borrow checker

### Closed
- (a) Move tracking for owned structs, slices, maps — enforced.
- (b) Writes through `&T` are rejected by the checker.
- (c) Writes through `*T` for primitives compile correctly.

### Open

| # | Severity | Gap |
|---|----------|---|
| 1 | HIGH     | **Memory is never actually freed.** Runtime is a bump allocator over a 16 MB BSS buffer (`runtime.c` `volt_alloc`). `Drop()` methods run at scope exit; backing bytes leak until process exit. Long-running programs OOM. Fix: real allocator with free. |
| 2 | MEDIUM   | **Field- and index-level move tracking missing.** `maybeMoveBareIdent` in `check.go` only handles `*ast.IdentExpr`. `consume(p.a)` moves `p.a` but doesn't mark `p`. Same for `consume(s[i])`. Fix: extend the checker to walk `SelectorExpr` and `IndexExpr` LHS for moves; mark the parent conservatively. |
| 3 | MEDIUM   | **`run f(args)` doesn't reject borrow-typed args.** Design says borrows can't cross thread boundaries. Movable args get moved (good), but `&T`/`*T` args aren't rejected. Fix: `RunStmt`-specific check in `check.go` that rejects any arg whose parameter type is a `*ast.BorrowType` or `*ast.PointerType`. |
| 4 | MEDIUM   | **Drop only fires for top-level owned struct vars.** `codegen.go emitVar` registers a Drop only when the declared type is a struct with `Drop()`. Drop is **not called recursively** for struct fields, slice elements, or map values that have their own `Drop()`. Holding a non-memory resource (file fd, lock) inside a container leaks. Fix: walk struct field types recursively in drop emission; slice/map needs runtime iteration helpers. |
| 5 | MEDIUM   | **`clone()` for slices and maps is unimplemented.** Today returns "clone of slices not yet implemented". Fix: extend `cloneValue` in `codegen.go` with `*ast.SliceType` and `*ast.MapType` cases. Allocate fresh backing, recursively clone each element/entry. |
| 6 | LOW      | **Gap (d): cross-statement aliasing-XOR-mutation.** Enforced within a single call (`f(*x, &x)` is rejected). Outstanding read/write access across statements not yet tracked. Currently unreachable because no syntax exists for `var r &T = …`. Lands together with item 8. |
| 7 | LOW      | **`error` / `any` declared but don't dispatch.** Interface types parse, but user code cannot construct non-nil values — vtable / method dispatch isn't wired. Depends on full interfaces work. |
| 8 | LOW      | **No `&x` / `*x` expression to hold a borrow in a variable.** Borrows are call-site-only today via bare-name inference. Adding `&x`/`*x` as expressions is a design decision; if accepted, gap 6 must land with it. |

---

## Allocator / runtime

| # | Severity | Item |
|---|----------|---|
| A1 | HIGH    | Real allocator with `free` (see ownership #1). |
| A2 | MEDIUM  | **Map auto-resize.** `runtime.c` uses 256 fixed buckets with chaining — degrades to O(n) for maps with >>256 entries. Add load-factor-based resize (double when load > 0.75 → ~16K buckets for ~12K entries). Pure runtime change. The biggest perf payoff the map can get. |
| A3 | LOW     | Open-addressing hash maps. Switch from chaining if chaining ever becomes a hotspot. |
| A4 | LOW     | Small-string optimization (SSO) for `string` — inline ~14 bytes in the header. Won't pay off until allocator + string-mutation story is mature. |

---

## Language surface — design decisions pending

| # | Item |
|---|---|
| D1 | **Slice `cap` field.** Currently `%slice = {ptr, i64}` (16 bytes). Add a `cap` field (→ 24 bytes, `{ptr, len, cap}`) — required for any growable / sub-slicing story. If yes → must land before slices are widely used in user code; retrofit breaks every existing slice header in IR. If no → slices stay fixed-size; introduce a separate `vec` type for growable buffers. |
| D2 | **Should bare `new chan T` and bare `new []T` stay legal?** Today bare `new T` works for struct (zero-default), chan (unbuffered), and slice (empty). Bare `new map[K]V` is rejected. For consistency: either reject all bare non-struct forms, or accept all. Currently inconsistent. |
| D3 | **Held-borrow syntax** (see ownership #8). `var r &T = ...` and its tracking. |

---

## Language features — planned, not yet implemented

| # | Item |
|---|---|
| F1 | **Float literal lexing.** `float`/`float32`/`float64` types exist but the lexer doesn't recognize `3.14` etc. — so `var x float32 = 3.14` doesn't parse. Need to add Float-token recognition. |
| F2 | **Unused-var error like Go's.** Track `read`/`written` flags per symbol in `check.go`; if neither at end of scope, emit error. Pattern matches Go's "declared and not used". `_`-prefix opt-out. |
| F3 | **`log.Fatal` / `log.Fatalf`** — log + `syscall.Exit(1)`. Common shape; otherwise users write `log.Println(...); syscall.Exit(1)` everywhere. |
| F4 | **Auto-reorder struct fields to minimize padding.** Would require a `repr(volt)` vs `repr(c)` distinction. Marginal until users hit padding pain. |
| F5 | **Bit-packed `bool` arrays / `bitset` library type.** Only if dense-boolean perf matters. |
| F6 | **Select-case name collision.** `case v := read(a):` and `case v := read(b):` in the same `select` both emit `%v.addr` allocas in the function-level scope → LLVM "multiple definition of local value named 'v.addr'". Each case body should be a separate scope. Workaround: use distinct names per case (`case x := read(a)`, `case y := read(b)`). Fix: codegen for `SelectStmt` should generate fresh-name allocas per case. |

---

## Concurrency primitives

Six sync primitives ship: `chan T`, `mutex T`, `rwmutex T`, `atomic T`, `waitgroup`, `once`. The mutex/rwmutex family uses guard-with-Drop; atomic uses per-width lock-free ops; waitgroup/once are pure coordination primitives (no payload). C1–C5 closed in May 2026; waitgroup/once landed on the same pass. Remaining work below is edge cases.

| # | Item |
|---|---|
| C6 | **`atomic bool`, `atomic int8`, `atomic int16`.** Today `atomicSuffix` accepts int / int32 / ptr only. Smaller widths need per-width runtime entry points + the right `__atomic_*` instantiation. Skipped initially because `i1` atomic ABI is fiddly (most hardware treats as `i8`). |
| C7 | **`run f(...)` with >4 args.** Today capped at 4 ptr slots, matching the spawn asm in start_*.s. For workers wanting 5+ handles, either bump the asm further or synthesize a struct-pack thunk at codegen. |
| C8 | **`&x` / `*x` expression syntax.** Borrows only materialize via bare-name inference at call sites — there's no way to take an explicit address. Blocks some patterns (e.g. building a `*T` to publish through `atomic *T` from user code). |
| C9 | **`once` with closure / function-value argument.** Today the user must split init into `if o.Begin() == 1 { ...; o.Done() }`. A `o.Do(fn)` single-call form (Go-style) needs first-class function values, which volt doesn't have yet. |
| C10 | **Conditional variable as a user-facing primitive.** Runtime `cond_t` already exists and is used by chan/mutex/rwmutex internally. Surfacing it as `condvar` would unlock things like generalized wait-for-predicate patterns, but most use cases are covered by chan/waitgroup/once. |

---

## Design constraints to preserve through all additions

- Borrows (`&T`, `*T`) cannot cross thread boundaries. `run f(args)` should reject borrow-typed args. The `mutex`/`atomic`/`rwmutex` wrappers themselves are the only way two threads touch the same memory.
- No exceptions, no GC. Guards for `mutex T` and `rwmutex T` release via the existing block-scoped `Drop` machinery.
- No libc. Atomic intrinsics lower to `__atomic_*` builtins in runtime.c, not C library calls. Mutex uses the existing in-runtime futex helpers.

---

## Suggested ordering when work resumes

Smallest → biggest within each batch:

**Quick wins (1 day each):**
- F1 float literal lexing
- F2 unused-var error
- F3 `log.Fatal`/`Fatalf`
- Ownership #3 `run f(&x)` rejection

**Medium (1 week each):**
- Ownership #2 field/index move tracking
- Ownership #5 `clone()` for slices/maps
- Ownership #4 recursive Drop
- A2 map auto-resize

**Large (multi-week):**
- A1 real allocator (unblocks long-running programs)
- C6 atomic bool/i8/i16 (smaller widths)
- Ownership #7 `error`/`any` dispatch (blocked on full interfaces work)
- Ownership #8 + #6 held-borrow syntax + cross-statement tracking
