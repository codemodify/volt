package main

// Positive test: returning a concrete value from a function whose
// declared return type is an interface (`error` here, but the same
// machinery covers `any` and user interfaces) must auto-box at the
// ret site. Same shape applies to multi-return.

type MyErr struct {
	msg string
}

fun (e *MyErr) Error() string {
	ret e.msg
}

fun makeErr() error {
	var e MyErr = new MyErr{msg: "oh no"}
	ret e
}

fun multiRet() (int, error) {
	var e MyErr = new MyErr{msg: "fail"}
	ret 7, e
}

fun main() int {
	var err error = makeErr()
	if err == nil { ret 1 }

	v, e := multiRet()
	if e == nil { ret 2 }
	if v != 7 { ret 3 }

	ret 42
}
