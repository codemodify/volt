### `volt` types
- `PRIMITIVE`: int, float, bool, byte
- `COMPLEX`: string, struct, slice, map, chan

### `volt` types rules
- for a type `T` (primitive/complex)
- the memory is owned by a `VAR` called `OWNER`
- ownership can be `MOVED` to a new `OWNER`
	- the old owner becomes dead (compile error)
	- the old owner can be used only after assigning new memory/ownership
- each `T` also supports (C8 phase 4+5)
	- `&T` SHARED borrow: read-only, many concurrent readers OK
		- the source is FROZEN (no direct mutation) while any `&T` is held
	- `&mut T` EXCLUSIVE borrow: read+write through `*p`, only one at a time
		- blocks all other borrows (shared or mut) of the same source
		- the source is FROZEN through this borrow; write via `*p = v`
	- `*T` raw pointer: FFI / struct heap pointer; no borrow-checker rules
	- mutual exclusivity of `&T` and `&mut T` is what avoids data races
		- nobody reads while a writer is active
		- nobody writes while readers are active
		- **natural question**: if reads and writes are mutually exclusive, how do you mutate shared state?
			- short answer: use a `channel` / `Mutex` / `RwMutex` / `Atomic` / `condvar` wrapper
			- full answer with examples: [3-concurrency.md ](3-concurrency.md#concurrency-patterns-mutating-shared-data)

lang		| one-liner
----		|----
volt		| pass-by-value MOVES ownership; ownership is enforced at compile time.
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
`&T`, `&mut T`, `*T`			| n/a			| Borrows can't be moved or cloned; source frozen while held	|


### `volt` vs `C` vs `Go`
&nbsp;						| &nbsp;							| &nbsp;												| &nbsp;
----						|----								|----													|----
`primitives`				| `VOLT`							| `C`													| `GO`
pass-by-value `f(t)`		| **COPY**							| **COPY**												| **COPY**
read-only					| `f(n &int)`						| `f(const int *n)`										| `f(n *int)` (no marker)
read-write					| `f(n *int)`						| `f(int *n)`											| `f(n *int)`
at the call site			| `f(x)`							| `f(&x)`												| `f(&x)`
aliasing rule enforced		| yes (compile)						| no (UB possible)										| no (race possible)
&nbsp;						| &nbsp;							| &nbsp;												| &nbsp;
&nbsp;						| &nbsp;							| &nbsp;												| &nbsp;
`struct`					| `VOLT`							| `C`													| `GO`
allocate					| `new T{...}`						| `malloc + manual free`								| `&T{...}` (GC)
pass-by-value `f(t)`		| **MOVE** — `t` invalidated		| **COPY** (memcpy)										| **COPY**
read `t.f` after `f(t)`		| compile error						| OK (callee owns a copy)								| OK (callee owns a copy)
pass for write				| `f(t *T)` — exclusive				| `f(T* t)`												| `f(t *T)`
two mutable refs OK?		| NO (compile error)				| YES (UB if misused)									| YES (data race risk)
cleanup						| `def` + `Drop` method				| manual `free()` + cleanup								| finalizers (rare)
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
