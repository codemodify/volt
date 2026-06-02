package main

// Negative test: a closure literal that lists the same parameter
// name twice (`fun(a int, a int) int`) used to slip past the
// volt-level checks (Pass 154's dup-param only covered named
// FuncDecls) and only surface as a downstream
// "log.Println takes a string" misfire when the closure call's
// return type was misread by codegen. Now caught at the closure
// literal itself.
//
// Expected error: closure has duplicate parameter "a"

import "log"

fun main() int {
	var fn fun(int, int) int = fun(a int, a int) int { ret a }
	log.Println(fn(1, 2))
	ret 0
}
