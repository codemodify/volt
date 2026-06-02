package main

// Positive test: every type trivially satisfies an empty interface.
// Previously the impl-scan only iterated types that owned at least
// one method, so a methodless type like `Cat` (with no `Drop`, no
// `Error`, nothing) was never registered as implementing an empty
// `Any interface {}` — even though it should trivially satisfy
// zero method requirements.

type Any interface {}

type Cat struct {
	name string
}

fun useAny(a Any) int {
	ret 42
}

fun main() int {
	var c Cat = new Cat{name: "Tom"}
	ret useAny(c)
}
