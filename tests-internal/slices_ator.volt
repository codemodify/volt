package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// AtOrInt — in-range.
	var a []int = new(4) []int { 10, 20, 30, 40 }
	if slices.AtOrInt(a, 0, 99) == 10 { pass = pass + 1 }
	if slices.AtOrInt(a, 2, 99) == 30 { pass = pass + 1 }
	if slices.AtOrInt(a, 3, 99) == 40 { pass = pass + 1 }

	// Out-of-range positive.
	if slices.AtOrInt(a, 4, 99) == 99 { pass = pass + 1 }
	if slices.AtOrInt(a, 100, 99) == 99 { pass = pass + 1 }

	// Negative index.
	if slices.AtOrInt(a, -1, 99) == 99 { pass = pass + 1 }
	if slices.AtOrInt(a, -100, 99) == 99 { pass = pass + 1 }

	// Empty slice.
	var empty []int = new(0) []int {}
	if slices.AtOrInt(empty, 0, 7) == 7 { pass = pass + 1 }
	if slices.AtOrInt(empty, -1, 7) == 7 { pass = pass + 1 }

	// AtOrString — in-range.
	var s []string = new(3) []string { "apple", "banana", "cherry" }
	if slices.AtOrString(s, 0, "?") == "apple" { pass = pass + 1 }
	if slices.AtOrString(s, 2, "?") == "cherry" { pass = pass + 1 }

	// Out-of-range.
	if slices.AtOrString(s, 3, "fallback") == "fallback" { pass = pass + 1 }
	if slices.AtOrString(s, -1, "neg") == "neg" { pass = pass + 1 }

	// Empty string slice.
	var es []string = new(0) []string {}
	if slices.AtOrString(es, 0, "x") == "x" { pass = pass + 1 }

	// Default can be any value — even "" or 0 — without disguising existence.
	if slices.AtOrInt(a, 0, 0) == 10 { pass = pass + 1 }
	if slices.AtOrInt(a, 99, 0) == 0 { pass = pass + 1 }

	// Use case: parse positional CLI args.
	var argv []string = new(2) []string { "/cmd", "input.txt" }
	var out string = slices.AtOrString(argv, 1, "default.txt")
	if out == "input.txt" { pass = pass + 1 }
	var out2 string = slices.AtOrString(argv, 2, "default.out")
	if out2 == "default.out" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
