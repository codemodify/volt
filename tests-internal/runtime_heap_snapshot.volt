// runtime.HeapSnapshot + per-size-class accessors. HeapSnapshot
// bundles the scalar totals with per-class live-block counts so a
// single call gives the whole allocator picture.
package main
import "log"
import "runtime"

fun main() int {
	var n int = runtime.NumSizeClasses()
	if n <= 0 { ret 1 }

	// Allocate a batch of small slices to populate a low size class.
	var keep [][]int = new(20) [][]int {}
	for i := 0; i < 20; i++ {
		var s []int = new(4) []int {}
		s[0] = i
		keep[i] = s
	}

	var snap runtime.Snapshot = runtime.HeapSnapshot()
	if snap.NumClasses != n { ret 2 }
	if len(snap.LiveByClass) != n { ret 3 }
	if len(snap.ClassBytes) != n { ret 4 }
	// ClassBytes should be the doubling table 16,32,64,...
	if snap.ClassBytes[0] != 16 { ret 5 }
	if snap.ClassBytes[1] != 32 { ret 6 }
	// AllocTotal >= FreeTotal always.
	if snap.AllocTotal < snap.FreeTotal { ret 7 }
	// Some class must have live blocks (we're holding 20 slices + their
	// backing arrays).
	var anyLive bool = false
	var sumLive int = 0
	for i := 0; i < n; i++ {
		if snap.LiveByClass[i] > 0 { anyLive = true }
		sumLive = sumLive + snap.LiveByClass[i]
	}
	if !anyLive { ret 8 }

	// Per-class accessor agrees with the snapshot.
	if runtime.LiveCountClass(0) != snap.LiveByClass[0] { ret 9 }

	// AllocCountClass / AllocBytesClass relationship: bytes == count*classBytes.
	for i := 0; i < n; i++ {
		var cnt int = runtime.AllocCountClass(i)
		var byt int = runtime.AllocBytesClass(i)
		if byt != cnt * snap.ClassBytes[i] { ret 10 }
	}

	// Keep `keep` live until after the snapshot read so the live counts
	// above are real.
	var checksum int = 0
	for i := 0; i < 20; i++ { checksum = checksum + keep[i][0] }
	if checksum != 190 { ret 11 }   // sum 0..19

	// MemProfileReset zeroes the lifetime histogram but not live counts.
	var liveBefore int = runtime.LiveCountClass(0)
	runtime.MemProfileReset()
	if runtime.AllocCountClass(0) != 0 { ret 12 }
	if runtime.LiveCountClass(0) != liveBefore { ret 13 }

	log.Println("snapshot ok: classes=%d sumLive=%d", n, sumLive)
	ret 42
}
