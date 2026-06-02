package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// width 0 → "".
	if strings.AsciiBar(5, 0, 35, 46) == "" { pass = pass + 1 }

	// negative width → "".
	if strings.AsciiBar(5, -3, 35, 46) == "" { pass = pass + 1 }

	// count 0 → all-empty.
	if strings.AsciiBar(0, 5, 35, 46) == "....." { pass = pass + 1 }

	// count == width → all-filled.
	if strings.AsciiBar(5, 5, 35, 46) == "#####" { pass = pass + 1 }

	// Partial.
	if strings.AsciiBar(3, 5, 35, 46) == "###.." { pass = pass + 1 }
	if strings.AsciiBar(7, 10, 35, 46) == "#######..." { pass = pass + 1 }

	// count > width clamps.
	if strings.AsciiBar(99, 5, 35, 46) == "#####" { pass = pass + 1 }

	// Negative count clamps to 0.
	if strings.AsciiBar(-5, 5, 35, 46) == "....." { pass = pass + 1 }

	// Different fill / empty bytes.
	if strings.AsciiBar(3, 5, 42, 32) == "***  " { pass = pass + 1 }   // '*' / ' '
	if strings.AsciiBar(3, 5, 124, 45) == "|||--" { pass = pass + 1 }   // '|' / '-'

	// Width 1.
	if strings.AsciiBar(0, 1, 35, 46) == "." { pass = pass + 1 }
	if strings.AsciiBar(1, 1, 35, 46) == "#" { pass = pass + 1 }

	// Block characters.
	if strings.AsciiBar(4, 8, 35, 46) == "####...." { pass = pass + 1 }

	// Bar-chart use case with PercentOfMaxInt.
	// data [10, 30, 20] → max=30 → percents [33, 100, 66] for scale=100
	// Pick width=10, so bars get 3, 10, 6 fill.
	var b1 string = strings.AsciiBar(3, 10, 35, 46)
	if b1 == "###......." { pass = pass + 1 }
	var b2 string = strings.AsciiBar(10, 10, 35, 46)
	if b2 == "##########" { pass = pass + 1 }
	var b3 string = strings.AsciiBar(6, 10, 35, 46)
	if b3 == "######...." { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
