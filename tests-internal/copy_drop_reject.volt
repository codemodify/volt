// EXPECTED-NEGATIVE: Copy and Drop are mutually exclusive. `Res` has
// all-Copy fields (one int) but a Drop method, so it must keep MOVE
// semantics — bit-copying it and dropping each copy would run the
// resource cleanup more than once (os.File is the real-world case:
// all-Copy fields, but a Drop that closes the fd). Reusing `r` after it
// was moved into use() must be REJECTED. (If this test ever BUILDS, the
// Copy-struct analysis wrongly treats a Drop type as Copy.)
package main

import "log"

type Res struct {
	id int
}

fun (r Res) Drop() {
	log.Println("drop %d", r.id)
}

fun use(r Res) {
	log.Println("use %d", r.id)
}

fun main() int {
	var r Res = new Res {id: 7}
	use(r)
	use(r) // use-after-move — Res is NOT Copy because it has a Drop
	ret 42
}
