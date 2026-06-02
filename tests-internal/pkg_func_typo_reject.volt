package main

import "strings"

// Negative test: calling a non-existent function on a known package
// must produce a friendly volt-level error with a did-you-mean hint,
// not a cryptic clang IR error from the legacy void-call fallback.
//
// Expected error: package strings has no function "ToUper" (did you mean "ToUpper"?)

fun main() int {
	var s string = strings.ToUper("hello")
	ret len(s)
}
