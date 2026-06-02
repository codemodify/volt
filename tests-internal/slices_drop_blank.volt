package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Basic: drop empty entries.
	var s1 []string = new(5) []string {"a", "", "b", "", "c"}
	var r1 []string = slices.DropBlankStrings(s1)
	if len(r1) == 3 { pass = pass + 1 }
	if r1[0] == "a" { pass = pass + 1 }
	if r1[1] == "b" { pass = pass + 1 }
	if r1[2] == "c" { pass = pass + 1 }

	// All empty → empty.
	var s2 []string = new(3) []string {"", "", ""}
	var r2 []string = slices.DropBlankStrings(s2)
	if len(r2) == 0 { pass = pass + 1 }

	// None empty → identical content.
	var s3 []string = new(3) []string {"x", "y", "z"}
	var r3 []string = slices.DropBlankStrings(s3)
	if len(r3) == 3 { pass = pass + 1 }
	if r3[0] == "x" { pass = pass + 1 }
	if r3[1] == "y" { pass = pass + 1 }
	if r3[2] == "z" { pass = pass + 1 }

	// Empty input.
	var s4 []string = new(0) []string {}
	var r4 []string = slices.DropBlankStrings(s4)
	if len(r4) == 0 { pass = pass + 1 }

	// Leading/trailing empties.
	var s5 []string = new(5) []string {"", "alpha", "", "", "omega"}
	var r5 []string = slices.DropBlankStrings(s5)
	if len(r5) == 2 { pass = pass + 1 }
	if r5[0] == "alpha" { pass = pass + 1 }
	if r5[1] == "omega" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 13 { ret 42 }
	ret 0
}
