package main
import "log"
import "sort"

fun main() int {
	var pass int = 0

	// Empty.
	var e []string = new(0) []string {}
	e = sort.StringsAscCI(e)
	if len(e) == 0 { pass = pass + 1 }

	// Single.
	var s1 []string = new(1) []string { "hello" }
	s1 = sort.StringsAscCI(s1)
	if s1[0] == "hello" { pass = pass + 1 }

	// Basic CI ordering.
	var s2 []string = new(3) []string { "Bob", "alice", "Carol" }
	s2 = sort.StringsAscCI(s2)
	if s2[0] == "alice" { pass = pass + 1 }
	if s2[1] == "Bob" { pass = pass + 1 }
	if s2[2] == "Carol" { pass = pass + 1 }

	// All uppercase vs lowercase mix.
	var s3 []string = new(4) []string { "DOG", "cat", "Elephant", "bear" }
	s3 = sort.StringsAscCI(s3)
	if s3[0] == "bear" { pass = pass + 1 }
	if s3[1] == "cat" { pass = pass + 1 }
	if s3[2] == "DOG" { pass = pass + 1 }
	if s3[3] == "Elephant" { pass = pass + 1 }

	// Stable: equal-fold preserved.
	var s4 []string = new(4) []string { "Alice", "alice", "ALICE", "aLiCe" }
	s4 = sort.StringsAscCI(s4)
	if s4[0] == "Alice" { pass = pass + 1 }
	if s4[1] == "alice" { pass = pass + 1 }
	if s4[2] == "ALICE" { pass = pass + 1 }
	if s4[3] == "aLiCe" { pass = pass + 1 }

	// Descending.
	var s5 []string = new(3) []string { "alice", "Bob", "Carol" }
	s5 = sort.StringsDescCI(s5)
	if s5[0] == "Carol" { pass = pass + 1 }
	if s5[1] == "Bob" { pass = pass + 1 }
	if s5[2] == "alice" { pass = pass + 1 }

	// Shorter-prefix-is-less.
	var s6 []string = new(2) []string { "abc", "ab" }
	s6 = sort.StringsAscCI(s6)
	if s6[0] == "ab" { pass = pass + 1 }
	if s6[1] == "abc" { pass = pass + 1 }

	// Mixed empty strings.
	var s7 []string = new(3) []string { "x", "", "y" }
	s7 = sort.StringsAscCI(s7)
	if s7[0] == "" { pass = pass + 1 }

	// Non-letter bytes unchanged.
	var s8 []string = new(3) []string { "Z9", "a1", "B5" }
	s8 = sort.StringsAscCI(s8)
	if s8[0] == "a1" { pass = pass + 1 }
	if s8[1] == "B5" { pass = pass + 1 }
	if s8[2] == "Z9" { pass = pass + 1 }

	// User-list use case.
	var users []string = new(5) []string { "Zelda", "alice", "BOB", "carol", "Dan" }
	users = sort.StringsAscCI(users)
	if users[0] == "alice" { pass = pass + 1 }
	if users[1] == "BOB" { pass = pass + 1 }
	if users[2] == "carol" { pass = pass + 1 }
	if users[3] == "Dan" { pass = pass + 1 }
	if users[4] == "Zelda" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 27 { ret 42 }
	ret 0
}
