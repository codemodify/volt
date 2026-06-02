package main
import "log"
import "slices"

fun isEven(n int) bool { ret n % 2 == 0 }
fun isPositive(n int) bool { ret n > 0 }
fun nonEmpty(s string) bool { ret len(s) > 0 }

fun main() int {
	var pass int = 0

	// LinearRegressionInt basics: y = 2x + 0 exactly.
	var xs1 []int = new(5) []int {0, 1, 2, 3, 4}
	var ys1 []int = new(5) []int {0, 2, 4, 6, 8}
	var slope1 int = 0
	var intercept1 int = 0
	slope1, intercept1 = slices.LinearRegressionInt(xs1, ys1)
	// slope = 2 → scaled 2000; intercept = 0
	if slope1 == 2000 { pass = pass + 1 }
	if intercept1 == 0 { pass = pass + 1 }

	// y = 3x + 5
	var xs2 []int = new(4) []int {1, 2, 3, 4}
	var ys2 []int = new(4) []int {8, 11, 14, 17}
	var slope2 int = 0
	var intercept2 int = 0
	slope2, intercept2 = slices.LinearRegressionInt(xs2, ys2)
	if slope2 == 3000 { pass = pass + 1 }
	if intercept2 == 5000 { pass = pass + 1 }

	// Empty input.
	var xs3 []int = new(0) []int {}
	var ys3 []int = new(0) []int {}
	var slope3 int = 0
	var intercept3 int = 0
	slope3, intercept3 = slices.LinearRegressionInt(xs3, ys3)
	if slope3 == 0 { pass = pass + 1 }
	if intercept3 == 0 { pass = pass + 1 }

	// Mismatched lengths.
	var xs4 []int = new(2) []int {1, 2}
	var ys4 []int = new(3) []int {1, 2, 3}
	var slope4 int = 0
	var intercept4 int = 0
	slope4, intercept4 = slices.LinearRegressionInt(xs4, ys4)
	if slope4 == 0 { pass = pass + 1 }
	if intercept4 == 0 { pass = pass + 1 }

	// CountIfInt basics.
	var s1 []int = new(6) []int {1, 2, 3, 4, 5, 6}
	if slices.CountIfInt(s1, isEven) == 3 { pass = pass + 1 }
	if slices.CountIfInt(s1, isPositive) == 6 { pass = pass + 1 }

	// All-fail predicate.
	var s2 []int = new(3) []int {-1, -2, -3}
	if slices.CountIfInt(s2, isPositive) == 0 { pass = pass + 1 }

	// Empty input.
	var s3 []int = new(0) []int {}
	if slices.CountIfInt(s3, isEven) == 0 { pass = pass + 1 }

	// CountIfString.
	var ss []string = new(5) []string {"a", "", "b", "", "c"}
	if slices.CountIfString(ss, nonEmpty) == 3 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 13 { ret 42 }
	ret 0
}
