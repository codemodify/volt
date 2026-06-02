package main

// Positive test: composite literals for slices and maps of
// interface-typed elements/values must auto-box each concrete
// element. Without this, `new(2) []error{e1, e2}` and
// `new map[string]error{"a": e}` both fail clang with
// struct-vs-ptr or struct-vs-i64 mismatches.

type MyErr struct {
	msg string
}

fun (e *MyErr) Error() string {
	ret e.msg
}

fun main() int {
	var e1 MyErr = new MyErr{msg: "one"}
	var e2 MyErr = new MyErr{msg: "two"}

	// Slice literal with two concrete error values.
	var s []error = new(2) []error{e1, e2}
	if s[0] == nil { ret 1 }
	if s[1] == nil { ret 2 }

	// Map literal with one concrete error value.
	var e3 MyErr = new MyErr{msg: "three"}
	var m map[string]error = new {"k": e3}
	var got error = m["k"]
	if got == nil { ret 3 }

	ret 42
}
