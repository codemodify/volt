package main

// Positive test: closures whose declared return type is an
// interface must auto-box concrete `ret` values, same as named
// functions do. Previously the closure body's funcCtx didn't
// carry the AST return types, so the IFACE.4 boxing chain
// didn't fire — clang errored with the struct-vs-ptr ret type.

type MyErr struct {
	msg string
}

fun (e *MyErr) Error() string {
	ret e.msg
}

fun main() int {
	var fn fun() error = fun() error {
		var e MyErr = new MyErr{msg: "boom"}
		ret e
	}
	var err error = fn()
	if err == nil { ret 1 }
	if len(err.Error()) != 4 { ret 2 }
	ret 42
}
