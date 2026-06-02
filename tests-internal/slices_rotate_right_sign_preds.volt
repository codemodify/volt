package main
import "log"
import "slices"

// Positive test: slices.RotateRightInt + RotateRightString + IsAllPositiveInt + IsAllNegativeInt.

fun main() int {
	var pass int = 0

	// RotateRightInt — by 1.
	var a []int = new(5) []int{1, 2, 3, 4, 5}
	var ra []int = slices.RotateRightInt(a, 1)
	// {5, 1, 2, 3, 4}
	if ra[0] == 5 { pass = pass + 1 }
	if ra[1] == 1 { pass = pass + 1 }
	if ra[2] == 2 { pass = pass + 1 }
	if ra[4] == 4 { pass = pass + 1 }

	// RotateRightInt — by 2.
	var rb []int = slices.RotateRightInt(a, 2)
	// {4, 5, 1, 2, 3}
	if rb[0] == 4 { pass = pass + 1 }
	if rb[1] == 5 { pass = pass + 1 }
	if rb[2] == 1 { pass = pass + 1 }
	if rb[4] == 3 { pass = pass + 1 }

	// k=0 → identity.
	var rc []int = slices.RotateRightInt(a, 0)
	if rc[0] == 1 { pass = pass + 1 }
	if rc[4] == 5 { pass = pass + 1 }

	// k=n → identity.
	var rd []int = slices.RotateRightInt(a, 5)
	if rd[0] == 1 { pass = pass + 1 }

	// Negative k = left rotate.
	var re []int = slices.RotateRightInt(a, -1)
	// {2, 3, 4, 5, 1}
	if re[0] == 2 { pass = pass + 1 }
	if re[4] == 1 { pass = pass + 1 }

	// Empty.
	var em []int = new(0) []int{}
	if len(slices.RotateRightInt(em, 3)) == 0 { pass = pass + 1 }

	// RotateRightString.
	var s []string = new(4) []string{"a", "b", "c", "d"}
	var rs []string = slices.RotateRightString(s, 1)
	if rs[0] == "d" { pass = pass + 1 }
	if rs[1] == "a" { pass = pass + 1 }

	// IsAllPositiveInt.
	if slices.IsAllPositiveInt(new(3) []int{1, 2, 3}) { pass = pass + 1 }
	if !slices.IsAllPositiveInt(new(3) []int{1, 0, 3}) { pass = pass + 1 }   // 0 not positive
	if !slices.IsAllPositiveInt(new(3) []int{1, -1, 3}) { pass = pass + 1 }
	if slices.IsAllPositiveInt(new(0) []int{}) { pass = pass + 1 }   // vacuous

	// IsAllNegativeInt.
	if slices.IsAllNegativeInt(new(3) []int{-1, -2, -3}) { pass = pass + 1 }
	if !slices.IsAllNegativeInt(new(3) []int{-1, 0, -3}) { pass = pass + 1 }   // 0 not negative
	if !slices.IsAllNegativeInt(new(3) []int{-1, 5, -3}) { pass = pass + 1 }
	if slices.IsAllNegativeInt(new(0) []int{}) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 24 { ret 42 }
	ret 0
}
