# Design — runnable examples, one topic per file

Each file is a self-contained, runnable program that demonstrates a
single concept. Read the header comment of each for the design notes,
then run it directly:

```sh
volt run docs/design/0-primitives.volt
```

Suggested reading order — earlier files lay the groundwork for later
ones, but each is independently runnable:

| File | What it shows |
|---|---|
| `0-intent.volt`      | One-page schematic of every type and concurrency primitive — the language's "what fits where" overview. |
| `0-primitives.volt`  | Every built-in primitive: int{8,16,32,64}, uint{8,16,32,64}, byte, bool, string, slice, map, empty struct |
| `1-allocation.volt`  | The `new` keyword: `new T {…}` / `new T {}` for structs, `new(cap) chan T` for channels, `new(cap) map[K]V {…}` for maps, `new(N) []T {…}` for slices. Size always comes immediately after `new`, before the type. Short form `new(…)` / `new {…}` allowed when LHS provides the type. |
| `2-ownership.volt`   | The three forms of a value: `T` (owned), `&T` (read access — many readers OK), `*T` (write access — exclusive). Method dispatch on each. |
| `3-concurrency.volt` | `run f()` launches a real OS thread; channels (unbuffered by default), direction (`chan read T` / `chan write T`), multiplicity contracts (`chan11`/`chan1N`/`chanN1`/`chanNN`), `select`, `mutex T`, `rwmutex T`, `atomic T`, `waitgroup`, `once`. |
| `multi-return.volt`  | Multi-value return + `a, b := f()` short decl. The `(T, bool)` "maybe-absent" pattern that replaces `Option<T>`. |
| `move.volt`          | Move semantics: passing `T` consumes it; use-after-move is a compile error. Read access (`&T`) or write access (`*T`) avoids the move. |
| `errors.volt`        | The `(T, error)` pattern — multi-return; caller checks `err != nil` first, reads the value only when error is nil. |
| `interfaces.volt`    | Structural interfaces — any type with matching methods satisfies. No `impl` keyword. |
| `timers.volt`        | `time.Sleep(ns int)` and the duration unit constants `time.{Nanosecond, Microsecond, Millisecond, Second}` (compile-time integers). |
| `defer.volt`         | `def` — registers cleanup that fires at function exit in LIFO order. No exceptions; no auto-destructors. |

## Companion docs

Some topics have a longer-form companion that lives alongside the
runnable file. These are the deeper-discussion / cross-language-comparison
docs you'd want when designing or porting from another language.

| Doc | Companion to | What it adds |
|---|---|---|
| `0-primitives.md`  | `0-primitives.volt` | Per-type storage and read/write perf (register vs cache line); cases where promoting widths helps. |
| `2-ownership.md`   | `2-ownership.volt`  | Ownership model overview + cross-language comparison (volt vs C vs Go) for primitives, struct, chan, slice/map. |
| `3-concurrency.md` | `3-concurrency.volt`| Channel API reference, `select` grammar, and common concurrency patterns (producer/consumer, fan-in, fan-out, request/reply, non-blocking poll). |

## Minimal feature tests

For one-feature-at-a-time tests, see `tests-internal/*.volt` at the repo root.
