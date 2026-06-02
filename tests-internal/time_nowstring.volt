package main
import "log"
import "time"
import "strings"

// Positive test: time.NowString / time.NowDate / Time.DateString.

fun main() int {
	var pass int = 0

	// NowString: should be 20 chars (YYYY-MM-DDTHH:MM:SSZ).
	var n string = time.NowString()
	if len(n) == 20 { pass = pass + 1 }
	// Must end in 'Z'.
	if n[19] == 90 { pass = pass + 1 }
	// Must contain 'T' at position 10.
	if n[10] == 84 { pass = pass + 1 }
	// Year prefix should start with '20'.
	if strings.HasPrefix(n, "20") { pass = pass + 1 }

	// NowDate: should be 10 chars (YYYY-MM-DD).
	var d string = time.NowDate()
	if len(d) == 10 { pass = pass + 1 }
	if d[4] == 45 { pass = pass + 1 }   // '-'
	if d[7] == 45 { pass = pass + 1 }   // '-'
	if strings.HasPrefix(d, "20") { pass = pass + 1 }

	// DateString on a known Time.
	var t time.Time = time.Date(2024, 3, 15, 12, 30, 45, 0)
	if t.DateString() == "2024-03-15" { pass = pass + 1 }

	// Old date.
	var t2 time.Time = time.Date(1970, 1, 1, 0, 0, 0, 0)
	if t2.DateString() == "1970-01-01" { pass = pass + 1 }

	// Far future.
	var t3 time.Time = time.Date(2099, 12, 31, 0, 0, 0, 0)
	if t3.DateString() == "2099-12-31" { pass = pass + 1 }

	// NowString and NowDate prefix agree.
	var n2 string = time.NowString()
	var d2 string = time.NowDate()
	if strings.HasPrefix(n2, d2) { pass = pass + 1 }

	log.Println("pass=%d now=%s date=%s", pass, n, d)
	if pass == 12 { ret 42 }
	ret 0
}
