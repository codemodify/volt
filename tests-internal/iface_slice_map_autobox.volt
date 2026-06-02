package main

// Positive test: a concrete value flowing into an interface-typed
// slice element or map value must auto-box, same as it does for
// var-decl, call-arg, ret, and struct fields. Without this, the
// slice/map index assignment fails clang with a struct-vs-ptr error.

type MyErr struct {
	msg string
}

fun (e *MyErr) Error() string {
	ret e.msg
}

fun main() int {
	// Slice element store.
	var s []error = new(2) []error{}
	var e1 MyErr = new MyErr{msg: "in slice"}
	s[0] = e1
	if s[0] == nil { ret 1 }

	// Map value store + read: assignment auto-boxes ptr→i64, read
	// auto-unboxes i64→ptr (via inttoptr) so `m["k"] == nil`
	// compares against a ptr null cleanly. Missing keys come back
	// as i64 0, which inttoptr's to null.
	var m map[string]error = new {}
	var e2 MyErr = new MyErr{msg: "in map"}
	m["k"] = e2
	if m["k"] == nil { ret 3 }
	if m["missing"] != nil { ret 4 }

	ret 42
}
