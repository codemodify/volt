package main
import "log"
import "strconv"

fun main() int {
	var pass int = 0

	// Base 10 — valid values.
	if strconv.ParseIntOr("42", 10, 99) == 42 { pass = pass + 1 }
	if strconv.ParseIntOr("0", 10, 99) == 0 { pass = pass + 1 }
	if strconv.ParseIntOr("-7", 10, 99) == -7 { pass = pass + 1 }

	// Base 10 — invalid → fallback.
	if strconv.ParseIntOr("", 10, 99) == 99 { pass = pass + 1 }
	if strconv.ParseIntOr("abc", 10, 99) == 99 { pass = pass + 1 }
	if strconv.ParseIntOr("12x", 10, 99) == 99 { pass = pass + 1 }

	// Base 16 — valid hex.
	if strconv.ParseIntOr("ff", 16, 0) == 255 { pass = pass + 1 }
	if strconv.ParseIntOr("FF", 16, 0) == 255 { pass = pass + 1 }
	if strconv.ParseIntOr("deadbeef", 16, 0) == 3735928559 { pass = pass + 1 }
	if strconv.ParseIntOr("0", 16, -1) == 0 { pass = pass + 1 }

	// Base 16 — invalid → fallback.
	if strconv.ParseIntOr("XYZ", 16, -1) == -1 { pass = pass + 1 }
	if strconv.ParseIntOr("", 16, 99) == 99 { pass = pass + 1 }
	// 'g' is not a hex digit.
	if strconv.ParseIntOr("g", 16, 7) == 7 { pass = pass + 1 }

	// Base 2 — binary.
	if strconv.ParseIntOr("1011", 2, 0) == 11 { pass = pass + 1 }
	if strconv.ParseIntOr("0", 2, -1) == 0 { pass = pass + 1 }
	if strconv.ParseIntOr("102", 2, -1) == -1 { pass = pass + 1 }   // '2' invalid in binary

	// Base 8 — octal.
	if strconv.ParseIntOr("755", 8, 0) == 493 { pass = pass + 1 }
	if strconv.ParseIntOr("8", 8, -1) == -1 { pass = pass + 1 }    // invalid octal digit

	// Base 36 (max).
	if strconv.ParseIntOr("z", 36, 0) == 35 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 19 { ret 42 }
	ret 0
}
