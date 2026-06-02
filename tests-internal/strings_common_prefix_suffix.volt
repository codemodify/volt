package main
import "log"
import "strings"

// Positive test: strings.CommonPrefix + strings.CommonSuffix.

fun main() int {
	var pass int = 0

	// CommonPrefix — typical.
	if strings.CommonPrefix("foobar", "foobaz") == "fooba" { pass = pass + 1 }
	if strings.CommonPrefix("hello", "help") == "hel" { pass = pass + 1 }

	// Identical strings — full string shared.
	if strings.CommonPrefix("same", "same") == "same" { pass = pass + 1 }

	// No common prefix.
	if strings.CommonPrefix("abc", "xyz") == "" { pass = pass + 1 }

	// One empty.
	if strings.CommonPrefix("", "abc") == "" { pass = pass + 1 }
	if strings.CommonPrefix("abc", "") == "" { pass = pass + 1 }

	// Both empty.
	if strings.CommonPrefix("", "") == "" { pass = pass + 1 }

	// Prefix-of relationship.
	if strings.CommonPrefix("foo", "foobar") == "foo" { pass = pass + 1 }
	if strings.CommonPrefix("foobar", "foo") == "foo" { pass = pass + 1 }

	// Single char shared.
	if strings.CommonPrefix("apple", "ant") == "a" { pass = pass + 1 }

	// Path-like.
	if strings.CommonPrefix("/usr/local/bin", "/usr/local/lib") == "/usr/local/" { pass = pass + 1 }

	// CommonSuffix — typical.
	if strings.CommonSuffix("foobar", "foobaz") == "" { pass = pass + 1 }
	if strings.CommonSuffix("running", "jumping") == "ing" { pass = pass + 1 }

	// Identical strings — full string shared.
	if strings.CommonSuffix("same", "same") == "same" { pass = pass + 1 }

	// One empty.
	if strings.CommonSuffix("", "abc") == "" { pass = pass + 1 }
	if strings.CommonSuffix("abc", "") == "" { pass = pass + 1 }

	// Both empty.
	if strings.CommonSuffix("", "") == "" { pass = pass + 1 }

	// Suffix-of relationship.
	if strings.CommonSuffix("bar", "foobar") == "bar" { pass = pass + 1 }
	if strings.CommonSuffix("foobar", "bar") == "bar" { pass = pass + 1 }

	// File-extension style.
	if strings.CommonSuffix("readme.md", "todo.md") == ".md" { pass = pass + 1 }

	// Single char shared at end.
	if strings.CommonSuffix("dog", "frog") == "og" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 21 { ret 42 }
	ret 0
}
