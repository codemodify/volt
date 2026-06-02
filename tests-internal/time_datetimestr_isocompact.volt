package main
import "log"
import "time"

// Positive test: (t Time).DateTimeString + IsoCompact.

fun main() int {
	var pass int = 0

	// DateTimeString.
	var t1 time.Time = time.Date(2024, 6, 15, 15, 5, 42, 0)
	if t1.DateTimeString() == "2024-06-15 15:05:42" { pass = pass + 1 }

	var midnight time.Time = time.Date(2024, 1, 1, 0, 0, 0, 0)
	if midnight.DateTimeString() == "2024-01-01 00:00:00" { pass = pass + 1 }

	var lastSec time.Time = time.Date(2024, 12, 31, 23, 59, 59, 0)
	if lastSec.DateTimeString() == "2024-12-31 23:59:59" { pass = pass + 1 }

	var singleDigit time.Time = time.Date(2024, 3, 4, 5, 6, 7, 0)
	if singleDigit.DateTimeString() == "2024-03-04 05:06:07" { pass = pass + 1 }

	// Epoch instant.
	var epoch time.Time = time.Date(1970, 1, 1, 0, 0, 0, 0)
	if epoch.DateTimeString() == "1970-01-01 00:00:00" { pass = pass + 1 }

	// IsoCompact.
	if t1.IsoCompact() == "20240615T150542Z" { pass = pass + 1 }
	if midnight.IsoCompact() == "20240101T000000Z" { pass = pass + 1 }
	if lastSec.IsoCompact() == "20241231T235959Z" { pass = pass + 1 }
	if singleDigit.IsoCompact() == "20240304T050607Z" { pass = pass + 1 }
	if epoch.IsoCompact() == "19700101T000000Z" { pass = pass + 1 }

	// Far-future year (within int64 ns range).
	var year2099 time.Time = time.Date(2099, 12, 31, 23, 59, 59, 0)
	if year2099.DateTimeString() == "2099-12-31 23:59:59" { pass = pass + 1 }
	if year2099.IsoCompact() == "20991231T235959Z" { pass = pass + 1 }

	// IsoCompact length is always 16.
	if len(t1.IsoCompact()) == 16 { pass = pass + 1 }
	if len(epoch.IsoCompact()) == 16 { pass = pass + 1 }

	// DateTimeString length is always 19.
	if len(t1.DateTimeString()) == 19 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 15 { ret 42 }
	ret 0
}
