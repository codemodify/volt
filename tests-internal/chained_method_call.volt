package main

// Positive test: method calls chained off a struct field
// (`r.err.Error()`) used to error out at codegen — the v0.4
// restriction required a bare-variable receiver. Now the field
// receiver gets spilled into a temp local automatically, so
// chained calls Just Work for the common SelectorExpr case.

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
	var r Result = new Result{err: new MyErr{msg: "ok"}}
	var s string = r.err.Error()
	if len(s) != 2 { ret 1 }
	ret 42
}
