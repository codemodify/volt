// Cross-statement borrow alias: when b1 (original) and b2 (alias)
// both go out of scope, the source's borrow slot is fully released
// — re-borrowing works after the block closes.
package main
import "log"

fun main() int {
	var x int = 100

	{
		var b1 &mut int = &mut x
		var b2 &mut int = b1
		*b1 = 1
		*b2 = *b2 + 1
		if *b1 != 2 { ret 1 }
	}                       // BOTH b1 + b2 go out of scope here.

	// x should be writable again — the alias didn't leak a phantom
	// borrow slot.
	x = 50
	if x != 50 { ret 2 }

	// Verify shared-borrow alias works the same: many shared aliases
	// at once are fine, source still readable.
	{
		var s1 &int = &x
		var s2 &int = s1
		var s3 &int = s2
		var sum int = *s1 + *s2 + *s3
		if sum != 150 { ret 3 }    // 50 * 3
	}

	x = 999
	if x != 999 { ret 4 }

	log.Println("alias release ok")
	ret 42
}
