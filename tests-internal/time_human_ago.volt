package main
import "log"
import "time"

fun main() int {
	var pass int = 0

	// HumanAgoFromNanos (deterministic - prefer for testing).
	if time.HumanAgoFromNanos(0) == "just now" { pass = pass + 1 }

	// Past.
	if time.HumanAgoFromNanos(-1000000000) == "1 second ago" { pass = pass + 1 }
	if time.HumanAgoFromNanos(-60000000000) == "1 minute ago" { pass = pass + 1 }
	if time.HumanAgoFromNanos(-3600000000000) == "1 hour ago" { pass = pass + 1 }
	if time.HumanAgoFromNanos(-86400000000000) == "1 day ago" { pass = pass + 1 }
	if time.HumanAgoFromNanos(-7200000000000) == "2 hours ago" { pass = pass + 1 }
	if time.HumanAgoFromNanos(-172800000000000) == "2 days ago" { pass = pass + 1 }
	if time.HumanAgoFromNanos(-300000000000) == "5 minutes ago" { pass = pass + 1 }

	// Future.
	if time.HumanAgoFromNanos(1000000000) == "in 1 second" { pass = pass + 1 }
	if time.HumanAgoFromNanos(60000000000) == "in 1 minute" { pass = pass + 1 }
	if time.HumanAgoFromNanos(3600000000000) == "in 1 hour" { pass = pass + 1 }
	if time.HumanAgoFromNanos(86400000000000) == "in 1 day" { pass = pass + 1 }
	if time.HumanAgoFromNanos(7200000000000) == "in 2 hours" { pass = pass + 1 }

	// Sub-second nonzero past rounds to "1 second ago".
	if time.HumanAgoFromNanos(-500000) == "1 second ago" { pass = pass + 1 }
	if time.HumanAgoFromNanos(-1) == "1 second ago" { pass = pass + 1 }

	// HumanAgo against time.Now-based time.
	// Picking a past time well in the past (epoch + 1) so the delta is large.
	var past time.Time = time.FromNano(1)
	var msg string = time.HumanAgo(past)
	// We can't predict exact value but it should end with "ago".
	var endsAgo bool = false
	if len(msg) >= 4 {
		if msg[len(msg) - 1] == 111 {   // 'o'
			endsAgo = true
		}
	}
	if endsAgo { pass = pass + 1 }

	// Activity-feed use case.
	var event string = "last login: " + time.HumanAgoFromNanos(-3600000000000)
	if event == "last login: 1 hour ago" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 17 { ret 42 }
	ret 0
}
