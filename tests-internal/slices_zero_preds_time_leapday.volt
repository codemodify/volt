package main
import "log"
import "slices"
import "time"

// Positive test: slices.IsAllZeroInt + slices.AnyZeroInt + (t Time).IsLeapDay.

fun main() int {
	var pass int = 0

	// IsAllZeroInt.
	if slices.IsAllZeroInt(new(3) []int{0, 0, 0}) { pass = pass + 1 }
	if slices.IsAllZeroInt(new(0) []int{}) { pass = pass + 1 }   // vacuous
	if slices.IsAllZeroInt(new(1) []int{0}) { pass = pass + 1 }
	if !slices.IsAllZeroInt(new(3) []int{0, 1, 0}) { pass = pass + 1 }
	if !slices.IsAllZeroInt(new(3) []int{1, 2, 3}) { pass = pass + 1 }
	if !slices.IsAllZeroInt(new(1) []int{-1}) { pass = pass + 1 }

	// AnyZeroInt.
	if slices.AnyZeroInt(new(3) []int{1, 0, 3}) { pass = pass + 1 }
	if slices.AnyZeroInt(new(3) []int{0, 1, 2}) { pass = pass + 1 }
	if slices.AnyZeroInt(new(3) []int{1, 2, 0}) { pass = pass + 1 }
	if slices.AnyZeroInt(new(1) []int{0}) { pass = pass + 1 }
	if !slices.AnyZeroInt(new(3) []int{1, 2, 3}) { pass = pass + 1 }
	if !slices.AnyZeroInt(new(0) []int{}) { pass = pass + 1 }

	// IsLeapDay — Feb 29 in leap year.
	if time.Date(2024, 2, 29, 0, 0, 0, 0).IsLeapDay() { pass = pass + 1 }
	if time.Date(2020, 2, 29, 0, 0, 0, 0).IsLeapDay() { pass = pass + 1 }
	if time.Date(2000, 2, 29, 0, 0, 0, 0).IsLeapDay() { pass = pass + 1 }

	// Not Feb 29.
	if !time.Date(2024, 2, 28, 0, 0, 0, 0).IsLeapDay() { pass = pass + 1 }
	if !time.Date(2023, 3, 1, 0, 0, 0, 0).IsLeapDay() { pass = pass + 1 }   // 2023 Feb 29 doesn't exist; March 1
	if !time.Date(2024, 3, 29, 0, 0, 0, 0).IsLeapDay() { pass = pass + 1 }   // not February
	if !time.Date(2024, 1, 29, 0, 0, 0, 0).IsLeapDay() { pass = pass + 1 }   // not February
	if !time.Date(2024, 12, 29, 0, 0, 0, 0).IsLeapDay() { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 20 { ret 42 }
	ret 0
}
