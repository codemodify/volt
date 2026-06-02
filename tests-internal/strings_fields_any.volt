package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Basic: comma + semicolon separators.
	var r1 []string = strings.FieldsAny("a,b;c", ",;")
	if len(r1) == 3 { pass = pass + 1 }
	if r1[0] == "a" { pass = pass + 1 }
	if r1[1] == "b" { pass = pass + 1 }
	if r1[2] == "c" { pass = pass + 1 }

	// Multiple consecutive separators collapse.
	var r2 []string = strings.FieldsAny("a,,;,b", ",;")
	if len(r2) == 2 { pass = pass + 1 }
	if r2[0] == "a" { pass = pass + 1 }
	if r2[1] == "b" { pass = pass + 1 }

	// Mix of space + tab separators.
	var r3 []string = strings.FieldsAny("  one\ttwo three", " \t")
	if len(r3) == 3 { pass = pass + 1 }
	if r3[0] == "one" { pass = pass + 1 }
	if r3[1] == "two" { pass = pass + 1 }
	if r3[2] == "three" { pass = pass + 1 }

	// Empty string → no fields.
	var r4 []string = strings.FieldsAny("", ",;")
	if len(r4) == 0 { pass = pass + 1 }

	// Empty separators → whole string as one field.
	var r5 []string = strings.FieldsAny("hello", "")
	if len(r5) == 1 { pass = pass + 1 }
	if r5[0] == "hello" { pass = pass + 1 }

	// All separators → no fields.
	var r6 []string = strings.FieldsAny(",,;;,,", ",;")
	if len(r6) == 0 { pass = pass + 1 }

	// Single field, no separators.
	var r7 []string = strings.FieldsAny("solo", ",;")
	if len(r7) == 1 { pass = pass + 1 }
	if r7[0] == "solo" { pass = pass + 1 }

	// Leading + trailing separators.
	var r8 []string = strings.FieldsAny(",alpha,beta,", ",")
	if len(r8) == 2 { pass = pass + 1 }
	if r8[0] == "alpha" { pass = pass + 1 }
	if r8[1] == "beta" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 20 { ret 42 }
	ret 0
}
