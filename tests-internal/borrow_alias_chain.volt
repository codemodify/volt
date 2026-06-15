// Cross-statement borrow alias tracking: `var b2 = b1` where b1 is
// itself a borrow propagates the source-tracking metadata so the
// source-freeze rule still fires correctly even through an alias
// chain.
package main
import "log"

fun main() int {
	var x int = 7
	// First write borrow (`*int`).
	var b1 *int = &x
	// Alias: b2 inherits b1's source tracking but doesn't bump the
	// source's borrow slot a second time.
	var b2 *int = b1

	// Writes through either pointer reach x.
	*b1 = 11
	*b2 = *b2 + 1
	// b1/b2 in scope here so x is still frozen — direct write would
	// be rejected. Use the write borrow instead.
	if *b1 != 12 { ret 1 }
	if *b2 != 12 { ret 2 }

	// Once both go out of scope, x is writable again.
	log.Println("alias chain ok: x=%d", *b2)
	ret 42
}
