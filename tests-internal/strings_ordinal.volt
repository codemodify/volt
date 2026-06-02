package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// OrdinalSuffix basics.
	if strings.OrdinalSuffix(1) == "st" { pass = pass + 1 }
	if strings.OrdinalSuffix(2) == "nd" { pass = pass + 1 }
	if strings.OrdinalSuffix(3) == "rd" { pass = pass + 1 }
	if strings.OrdinalSuffix(4) == "th" { pass = pass + 1 }
	if strings.OrdinalSuffix(5) == "th" { pass = pass + 1 }
	if strings.OrdinalSuffix(10) == "th" { pass = pass + 1 }

	// Teens all take "th".
	if strings.OrdinalSuffix(11) == "th" { pass = pass + 1 }
	if strings.OrdinalSuffix(12) == "th" { pass = pass + 1 }
	if strings.OrdinalSuffix(13) == "th" { pass = pass + 1 }
	if strings.OrdinalSuffix(14) == "th" { pass = pass + 1 }
	if strings.OrdinalSuffix(19) == "th" { pass = pass + 1 }

	// 20s+ resume normal pattern.
	if strings.OrdinalSuffix(20) == "th" { pass = pass + 1 }
	if strings.OrdinalSuffix(21) == "st" { pass = pass + 1 }
	if strings.OrdinalSuffix(22) == "nd" { pass = pass + 1 }
	if strings.OrdinalSuffix(23) == "rd" { pass = pass + 1 }
	if strings.OrdinalSuffix(24) == "th" { pass = pass + 1 }

	// 100s.
	if strings.OrdinalSuffix(101) == "st" { pass = pass + 1 }
	if strings.OrdinalSuffix(111) == "th" { pass = pass + 1 }
	if strings.OrdinalSuffix(112) == "th" { pass = pass + 1 }
	if strings.OrdinalSuffix(113) == "th" { pass = pass + 1 }
	if strings.OrdinalSuffix(121) == "st" { pass = pass + 1 }

	// 0 and negative.
	if strings.OrdinalSuffix(0) == "th" { pass = pass + 1 }
	if strings.OrdinalSuffix(-1) == "st" { pass = pass + 1 }
	if strings.OrdinalSuffix(-13) == "th" { pass = pass + 1 }

	// Ordinal full string.
	if strings.Ordinal(1) == "1st" { pass = pass + 1 }
	if strings.Ordinal(2) == "2nd" { pass = pass + 1 }
	if strings.Ordinal(3) == "3rd" { pass = pass + 1 }
	if strings.Ordinal(4) == "4th" { pass = pass + 1 }
	if strings.Ordinal(11) == "11th" { pass = pass + 1 }
	if strings.Ordinal(21) == "21st" { pass = pass + 1 }
	if strings.Ordinal(101) == "101st" { pass = pass + 1 }
	if strings.Ordinal(112) == "112th" { pass = pass + 1 }
	if strings.Ordinal(0) == "0th" { pass = pass + 1 }
	if strings.Ordinal(-3) == "-3rd" { pass = pass + 1 }

	// Rank use case.
	if strings.Ordinal(1) + " place" == "1st place" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 35 { ret 42 }
	ret 0
}
