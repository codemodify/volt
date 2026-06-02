package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// JoinNonEmpty — skip empties.
	if strings.JoinNonEmpty(new(4) []string { "a", "", "b", "c" }, "/") == "a/b/c" { pass = pass + 1 }

	// JoinNonEmpty — all non-empty.
	if strings.JoinNonEmpty(new(3) []string { "x", "y", "z" }, "-") == "x-y-z" { pass = pass + 1 }

	// JoinNonEmpty — all empty.
	if strings.JoinNonEmpty(new(3) []string { "", "", "" }, "/") == "" { pass = pass + 1 }

	// JoinNonEmpty — empty input.
	if strings.JoinNonEmpty(new(0) []string {}, "/") == "" { pass = pass + 1 }

	// JoinNonEmpty — leading and trailing empties trimmed.
	if strings.JoinNonEmpty(new(5) []string { "", "a", "", "b", "" }, ",") == "a,b" { pass = pass + 1 }

	// JoinNonEmpty — single element.
	if strings.JoinNonEmpty(new(1) []string { "alone" }, ",") == "alone" { pass = pass + 1 }

	// JoinNonEmpty — single empty becomes "".
	if strings.JoinNonEmpty(new(1) []string { "" }, ",") == "" { pass = pass + 1 }

	// JoinLast — Oxford-comma style.
	if strings.JoinLast(new(3) []string { "a", "b", "c" }, ", ", ", and ") == "a, b, and c" { pass = pass + 1 }

	// JoinLast — 2 parts use lastSep only.
	if strings.JoinLast(new(2) []string { "a", "b" }, ", ", " and ") == "a and b" { pass = pass + 1 }

	// JoinLast — single part.
	if strings.JoinLast(new(1) []string { "only" }, ", ", " and ") == "only" { pass = pass + 1 }

	// JoinLast — empty input.
	if strings.JoinLast(new(0) []string {}, ", ", " and ") == "" { pass = pass + 1 }

	// JoinLast — 4-part list.
	if strings.JoinLast(new(4) []string { "red", "green", "blue", "yellow" }, ", ", ", or ") == "red, green, blue, or yellow" { pass = pass + 1 }

	// JoinLast — same sep both ways behaves like Join.
	if strings.JoinLast(new(3) []string { "a", "b", "c" }, ", ", ", ") == strings.Join(new(3) []string { "a", "b", "c" }, ", ") { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 13 { ret 42 }
	ret 0
}
