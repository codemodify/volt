#### sync primitives
- `chan T`
	```go
	var ch chan int = new()         // default cap = 0 (unbuffered — rendezvous)
	var bc chan int = new(8)        // buffered: holds up to 8 values
	var valFromChan, ok = read(ch)
	write(ch, valFromChan)
	close(ch)
	```
	- only **owned** `T` values cross a channel.
	- **default `new()` is cap = 0 (unbuffered, same as Go)** — each `write` blocks until a matching `read` arrives. `new(N)` allocates a buffer of N.
	- writing on a closed channel is a runtime panic.
	- writing on a buffered channel blocks once the buffer is full and the receiver is behind.
	- reading from a closed-and-drained channel returns the zero value and `ok == false`.

	**Multiplicity contracts (`chan11 T`, `chan1N T`, `chanN1 T`, `chanNN T`)** — declare the channel's intended reader/writer cardinality at the type level and let the compiler verify it. Notation: `chan<readers><writers>`, `1` = exactly one endpoint, `N` = one or more.

	| Type        | Readers | Writers |
	|-------------|---------|---------|
	| `chan11 T`  | one     | one     |
	| `chan1N T`  | one     | many    |
	| `chanN1 T`  | many    | one     |
	| `chanNN T`  | many    | many    |

	```go
	var ch chan11 int = new()          // exactly one reader, exactly one writer
	var jobs chanN1 int = new(8)       // many readers, one writer
	```
	- The contract is checked at the **declaring scope** by walking the function body and counting endpoints. Each `read(ch)` / `write(ch, v)` / `close(ch)` in the declaring thread, and each `run f(ch)` with a directional param (`chan read T` / `chan write T`), counts as an endpoint.
	- A `run f(ch)` **inside a `for` loop** counts as "many" of that endpoint kind (the iteration spawns N threads). For "One X" contracts this is a compile error — use the matching "Many" form instead.
	- Passing a contract channel to a function with an **unrestricted** `chan T` parameter is conservatively counted as **both** a reader and a writer endpoint (the callee could do either). Narrow to `chan read T` / `chan write T` on the param for tighter checking.
	- Limitations: the contract is enforced at the variable's declaring scope only — aliasing (`var b chan int = a`) or escaping the channel via a return value/struct field is not tracked.

	**Direction (`chan read T` / `chan write T`)** — channel handles can be narrowed to a single direction at the type level. Many readers and many writers may share the same channel; direction is purely a compile-time discipline so a function can declare "I only consume" or "I only produce":

	```go
	fun producer(out chan write int) {       // can write/close, cannot read
	    for i := 0; i < 5; i++ { write(out, i) }
	    close(out)
	}

	fun consumer(in chan read int) {         // can read, cannot write/close
	    for {
	        v, ok := read(in)
	        if !ok { break }
	        log.Println("%d", v)
	    }
	}

	var ch chan int = new()                  // unrestricted handle (default cap=0)
	run producer(ch)                         // narrows to `chan write int`
	run consumer(ch)                         // narrows to `chan read  int`
	```
	- `chan read T` permits `read(ch)` only — `write` and `close` on it are compile errors.
	- `chan write T` permits `write(ch, v)` and `close(ch)` — `read` on it is a compile error.
	- Both are still **reference-typed**: copying the handle gives another reference to the same channel. Many threads may hold `chan read T` over the same channel (many readers), and many may hold `chan write T` (many writers).
	- An unrestricted `chan T` narrows implicitly on call to either directional form; the reverse (widening back to `chan T`) is not allowed.
