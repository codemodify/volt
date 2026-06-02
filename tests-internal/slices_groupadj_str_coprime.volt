package main
import "log"
import "slices"
import "math"

// Positive test: slices.GroupAdjacentString + math.IsCoprime.

fun main() int {
	var pass int = 0

	// GroupAdjacentString — basic.
	var s []string = new(7) []string{"a", "a", "b", "c", "c", "c", "a"}
	var g [][]string = slices.GroupAdjacentString(s)
	if len(g) == 4 { pass = pass + 1 }
	if len(g[0]) == 2 { pass = pass + 1 }
	if g[0][0] == "a" { pass = pass + 1 }
	if len(g[1]) == 1 { pass = pass + 1 }
	if g[1][0] == "b" { pass = pass + 1 }
	if len(g[2]) == 3 { pass = pass + 1 }
	if g[2][0] == "c" { pass = pass + 1 }
	if len(g[3]) == 1 { pass = pass + 1 }
	if g[3][0] == "a" { pass = pass + 1 }

	// All distinct.
	var dd []string = new(3) []string{"x", "y", "z"}
	var ddg [][]string = slices.GroupAdjacentString(dd)
	if len(ddg) == 3 { pass = pass + 1 }
	if len(ddg[0]) == 1 { pass = pass + 1 }

	// All same.
	var ss []string = new(4) []string{"q", "q", "q", "q"}
	var ssg [][]string = slices.GroupAdjacentString(ss)
	if len(ssg) == 1 { pass = pass + 1 }
	if len(ssg[0]) == 4 { pass = pass + 1 }

	// Empty.
	var e []string = new(0) []string{}
	var eg [][]string = slices.GroupAdjacentString(e)
	if len(eg) == 0 { pass = pass + 1 }

	// IsCoprime basic.
	if math.IsCoprime(7, 11) { pass = pass + 1 }
	if math.IsCoprime(15, 28) { pass = pass + 1 }   // GCD=1
	if math.IsCoprime(1, 100) { pass = pass + 1 }
	if math.IsCoprime(3, 5) { pass = pass + 1 }

	// Not coprime.
	if !math.IsCoprime(4, 6) { pass = pass + 1 }     // GCD=2
	if !math.IsCoprime(15, 25) { pass = pass + 1 }   // GCD=5
	if !math.IsCoprime(12, 18) { pass = pass + 1 }   // GCD=6

	// Negatives — absolute values used.
	if math.IsCoprime(-3, 5) { pass = pass + 1 }
	if math.IsCoprime(-3, -5) { pass = pass + 1 }
	if !math.IsCoprime(-4, 6) { pass = pass + 1 }

	// Edge: 1 paired with anything is coprime.
	if math.IsCoprime(1, 1) { pass = pass + 1 }
	if math.IsCoprime(1, 0) { pass = pass + 1 }

	// 0, 0 → gcd=0, not coprime.
	if !math.IsCoprime(0, 0) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 27 { ret 42 }
	ret 0
}
