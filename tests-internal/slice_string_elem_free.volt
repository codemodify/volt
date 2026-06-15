// S1 (move model): a []string the compiler proves it solely owns has its
// per-element string PAYLOADS freed at scope exit (not just the backing) —
// the #5 element-payload leak, now safe because owned-element reads deep-copy
// (S1a) so nothing aliases the slice's element strings. Looped 100k times;
// a double-free in the element-free path would crash, and a leak shows as
// VmPeak growth (verified ~flat at 80 kB over 2M iters separately).
package main

fun build() int {
	var xs []string = new(4) []string {}
	var i int = 0
	for i < 4 {
		xs[i] = "item" + "value" // heap string moved into element i
		i = i + 1
	}
	var total int = 0
	var j int = 0
	for j < 4 {
		var e string = xs[j] // index-binding read → deep-copied (S1a)
		total = total + len(e)
		j = j + 1
	}
	ret total // xs freed here: each element string + the backing
}

fun main() int {
	var acc int = 0
	var k int = 0
	for k < 100000 {
		acc = acc + build()
		k = k + 1
	}
	// build() = 4 * len("itemvalue")=9 = 36; 100000*36 = 3,600,000
	if acc == 3600000 {
		ret 42
	}
	ret 0
}
