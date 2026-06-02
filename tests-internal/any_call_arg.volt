package main

// Positive test: a concrete value passed to an `any`-typed parameter
// must be auto-boxed (heap-copy + pass ptr), matching the existing
// `var x any = concrete` boxing path. Previously this produced a
// cryptic clang IR mismatch: the struct value sat at SSA-level
// while the call expected a `ptr`.

type Cat struct {
	name string
}

fun acceptStruct(a any) int {
	ret 10
}

fun acceptInt(a any) int {
	ret 20
}

fun acceptString(a any) int {
	ret 30
}

fun main() int {
	var c Cat = new Cat{name: "Tom"}
	var sum int = acceptStruct(c) + acceptInt(7) + acceptString("hi")
	if sum != 60 {
		ret 1
	}
	ret 42
}
