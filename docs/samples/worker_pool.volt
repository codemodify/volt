// worker_pool — a fixed pool of worker threads squares numbers pulled off a
// jobs channel and pushes results back. Shows the SHARED-HANDLE bucket and
// move-across-threads — the concurrency side of the memory model.
//
// MEMORY MODEL:
//   - Shared-handle bucket: `chan Job` / `chan Result` are reference-counted
//     handles (#6). `run worker(jobs, results)` hands each worker a handle to
//     the SAME channel — the runtime retains a ref per spawn and frees the
//     channel (buffer + struct) only when the last holder drops. No GC.
//   - Owned bucket, moved across the boundary: each `Job`/`Result` is MOVED
//     into the channel by `write` and MOVED out by `read` — the value crosses
//     the thread boundary with a single clear owner at every step (here they
//     are all-scalar structs → Copy fields → no heap payloads at all).
//   - `chan read T` / `chan write T` are compile-time direction discipline:
//     a worker can only consume jobs and only produce results.
//
// DEADLOCK SAFETY (#7): the obvious-looking "write all 100 jobs, THEN read all
// results" version DEADLOCKS with bounded channels — main blocks writing jobs
// while every worker blocks writing results and nobody is draining results.
// volt's runtime backstop CATCHES that at runtime ("deadlock detected", clean
// non-zero exit) instead of hanging forever. The fix below is the idiomatic
// one: feed jobs from their OWN goroutine so main drains results concurrently.
//
// MEASURED: 100 jobs / 4 workers in ~3 ms. (Aside: each `run` currently leaks
// its ~1 MB OS-thread stack — a known runtime gap, unrelated to the channel
// refcounting, which does reclaim correctly.)

package main

import "log"

type Job struct {
	id int
	n  int
}
type Result struct {
	id int
	sq int
}

fun worker(jobs chan read Job, results chan write Result) {
	for {
		j, ok := read(jobs) // a Job moves OUT of the channel to us
		if !ok {
			break // jobs closed + drained → done
		}
		var r Result = new Result{id: j.id, sq: j.n * j.n}
		write(results, r) // the Result moves INTO the channel
	}
}

fun produce(jobs chan write Job, n int) {
	for i := 0; i < n; i++ {
		write(jobs, new Job{id: i, n: i})
	}
	close(jobs) // tells the workers to stop once jobs is drained
}

fun main() int {
	var jobs chan Job = new(16) chan Job
	var results chan Result = new(16) chan Result
	var nJobs int = 100
	var nWorkers int = 4

	for w := 0; w < nWorkers; w++ {
		run worker(jobs, results) // each worker retains both channel handles
	}
	run produce(jobs, nJobs) // jobs fed from their own goroutine

	var total int = 0
	for i := 0; i < nJobs; i++ {
		var r Result = read(results) // drain results concurrently with production
		total = total + r.sq
	}
	log.Println("sum of squares 0..99 = %d", total)
	if total == 328350 {
		ret 42
	}
	ret 0
}
