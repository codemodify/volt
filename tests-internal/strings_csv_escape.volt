package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// CsvEscape — plain value (no special chars) passes through.
	if strings.CsvEscape("hello") == "hello" { pass = pass + 1 }
	if strings.CsvEscape("") == "" { pass = pass + 1 }

	// CsvEscape — comma triggers quoting.
	if strings.CsvEscape("a,b") == "\"a,b\"" { pass = pass + 1 }

	// CsvEscape — newline triggers quoting.
	if strings.CsvEscape("line1\nline2") == "\"line1\nline2\"" { pass = pass + 1 }

	// CsvEscape — CR triggers quoting.
	if strings.CsvEscape("a\rb") == "\"a\rb\"" { pass = pass + 1 }

	// CsvEscape — quote triggers quoting + doubling.
	if strings.CsvEscape("say \"hi\"") == "\"say \"\"hi\"\"\"" { pass = pass + 1 }

	// CsvEscape — only-quote.
	if strings.CsvEscape("\"") == "\"\"\"\"" { pass = pass + 1 }   // "" "" "" → escape: open, escaped quote (""), close

	// CsvUnescape — strips quotes.
	if strings.CsvUnescape("\"hello\"") == "hello" { pass = pass + 1 }

	// CsvUnescape — de-doubles internal quotes.
	if strings.CsvUnescape("\"say \"\"hi\"\"\"") == "say \"hi\"" { pass = pass + 1 }

	// CsvUnescape — comma preserved inside quoted cell.
	if strings.CsvUnescape("\"a,b\"") == "a,b" { pass = pass + 1 }

	// CsvUnescape — unquoted value passes through.
	if strings.CsvUnescape("hello") == "hello" { pass = pass + 1 }

	// CsvUnescape — empty.
	if strings.CsvUnescape("") == "" { pass = pass + 1 }

	// CsvUnescape — single-char.
	if strings.CsvUnescape("a") == "a" { pass = pass + 1 }

	// CsvUnescape — empty quoted cell.
	if strings.CsvUnescape("\"\"") == "" { pass = pass + 1 }

	// Roundtrip: CsvUnescape(CsvEscape(s)) == s.
	if strings.CsvUnescape(strings.CsvEscape("a,b,c")) == "a,b,c" { pass = pass + 1 }
	if strings.CsvUnescape(strings.CsvEscape("say \"hi\"")) == "say \"hi\"" { pass = pass + 1 }
	if strings.CsvUnescape(strings.CsvEscape("multi\nline")) == "multi\nline" { pass = pass + 1 }
	if strings.CsvUnescape(strings.CsvEscape("plain")) == "plain" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
