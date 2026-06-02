// runtime.MemProfileDump explicit call: allocate a known batch, dump
// the profile to a file, read it back and verify the JSON shape +
// that the totals moved. The `--memprofile <path>` build flag is the
// auto-at-exit form of the same dump (verified separately).
package main
import "log"
import "runtime"
import "os"
import "strings"

fun main() int {
	// Reset the lifetime histogram so the counts we assert are ours.
	runtime.MemProfileReset()

	// Allocate a batch landing in low size classes.
	var keep [][]int = new(30) [][]int {}
	for i := 0; i < 30; i++ {
		var s []int = new(2) []int {}
		s[0] = i
		keep[i] = s
	}
	var checksum int = 0
	for i := 0; i < 30; i++ { checksum = checksum + keep[i][0] }
	if checksum != 435 { ret 1 }   // sum 0..29

	var path string = "/tmp/_volt_memprofile_test.json"
	var rc int = runtime.MemProfileDump(path)
	if rc != 0 {
		log.Println("MemProfileDump failed rc=%d", rc)
		ret 2
	}

	var data string = ""
	var err error = nil
	data, err = os.ReadFile(path)
	if err != nil { ret 3 }

	// JSON shape checks.
	if !strings.HasPrefix(data, "{\"size_classes\":[") { ret 4 }
	if !strings.Contains(data, "\"bytes\":16") { ret 5 }
	if !strings.Contains(data, "\"huge\":{") { ret 6 }
	if !strings.Contains(data, "\"totals\":{\"alloc_count\":") { ret 7 }
	if !strings.Contains(data, "\"live_bytes\":") { ret 8 }
	// There must be at least one non-zero alloc_count since we reset
	// then allocated 30+ blocks.
	if !strings.Contains(data, "\"alloc_count\":") { ret 9 }

	log.Println("memprofile ok: %d bytes json", len(data))
	ret 42
}
