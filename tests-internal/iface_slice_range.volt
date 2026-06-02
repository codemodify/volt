package main

// Positive test: ranging over a slice of interface values must
// expose `v` with the interface's AST type so method dispatch
// works. Without the AstType propagation, codegen would see `v` as
// just a raw ptr and "cannot call method on ptr".

type MyErr struct {
	msg string
}

fun (e *MyErr) Error() string {
	ret e.msg
}

fun main() int {
	var s []error = new(2) []error{}
	s[0] = new MyErr{msg: "first"}
	s[1] = new MyErr{msg: "second"}

	var combinedLen int = 0
	for _, v := range s {
		combinedLen = combinedLen + len(v.Error())
	}
	if combinedLen != 11 { ret 1 }
	ret 42
}
