package main
import "log"
import "slices"

fun isPositive(x int) bool { ret x > 0 }
fun isSmall(x int) bool { ret x < 5 }
fun alwaysTrue(x int) bool { ret true }
fun alwaysFalse(x int) bool { ret false }

fun main() int {
	var pass int = 0

	// TakeWhileInt — basic.
	var t1 []int = slices.TakeWhileInt(new(6) []int { 1, 2, 3, -1, 4, 5 }, isPositive)
	if len(t1) == 3 { pass = pass + 1 }
	if t1[0] == 1 { pass = pass + 1 }
	if t1[2] == 3 { pass = pass + 1 }

	// TakeWhileInt — pred fails on first.
	var t2 []int = slices.TakeWhileInt(new(3) []int { -1, 1, 2 }, isPositive)
	if len(t2) == 0 { pass = pass + 1 }

	// TakeWhileInt — pred true throughout.
	var t3 []int = slices.TakeWhileInt(new(3) []int { 1, 2, 3 }, isPositive)
	if len(t3) == 3 { pass = pass + 1 }

	// TakeWhileInt — empty input.
	var t4 []int = slices.TakeWhileInt(new(0) []int {}, isPositive)
	if len(t4) == 0 { pass = pass + 1 }

	// TakeWhileInt — small filter.
	var t5 []int = slices.TakeWhileInt(new(5) []int { 1, 2, 3, 5, 4 }, isSmall)
	if len(t5) == 3 { pass = pass + 1 }
	if t5[2] == 3 { pass = pass + 1 }

	// TakeWhileInt — alwaysTrue.
	var t6 []int = slices.TakeWhileInt(new(4) []int { 1, 2, 3, 4 }, alwaysTrue)
	if len(t6) == 4 { pass = pass + 1 }

	// TakeWhileInt — alwaysFalse.
	var t7 []int = slices.TakeWhileInt(new(4) []int { 1, 2, 3, 4 }, alwaysFalse)
	if len(t7) == 0 { pass = pass + 1 }

	// DropWhileInt — basic.
	var d1 []int = slices.DropWhileInt(new(6) []int { 1, 2, 3, -1, 4, 5 }, isPositive)
	if len(d1) == 3 { pass = pass + 1 }
	if d1[0] == -1 { pass = pass + 1 }
	if d1[2] == 5 { pass = pass + 1 }

	// DropWhileInt — pred fails on first → no drop.
	var d2 []int = slices.DropWhileInt(new(3) []int { -1, 1, 2 }, isPositive)
	if len(d2) == 3 { pass = pass + 1 }
	if d2[0] == -1 { pass = pass + 1 }

	// DropWhileInt — pred true throughout → empty.
	var d3 []int = slices.DropWhileInt(new(3) []int { 1, 2, 3 }, isPositive)
	if len(d3) == 0 { pass = pass + 1 }

	// DropWhileInt — empty.
	var d4 []int = slices.DropWhileInt(new(0) []int {}, isPositive)
	if len(d4) == 0 { pass = pass + 1 }

	// Partition identity: len(Take) + len(Drop) == len(input).
	var sample []int = new(6) []int { 1, 2, 3, -1, 4, 5 }
	if len(slices.TakeWhileInt(sample, isPositive)) + len(slices.DropWhileInt(sample, isPositive)) == 6 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
