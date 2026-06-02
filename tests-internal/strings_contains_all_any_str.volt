package main
import "log"
import "strings"

// Positive test: strings.ContainsAll + strings.ContainsAnyStr.

fun main() int {
	var pass int = 0

	// ContainsAll — all present.
	var all []string = new(3) []string{"foo", "bar", "baz"}
	if strings.ContainsAll("the foo bar baz line", all) { pass = pass + 1 }

	// ContainsAll — one missing.
	if !strings.ContainsAll("foo and bar but not the third", all) { pass = pass + 1 }

	// ContainsAll — empty list → vacuously true.
	var em []string = new(0) []string{}
	if strings.ContainsAll("anything", em) { pass = pass + 1 }
	if strings.ContainsAll("", em) { pass = pass + 1 }

	// ContainsAll — empty string in subs is contained by everything.
	var one []string = new(1) []string{""}
	if strings.ContainsAll("anything", one) { pass = pass + 1 }
	if strings.ContainsAll("", one) { pass = pass + 1 }

	// ContainsAll — overlapping substrings.
	var o []string = new(2) []string{"abc", "bcd"}
	if strings.ContainsAll("xxxabcdxxx", o) { pass = pass + 1 }

	// ContainsAll — all missing from empty string.
	if !strings.ContainsAll("", all) { pass = pass + 1 }

	// ContainsAnyStr — at least one present.
	var subs []string = new(3) []string{"foo", "bar", "baz"}
	if strings.ContainsAnyStr("xxx foo xxx", subs) { pass = pass + 1 }
	if strings.ContainsAnyStr("xxx bar xxx", subs) { pass = pass + 1 }
	if strings.ContainsAnyStr("xxx baz xxx", subs) { pass = pass + 1 }

	// ContainsAnyStr — none present.
	if !strings.ContainsAnyStr("xxx qux xxx", subs) { pass = pass + 1 }

	// ContainsAnyStr — empty list → false.
	if !strings.ContainsAnyStr("anything", em) { pass = pass + 1 }

	// ContainsAnyStr — empty substring matches every string.
	if strings.ContainsAnyStr("anything", one) { pass = pass + 1 }
	if strings.ContainsAnyStr("", one) { pass = pass + 1 }

	// ContainsAnyStr — single matches.
	var single []string = new(1) []string{"hello"}
	if strings.ContainsAnyStr("say hello world", single) { pass = pass + 1 }
	if !strings.ContainsAnyStr("say goodbye world", single) { pass = pass + 1 }

	// ContainsAll + ContainsAnyStr relation: ContainsAll implies ContainsAnyStr for non-empty inputs.
	if strings.ContainsAll("foo bar baz", all) {
		if strings.ContainsAnyStr("foo bar baz", all) { pass = pass + 1 }
	}

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
