package main
import "log"
import "slices"

// Positive test: slices.IsSetInt + slices.IsSetString.

fun main() int {
	var pass int = 0

	// IsSetInt all distinct.
	if slices.IsSetInt(new(5) []int{1, 2, 3, 4, 5}) { pass = pass + 1 }
	if slices.IsSetInt(new(3) []int{10, 20, 30}) { pass = pass + 1 }
	if slices.IsSetInt(new(3) []int{-1, 0, 1}) { pass = pass + 1 }   // negatives + 0

	// IsSetInt with duplicates.
	if !slices.IsSetInt(new(5) []int{1, 2, 3, 4, 1}) { pass = pass + 1 }
	if !slices.IsSetInt(new(2) []int{5, 5}) { pass = pass + 1 }
	if !slices.IsSetInt(new(4) []int{0, 1, 0, 2}) { pass = pass + 1 }

	// Single element.
	if slices.IsSetInt(new(1) []int{42}) { pass = pass + 1 }

	// Empty.
	if slices.IsSetInt(new(0) []int{}) { pass = pass + 1 }

	// IsSetString all distinct.
	if slices.IsSetString(new(3) []string{"a", "b", "c"}) { pass = pass + 1 }
	if slices.IsSetString(new(4) []string{"alpha", "beta", "gamma", "delta"}) { pass = pass + 1 }
	if slices.IsSetString(new(2) []string{"", "x"}) { pass = pass + 1 }   // empty + non-empty

	// IsSetString with duplicates.
	if !slices.IsSetString(new(3) []string{"a", "b", "a"}) { pass = pass + 1 }
	if !slices.IsSetString(new(3) []string{"", "", "x"}) { pass = pass + 1 }   // empty strings count
	if !slices.IsSetString(new(2) []string{"x", "x"}) { pass = pass + 1 }

	// Single string.
	if slices.IsSetString(new(1) []string{"only"}) { pass = pass + 1 }

	// Empty string slice.
	if slices.IsSetString(new(0) []string{}) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
