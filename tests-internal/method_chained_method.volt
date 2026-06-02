package main

// Positive test: method dispatch on a method-call result, where
// the outer method needs interface vtable dispatch
// (`m.Make().Error()` where Make returns error). Required
// `spillCallResultAsLocal` to recognize method-call shapes when
// recovering the AST return type — previously it only handled
// bare-function and pkg-qualified function calls, missing the
// `recv.Method()` shape.

type MyErr struct {
	msg string
}

fun (e *MyErr) Error() string {
	ret e.msg
}

type Maker struct {
	tag int
}

fun (m *Maker) Make() error {
	ret new MyErr{msg: "from-method"}
}

fun main() int {
	var m Maker = new Maker{tag: 1}
	if len(m.Make().Error()) != 11 { ret 1 }
	ret 42
}
