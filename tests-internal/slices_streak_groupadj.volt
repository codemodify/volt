package main
import "log"
import "slices"

// Positive test: slices.LongestStreakInt + LongestStreakString + GroupAdjacentInt.

fun isPositive(x int) bool { if x > 0 { ret true }; ret false }
fun isEven(x int) bool { if x % 2 == 0 { ret true }; ret false }
fun nonEmpty(s string) bool { if len(s) > 0 { ret true }; ret false }

fun main() int {
	var pass int = 0

	// LongestStreakInt — positives.
	var a []int = new(7) []int{1, 2, -1, 3, 4, 5, -2}
	if slices.LongestStreakInt(a, isPositive) == 3 { pass = pass + 1 }

	// All match.
	var b []int = new(4) []int{1, 2, 3, 4}
	if slices.LongestStreakInt(b, isPositive) == 4 { pass = pass + 1 }

	// None match.
	var c []int = new(3) []int{-1, -2, -3}
	if slices.LongestStreakInt(c, isPositive) == 0 { pass = pass + 1 }

	// Empty.
	var e []int = new(0) []int{}
	if slices.LongestStreakInt(e, isPositive) == 0 { pass = pass + 1 }

	// Even streak.
	var d []int = new(6) []int{2, 4, 1, 6, 8, 10}
	if slices.LongestStreakInt(d, isEven) == 3 { pass = pass + 1 }

	// LongestStreakString.
	var s []string = new(5) []string{"hi", "yo", "ok", "", ""}
	if slices.LongestStreakString(s, nonEmpty) == 3 { pass = pass + 1 }

	// GroupAdjacentInt — basic.
	var g []int = new(7) []int{1, 1, 2, 3, 3, 3, 1}
	var groups [][]int = slices.GroupAdjacentInt(g)
	if len(groups) == 4 { pass = pass + 1 }
	if len(groups[0]) == 2 { pass = pass + 1 }
	if groups[0][0] == 1 { pass = pass + 1 }
	if len(groups[1]) == 1 { pass = pass + 1 }
	if groups[1][0] == 2 { pass = pass + 1 }
	if len(groups[2]) == 3 { pass = pass + 1 }
	if groups[2][0] == 3 { pass = pass + 1 }
	if len(groups[3]) == 1 { pass = pass + 1 }
	if groups[3][0] == 1 { pass = pass + 1 }

	// All distinct → n single-element groups.
	var dd []int = new(4) []int{1, 2, 3, 4}
	var ddg [][]int = slices.GroupAdjacentInt(dd)
	if len(ddg) == 4 { pass = pass + 1 }
	if len(ddg[0]) == 1 { pass = pass + 1 }

	// All same → single group.
	var ss []int = new(5) []int{7, 7, 7, 7, 7}
	var ssg [][]int = slices.GroupAdjacentInt(ss)
	if len(ssg) == 1 { pass = pass + 1 }
	if len(ssg[0]) == 5 { pass = pass + 1 }

	// Single element.
	var sg []int = new(1) []int{42}
	var sgg [][]int = slices.GroupAdjacentInt(sg)
	if len(sgg) == 1 { pass = pass + 1 }
	if sgg[0][0] == 42 { pass = pass + 1 }

	// Empty → empty outer.
	var em []int = new(0) []int{}
	var emg [][]int = slices.GroupAdjacentInt(em)
	if len(emg) == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 22 { ret 42 }
	ret 0
}
