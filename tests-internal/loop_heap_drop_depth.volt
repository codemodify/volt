// Regression (item 2 / hardening): a heap value (string/slice) first
// declared with a NON-heap initializer and then BUILT inside a loop
// must not be freed every iteration. The drop must bind to the var's
// declaration scope, not the loop-body scope. Before the fix, the
// loop-built `pad` was freed each iteration and read as NUL once a
// later alloc reused the block (surfaced via strconv pad functions).
package main
import "log"

fun zpad(width int, body string) string {
	var pad string = ""                       // non-heap init → no drop yet
	for i := 0; i < width - len(body); i++ {
		pad = pad + "0"                       // first heap assign is in-loop
	}
	ret pad + body                            // use as concat operand
}

fun main() int {
	var pass int = 0
	if zpad(4, "ff") == "00ff" { pass = pass + 1 }
	if zpad(8, "101") == "00000101" { pass = pass + 1 }
	if zpad(2, "abcd") == "abcd" { pass = pass + 1 }   // width<=len → unpadded
	// Build several to churn the allocator (would surface freelist reuse).
	var ok bool = true
	for i := 0; i < 30; i++ {
		var r string = zpad(6, "xy")
		if r != "0000xy" { ok = false }
	}
	if ok { pass = pass + 1 }

	// Same hazard for a slice built in a loop then returned via append-ish use.
	var acc []int = new(0) []int {}
	for i := 0; i < 5; i++ { acc = append(acc, i * i) }
	if len(acc) == 5 { pass = pass + 1 }
	if acc[4] == 16 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 6 { ret 42 }
	ret 0
}
