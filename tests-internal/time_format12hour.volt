package main
import "log"
import "time"

// Positive test: (t Time).Format12Hour + Format12HourFull.

fun main() int {
	var pass int = 0

	// Format12Hour — midnight.
	var midnight time.Time = time.Date(2024, 6, 15, 0, 5, 0, 0)
	if midnight.Format12Hour() == "12:05 AM" { pass = pass + 1 }

	// Noon.
	var noon time.Time = time.Date(2024, 6, 15, 12, 0, 0, 0)
	if noon.Format12Hour() == "12:00 PM" { pass = pass + 1 }

	// 3:05 PM.
	var afternoon time.Time = time.Date(2024, 6, 15, 15, 5, 0, 0)
	if afternoon.Format12Hour() == "3:05 PM" { pass = pass + 1 }

	// 9:30 AM.
	var morning time.Time = time.Date(2024, 6, 15, 9, 30, 0, 0)
	if morning.Format12Hour() == "9:30 AM" { pass = pass + 1 }

	// 11:59 PM.
	var lateNight time.Time = time.Date(2024, 6, 15, 23, 59, 0, 0)
	if lateNight.Format12Hour() == "11:59 PM" { pass = pass + 1 }

	// 1:00 AM.
	var earlyMorning time.Time = time.Date(2024, 6, 15, 1, 0, 0, 0)
	if earlyMorning.Format12Hour() == "1:00 AM" { pass = pass + 1 }

	// Format12HourFull — includes seconds.
	if midnight.Format12HourFull() == "12:05:00 AM" { pass = pass + 1 }
	if afternoon.Format12HourFull() == "3:05:00 PM" { pass = pass + 1 }

	var withSec time.Time = time.Date(2024, 6, 15, 15, 5, 42, 0)
	if withSec.Format12HourFull() == "3:05:42 PM" { pass = pass + 1 }

	var earlyMornSec time.Time = time.Date(2024, 6, 15, 1, 2, 3, 0)
	if earlyMornSec.Format12HourFull() == "1:02:03 AM" { pass = pass + 1 }

	// Minute / second always zero-padded.
	var single time.Time = time.Date(2024, 6, 15, 4, 7, 9, 0)
	if single.Format12HourFull() == "4:07:09 AM" { pass = pass + 1 }

	// Hour is NOT zero-padded (h:mm style).
	if single.Format12Hour() == "4:07 AM" { pass = pass + 1 }

	// Boundary 11:00 AM / 12:00 PM transition.
	var elevenAM time.Time = time.Date(2024, 6, 15, 11, 0, 0, 0)
	if elevenAM.Format12Hour() == "11:00 AM" { pass = pass + 1 }
	if noon.Format12Hour() == "12:00 PM" { pass = pass + 1 }
	var onePM time.Time = time.Date(2024, 6, 15, 13, 0, 0, 0)
	if onePM.Format12Hour() == "1:00 PM" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 15 { ret 42 }
	ret 0
}
