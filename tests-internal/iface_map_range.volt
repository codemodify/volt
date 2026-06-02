package main

// Positive test: ranging over a map with interface-typed values
// exposes `v` as a ptr typed to the declared interface, not as the
// raw i64 storage slot. So `v.Error()` dispatches via the boxed
// vtable and behaves like a normal interface value.

type MyErr struct {
	msg string
}

fun (e *MyErr) Error() string {
	ret e.msg
}

fun main() int {
	var m map[string]error = new {}
	m["a"] = new MyErr{msg: "alpha"}
	m["b"] = new MyErr{msg: "beta"}

	var count int = 0
	for k, v := range m {
		var s string = v.Error()
		if len(s) == 0 { ret 1 }
		if len(k) != 1 { ret 2 }
		count = count + 1
	}
	if count != 2 { ret 3 }
	ret 42
}
