// #6: a channel created, used, and dropped inside a helper is freed at
// the helper's scope exit (volt_chan_release drops the creator's ref to
// 0 → buffer + handle freed). Calling the helper in a tight loop must
// neither leak nor crash — this exercises the single-threaded
// scope-end release path. 1000 channels are allocated and freed.

package main

fun roundtrip(n int) int {
	var ch chan int = new(8) chan int
	var i int = 0
	for i < n {
		write(ch, i)
		i = i + 1
	}
	var sum int = 0
	var j int = 0
	for j < n {
		sum = sum + read(ch)
		j = j + 1
	}
	ret sum
	// ch released here at scope exit — buffer + handle freed.
}

fun main() int {
	var total int = 0
	var k int = 0
	for k < 1000 {
		total = total + roundtrip(6) // each call frees its own channel
		k = k + 1
	}
	// 1000 * (0+1+2+3+4+5) = 1000 * 15 = 15000
	if total == 15000 {
		ret 42
	}
	ret 0
}
