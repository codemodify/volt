package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Empty.
	var e []string = new(0) []string {}
	if strings.BulletList(e, "-") == "" { pass = pass + 1 }
	var e2 []string = new(0) []string {}
	if strings.NumberedList(e2) == "" { pass = pass + 1 }

	// Single item.
	var s1 []string = new(1) []string { "hello" }
	if strings.BulletList(s1, "-") == "- hello" { pass = pass + 1 }
	var s1b []string = new(1) []string { "hello" }
	if strings.NumberedList(s1b) == "1. hello" { pass = pass + 1 }

	// Multi-item.
	var s2 []string = new(3) []string { "alpha", "bravo", "charlie" }
	if strings.BulletList(s2, "-") == "- alpha\n- bravo\n- charlie" { pass = pass + 1 }
	var s2b []string = new(3) []string { "alpha", "bravo", "charlie" }
	if strings.NumberedList(s2b) == "1. alpha\n2. bravo\n3. charlie" { pass = pass + 1 }

	// Alt marker.
	var s3 []string = new(3) []string { "a", "b", "c" }
	if strings.BulletList(s3, "*") == "* a\n* b\n* c" { pass = pass + 1 }
	var s3b []string = new(2) []string { "x", "y" }
	if strings.BulletList(s3b, "→") == "→ x\n→ y" { pass = pass + 1 }

	// Empty marker → naked list.
	var s4 []string = new(3) []string { "a", "b", "c" }
	if strings.BulletList(s4, "") == "a\nb\nc" { pass = pass + 1 }

	// Empty strings in list.
	var s5 []string = new(3) []string { "first", "", "third" }
	if strings.BulletList(s5, "-") == "- first\n- \n- third" { pass = pass + 1 }

	// Numbered, 10+ items.
	var s6 []string = new(11) []string { "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k" }
	var nl string = strings.NumberedList(s6)
	if strings.Contains(nl, "10. j") { pass = pass + 1 }
	if strings.Contains(nl, "11. k") { pass = pass + 1 }
	if strings.HasPrefix(nl, "1. a") { pass = pass + 1 }

	// CLI help-output use case.
	var commands []string = new(3) []string { "init", "build", "run" }
	var menu string = strings.BulletList(commands, "•")
	if menu == "• init\n• build\n• run" { pass = pass + 1 }

	// Recipe-step use case.
	var steps []string = new(3) []string { "Heat oil", "Add onions", "Stir 5 min" }
	var recipe string = strings.NumberedList(steps)
	if recipe == "1. Heat oil\n2. Add onions\n3. Stir 5 min" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 15 { ret 42 }
	ret 0
}
