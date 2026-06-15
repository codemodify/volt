// Cross-package method-receiver borrow rejection (item 9): a method
// imported from another package (bytes.Builder.WriteByte, receiver
// `*Builder`) needs write access to its receiver. Calling it while a
// write borrow (`*T`) of the receiver is still active must be rejected —
// the method registry is populated from AddExternal, so this exercises
// the cross-package path specifically.
package main
import "bytes"

fun main() int {
	var b bytes.Builder = new bytes.Builder {}
	// Hold a write borrow of b.
	var p *bytes.Builder = &b
	// Call a mutating method on b while the borrow is live → ERROR.
	b.WriteByte(65)
	// Use p so it isn't flagged unused (never reached past the error).
	var _drop *bytes.Builder = p
	ret 0
}
