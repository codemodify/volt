package main
import "log"
import "strings"
import "time"

// Positive test: strings.IsHex + (t Time).MonthShortName.

fun main() int {
	var pass int = 0

	// IsHex digits.
	if strings.IsHex("0") { pass = pass + 1 }
	if strings.IsHex("9") { pass = pass + 1 }
	if strings.IsHex("a") { pass = pass + 1 }
	if strings.IsHex("f") { pass = pass + 1 }
	if strings.IsHex("A") { pass = pass + 1 }
	if strings.IsHex("F") { pass = pass + 1 }

	// IsHex multi-char.
	if strings.IsHex("deadbeef") { pass = pass + 1 }
	if strings.IsHex("DEADBEEF") { pass = pass + 1 }
	if strings.IsHex("01234567") { pass = pass + 1 }
	if strings.IsHex("aBcDeF") { pass = pass + 1 }

	// IsHex rejections.
	if !strings.IsHex("g") { pass = pass + 1 }
	if !strings.IsHex("0g") { pass = pass + 1 }
	if !strings.IsHex("0x12") { pass = pass + 1 }   // 'x' rejected
	if !strings.IsHex("1.2") { pass = pass + 1 }
	if !strings.IsHex("") { pass = pass + 1 }
	if !strings.IsHex(" abc") { pass = pass + 1 }
	if !strings.IsHex("abc ") { pass = pass + 1 }

	// MonthShortName — every month.
	if time.Date(2024, 1, 15, 0, 0, 0, 0).MonthShortName() == "Jan" { pass = pass + 1 }
	if time.Date(2024, 2, 15, 0, 0, 0, 0).MonthShortName() == "Feb" { pass = pass + 1 }
	if time.Date(2024, 3, 15, 0, 0, 0, 0).MonthShortName() == "Mar" { pass = pass + 1 }
	if time.Date(2024, 4, 15, 0, 0, 0, 0).MonthShortName() == "Apr" { pass = pass + 1 }
	if time.Date(2024, 5, 15, 0, 0, 0, 0).MonthShortName() == "May" { pass = pass + 1 }
	if time.Date(2024, 6, 15, 0, 0, 0, 0).MonthShortName() == "Jun" { pass = pass + 1 }
	if time.Date(2024, 7, 15, 0, 0, 0, 0).MonthShortName() == "Jul" { pass = pass + 1 }
	if time.Date(2024, 8, 15, 0, 0, 0, 0).MonthShortName() == "Aug" { pass = pass + 1 }
	if time.Date(2024, 9, 15, 0, 0, 0, 0).MonthShortName() == "Sep" { pass = pass + 1 }
	if time.Date(2024, 10, 15, 0, 0, 0, 0).MonthShortName() == "Oct" { pass = pass + 1 }
	if time.Date(2024, 11, 15, 0, 0, 0, 0).MonthShortName() == "Nov" { pass = pass + 1 }
	if time.Date(2024, 12, 15, 0, 0, 0, 0).MonthShortName() == "Dec" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 29 { ret 42 }
	ret 0
}
