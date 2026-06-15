// COMPILER.iface-assign-box: assigning a concrete `*T` to an interface
// VARIABLE (an AssignStmt, not a var-decl) must box it into a {data,vtable}
// fat pointer. Previously the assign path stored the raw pointer, so a later
// method call dispatched through a garbage vtable → SIGSEGV. var-decl and
// call-arg sites already boxed; this covers reassignment.
package main

type Animal interface {
	Speak() int
}

type Dog struct {
	x int
}

fun (d *Dog) Speak() int { ret d.x }
fun mkDog(v int) *Dog { ret new Dog{x: v} }

fun main() int {
	var a Animal = mkDog(1) // var-decl boxing (already worked)
	a = mkDog(42)           // reassign: must re-box, else a.Speak() segfaults
	ret a.Speak()
}
