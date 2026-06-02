package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// FilledInt basics
	var r1 []int = slices.FilledInt(7, 5)
	if len(r1) == 5 { pass = pass + 1 }
	if r1[0] == 7 { pass = pass + 1 }
	if r1[4] == 7 { pass = pass + 1 }

	// n <= 0 → empty
	var r2 []int = slices.FilledInt(42, 0)
	if len(r2) == 0 { pass = pass + 1 }
	var r3 []int = slices.FilledInt(42, -5)
	if len(r3) == 0 { pass = pass + 1 }

	// Single element
	var r4 []int = slices.FilledInt(99, 1)
	if len(r4) == 1 { pass = pass + 1 }
	if r4[0] == 99 { pass = pass + 1 }

	// Negative value, zero, large
	var r5 []int = slices.FilledInt(-3, 3)
	if r5[0] == -3 { pass = pass + 1 }
	if r5[1] == -3 { pass = pass + 1 }
	if r5[2] == -3 { pass = pass + 1 }

	// FilledString basics
	var s1 []string = slices.FilledString("x", 4)
	if len(s1) == 4 { pass = pass + 1 }
	if s1[0] == "x" { pass = pass + 1 }
	if s1[3] == "x" { pass = pass + 1 }

	// Empty string and n>0
	var s2 []string = slices.FilledString("", 3)
	if len(s2) == 3 { pass = pass + 1 }
	if s2[0] == "" { pass = pass + 1 }

	// n=0 string empty
	var s3 []string = slices.FilledString("hello", 0)
	if len(s3) == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
