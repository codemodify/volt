package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	var ns int = 0
	var err error = nil

	// Each unit.
	ns, err = time.ParseDuration("1ns")
	if err == nil { pass = pass + 1 }
	if ns == 1 { pass = pass + 1 }

	ns, err = time.ParseDuration("5us")
	if err == nil { pass = pass + 1 }
	if ns == 5000 { pass = pass + 1 }

	ns, err = time.ParseDuration("100ms")
	if err == nil { pass = pass + 1 }
	if ns == 100000000 { pass = pass + 1 }

	ns, err = time.ParseDuration("3s")
	if err == nil { pass = pass + 1 }
	if ns == 3000000000 { pass = pass + 1 }

	ns, err = time.ParseDuration("2m")
	if err == nil { pass = pass + 1 }
	if ns == 120000000000 { pass = pass + 1 }

	ns, err = time.ParseDuration("1h")
	if err == nil { pass = pass + 1 }
	if ns == 3600000000000 { pass = pass + 1 }

	// Zero.
	ns, err = time.ParseDuration("0s")
	if err == nil { pass = pass + 1 }
	if ns == 0 { pass = pass + 1 }

	// Negative.
	ns, err = time.ParseDuration("-5s")
	if err == nil { pass = pass + 1 }
	if ns == -5000000000 { pass = pass + 1 }

	// Multi-digit value.
	ns, err = time.ParseDuration("250ms")
	if err == nil { pass = pass + 1 }
	if ns == 250000000 { pass = pass + 1 }

	// Round-trip with FormatDuration (single-unit forms only).
	if time.FormatDuration(5000000000) == "5s" { pass = pass + 1 }
	ns, err = time.ParseDuration("5s")
	if ns == 5000000000 { pass = pass + 1 }

	// Errors.
	ns, err = time.ParseDuration("")
	if err != nil { pass = pass + 1 }
	if ns < 0 { ret 0 }

	ns, err = time.ParseDuration("5")              // no unit
	if err != nil { pass = pass + 1 }
	if ns < 0 { ret 0 }

	ns, err = time.ParseDuration("ms")             // no digits
	if err != nil { pass = pass + 1 }
	if ns < 0 { ret 0 }

	ns, err = time.ParseDuration("5xy")            // unknown unit
	if err != nil { pass = pass + 1 }
	if ns < 0 { ret 0 }

	ns, err = time.ParseDuration("-")              // just minus
	if err != nil { pass = pass + 1 }
	if ns < 0 { ret 0 }

	ns, err = time.ParseDuration("abc")            // no digits
	if err != nil { pass = pass + 1 }
	if ns < 0 { ret 0 }

	log.Println("pass=%d", pass)
	if pass == 26 { ret 42 }
	ret 0
}