- `mutex T` / `rwmutex T` / `atomic T` — see [mutating shared data](#concurrency-patterns---mutating-shared-data)
- `waitgroup` / `once` / `condvar` — coordination primitives (no payload); see same section
	- `condvar`: Pass 750 wait/signal/broadcast pair built on the futex `cond_t`. `c.Wait(m)` atomically releases mutex `m`, blocks, and reacquires `m` before returning. `c.Signal()` wakes one waiter; `c.Broadcast()` wakes all. Use when chan/waitgroup/once don't fit (predicate-wait patterns).

#### `select` -  reading concurrently from different channels using
```go
select {
case v, ok := read(ch1):
case v, ok := read(ch2):
case v, ok := read(ch3):
default:
}
```

- `select` **blocks** until exactly one case is ready, then runs that case's body.
- `default:` **non-blocking** — if no other case is ready, `default` runs immediately.
- If multiple cases are simultaneously ready, one is picked.

#### concurrency patterns - producer / consumer
Direction declarations make the contract obvious: producer only writes, consumer only reads. The unrestricted `new()` handle narrows automatically at the call site.

```go
fun producer(out chan write int) {
    for i := 1; i <= N; i++ {
        write(out, i)
    }
    close(out)
}

fun consumer(in chan read int) {
    for {
        v, ok := read(in)
        if !ok { break }
        log.Println("%d", v)
    }
}

var ch chan int = new()                 // cap=0 — rendezvous; pair with new(N) for a buffer
run producer(ch)                         // narrows to `chan write int`
run consumer(ch)                         // narrows to `chan read  int`
```

#### concurrency patterns - non-blocking poll
```go
select {
case v := read(ch):
    handle(v)
default:
    // nothing ready right now — do other work
}
```

#### concurrency patterns - fan-in (many producers, one consumer)
```go
run producer(results)
run producer(results)
run producer(results)

for  {
    var r int = read(results)
    consumer(r)
}
```

#### concurrency patterns - fan-out (one source, many workers)
```go
fun worker(jobs chan read int, results chan write int) {
    for {
        j, ok := read(jobs)
        if !ok { break }              // jobs closed and drained → exit
        write(results, j * j)         // do the work, publish the result
    }
}

fun main() {
    var jobs    chan int = new(8) chan int
    var results chan int = new(8) chan int

    // (1) Spawn the worker pool. All N workers read from `jobs`.
    for w := 0; w < 3; w++ {
        run worker(jobs, results)
    }

    // (2) Dispatch the work. Each `write(jobs, j)` goes to one worker.
    for j := 0; j < 10; j++ {
        write(jobs, j)
    }
    close(jobs)                       // signal "no more jobs"

    // (3) Collect results. We sent 10 jobs, so expect 10 results.
    for got := 0; got < 10; got++ {
        var r int = read(results)
        log.Println("result=%d", r)
    }
}
```

#### concurrency patterns - request + reply channel to reply on
```go
type Req struct {
    id    int
    reply chan int
}

fun server(reqs chan Req) {
    for {
        r, ok := read(reqs)
        if !ok { break }
        write(r.reply, compute(r.id))
    }
}

fun client(reqs chan Req, id int) int {
    var reply chan int = new(1) chan int
    write(reqs, Req{id: id, reply: reply})
    ret read(reply)
}
```

#### concurrency patterns - mutating shared data
The ownership model says that at any *instant* you can have either many readers `&T` **or** one writer `*T` — **never both at the same time**. This is the "many readers, one writer" rule (sometimes called *aliasing-XOR-mutation* in PL theory).
***If reads and writes are mutually exclusive, how do you mutate something that other code is using?***

- answer 1: cross-thread coordination using channels
	- one thread owns the data others request it through a channel
	- cost: one channel round-trip per operation
		- fits coarse-grained work (handlers, request/response, pipelines) well
		- too much overhead for a single hot counter incremented millions of times per second

- answer 2: cross-thread shared state — `mutex`, `rwmutex`, `atomic`
	- when message-passing is the wrong shape — multiple threads genuinely need to read and write
	the same memory — the language adds keyword-shape wrapper types whose internals serialize access. All three are **reference-typed** like `chan T` — copying the handle gives another reference to the **same** primitive (otherwise threads would lock different copies and the serialization would be meaningless). Declared with the same `var <name> <kw> <T>` shape as channels:
	- **`mutex T`** — wrapper around an owned `T` accessed through a guard
		- `Lock()` blocks until the lock is acquired, then binds a guard to a local variable
		- The guard reads/writes the protected `T` directly (no copy); field writes go straight into the mutex's storage
		- The lock releases **automatically** when the guard variable goes out of scope (RAII — same machinery as struct `Drop`). There is no `Unlock` method.
		- The guard cannot escape its scope: it can't be passed to a function, returned, or aliased — the lock has to release where it was acquired.
		- cost: ~10ns uncontested; ~1µs under contention
		```go
		fun bumper(c mutex Counter) {
			for i := 0; i < 10; i++ {
				var v Counter = c.Lock()		// acquire — v is a guard
				v.value = v.value + 1			// exclusive write through the guard
			}									// guard drops here → lock released
		}

		type Counter struct {
			value int
		}

		var c mutex Counter = new {value: 0}		// init the inner Counter via braces

		run bumper(c)
		run bumper(c)
		```
	- **`rwmutex T`** — same shape, two locks for read-mostly workloads
		- `Lock()` binds a writer guard — one writer at a time, no readers alongside
		- `LockRead()` binds a reader guard — many readers may coexist, no writer alongside
		- Both guards auto-release at scope end (same Drop-based release as `mutex T`)
		- cost: a read lock is roughly the same as a `mutex` lock when uncontested, but many readers can hold it at once — the win is letting N readers proceed in parallel instead of serializing them
		```go
		// One writer increments the snapshot; many readers observe it.
		// Readers never block each other — they only wait when the
		// writer is mid-update.

		fun writer(s rwmutex Snapshot) {
			for i := 0; i < 100; i++ {
				var v Snapshot = s.Lock()       // exclusive: no readers, no writers
				v.version = v.version + 1
				v.payload = recompute(v.payload)
			}                                   // writer guard drops → exclusive lock released
		}

		fun reader(s rwmutex Snapshot) {
			for i := 0; i < 1000; i++ {
				var v Snapshot = s.LockRead()   // shared: other readers may proceed too
				observe(v.version, v.payload)
			}                                   // reader guard drops → read lock released
		}

		type Snapshot struct {
			version int
			payload int
		}

		var s rwmutex Snapshot = new {version: 0, payload: 0}

		run writer(s)                           // 1 writer thread
		run reader(s)                           // N reader threads run in parallel
		run reader(s)                           // — each LockRead() does NOT block the other
		```
	- **`atomic T`** — for word-sized primitives only
		- CPU-level atomic Read / Write / Add / CompSwap
		- No lock; the hardware enforces atomicity for single-word ops:
		```go
		var hits atomic int = new {}
		hits.Add(1)                        // single fused CPU instruction
		var n int = hits.Read()            // single CPU instruction
		hits.Write(0)                      // single CPU instruction
		var ok bool = hits.CompSwap(0, 1)  // true = success, false = current value differed
		```
		- `atomic` is roughly 100x faster than a `mutex`.
		- limited to primitives (int, ptr, bool); can't wrap a struct.
		- Only `Add` has a dedicated hardware instruction besides Read/Write/CompSwap. `Sub` folds into `Add(-x)`; `Mul`/`Div`/etc. don't exist because they'd just be CompSwap loops you can write yourself.

- answer 3: coordination, not data — `waitgroup`, `once`
	- These don't protect a value; they coordinate timing across threads. Cheap to allocate (~16-24 bytes) and orthogonal to the mutex/atomic family above.
	- **`waitgroup`** — counter; `Wait()` blocks until it hits zero
		- the "spawn N workers, wait for all to finish" idiom in one type
		- `Add(n)` bumps the counter (can be called dynamically as new work appears); `Done()` is `Add(-1)`; `Wait()` blocks until the counter reaches 0 and then returns to every waiter at once
		- cheaper than juggling `N` channel reads — one futex wake regardless of N waiters
		```go
		var wg waitgroup = new()
		for i := 0; i < N; i++ {
			wg.Add(1)
			run worker(wg, ...)
		}
		wg.Wait()                          // single block until all N workers Done()
		```
	- **`once`** — guarantees a block of code runs exactly once across all threads
		- **`o.Do(fn)`** — Go-style closure form. Takes a `fun()` value (named function or closure literal). Runs it exactly once across all callers; every caller blocks until that single run completes, then proceeds.
		- No `Done()` method, no manual release — the runtime gates the call entirely. Ideal for lazy first-touch initialization (loading config, opening a shared resource). Anything that needs to happen "if I'm the first arriver" goes inside the closure.
		```go
		var o once = new()

		fun ensure_ready(o once, cfg atomic *Config) {
			o.Do(fun() {
				log.Println("first-touch init")
				load_and_publish(cfg)
			})
			// every caller reaches here only after init has completed
		}
		```

#### worked example - `mutex` for a shared counter

Two workers race to bump a shared counter. The guard form: `Lock()` returns a guard bound to a variable; mutations to the guard's fields go straight to the mutex's storage; release fires when the guard's scope ends.

```go
package main

import "log"

type Counter struct {
    value int
}

fun bumper(c mutex Counter, done chan int) {
    for i := 0; i < 1000; i++ {
        var v Counter = c.Lock()        // acquire — v is a guard over Counter
        v.value = v.value + 1           // exclusive write through the guard
    }                                   // guard drops here → lock released
    write(done, 1)
}

fun main() int {
    var c    mutex Counter = new {value: 0}
    var done chan int      = new(2) chan int

    run bumper(c, done)
    run bumper(c, done)
    read(done)
    read(done)

    var snap Counter = c.Lock()
    if snap.value == 2000 {             // -> 2000 (no lost updates)
        log.Println("counter ok")
        ret 42
    }
    ret 0
}
```

What to notice:
- `var c mutex Counter = new {value: 0}` — payload is initialized via the brace form. `mutex` rejects the parens form because it has no size.
- `c.Lock()` is special — it binds the guard to the variable on its LHS; calling it elsewhere is a compile error pointing back to this idiom.
- No `Unlock` method. The guard's storage carries the handle internally and fires `volt_mutex_unlock` when the variable's scope ends.
- The guard cannot be passed to another function or returned — the lock has to release where it was acquired. The compiler enforces this.

#### worked example - `once` for first-touch initialization

`o.Do(fn)` runs `fn` exactly once across every caller. Every other caller blocks inside `Do` until that one run completes, then proceeds.

```go
package main

import "log"

fun ensure_loaded(o once, cfg atomic *Config) {
    o.Do(fun() {
        // Runs on exactly one thread, even though many threads call
        // ensure_loaded concurrently. Every other caller blocks here
        // until this body returns.
        var initial *Config = load_config_from_disk()
        cfg.Write(initial)
        log.Println("config loaded")
    })
    // After Do returns, init is guaranteed complete — for all callers.
}
```

What to notice:
- `Do` is the only method on `once`. No `Begin`, no `Done`, no manual release. Anything that needs to happen "if I'm the first arriver" goes inside the closure — the closure runs only on the first arriver.
- The closure must be a `fun()` value (named function or anonymous literal). Captures are by-move / by-copy (see [the function-value rules](#)). Borrow captures (`&T` / `*T`) are rejected — the closure could outlive the borrowed storage.

#### concurrency patterns - use the right tool
when												| what
----												|----
One thread, sequential access						| nothing extra
Many threads, coarse-grained operations				| `chan T` + owner thread
Many threads, shared struct, mixed reads + writes	| `mutex T`
Many threads, read-mostly shared struct				| `rwmutex T`
Many threads, "wait for N workers to finish"		| `waitgroup`
Many threads, "run init exactly once across all"	| `once`
Many threads, single counter / flag / pointer		| `atomic T`
