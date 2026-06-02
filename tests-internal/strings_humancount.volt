package main
import "log"
import "strings"

// Positive test: strings.HumanCount.

fun main() int {
	var pass int = 0

	// Sub-1000 → bare digits.
	if strings.HumanCount(0) == "0" { pass = pass + 1 }
	if strings.HumanCount(1) == "1" { pass = pass + 1 }
	if strings.HumanCount(42) == "42" { pass = pass + 1 }
	if strings.HumanCount(999) == "999" { pass = pass + 1 }

	// K tier — integer thousands.
	if strings.HumanCount(1000) == "1K" { pass = pass + 1 }
	if strings.HumanCount(3000) == "3K" { pass = pass + 1 }
	if strings.HumanCount(10000) == "10K" { pass = pass + 1 }
	if strings.HumanCount(999000) == "999K" { pass = pass + 1 }

	// K with decimal.
	if strings.HumanCount(1500) == "1.5K" { pass = pass + 1 }
	if strings.HumanCount(1200) == "1.2K" { pass = pass + 1 }
	if strings.HumanCount(2700) == "2.7K" { pass = pass + 1 }
	if strings.HumanCount(1050) == "1K" { pass = pass + 1 }   // tenths digit is 0

	// M tier.
	if strings.HumanCount(1000000) == "1M" { pass = pass + 1 }
	if strings.HumanCount(2500000) == "2.5M" { pass = pass + 1 }
	if strings.HumanCount(10000000) == "10M" { pass = pass + 1 }
	if strings.HumanCount(999000000) == "999M" { pass = pass + 1 }

	// B tier.
	if strings.HumanCount(1000000000) == "1B" { pass = pass + 1 }
	if strings.HumanCount(2500000000) == "2.5B" { pass = pass + 1 }

	// Negatives.
	if strings.HumanCount(-500) == "-500" { pass = pass + 1 }
	if strings.HumanCount(-1500) == "-1.5K" { pass = pass + 1 }
	if strings.HumanCount(-1000000) == "-1M" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 21 { ret 42 }
	ret 0
}
