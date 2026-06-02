// A3 strings: heap-allocated strings (concat results, chr) should
// auto-free at scope exit. String LITERALS (.rodata) must NOT be
// freed — the codegen only registers a string-drop when the RHS is
// a known heap-producer (binary `+` concat, `chr` builtin). This
// test exercises high iteration counts to make a leak / double-free
// visible (crash on memory pressure or corruption).
package main
import "log"

fun concatHelper(a string, b string) string {
	var s string = a + b
	ret s
}

fun makeChar(n int) string {
	var c string = chr(65 + n)  // 'A' + n
	ret c
}

fun work() int {
	var sum int = 0
	// 10000 iterations of local concat that should auto-free.
	for i := 0; i < 10000; i++ {
		var s string = "hello-" + "world"
		sum = sum + len(s)
	}
	ret sum
}

fun main() int {
	// 1. Concat result auto-freed at scope exit (function-level).
	var a int = work()
	// each iter: len("hello-world") = 11; 10000 iters → 110000
	if a != 110000 { ret 1 }

	// 2. chr() result auto-freed.
	var b int = 0
	for i := 0; i < 1000; i++ {
		var c string = chr(65)  // "A"
		b = b + len(c)
	}
	// each iter: len("A") = 1; 1000 iters → 1000
	if b != 1000 { ret 2 }

	// 3. Make sure LITERALS still work (don't get freed).
	var lit string = "this is a literal"
	if len(lit) != 17 { ret 3 }
	// Use lit again to ensure it's still valid.
	if lit != "this is a literal" { ret 4 }

	// 4. Function returning a heap string — caller has the moved
	// ownership. We test that double-free doesn't occur even when the
	// callee allocates internally.
	var ok int = 0
	for i := 0; i < 1000; i++ {
		var s string = concatHelper("ab", "cd")
		ok = ok + len(s)
	}
	// each iter: len("abcd") = 4; 1000 iters → 4000
	if ok != 4000 { ret 5 }

	log.Println("a=%d b=%d ok=%d", a, b, ok)
	ret 42
}
