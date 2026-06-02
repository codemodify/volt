package main
import "log"
import "math"
import "slices"

// Positive test: math.LerpInt + slices.ZipStringInt + ZipStringString.

fun main() int {
	var pass int = 0

	// LerpInt endpoints.
	if math.LerpInt(0, 100, 0, 10) == 0 { pass = pass + 1 }
	if math.LerpInt(0, 100, 10, 10) == 100 { pass = pass + 1 }

	// LerpInt midpoint.
	if math.LerpInt(0, 100, 5, 10) == 50 { pass = pass + 1 }

	// LerpInt arbitrary fractions.
	if math.LerpInt(0, 100, 3, 10) == 30 { pass = pass + 1 }
	if math.LerpInt(0, 100, 7, 10) == 70 { pass = pass + 1 }

	// LerpInt with non-zero start.
	if math.LerpInt(10, 20, 5, 10) == 15 { pass = pass + 1 }

	// LerpInt negative endpoints.
	if math.LerpInt(-10, 10, 5, 10) == 0 { pass = pass + 1 }

	// LerpInt t past denom — extrapolates.
	if math.LerpInt(0, 10, 20, 10) == 20 { pass = pass + 1 }   // 2x past

	// LerpInt t negative — extrapolates back.
	if math.LerpInt(0, 10, -5, 10) == -5 { pass = pass + 1 }

	// LerpInt degenerate denom.
	if math.LerpInt(5, 99, 3, 0) == 5 { pass = pass + 1 }      // returns a
	if math.LerpInt(5, 99, 3, -1) == 5 { pass = pass + 1 }

	// ZipStringInt basic.
	var k []string = new(3) []string{"a", "b", "c"}
	var v []int = new(3) []int{1, 2, 3}
	var z []string = slices.ZipStringInt(k, v)
	if len(z) == 3 { pass = pass + 1 }
	if z[0] == "a=1" { pass = pass + 1 }
	if z[1] == "b=2" { pass = pass + 1 }
	if z[2] == "c=3" { pass = pass + 1 }

	// ZipStringInt — keys longer.
	var k2 []string = new(4) []string{"a", "b", "c", "d"}
	var v2 []int = new(2) []int{1, 2}
	var z2 []string = slices.ZipStringInt(k2, v2)
	if len(z2) == 2 { pass = pass + 1 }
	if z2[0] == "a=1" { pass = pass + 1 }

	// ZipStringInt — vals longer.
	var k3 []string = new(2) []string{"a", "b"}
	var v3 []int = new(4) []int{1, 2, 3, 4}
	var z3 []string = slices.ZipStringInt(k3, v3)
	if len(z3) == 2 { pass = pass + 1 }

	// ZipStringInt — empty.
	var ke []string = new(0) []string{}
	var ve []int = new(0) []int{}
	if len(slices.ZipStringInt(ke, ve)) == 0 { pass = pass + 1 }

	// ZipStringString.
	var ks []string = new(2) []string{"name", "city"}
	var vs []string = new(2) []string{"alice", "denver"}
	var zs []string = slices.ZipStringString(ks, vs)
	if zs[0] == "name=alice" { pass = pass + 1 }
	if zs[1] == "city=denver" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 21 { ret 42 }
	ret 0
}
