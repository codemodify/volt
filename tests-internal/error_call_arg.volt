package main

// Positive test: a concrete struct that implements Error() is
// auto-boxed when passed to an `error`-typed parameter, mirroring
// the existing var-decl boxing path. Previously this produced the
// cryptic clang IR `defined with type %MyErr but expected ptr`.

type MyErr struct {
	msg string
}

fun (e *MyErr) Error() string {
	ret e.msg
}

fun useErr(e error) int {
	ret 42
}

fun main() int {
	var e MyErr = new MyErr{msg: "oh no"}
	ret useErr(e)
}
