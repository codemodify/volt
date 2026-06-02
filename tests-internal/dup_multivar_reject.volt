package main

// Negative test: a multi-value declaration that lists the same name
// twice (`a, a := pair()`) used to surface only as a cryptic clang
// error `multiple definition of local value named 'a.addr'`. Now
// rejected upfront at the declaration site.
//
// Expected error: multi-value decl lists name "a" twice

fun pair() (int, int) {
	ret 1, 2
}

fun main() int {
	a, a := pair()
	ret a
}
