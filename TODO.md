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
- **(2)** Field/index move tracking — `consume(p.a)` / `consume(s[i])` now conservatively mark the root container as moved.
- **(3)** `run f(args)` rejects borrow / pointer args (`&T` / `*T`).
- **(4)** Recursive Drop — struct fields with their own `Drop()` now fire in reverse declaration order after the parent's `Drop`.
- **(5)** `clone()` for slices and maps — slices byte-clone their backing storage; maps copy every entry via `volt_map_clone` runtime helper. Shallow at the element level (pointer-valued elements still alias).

### Open

| # | Severity | Gap |
|---|----------|---|
| ~~1~~ | ~~HIGH~~ | ~~**Memory is never actually freed.**~~ Partially closed: allocator now supports free (A1). Wiring it into Drop for owned slice/map/string vars is tracked as A3 (needs move-tracking → codegen integration). |
| 6 | LOW      | **Gap (d): cross-statement aliasing-XOR-mutation.** Enforced within a single call (`f(*x, &x)` is rejected). Outstanding read/write access across statements not yet tracked. Currently unreachable because no syntax exists for `var r &T = …`. Lands together with item 8. |
| ~~7~~ | ~~LOW~~ | **`error` dispatch landed.** Concrete types with `Error() string` auto-implement `error`; conversion boxes into `%error_box = {data, error_fn}`; `e.Error()` does indirect call through the stored fn pointer. User-defined interfaces and `any` typed-storage are the remaining gaps (separate item below). |
| 8 | LOW      | **No `&x` / `*x` expression to hold a borrow in a variable.** Borrows are call-site-only today via bare-name inference. Adding `&x`/`*x` as expressions is a design decision; if accepted, gap 6 must land with it. |
| 9 | LOW      | **Element-level deep clone.** `clone(slice)` and `clone(map)` are byte-copy / entry-copy today. A slice of strings or a map of strings will alias the inner heap data. Fix: in `cloneSlice` / `cloneMap`, walk per-element with `cloneValue` when the element type is not POD. Runtime needs a `volt_map_clone_deep(m, fn)` if we go through a callback. |
| ~~10~~ | ~~LOW~~ | **Branch-local unused vars** landed — `checkBlock` now snapshots entry names and reports any newly-declared var that wasn't read by block end. |
| ~~11~~ | ~~LOW~~ | **User-defined interfaces** landed — per (concrete T, interface I) vtable `@<T>_<I>_vtable = constant [N x ptr]`. Method-set matching is name-based at v0.7 (signature-strict matching is a polish item once parser captures sigs strictly). Test `iface_user.volt`. |
| ~~12~~ | ~~LOW~~ | **`any` storage** landed — heap-copy + ptr; no method dispatch (none to dispatch), no type recovery (no type tag yet — future addition). Test `any_struct.volt`. |
| 13 | LOW     | **Type-assertion / unboxing for `any`.** Today values stuffed into `any` can't be read back as their original type — no type tag. Add a runtime type-id alongside the data ptr, and an `assert[T](v any) T` builtin or similar. |
| 14 | LOW     | **`for k, v := range map`.** Range over slice + string landed; map iteration needs a runtime iterator (allocate iter state, `next` returns key bytes + value + done flag). Codegen would lower the loop to alloc iter + while-not-done. Not blocking; rare in practice. |

---

## Allocator / runtime

| # | Severity | Item |
|---|----------|---|
| ~~A1~~ | ~~HIGH~~ | **Real allocator** landed — mmap-backed, size-classed freelists, `volt_free` + huge-block munmap. No more 16 MB BSS cap. |
| ~~A2~~ | ~~MEDIUM~~ | **Map auto-resize** landed — initial 16 buckets, doubles when load > 0.75. Test `map_grow.volt`. |
| A3 | MEDIUM  | **Wire `volt_free` into Drop** for owned slice/map/string values whose vars are NOT moved out before scope end. Needs the checker to expose move state to codegen at Drop-emission time. Still pending. |
| A4 | LOW     | Open-addressing hash maps. Switch from chaining if chaining ever becomes a hotspot. |
| A5 | LOW     | Small-string optimization (SSO) for `string` — inline ~14 bytes in the header. Won't pay off until allocator + string-mutation story is mature. |

