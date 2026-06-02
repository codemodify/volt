package main

// Positive test: concrete values sent on an interface-typed channel
// must auto-box. Previously this failed clang with the same
// struct-vs-ptr mismatch we saw at var-decl, call-arg, ret, struct
// fields, and slice/map stores.

type MyErr struct {
	msg string
}

fun (e *MyErr) Error() string {
	ret e.msg
}

fun producer(ch chan write error) {
	var e MyErr = new MyErr{msg: "from-chan"}
	write(ch, e)
}

fun main() int {
	var ch chan11 error = new()
	run producer(ch)
	var got error = read(ch)
	if got == nil { ret 1 }
	ret 42
}
