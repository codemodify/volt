package main
import "log"
import "strconv"

fun main() int {
	var pass int = 0

	// AtoiOr — valid ints parse to value (default ignored).
	if strconv.AtoiOr("42", 99) == 42 { pass = pass + 1 }
	if strconv.AtoiOr("0", 99) == 0 { pass = pass + 1 }
	if strconv.AtoiOr("-7", 99) == -7 { pass = pass + 1 }

	// AtoiOr — invalid input falls back to default.
	if strconv.AtoiOr("", 99) == 99 { pass = pass + 1 }
	if strconv.AtoiOr("abc", 99) == 99 { pass = pass + 1 }
	if strconv.AtoiOr("12x", 99) == 99 { pass = pass + 1 }
	if strconv.AtoiOr(" 42", 99) == 99 { pass = pass + 1 }       // leading space rejected by Atoi
	if strconv.AtoiOr("42 ", 99) == 99 { pass = pass + 1 }       // trailing space rejected
	if strconv.AtoiOr("--5", 99) == 99 { pass = pass + 1 }       // double sign

	// AtoiOr — large numbers preserved.
	if strconv.AtoiOr("1000000", 0) == 1000000 { pass = pass + 1 }
	if strconv.AtoiOr("-1000000", 0) == -1000000 { pass = pass + 1 }

	// AtoiOr — default can be negative.
	if strconv.AtoiOr("garbage", -1) == -1 { pass = pass + 1 }

	// ParseBoolOr — all known true forms.
	if strconv.ParseBoolOr("true", false) == true { pass = pass + 1 }
	if strconv.ParseBoolOr("1", false) == true { pass = pass + 1 }
	if strconv.ParseBoolOr("T", false) == true { pass = pass + 1 }

	// ParseBoolOr — all known false forms.
	if strconv.ParseBoolOr("false", true) == false { pass = pass + 1 }
	if strconv.ParseBoolOr("0", true) == false { pass = pass + 1 }
	if strconv.ParseBoolOr("F", true) == false { pass = pass + 1 }

	// ParseBoolOr — unknown / empty / garbage falls back.
	if strconv.ParseBoolOr("", true) == true { pass = pass + 1 }
	if strconv.ParseBoolOr("yes", true) == true { pass = pass + 1 }    // not recognized by ParseBool
	if strconv.ParseBoolOr("no", false) == false { pass = pass + 1 }
	if strconv.ParseBoolOr("maybe", true) == true { pass = pass + 1 }
	if strconv.ParseBoolOr("2", false) == false { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 23 { ret 42 }
	ret 0
}
