// Package runtime: low-level observability + control surface over
// volt's runtime (allocator, thread state, race detector). Most
// programs never need it; it's for benchmarks, leak hunts, custom
// memory tuning, and integration tests.

package runtime

// Compact requests the allocator to walk each size-class freelist,
// sort by address, and merge adjacent free blocks into larger
// contiguous regions. Reduces long-run fragmentation in programs
// that repeatedly allocate + free in mixed sizes. Safe to call any
// time; takes the global allocator lock for the duration.
//
// Pass 752 ships this as a no-op stub; the substance lands when the
// design is finalized. Calling sites can be wired today against the
// stable surface.
fun Compact() {
    syscallCompact()
}

// ThreadCount returns the number of OS threads volt's runtime has
// registered with the race detector (when -race is active) or 0
// when the detector hasn't been enabled. Each thread spawned via
// `run f(...)` registers on its first sync operation. Useful for
// benchmarks ("did all 8 workers actually run?") and leak hunts
// ("why are there 17 threads when I only spawned 4?").
fun ThreadCount() int {
    ret syscallThreadCount()
}

// RaceViolations returns the cumulative count of data-race warnings
// detected by the runtime since program start (or the last
// ResetRaceViolations call). Returns 0 when the detector isn't on
// (no `-race` flag). Use in tests to assert race-freedom:
//   if runtime.RaceViolations() != 0 { t.Fail("races detected") }
// Or to count expected races in deliberate-race demos.
fun RaceViolations() int {
    ret syscallRaceViolations()
}

// ResetRaceViolations zeroes the cumulative race counter. Useful in
// test harnesses that run multiple sub-tests and want per-test
// race accounting.
fun ResetRaceViolations() {
    syscallResetRaceViolations()
}

fun syscallRaceViolations() int { ret 0 }
fun syscallResetRaceViolations() {}

// HeapBytes returns the total bytes mmap'd by the allocator (sum of
// every arena chunk + huge-allocation block currently held by the
// runtime). NOT the active-allocation footprint — fragmentation and
// the current arena's unused tail also contribute. Call after
// Compact() for the most accurate reading.
fun HeapBytes() int {
    ret syscallHeapBytes()
}

// FreelistCount returns the number of FREE blocks on the freelist for
// size class `sc` (0-indexed, currently 0..11 corresponding to 16,
// 32, 64, ..., 32768 byte classes). Out-of-range sc returns 0. Use
// case: fragmentation diagnostics — many small free blocks but no
// large ones often means Compact() would help.
fun FreelistCount(sc int) int {
    ret syscallFreelistCount(sc)
}

// NumSizeClasses returns the total number of allocator size classes
// (12 in v1). Use with FreelistCount to iterate over all classes.
fun NumSizeClasses() int {
    ret syscallNumSizeClasses()
}

// SetArenaChunkSize overrides the arena's per-chunk mmap size. The
// runtime allocates a new chunk whenever the current one is full;
// each chunk is one mmap call. Default 1 MiB. Useful for embedded
// targets (drop to 64 KiB) or large-heap programs (raise to 16 MiB
// to amortize syscall cost). Clamped to [4 KiB, 256 MiB] and rounded
// up to the page boundary.
fun SetArenaChunkSize(bytes int) {
    syscallSetArenaChunkSize(bytes)
}

fun syscallHeapBytes() int { ret 0 }
fun syscallNumSizeClasses() int { ret 0 }
fun syscallFreelistCount(sc int) int { ret 0 }
fun syscallSetArenaChunkSize(bytes int) {}

// AllocCount returns the lifetime count of volt_alloc calls — a
// monotonic counter that never decreases. Useful for "no-alloc
// hotspot" assertions: snapshot before, run the code, snapshot
// after, assert the delta is 0.
fun AllocCount() int {
    ret syscallAllocCount()
}

// FreeCount returns the lifetime count of volt_free calls. Always
// less than or equal to AllocCount. The delta (AllocCount-FreeCount)
// is a quick "raw block count currently held" estimate — though
// "freelist" blocks (returned to the allocator but not munmap'd) also
// count as live for this metric.
fun FreeCount() int {
    ret syscallFreeCount()
}

// LiveBytes returns the approximate signed delta of allocated minus
// freed payload bytes. Counts the full size-class slot (not the
// user-requested byte count), so allocate(17) lands in the 32-byte
// class and contributes 32. Approximate because:
//   * It excludes per-block 16-byte headers (so true RAM use is
//     LiveBytes + 16*(AllocCount-FreeCount)).
//   * Huge (>32 KiB) allocs are rounded UP to the next 4 KiB page.
//   * It's an atomic counter, so consecutive reads from different
//     threads will not match unless you've synchronized.
fun LiveBytes() int {
    ret syscallLiveBytes()
}

