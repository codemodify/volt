#### sync primitives
- `chan T`
	```go
	var ch chan int = new()
	var valFromChan, ok = read(ch)
	write(ch, valFromChan)
	close(ch)
	```
	- ony **owned** `T` values cross a channel.
	- writing on a closed channel is a runtime panic.
	- writing after a receiver has stopped reading blocks until the buffer fills.
	- reading from a closed-and-drained channel returns the zero value and `ok == false`.
- `mutex T` / `rwmutex T` / `atomic T` — see [mutating shared data](#concurrency-patterns---mutating-shared-data)
- `waitgroup` / `once` — coordination primitives (no payload); see same section

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
```go
fun producer(out chan int) {
    var i int = 1
    for i <= N {
        write(out, i)
        i = i + 1
    }
}

fun consumer(in chan int) {
    var sum int = 0
    for {
        v, ok := read(in)
        if !ok { break }
        log.Println("%d", v)
    }
}
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
fun worker(jobs chan int, results chan int) {
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
    var w int = 0
    for w < 3 {
        run worker(jobs, results)
        w = w + 1
    }

    // (2) Dispatch the work. Each `write(jobs, j)` goes to one worker.
    var j int = 0
    for j < 10 {
        write(jobs, j)
        j = j + 1
    }
    close(jobs)                       // signal "no more jobs"

    // (3) Collect results. We sent 10 jobs, so expect 10 results.
    var got int = 0
    for got < 10 {
        var r int = read(results)
        log.Println("result=%d", r)
        got = got + 1
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
			var i int = 0
			for i < 10 {
				var v Counter = c.Lock()		// acquire — v is a guard
				v.value = v.value + 1			// exclusive write through the guard
				i = i + 1
			}									// guard drops here → lock released
		}

		type Counter struct {
			value int
		}

		var c mutex Counter = new{value: 0}		// init the inner Counter via braces

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
			var i int = 0
			for i < 100 {
				var v Snapshot = s.Lock()       // exclusive: no readers, no writers
				v.version = v.version + 1
				v.payload = recompute(v.payload)
				i = i + 1
			}                                   // writer guard drops → exclusive lock released
		}

		fun reader(s rwmutex Snapshot) {
			var i int = 0
			for i < 1000 {
				var v Snapshot = s.LockRead()   // shared: other readers may proceed too
				observe(v.version, v.payload)
				i = i + 1
			}                                   // reader guard drops → read lock released
		}

		type Snapshot struct {
			version int
			payload int
		}

		var s rwmutex Snapshot = new{version: 0, payload: 0}

		run writer(s)                           // 1 writer thread
		run reader(s)                           // N reader threads run in parallel
		run reader(s)                           // — each LockRead() does NOT block the other
		```
	- **`atomic T`** — for word-sized primitives only
		- CPU-level atomic load / store / add / compare-and-swap
		- No lock; the hardware enforces atomicity for single-word ops:
		```go
		var hits atomic int = new{}
		hits.Add(1)                        // single CPU instruction
		var n int = hits.Load()            // single CPU instruction
		```
		- `atomic` is roughly 100x faster than a `mutex`.
		- limited to primitives (int, ptr, bool); can't wrap a struct.

- answer 3: coordination, not data — `waitgroup`, `once`
	- These don't protect a value; they coordinate timing across threads. Cheap to allocate (~16-24 bytes) and orthogonal to the mutex/atomic family above.
	- **`waitgroup`** — counter; `Wait()` blocks until it hits zero
		- the "spawn N workers, wait for all to finish" idiom in one type
		- `Add(n)` bumps the counter (can be called dynamically as new work appears); `Done()` is `Add(-1)`; `Wait()` blocks until the counter reaches 0 and then returns to every waiter at once
		- cheaper than juggling `N` channel reads — one futex wake regardless of N waiters
		```go
		var wg waitgroup = new()
		var i int = 0
		for i < N {
			wg.Add(1)
			run worker(wg, ...)
			i = i + 1
		}
		wg.Wait()                          // single block until all N workers Done()
		```
	- **`once`** — guarantees a block of code runs exactly once across all threads
		- two-method contract: `Begin()` returns 1 to the *first* caller (others block until init completes), `Done()` marks init complete and wakes everyone
		- typical pattern is `if o.Begin() == 1 { ...init...; o.Done() }` — every caller is guaranteed init is complete by the time the block finishes
		- ideal for lazy first-touch initialization (loading config, opening a shared resource)
		```go
		var o once = new()
		fun ensure_ready(o once, cfg atomic *Config) {
			if o.Begin() == 1 {
				// runs exactly once across all threads
				load_and_publish(cfg)
				o.Done()
			}
			// every caller proceeds here after init is complete
		}
		```

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
