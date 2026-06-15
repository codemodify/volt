### `volt` memory model — "VALUES OWN, BORROWS VISIT"

Three rules, and a 10-year-old has the whole model:
1. **You make it, you own it.** `new T{...}` gives you a VALUE. Leave the block and it's tidied up — automatically, no `free()`, no GC.
2. **You can lend it, but lends come back.** `&T` lets a function LOOK (read-only); `*T` lets it USE-AND-CHANGE in place. A borrow ends when the call ends — it can't be returned, stored, or smuggled out in a closure.
3. **Want someone to KEEP one?** Give it away (MOVE — you can't use it after) or give a copy (`.Clone()`).

Everything else falls out:
- **No nil.** "Absent" is `(T, bool)` or `(T, error)`. The lone exception is `error` itself — nilable, but only ever COMPARED (`if err != nil`), never read THROUGH, so it can never crash.
- **No keepable pointers ⇒ no cycles.** Every value is a TREE with exactly ONE owner — which is why the compiler frees it, exactly once, when the owner leaves scope.
- **Recursion goes through a container** (`[]T`), never a stored pointer.
- **A read is a copy or a `&` peek — never a silent alias.** Reading an owned value out of a container (`x := names[i]`) hands you your OWN independent copy, so the container stays the sole owner of its storage; if you only want to look without copying, take a `&` peek. This is what keeps "exactly one owner" true in practice — there's never a second binding quietly sharing the first one's heap memory.

The three buckets, one rule ("exactly one owner"):

bucket			| types										| on pass/assign		| freed
----			|----										|----					|----
**Copy**		| int, float, bool, byte, structs of only those	| bit-copy (both usable)	| nothing (no heap)
**Owned**		| string, slice, map, struct-with-heap			| MOVE (original dead); `&`/`*` to lend	| at the owner's scope end
**Shared handle**	| chan, mutex, rwmutex, atomic, waitgroup		| SHARE (handle copy; same object)	| when the last holder drops (reference-counted)

### the same model vs `C` / `Go` / `Rust` / `Zig`

Same machine layout everywhere — a small inline header pointing at a heap payload. What differs is the *rules on that pointer*:

&nbsp;		| what `new T{}` gives			| who frees				| pass-by-value
----		|----							|----					|----
**volt**	| a VALUE (shell inline, heap interiors owned)	| compiler, at scope end	| MOVE (old name dead)
**Rust**	| a VALUE (`Box::new` only if asked)			| compiler, at scope end	| MOVE
**C**		| a `T*` you must `free`						| you, by hand			| COPY → aliases
**Go**		| a `*T`										| GC, whenever			| COPY → aliases
**Zig**		| a VALUE (`allocator.create` for heap)			| you (`defer deinit`)	| COPY → aliases

volt's model **is Rust's** — value-with-owned-interior, move on pass, deterministic free, no GC — with the annotations removed by forbidding the patterns (storable pointers, escaping borrows) that would otherwise need them.

### `volt` types
- `PRIMITIVE`: int, float, bool, byte
- `COMPLEX`: string, struct, slice, map, chan

### `volt` types rules
- for a type `T` (primitive/complex)
- the memory is owned by a `VAR` called `OWNER`
- ownership can be `MOVED` to a new `OWNER`
	- the old owner becomes dead (compile error)
	- the old owner can be used only after assigning new memory/ownership
- each `T` also supports two kinds of VISIT — a borrow that lives ONLY for the call/block that takes it:
	- `&T` a PEEK: read-only, many can peek at once
		- the value can't be CHANGED while anyone is peeking (you can still read it)
	- `*T` a LOAN to change in place: read+write through `*p`, only one at a time
		- nothing else may peek or loan the same value meanwhile
		- the original can't be changed except through the loan; write via `*p = v`
	- a borrow NEVER escapes: it can't be returned, stored in a field/slice/map/chan, or captured by a closure that escapes — so it can never dangle
	- a value can have many peeks OR one loan at a time, never both — that's what avoids data races
		- nothing reads while something is changing it; nothing changes it while something is reading
		- **natural question**: if peeks and loans are mutually exclusive, how do you change state several threads share?
			- short answer: use a `channel` / `Mutex` / `RwMutex` / `Atomic` / `condvar` wrapper
			- full answer with examples: [3-concurrency.md ](3-concurrency.md#concurrency-patterns-mutating-shared-data)

lang		| one-liner
----		|----
volt		| small values (int/bool/float + structs of only those) COPY on pass and stay usable; everything else HANDS OVER (the original is invalidated); enforced at compile time.
C			| pass-by-value COPIES; coder manages lifetime by hand; mistakes are undefined behavior.
Go			| pass-by-value COPIES primitives; COPIES headers for complex, underlying storage is shared; GC handles lifetime; data races are runtime issues.

### `volt` types rules examples
```go
type TestStruct struct {}

fun test(x T){}

var N = 10
var N = "test value"
var N = new TestStruct()
var N = new []string{}
var N = new map[string]string{}
var N = new chan int

// call function for different type
test(N)
```

&nbsp;							| `test(N)`		| ownership notes												| notes
----							|----			|----															|----
`int` `byte` `bool` `float`		| COPY			| primitives are cheap live in CPU-register						| COPY — original stays alive; identical bytes on each side
`string`						| MOVE			| owns backing memory (bytes)									| MOVE — original invalidated (compile error if used after MOVE)
`struct T`						| MOVE			| owns backing memory (heap via fields)							|
`[]T` (slice)					| MOVE			| owns backing memory (array)									|
`map[K]V`						| MOVE			| owns backing memory (hash table)								|
`chan T`						| SHARE			| reference-typed by design, handle copy						| SHARE — both sides hold a handle to the same underlying object
`error`, `any`					| SHARE			| Opaque interface ptr; nilable, handle copy					|
`&T`, `*T` (peek / loan)	| n/a			| a VISIT — can't be returned, stored, handed over, or cloned; the value is held still while one is out	|


### `volt` vs `C` vs `Go`
&nbsp;						| &nbsp;							| &nbsp;												| &nbsp;
----						|----								|----													|----
`primitives`				| `VOLT`							| `C`													| `GO`
pass-by-value `f(t)`		| **COPY**							| **COPY**												| **COPY**
read-only (peek)			| `f(n &int)`						| `f(const int *n)`										| `f(n *int)` (no marker)
read-write (loan)			| `f(n *int)`						| `f(int *n)`											| `f(n *int)`
at the call site			| `f(x)`							| `f(&x)`												| `f(&x)`
aliasing rule enforced		| yes (compile)						| no (UB possible)										| no (race possible)
&nbsp;						| &nbsp;							| &nbsp;												| &nbsp;
&nbsp;						| &nbsp;							| &nbsp;												| &nbsp;
`struct`					| `VOLT`							| `C`													| `GO`
allocate					| `new T{...}`						| `malloc + manual free`								| `&T{...}` (GC)
pass-by-value `f(t)`		| **MOVE** — `t` invalidated		| **COPY** (memcpy)										| **COPY**
read `t.f` after `f(t)`		| compile error						| OK (callee owns a copy)								| OK (callee owns a copy)
pass for write (loan)		| `f(t *T)` — one at a time			| `f(T* t)`												| `f(t *T)`
two write loans OK?			| NO (compile error)				| YES (UB if misused)									| YES (data race risk)
cleanup						| automatic at scope end (`Drop`/`def` for side-effects)	| manual `free()` + cleanup								| GC (nondeterministic)
independent copy			| `clone(t)` — explicit deep		| `memcpy` — shallow									| `t2 := t` — shallow
&nbsp;						| &nbsp;							| &nbsp;												| &nbsp;
&nbsp;						| &nbsp;							| &nbsp;												| &nbsp;
`chan`						| `VOLT`							| `C`													| `GO`
allocate					| `new()`							| (no native — pipe/queue lib)							| `make(chan T, N)`
pass-by-value `f(ch)`		| **SHARE** — both see same ch		| n/a													| **SHARE** — both see same ch
move tracking				| NO (deliberately exempt)			| n/a													| NO
`clone(ch)`					| error								| n/a													| (no clone API)
cross-thread sharing		| first-class						| pipes / shm + mutex (manual)							| first-class
&nbsp;						| &nbsp;							| &nbsp;												| &nbsp;
&nbsp;						| &nbsp;							| &nbsp;												| &nbsp;
`slice`						| `VOLT`							| `C`													| `GO`
header						| `{ptr, len}`						| `T* + size_t` (separate)								| `{ptr, len, cap}`
allocate					| `new()`							| `malloc(N*sizeof(T)) + free`							| `make([]T, N)` (GC)
pass-by-value				| **MOVE**							| COPY of `(ptr, len)` — both alias the backing array	| reference-like — both share the backing array
after `f(s)`				| `s` invalidated					| `s` still usable										| `s` still usable
aliasing after copy			| impossible						| possible (UB risk)									| common — mutations visible
&nbsp;						| &nbsp;							| &nbsp;												| &nbsp;
&nbsp;						| &nbsp;							| &nbsp;												| &nbsp;
`map`						| `VOLT`							| `C`													| `GO`
type						| `map[K]V` (first-class)			| (no native — hash table libs)							| `map[K]V` (first-class)
allocate					| `new()`							| n/a													| `make(map[K]V)`
pass-by-value				| **MOVE**							| n/a													| reference-like
map mutations visible		| only to the owner					| n/a													| yes (all aliases see them)
&nbsp;						| &nbsp;							| &nbsp;												| &nbsp;
&nbsp;						| &nbsp;							| &nbsp;												| &nbsp;
`string`					| `VOLT`							| `C`													| `GO`
allocate					| string literal					| char array / `malloc`									| string literal
length cost					| `len(s)` O(1) (length-prefixed)	| `strlen(s)` O(n) (null-terminated)					| `len(s)` O(1) (length-prefixed)
pass-by-value				| **MOVE**							| **COPY** of `char*` (shallow — both alias)			| **COPY** of header — immutable, sharing is safe
mutability					| immutable							| mutable in place									| immutable
&nbsp;						| &nbsp;							| &nbsp;												| &nbsp;
&nbsp;						| &nbsp;							| &nbsp;												| &nbsp;
`error/any`					| `VOLT`							| `C`													| `GO`
representation				| opaque ptr (interface-shaped)		| n/a (no interface concept)							| {type, data} pair (interface value)
nilability					| yes (only nilable type in volt)	| n/a													| yes
pass-by-value				| **SHARE** (opaque ptr)			| n/a													| **SHARE** (interface value copy)
dynamic dispatch			| at every method call				| n/a													| at every method call