fun syscallAllocCount() int { ret 0 }
fun syscallFreeCount() int { ret 0 }
fun syscallLiveBytes() int { ret 0 }

// LiveCountClass returns the number of CURRENTLY-live (allocated, not
// freed) blocks in size class `sc` (0-indexed, 0..NumSizeClasses()-1).
// Out-of-range sc returns 0. The per-class detail behind HeapSnapshot;
// non-zero counts in a class you didn't expect points at a leak there.
fun LiveCountClass(sc int) int {
    ret syscallLiveCountClass(sc)
}

// LiveCountHuge returns the number of live mmap-direct (>32 KiB)
// allocations. These bypass the size-class freelists entirely.
fun LiveCountHuge() int {
    ret syscallLiveCountHuge()
}

// AllocCountClass returns the LIFETIME alloc count in size class `sc`
// — a monotonic histogram bucket, never decremented (until
// MemProfileReset). Pairs with AllocBytesClass for "where did all the
// allocations go?" analysis.
fun AllocCountClass(sc int) int {
    ret syscallAllocCountClass(sc)
}

// AllocBytesClass returns the LIFETIME slot bytes handed out in size
// class `sc`. slot bytes = AllocCountClass(sc) * SizeClassBytes(sc).
fun AllocBytesClass(sc int) int {
    ret syscallAllocBytesClass(sc)
}

// SizeClassBytes returns the byte capacity of size class `sc` (16, 32,
// 64, ... 32768). Lets callers label each HeapSnapshot bucket.
fun SizeClassBytes(sc int) int {
    ret syscallSizeClassBytes(sc)
}

// MemProfileReset zeroes the LIFETIME alloc histogram (AllocCountClass
// / AllocBytesClass per class + the huge scalars). Live counts are
// preserved — they reflect outstanding allocations. Use to scope a
// profile: MemProfileReset(); run(); MemProfileDump(path).
fun MemProfileReset() {
    syscallMemProfileReset()
}

// MemProfileDump writes the current allocation profile to `path` as a
// single-line JSON object:
//   {"size_classes":[{"bytes":16,"live":N,"alloc_count":M,"alloc_bytes":B},...],
//    "huge":{"live":N,"alloc_count":M,"alloc_bytes":B},
//    "totals":{"alloc_count":X,"free_count":Y,"live_bytes":Z}}
// Returns 0 on success, a negative errno on open/write failure. This
// is what `volt build --memprofile <path>` injects at main's exit; you
// can also call it directly for scoped profiles.
fun MemProfileDump(path string) int {
    ret syscallMemProfileDump(path)
}

fun syscallLiveCountClass(sc int) int { ret 0 }
fun syscallLiveCountHuge() int { ret 0 }
fun syscallAllocCountClass(sc int) int { ret 0 }
fun syscallAllocBytesClass(sc int) int { ret 0 }
fun syscallSizeClassBytes(sc int) int { ret 0 }
fun syscallMemProfileReset() {}
fun syscallMemProfileDump(path string) int { ret 0 }

// Snapshot is the structured return of HeapSnapshot — a point-in-time
// view of the allocator's live state. LiveByClass[i] is the count of
// live blocks in size class i; ClassBytes[i] is that class's byte
// capacity. Totals mirror the scalar accessors so a single call gives
// the whole picture.
type Snapshot struct {
    LiveBytes   int
    AllocTotal  int
    FreeTotal   int
    LiveHuge    int
    NumClasses  int
    LiveByClass []int
    ClassBytes  []int
}

// HeapSnapshot captures a structured view of the allocator's current
// live state in one call. Cheaper to reason about than calling each
// scalar accessor separately, and the per-class slices let callers
// render a histogram. The snapshot is assembled from several atomic
// reads, so it's internally near-consistent but not a single atomic
// instant under heavy concurrent churn.
fun HeapSnapshot() Snapshot {
    var n int = NumSizeClasses()
    var live []int = new(n) []int {}
    var bytes []int = new(n) []int {}
    for i := 0; i < n; i++ {
        live[i] = LiveCountClass(i)
        bytes[i] = SizeClassBytes(i)
    }
    ret new Snapshot {
        LiveBytes:   LiveBytes(),
        AllocTotal:  AllocCount(),
        FreeTotal:   FreeCount(),
        LiveHuge:    LiveCountHuge(),
        NumClasses:  n,
        LiveByClass: live,
        ClassBytes:  bytes,
    }
}

// syscallCompact bridges to runtime's volt_compact() via the
// syscall package's "named runtime call" mechanism. Putting the
// FFI wrapper here keeps runtime.Compact()'s public surface clean.
fun syscallCompact() {
}

fun syscallThreadCount() int {
    ret 0
}
