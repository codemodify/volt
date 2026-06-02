package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Small numbers (no commas).
	if strings.WithCommas(0) == "0" { pass = pass + 1 }
	if strings.WithCommas(1) == "1" { pass = pass + 1 }
	if strings.WithCommas(42) == "42" { pass = pass + 1 }
	if strings.WithCommas(123) == "123" { pass = pass + 1 }
	if strings.WithCommas(999) == "999" { pass = pass + 1 }

	// First comma.
	if strings.WithCommas(1000) == "1,000" { pass = pass + 1 }
	if strings.WithCommas(1234) == "1,234" { pass = pass + 1 }
	if strings.WithCommas(9999) == "9,999" { pass = pass + 1 }

	// Two-digit leading group.
	if strings.WithCommas(10000) == "10,000" { pass = pass + 1 }
	if strings.WithCommas(99999) == "99,999" { pass = pass + 1 }

	// Three-digit leading group.
	if strings.WithCommas(100000) == "100,000" { pass = pass + 1 }
	if strings.WithCommas(999999) == "999,999" { pass = pass + 1 }

	// Millions.
	if strings.WithCommas(1000000) == "1,000,000" { pass = pass + 1 }
	if strings.WithCommas(1234567) == "1,234,567" { pass = pass + 1 }
	if strings.WithCommas(12345678) == "12,345,678" { pass = pass + 1 }
	if strings.WithCommas(123456789) == "123,456,789" { pass = pass + 1 }

	// Billions.
	if strings.WithCommas(1000000000) == "1,000,000,000" { pass = pass + 1 }
	if strings.WithCommas(1234567890) == "1,234,567,890" { pass = pass + 1 }

	// Negative.
	if strings.WithCommas(-1) == "-1" { pass = pass + 1 }
	if strings.WithCommas(-1000) == "-1,000" { pass = pass + 1 }
	if strings.WithCommas(-1234567) == "-1,234,567" { pass = pass + 1 }

	// Boundary: exactly 3 digits → no comma.
	if strings.WithCommas(999) == "999" { pass = pass + 1 }
	// Exactly 4 digits → one comma after first.
	if strings.WithCommas(1000) == "1,000" { pass = pass + 1 }

	// Report-line use case.
	var pop int = 8000000000
	var line string = "World population: " + strings.WithCommas(pop)
	if line == "World population: 8,000,000,000" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 24 { ret 42 }
	ret 0
}