---

## Language surface — design decisions pending

| # | Item |
|---|---|
| ~~D1~~ | **Slice `cap` field — landed.** `%slice = {ptr, i64 len, i64 cap}` (24 bytes). `cap()` builtin returns the third field; `append(s, v)` routes to `volt_slice_grow` runtime helper that doubles cap when full (min 8). Sub-slicing not yet exposed but the header now supports it. |
| D2 | **Should bare `new chan T` and bare `new []T` stay legal?** Today bare `new T` works for struct (zero-default), chan (unbuffered), and slice (empty). Bare `new map[K]V` is rejected. For consistency: either reject all bare non-struct forms, or accept all. Currently inconsistent. |
| D3 | **Held-borrow syntax** (see ownership #8). `var r &T = ...` and its tracking. |

---

## Language features — planned, not yet implemented

| # | Item |
|---|---|
| ~~F1~~ | ~~**Float literal lexing.**~~ Landed: lexer already produced Float tokens; parser now accepts them (new `*ast.FloatLit`), codegen emits literal verbatim, `convertInt` extended with `fpext` / `fptrunc`, `emitBinary` routes to `fadd` / `fcmp` etc. for float operands and auto-promotes int literals via `sitofp` in mixed expressions. |
| ~~F2~~ | ~~**Unused-var error like Go's.**~~ Landed: `state.used` flag, set by `checkExprUse` on IdentExpr (and on the receiver of selector/index assigns). `reportUnused` at end of `checkFunc` flags unused non-param locals; `_`-prefix opt-out. `mergeSyms` propagates `used` across branches. Coverage extended to `RunStmt`, `SendStmt`, `SelectStmt`, `MultiVar`/`MultiAssign`, `DeferStmt`. |
| ~~F3~~ | **`log.Fatal` / `log.Fatalf` removed (2026-05-25).** Originally landed as Println-then-`syscall.Exit(1)` intrinsics; rolled back because hiding a process exit behind a logging call obscures control flow. Use `log.Println` followed by an explicit `syscall.Exit(code)` instead. |
| F4 | **Auto-reorder struct fields to minimize padding.** Would require a `repr(volt)` vs `repr(c)` distinction. Marginal until users hit padding pain. |
| F5 | **Bit-packed `bool` arrays / `bitset` library type.** Only if dense-boolean perf matters. |
| ~~F6~~ | ~~**Select-case name collision.**~~ Landed: per-case alloca naming uses `%name.caseN.addr`, so two cases binding `v := read(...)` no longer collide. |
| ~~F7~~ | ~~**`i++` / `i--` statements.**~~ Landed: desugared in `parseSimpleStmt` to `i = i + 1` / `i = i - 1`. Works as a for-post or standalone statement. |
| ~~F8~~ | ~~**`for i, v := range EXPR`.**~~ Landed for slice + string (slice: i = index / v = element; string: i = byte-index / v = byte). 1-token vs 2-token parser lookahead distinguishes range-form from C-style init. Map range deferred (TODO 14). |

---

## Concurrency primitives

Six sync primitives ship: `chan T`, `mutex T`, `rwmutex T`, `atomic T`, `waitgroup`, `once`. The mutex/rwmutex family uses guard-with-Drop; atomic uses per-width lock-free ops (`int/int64`, `int32`, `int16`, `int8`/`byte`, `bool`, `ptr`); waitgroup/once are pure coordination primitives (no payload). Channels: **cap=0 is the default** (unbuffered, true rendezvous — sender blocks until paired receiver consumes); `new(N)` for buffered. Channel handles can narrow to a single direction via `chan read T` / `chan write T` — many readers and many writers may share the same channel. Channel values can also carry a **multiplicity contract** (`chan11 T` / `chan1N T` / `chanN1 T` / `chanNN T` — notation `chan<readers><writers>`, 1=exactly one, N=one or more) verified at compile time at the declaring scope. C1–C7 closed in May 2026; cap=0 default + directional types + multiplicity contracts closed 2026-05-25. Leftover items below.

| # | Item |
|---|---|
| C8 | **`&x` / `*x` expression syntax.** Borrows only materialize via bare-name inference at call sites — there's no way to take an explicit address. Real value would be **held borrows** (`var p &T = &x`), which is gap (d) territory and needs lifetime tracking design first. |
| ~~C9~~ | ~~**`once` with closure / function-value argument.**~~ Landed: first-class function values (bare fn ptrs, anonymous literals, closures with by-move/by-copy captures) + `o.Do(fn)` runtime hook. See item below for what landed and what's still gated. |
| C10 | **Conditional variable as a user-facing primitive.** Runtime `cond_t` already exists and is used by chan/mutex/rwmutex internally. Surfacing it as `condvar` doesn't fit volt's guard-based mutex (Wait needs to atomically release+reacquire, but the guard pattern hides Unlock). Needs a design pass. Most use cases are covered by chan/waitgroup/once. |
| C11 | **`run f(...)` with >6 args.** Today capped at 6 ptr slots, matching the SysV register-arg ceiling. For workers wanting 7+ shared handles, synthesize a struct-pack thunk at codegen. |
| ~~C12~~ | **Closure escape across thread boundaries** landed — `%fn_value` consumes 2 spawn slots (SysV passes the 16-byte struct in 2 GPRs anyway); the receiver function reassembles via its formal-arg convention. Test `run_closure.volt`. |
| C13 | **Capture-by-borrow.** All captures today are by-move (or by-copy for primitives). Borrow captures (`&T`/`*T`) are rejected because we can't prove the closure doesn't outlive the borrowed storage. Adding capture-by-borrow needs the held-borrow story (gap d + C8). |
| ~~C14~~ | **Function values returned from a function** landed — the env is heap-allocated, survives function exit. Test `fn_return.volt` builds three different closures from one factory, each with its own env. |
| ~~C15~~ | **Unbuffered channels (cap=0 default) + directional `chan read T` / `chan write T`** landed. Runtime tracks `has_handoff` + `receivers_parked` for true rendezvous semantics with `select` support; direction is type-only (handle still lowers to ptr) and is enforced at `read`/`write`/`close` builtin sites. Tests `chan_unbuffered.volt`, `chan_dir.volt`. |
| C16 | **Direction-narrowing at call sites with explicit directional params.** Today narrowing from bidi `chan T` to `chan read T` / `chan write T` works at calls. Passing a `chan read T` to a `chan write T` param (or vice versa) is only caught when the callee tries the disallowed op. Strict param-direction check would catch it at the call. Edge case — low priority. |
| ~~C17~~ | **Channel multiplicity contracts (`chan11 T` / `chan1N T` / `chanN1 T` / `chanNN T`)** landed — notation `chan<readers><writers>` with 1 = exactly one, N = one or more. Compile-time checks at the declaring scope. Same runtime as `chan T`; the checker walks the function body counting reader/writer endpoints (direct `read`/`write`/`close`, `run f(ch)` classified by callee param direction, `ch <- v` sends). A `run f(ch)` inside a `for` is treated as "many" of that endpoint kind. Tests `chan_11.volt`, `chan_1n.volt`, `chan_n1.volt`, `chan_nn.volt`. |
| C18 | **Contract enforcement across function boundaries.** A `chan11/chan1N/chanN1/chanNN T`-typed parameter today is parsed and the multiplicity is preserved on the AST, but the check only fires at the value's declaring `var ch chanXY T = new(...)` site. Cross-function flow tracking would need to know the caller's contract when the function does its own `run` spawns. Edge case — usually contracts are declared and verified at the same scope. |

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
