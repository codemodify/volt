package main
import "log"
import "bufio"
import "strings"
import "slices"
import "maps"
import "sort"

// Integration demo: a multi-line log parser that exercises the
// stdlib end-to-end:
//   - bufio.SplitLines to break input into lines (handles LF/CRLF)
//   - strings.HasPrefix / strings.Cut to parse "LEVEL: msg" format
//   - map[string][]string (slice-valued map, LANG.9) to group msgs
//   - sort.StringsAsc / maps.KeysStringString for deterministic order
//   - slices.IntsToStrings / strings.Join for output

fun levelKey(line string) string {
	// Lines look like "INFO: ..." / "WARN: ..." / "ERROR: ...".
	// Return the prefix before ": " (or "UNKNOWN" if absent).
	if !strings.Contains(line, ": ") { ret "UNKNOWN" }
	var before string = ""
	var after string = ""
	var found bool = false
	before, after, found = strings.Cut(line, ": ")
	if !found { ret "UNKNOWN" }
	// keep after alive
	if len(after) == 0 { ret "" + before }
	ret "" + before
}

fun main() int {
	var pass int = 0

	var input string = "INFO: server started\nWARN: deprecated flag\nINFO: connection accepted\nERROR: bad request\nWARN: slow query\nINFO: shutdown"
	var lines []string = bufio.SplitLines(input)
	if len(lines) == 6 { pass = pass + 1 }

	// Group lines by level using slices.GroupByStringString.
	var groups map[string][]string = slices.GroupByStringString(lines, levelKey)
	// We should have INFO, WARN, ERROR groups.
	if len(groups) == 3 { pass = pass + 1 }

	// Count per level (use a Copy-valued map so multi-read is OK).
	var counts map[string]int = new map[string]int
	for k, v := range groups {
		counts[k] = len(v)
	}
	if counts["INFO"] == 3 { pass = pass + 1 }
	if counts["WARN"] == 2 { pass = pass + 1 }
	if counts["ERROR"] == 1 { pass = pass + 1 }

	// Total via slices.SumInts on values.
	var keys []string = maps.KeysStringInt(counts)
	keys = sort.StringsAsc(keys)
	// Deterministic alphabetical order: ERROR, INFO, WARN.
	if keys[0] == "ERROR" { pass = pass + 1 }
	if keys[1] == "INFO" { pass = pass + 1 }
	if keys[2] == "WARN" { pass = pass + 1 }

	// Build a count slice in same order via repeated reads (counts
	// is Copy-valued so multi-read is OK per UX.21).
	var vals []int = new(3) []int{}
	for i := 0; i < 3; i++ {
		vals[i] = counts[keys[i]]
	}
	// ERROR=1, INFO=3, WARN=2.
	if vals[0] == 1 { pass = pass + 1 }
	if vals[1] == 3 { pass = pass + 1 }
	if vals[2] == 2 { pass = pass + 1 }

	// Total messages = 1+3+2 = 6.
	if slices.SumInts(vals) == 6 { pass = pass + 1 }

	// Render as "LEVEL=N LEVEL=N LEVEL=N" via joining.
	var valsStrings []string = slices.IntsToStrings(vals)
	var labels []string = new(3) []string{}
	for i := 0; i < 3; i++ {
		labels[i] = keys[i] + "=" + valsStrings[i]
	}
	var summary string = strings.Join(labels, " ")
	if summary == "ERROR=1 INFO=3 WARN=2" { pass = pass + 1 }

	log.Println("pass=%d summary=%s", pass, summary)
	if pass == 13 { ret 42 }
	ret 0
}
