package main

// Positive test: shadow-and-restore across nested scopes.
// `var i = 100` outer, `for i := 0; ...` inner, after the loop the
// outer i must be visible again. Same for if-init scopes and
// arbitrarily nested blocks. Without proper save/restore the inner
// declaration overwrites the outer in c.symbols permanently.

fun main() int {
	var i int = 100
	for i := 0; i < 3; i = i + 1 {
		i = i
	}
	if i != 100 { ret 1 }

	var x int = 1
	if true {
		var x int = 2
		if true {
			var x int = 3
			if x != 3 { ret 2 }
		}
		if x != 2 { ret 3 }
	}
	if x != 1 { ret 4 }

	// Range bindings also restore properly: outer i shadowed by
	// `for i, v := range s` should be intact after the loop.
	var j int = 99
	var s []int = new(3) []int{10, 20, 30}
	for j, v := range s {
		j = v
	}
	if j != 99 { ret 5 }

	ret 42
}
