package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Basic: [1,2,3,4,5,6,7,8,9,10]; Q1=3, Q3=8, IQR=5, fence=7
	// lo = 3-7 = -4; hi = 8+7 = 15
	var s1 []int = new(10) []int {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
	lo1, hi1 := slices.OutlierBoundsInt(s1)
	if lo1 == -4 { pass = pass + 1 }
	if hi1 == 15 { pass = pass + 1 }
	// Nothing inside is an outlier.
	if !slices.IsOutlierInt(s1, 5) { pass = pass + 1 }
	if !slices.IsOutlierInt(s1, 10) { pass = pass + 1 }
	// Below lo or above hi → outlier.
	if slices.IsOutlierInt(s1, -10) { pass = pass + 1 }
	if slices.IsOutlierInt(s1, 100) { pass = pass + 1 }

	// Empty: bounds (0,0), nothing is outlier.
	var s2 []int = new(0) []int {}
	lo2, hi2 := slices.OutlierBoundsInt(s2)
	if lo2 == 0 { pass = pass + 1 }
	if hi2 == 0 { pass = pass + 1 }
	if !slices.IsOutlierInt(s2, 50) { pass = pass + 1 }

	// Single element: bounds (0,0).
	var s3 []int = new(1) []int {42}
	lo3, hi3 := slices.OutlierBoundsInt(s3)
	if lo3 == 0 { pass = pass + 1 }
	if hi3 == 0 { pass = pass + 1 }

	// Heavily skewed: [1,1,1,1,1,1,1,1,1,1000]
	// Q1=1, Q3=1, IQR=0, fence=0; lo=1, hi=1; 1000 is outlier.
	var s4 []int = new(10) []int {1, 1, 1, 1, 1, 1, 1, 1, 1, 1000}
	if slices.IsOutlierInt(s4, 1000) { pass = pass + 1 }
	if !slices.IsOutlierInt(s4, 1) { pass = pass + 1 }

	// Negative values.
	var s5 []int = new(10) []int {-5, -4, -3, -2, -1, 0, 1, 2, 3, 4}
	// Q1 = -3, Q3 = 2, IQR = 5, fence = 7
	// lo = -10, hi = 9
	lo5, hi5 := slices.OutlierBoundsInt(s5)
	if lo5 == -10 { pass = pass + 1 }
	if hi5 == 9 { pass = pass + 1 }
	if slices.IsOutlierInt(s5, -50) { pass = pass + 1 }
	if !slices.IsOutlierInt(s5, 0) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 17 { ret 42 }
	ret 0
}
