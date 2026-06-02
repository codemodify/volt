package main
import "log"
import "strings"

// Positive test: strings.URLEncode + strings.URLDecode.

fun main() int {
	var pass int = 0

	// URLEncode — unreserved bytes pass through.
	if strings.URLEncode("abcXYZ012") == "abcXYZ012" { pass = pass + 1 }
	if strings.URLEncode("-_.~") == "-_.~" { pass = pass + 1 }

	// URLEncode — space → %20.
	if strings.URLEncode("hello world") == "hello%20world" { pass = pass + 1 }

	// URLEncode — common URL-unsafe chars.
	if strings.URLEncode("/") == "%2F" { pass = pass + 1 }
	if strings.URLEncode("?") == "%3F" { pass = pass + 1 }
	if strings.URLEncode("#") == "%23" { pass = pass + 1 }
	if strings.URLEncode("&") == "%26" { pass = pass + 1 }
	if strings.URLEncode("=") == "%3D" { pass = pass + 1 }
	if strings.URLEncode("+") == "%2B" { pass = pass + 1 }
	if strings.URLEncode(":") == "%3A" { pass = pass + 1 }

	// URLEncode — high-bit byte (UTF-8 multibyte).
	if strings.URLEncode("\xff") == "%FF" { pass = pass + 1 }

	// URLEncode — mixed.
	if strings.URLEncode("hello world!") == "hello%20world%21" { pass = pass + 1 }
	if strings.URLEncode("a=1&b=2") == "a%3D1%26b%3D2" { pass = pass + 1 }

	// URLEncode — empty.
	if strings.URLEncode("") == "" { pass = pass + 1 }

	// URLDecode — basic.
	var s string = ""
	var err error = nil
	s, err = strings.URLDecode("hello%20world")
	if err == nil { pass = pass + 1 }
	if s == "hello world" { pass = pass + 1 }

	// URLDecode — uppercase hex.
	s, err = strings.URLDecode("%2F")
	if s == "/" { pass = pass + 1 }
	// URLDecode — lowercase hex also accepted.
	s, err = strings.URLDecode("%2f")
	if s == "/" { pass = pass + 1 }

	// URLDecode — no percent → unchanged.
	s, err = strings.URLDecode("abc-_.~")
	if s == "abc-_.~" { pass = pass + 1 }

	// URLDecode — roundtrip various.
	s, err = strings.URLDecode(strings.URLEncode("Hello, World! a=1&b=2"))
	if s == "Hello, World! a=1&b=2" { pass = pass + 1 }

	// URLDecode — error: truncated.
	s, err = strings.URLDecode("foo%2")
	if err != nil { pass = pass + 1 }

	// URLDecode — error: bad hex digit.
	s, err = strings.URLDecode("%ZZ")
	if err != nil { pass = pass + 1 }

	// URLDecode — empty.
	s, err = strings.URLDecode("")
	if s == "" { pass = pass + 1 }
	if err == nil { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 24 { ret 42 }
	ret 0
}
