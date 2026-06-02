package main

// Positive test: a concrete value flowing into an interface-typed
// field — either in a struct literal (`Result{err: myErr}`) or via
// a field assignment (`r.err = myErr`) — must auto-box. Previously
// both paths failed with a struct-vs-ptr LLVM IR error.

type MyErr struct {
	msg string
}

fun (e *MyErr) Error() string {
	ret e.msg
}

type Result struct {
	err error
}

fun main() int {
	// Composite-literal path.
	var r1 Result = new Result{err: new MyErr{msg: "from-literal"}}
	if r1.err == nil { ret 1 }

	// Field-assignment path.
	var r2 Result = new Result{}
	var e MyErr = new MyErr{msg: "from-assign"}
	r2.err = e
	if r2.err == nil { ret 2 }

	ret 42
}
