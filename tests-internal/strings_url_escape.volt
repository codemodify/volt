package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// UrlEscape — unreserved passes through.
	if strings.UrlEscape("hello") == "hello" { pass = pass + 1 }
	if strings.UrlEscape("ABC-_.~") == "ABC-_.~" { pass = pass + 1 }
	if strings.UrlEscape("0123456789") == "0123456789" { pass = pass + 1 }

	// UrlEscape — common chars get escaped (lowercase hex).
	if strings.UrlEscape("a b") == "a%20b" { pass = pass + 1 }
	if strings.UrlEscape("/path") == "%2fpath" { pass = pass + 1 }
	if strings.UrlEscape("?q=1&r=2") == "%3fq%3d1%26r%3d2" { pass = pass + 1 }

	// UrlEscape — high-bit byte.
	if strings.UrlEscape("\xff") == "%ff" { pass = pass + 1 }

	// UrlEscape — empty.
	if strings.UrlEscape("") == "" { pass = pass + 1 }

	// UrlUnescape — basic.
	if strings.UrlUnescape("a%20b") == "a b" { pass = pass + 1 }
	if strings.UrlUnescape("%2Fpath") == "/path" { pass = pass + 1 }
	if strings.UrlUnescape("%3Fq%3D1%26r%3D2") == "?q=1&r=2" { pass = pass + 1 }

	// UrlUnescape — uppercase hex.
	if strings.UrlUnescape("%2F") == "/" { pass = pass + 1 }
	if strings.UrlUnescape("%FF") == "\xff" { pass = pass + 1 }

	// UrlUnescape — bad hex passes through.
	if strings.UrlUnescape("%XX") == "%XX" { pass = pass + 1 }
	if strings.UrlUnescape("%2") == "%2" { pass = pass + 1 }
	if strings.UrlUnescape("%") == "%" { pass = pass + 1 }

	// UrlUnescape — no-op cases.
	if strings.UrlUnescape("plain text") == "plain text" { pass = pass + 1 }
	if strings.UrlUnescape("") == "" { pass = pass + 1 }

	// Roundtrip: UrlUnescape(UrlEscape(s)) == s.
	if strings.UrlUnescape(strings.UrlEscape("a b/c?d=e&f=g")) == "a b/c?d=e&f=g" { pass = pass + 1 }
	if strings.UrlUnescape(strings.UrlEscape("héllo")) == "héllo" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 20 { ret 42 }
	ret 0
}
