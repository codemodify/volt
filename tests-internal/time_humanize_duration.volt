package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	// Zero.
	if time.HumanizeDuration(0) == "0 seconds" { pass = pass + 1 }

	// Seconds.
	if time.HumanizeDuration(1000000000) == "1 second" { pass = pass + 1 }
	if time.HumanizeDuration(2000000000) == "2 seconds" { pass = pass + 1 }
	if time.HumanizeDuration(45000000000) == "45 seconds" { pass = pass + 1 }
	if time.HumanizeDuration(59000000000) == "59 seconds" { pass = pass + 1 }

	// Sub-second nonzero rounds to "1 second".
	if time.HumanizeDuration(500000) == "1 second" { pass = pass + 1 }   // 500us
	if time.HumanizeDuration(1) == "1 second" { pass = pass + 1 }

	// Minutes.
	if time.HumanizeDuration(60000000000) == "1 minute" { pass = pass + 1 }
	if time.HumanizeDuration(120000000000) == "2 minutes" { pass = pass + 1 }
	if time.HumanizeDuration(150000000000) == "2 minutes" { pass = pass + 1 }   // truncates
	if time.HumanizeDuration(3540000000000) == "59 minutes" { pass = pass + 1 }

	// Hours.
	if time.HumanizeDuration(3600000000000) == "1 hour" { pass = pass + 1 }
	if time.HumanizeDuration(7200000000000) == "2 hours" { pass = pass + 1 }
	if time.HumanizeDuration(7500000000000) == "2 hours" { pass = pass + 1 }   // 2h5m → "2 hours"
	if time.HumanizeDuration(82800000000000) == "23 hours" { pass = pass + 1 }

	// Days.
	if time.HumanizeDuration(86400000000000) == "1 day" { pass = pass + 1 }
	if time.HumanizeDuration(172800000000000) == "2 days" { pass = pass + 1 }
	if time.HumanizeDuration(604800000000000) == "7 days" { pass = pass + 1 }

	// Negative.
	if time.HumanizeDuration(-1000000000) == "-1 second" { pass = pass + 1 }
	if time.HumanizeDuration(-86400000000000) == "-1 day" { pass = pass + 1 }

	// UI use case: "active X ago".
	var nsSince int = 3600000000000   // 1 hour
	var msg string = "active " + time.HumanizeDuration(nsSince) + " ago"
	if msg == "active 1 hour ago" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 21 { ret 42 }
	ret 0
}
