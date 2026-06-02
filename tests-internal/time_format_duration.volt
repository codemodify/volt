package main
import "log"
import "time"

// Positive test: time.FormatDuration — human-readable rendering
// of a nanosecond duration.

fun main() int {
	var pass int = 0

	// Zero.
	if time.FormatDuration(0) == "0s" { pass = pass + 1 }

	// Nanosecond range.
	if time.FormatDuration(42) == "42ns" { pass = pass + 1 }
	if time.FormatDuration(999) == "999ns" { pass = pass + 1 }

	// Microsecond range.
	if time.FormatDuration(1000) == "1us" { pass = pass + 1 }
	if time.FormatDuration(500000) == "500us" { pass = pass + 1 }

	// Millisecond range.
	if time.FormatDuration(1000000) == "1ms" { pass = pass + 1 }
	if time.FormatDuration(500 * time.Millisecond) == "500ms" { pass = pass + 1 }

	// Second range.
	if time.FormatDuration(time.Second) == "1s" { pass = pass + 1 }
	if time.FormatDuration(5 * time.Second) == "5s" { pass = pass + 1 }

	// Minute range.
	if time.FormatDuration(time.Minute) == "1m" { pass = pass + 1 }
	if time.FormatDuration(2 * time.Minute + 30 * time.Second) == "2m 30s" { pass = pass + 1 }

	// Hour range.
	if time.FormatDuration(time.Hour) == "1h" { pass = pass + 1 }
	if time.FormatDuration(2 * time.Hour + 15 * time.Minute) == "2h 15m" { pass = pass + 1 }

	// Negative duration.
	if time.FormatDuration(-1000) == "-1us" { pass = pass + 1 }
	if time.FormatDuration(-time.Second) == "-1s" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 15 { ret 42 }
	ret 0
}
