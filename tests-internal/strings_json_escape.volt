package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// JsonEscape — pass-through for plain ASCII.
	if strings.JsonEscape("hello") == "hello" { pass = pass + 1 }
	if strings.JsonEscape("") == "" { pass = pass + 1 }

	// JsonEscape — each mandatory escape.
	if strings.JsonEscape("\\") == "\\\\" { pass = pass + 1 }
	if strings.JsonEscape("\"") == "\\\"" { pass = pass + 1 }
	if strings.JsonEscape("\n") == "\\n" { pass = pass + 1 }
	if strings.JsonEscape("\r") == "\\r" { pass = pass + 1 }
	if strings.JsonEscape("\t") == "\\t" { pass = pass + 1 }
	if strings.JsonEscape("\f") == "\\f" { pass = pass + 1 }
	if strings.JsonEscape("\b") == "\\b" { pass = pass + 1 }

	// JsonEscape — control char becomes \u00HH.
	if strings.JsonEscape("\x00") == "\\u0000" { pass = pass + 1 }
	if strings.JsonEscape("\x01") == "\\u0001" { pass = pass + 1 }
	if strings.JsonEscape("\x1f") == "\\u001f" { pass = pass + 1 }

	// JsonEscape — high-bit byte passes through (UTF-8 raw).
	if strings.JsonEscape("\xc3\xa9") == "\xc3\xa9" { pass = pass + 1 }   // é in UTF-8

	// JsonEscape — mixed.
	if strings.JsonEscape("line1\nline2") == "line1\\nline2" { pass = pass + 1 }
	if strings.JsonEscape("say \"hi\"") == "say \\\"hi\\\"" { pass = pass + 1 }

	// JsonQuote — wraps in quotes.
	if strings.JsonQuote("hello") == "\"hello\"" { pass = pass + 1 }
	if strings.JsonQuote("") == "\"\"" { pass = pass + 1 }
	if strings.JsonQuote("a\"b") == "\"a\\\"b\"" { pass = pass + 1 }
	if strings.JsonQuote("multi\nline") == "\"multi\\nline\"" { pass = pass + 1 }

	// JsonQuote — control char.
	if strings.JsonQuote("\x00") == "\"\\u0000\"" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 20 { ret 42 }
	ret 0
}
