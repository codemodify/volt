package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty.
	var e []int = new(0) []int {}
	var p0 []int = new(0) []int {}
	var z0 []int = new(0) []int {}
	var n0 []int = new(0) []int {}
	p0, z0, n0 = slices.PartitionBySignInt(e)
	if len(p0) == 0 { pass = pass + 1 }
	if len(z0) == 0 { pass = pass + 1 }
	if len(n0) == 0 { pass = pass + 1 }

	// All positive.
	var s1 []int = new(4) []int { 1, 2, 3, 4 }
	var p1 []int = new(0) []int {}
	var z1 []int = new(0) []int {}
	var n1 []int = new(0) []int {}
	p1, z1, n1 = slices.PartitionBySignInt(s1)
	if len(p1) == 4 { pass = pass + 1 }
	if len(z1) == 0 { pass = pass + 1 }
	if len(n1) == 0 { pass = pass + 1 }
	if p1[0] == 1 { pass = pass + 1 }
	if p1[3] == 4 { pass = pass + 1 }

	// All negative.
	var s2 []int = new(3) []int { -1, -2, -3 }
	var p2 []int = new(0) []int {}
	var z2 []int = new(0) []int {}
	var n2 []int = new(0) []int {}
	p2, z2, n2 = slices.PartitionBySignInt(s2)
	if len(p2) == 0 { pass = pass + 1 }
	if len(z2) == 0 { pass = pass + 1 }
	if len(n2) == 3 { pass = pass + 1 }
	if n2[0] == -1 { pass = pass + 1 }

	// All zeros.
	var s3 []int = new(3) []int { 0, 0, 0 }
	var p3 []int = new(0) []int {}
	var z3 []int = new(0) []int {}
	var n3 []int = new(0) []int {}
	p3, z3, n3 = slices.PartitionBySignInt(s3)
	if len(p3) == 0 { pass = pass + 1 }
	if len(z3) == 3 { pass = pass + 1 }
	if len(n3) == 0 { pass = pass + 1 }

	// Mixed (preserves original order in each group).
	var s4 []int = new(8) []int { -2, 0, 3, -1, 0, 5, 7, -4 }
	var p4 []int = new(0) []int {}
	var z4 []int = new(0) []int {}
	var n4 []int = new(0) []int {}
	p4, z4, n4 = slices.PartitionBySignInt(s4)
	if len(p4) == 3 { pass = pass + 1 }
	if len(z4) == 2 { pass = pass + 1 }
	if len(n4) == 3 { pass = pass + 1 }
	if p4[0] == 3 { pass = pass + 1 }
	if p4[1] == 5 { pass = pass + 1 }
	if p4[2] == 7 { pass = pass + 1 }
	if n4[0] == -2 { pass = pass + 1 }
	if n4[1] == -1 { pass = pass + 1 }
	if n4[2] == -4 { pass = pass + 1 }

	// Cross-property: lengths sum to len(s).
	var s5 []int = new(8) []int { -2, 0, 3, -1, 0, 5, 7, -4 }
	var p5 []int = new(0) []int {}
	var z5 []int = new(0) []int {}
	var n5 []int = new(0) []int {}
	p5, z5, n5 = slices.PartitionBySignInt(s5)
	if len(p5) + len(z5) + len(n5) == 8 { pass = pass + 1 }

	// Doesn't mutate s.
	var s6 []int = new(4) []int { 3, -1, 0, 2 }
	var _p []int = new(0) []int {}
	var _z []int = new(0) []int {}
	var _n []int = new(0) []int {}
	_p, _z, _n = slices.PartitionBySignInt(s6)
	if s6[0] == 3 { pass = pass + 1 }
	if s6[1] == -1 { pass = pass + 1 }
	if s6[2] == 0 { pass = pass + 1 }
	if s6[3] == 2 { pass = pass + 1 }

	// Ledger use case: credits / zero / debits.
	var ledger []int = new(6) []int { 100, -50, 0, 200, -75, 300 }
	var credits []int = new(0) []int {}
	var zeros []int = new(0) []int {}
	var debits []int = new(0) []int {}
	credits, zeros, debits = slices.PartitionBySignInt(ledger)
	if len(credits) == 3 { pass = pass + 1 }
	if len(zeros) == 1 { pass = pass + 1 }
	if len(debits) == 2 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 32 { ret 42 }
	ret 0
}
