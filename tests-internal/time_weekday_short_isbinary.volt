package main
import "log"
import "time"
import "strings"

// Positive test: (t Time).WeekdayShortName + strings.IsBinary.

fun main() int {
	var pass int = 0

	// Walk a known week starting Sunday 2024-05-26.
	var sun time.Time = time.Date(2024, 5, 26, 0, 0, 0, 0)
	if sun.WeekdayShortName() == "Sun" { pass = pass + 1 }
	var mon time.Time = time.Date(2024, 5, 27, 0, 0, 0, 0)
	if mon.WeekdayShortName() == "Mon" { pass = pass + 1 }
	var tue time.Time = time.Date(2024, 5, 28, 0, 0, 0, 0)
	if tue.WeekdayShortName() == "Tue" { pass = pass + 1 }
	var wed time.Time = time.Date(2024, 5, 29, 0, 0, 0, 0)
	if wed.WeekdayShortName() == "Wed" { pass = pass + 1 }
	var thu time.Time = time.Date(2024, 5, 30, 0, 0, 0, 0)
	if thu.WeekdayShortName() == "Thu" { pass = pass + 1 }
	var fri time.Time = time.Date(2024, 5, 31, 0, 0, 0, 0)
	if fri.WeekdayShortName() == "Fri" { pass = pass + 1 }
	var sat time.Time = time.Date(2024, 6, 1, 0, 0, 0, 0)
	if sat.WeekdayShortName() == "Sat" { pass = pass + 1 }

	// Epoch is Thursday.
	var ep time.Time = time.FromNano(0)
	if ep.WeekdayShortName() == "Thu" { pass = pass + 1 }

	// IsBinary basic.
	if strings.IsBinary("0") { pass = pass + 1 }
	if strings.IsBinary("1") { pass = pass + 1 }
	if strings.IsBinary("01") { pass = pass + 1 }
	if strings.IsBinary("10110010") { pass = pass + 1 }
	if strings.IsBinary("00000000") { pass = pass + 1 }
	if strings.IsBinary("11111111") { pass = pass + 1 }

	// IsBinary rejections.
	if !strings.IsBinary("") { pass = pass + 1 }
	if !strings.IsBinary("2") { pass = pass + 1 }
	if !strings.IsBinary("012") { pass = pass + 1 }
	if !strings.IsBinary("0b10") { pass = pass + 1 }
	if !strings.IsBinary(" 01") { pass = pass + 1 }
	if !strings.IsBinary("0a") { pass = pass + 1 }
	if !strings.IsBinary("01x") { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 21 { ret 42 }
	ret 0
}
