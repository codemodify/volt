// Concurrency demo: 4 workers compute SHA-256 hashes of distinct
// inputs in parallel, post their results to a chan1N back to main,
// which collects and verifies. Exercises `run`, `chan1N`, `waitgroup`,
// `atomic`, plus the crypto stack — proving the concurrency
// primitives compose with the rest of the stdlib.

package main

import "crypto/sha256"
import "log"

type Job struct {
    idx     int
    payload string
}

type Result struct {
    idx  int
    hash string
}

fun worker(j Job, out chan write Result, done atomic int) {
    var r Result = new Result {idx: j.idx, hash: sha256.SumHex(j.payload)}
    write(out, r)
    done.Add(1)
}

fun main() int {
    var pass int = 0

    var inputs []string = new(4) []string { "", "", "", "" }
    inputs[0] = "abc"
    inputs[1] = "hello world"
    inputs[2] = "the quick brown fox"
    inputs[3] = "volt"

    // chan1N — main is the sole reader; workers are the many writers.
    var out chan1N Result = new(8)
    var done atomic int    = new {}

    // Spawn one worker per job.
    for i := range 4 {
        var j Job = new Job {idx: i, payload: inputs[i]}
        run worker(j, out, done)
    }

    // Collect 4 results. Order is non-deterministic — index back.
    var hashes []string = new(4) []string { "", "", "", "" }
    for i := range 4 {
        // r.idx is a Copy primitive (int) so reading it doesn't move
        // r — Pass 111 widening. The subsequent r.hash read consumes
        // r as expected.
        var r Result = read(out)
        hashes[r.idx] = r.hash
    }

    // All workers finished writing (done counter reaches 4 EITHER
    // before or after main's read loop completes — write happens
    // before Add, so done==4 after we've drained the channel).
    // Spin briefly just in case the last Add hasn't landed yet
    // (workers are OS threads; very tight race window).
    for done.Read() < 4 { }
    if done.Read() == 4 { pass = pass + 1 }

    // Verify each hash against the canonical values.
    if hashes[0] == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad" {
        pass = pass + 1
    }
    if hashes[1] == "b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9" {
        pass = pass + 1
    }
    if hashes[2] == "9ecb36561341d18eb65484e833efea61edc74b84cf5e6ae1b81c63533e25fc8f" {
        pass = pass + 1
    }
    if hashes[3] == "6aafbd2b3f430155014edea9e4605bd7da97330739b845038828ddc4851b3ba5" {
        pass = pass + 1
    }

    log.Println("pass=%d/5", pass)
    if pass == 5 { ret 42 }
    ret 0
}
