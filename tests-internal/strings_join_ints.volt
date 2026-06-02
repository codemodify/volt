package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// JoinInts — CSV-style.
	if strings.JoinInts(new(4) []int { 1, 2, 3, 4 }, ",") == "1,2,3,4" { pass = pass + 1 }

	// JoinInts — pipe separator.
	if strings.JoinInts(new(3) []int { 10, 20, 30 }, "|") == "10|20|30" { pass = pass + 1 }

	// JoinInts — single element.
	if strings.JoinInts(new(1) []int { 42 }, ",") == "42" { pass = pass + 1 }

	// JoinInts — empty.
	if strings.JoinInts(new(0) []int {}, ",") == "" { pass = pass + 1 }

	// JoinInts — negatives.
	if strings.JoinInts(new(3) []int { -1, 0, 1 }, " ") == "-1 0 1" { pass = pass + 1 }

	// JoinInts — large values.
	if strings.JoinInts(new(2) []int { 1000000, 999999 }, "/") == "1000000/999999" { pass = pass + 1 }

	// JoinInts — empty separator.
	if strings.JoinInts(new(3) []int { 1, 2, 3 }, "") == "123" { pass = pass + 1 }

	// JoinIntsBracket — Python-style.
	if strings.JoinIntsBracket(new(3) []int { 1, 2, 3 }, ", ", "[", "]") == "[1, 2, 3]" { pass = pass + 1 }

	// JoinIntsBracket — set notation.
	if strings.JoinIntsBracket(new(3) []int { 1, 2, 3 }, "; ", "{", "}") == "{1; 2; 3}" { pass = pass + 1 }

	// JoinIntsBracket — empty contents.
	if strings.JoinIntsBracket(new(0) []int {}, ", ", "[", "]") == "[]" { pass = pass + 1 }

	// JoinIntsBracket — single element.
	if strings.JoinIntsBracket(new(1) []int { 99 }, ",", "<", ">") == "<99>" { pass = pass + 1 }

	// JoinIntsBracket — empty brackets.
	if strings.JoinIntsBracket(new(2) []int { 1, 2 }, ",", "", "") == "1,2" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 12 { ret 42 }
	ret 0
}
