package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty → both 0.
	var e []int = new(0) []int {}
	if slices.SpreadInt(e) == 0 { pass = pass + 1 }
	var e2 []int = new(0) []int {}
	if slices.IQRInt(e2) == 0 { pass = pass + 1 }

	// Single element → both 0.
	var s1 []int = new(1) []int { 42 }
	if slices.SpreadInt(s1) == 0 { pass = pass + 1 }
	var s1b []int = new(1) []int { 42 }
	if slices.IQRInt(s1b) == 0 { pass = pass + 1 }

	// Two elements: spread = diff, IQR = same (q3-q1 happens to == max-min).
	var s2 []int = new(2) []int { 5, 15 }
	if slices.SpreadInt(s2) == 10 { pass = pass + 1 }

	// Sorted 1..10, spread = 9.
	var s3 []int = new(10) []int { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
	if slices.SpreadInt(s3) == 9 { pass = pass + 1 }
	// IQR(1..10): q1 = P25 (rank=ceil(2.5)=3) = 3; q3 = P75 (rank=ceil(7.5)=8) = 8; IQR = 5.
	var s3b []int = new(10) []int { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
	if slices.IQRInt(s3b) == 5 { pass = pass + 1 }

	// All-same → both 0.
	var s4 []int = new(5) []int { 7, 7, 7, 7, 7 }
	if slices.SpreadInt(s4) == 0 { pass = pass + 1 }
	var s4b []int = new(5) []int { 7, 7, 7, 7, 7 }
	if slices.IQRInt(s4b) == 0 { pass = pass + 1 }

	// Outlier: spread is dominated by it, IQR mostly ignores it.
	var s5 []int = new(11) []int { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 1000 }
	if slices.SpreadInt(s5) == 999 { pass = pass + 1 }
	// IQR shouldn't explode the same way.
	var s5b []int = new(11) []int { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 1000 }
	var iqr int = slices.IQRInt(s5b)
	if iqr < 100 { pass = pass + 1 }   // robust statistic — way smaller than spread

	// Negative values.
	var s6 []int = new(5) []int { -5, -3, 0, 3, 5 }
	if slices.SpreadInt(s6) == 10 { pass = pass + 1 }

	// Unsorted input → both still correct (Spread is O(n) scan, IQR sorts a copy).
	var s7 []int = new(5) []int { 30, 10, 50, 20, 40 }
	if slices.SpreadInt(s7) == 40 { pass = pass + 1 }
	var s7b []int = new(5) []int { 30, 10, 50, 20, 40 }
	// q1 = P25 (rank=ceil(1.25)=2) on sorted [10,20,30,40,50] = 20
	// q3 = P75 (rank=ceil(3.75)=4) = 40
	// IQR = 20
	if slices.IQRInt(s7b) == 20 { pass = pass + 1 }

	// Doesn't mutate s.
	var s8 []int = new(4) []int { 4, 1, 3, 2 }
	var spA int = slices.SpreadInt(s8)
	var spB int = slices.IQRInt(s8)
	if spA >= 0 { pass = pass + 0 }
	if spB >= 0 { pass = pass + 0 }
	if s8[0] == 4 { pass = pass + 1 }
	if s8[1] == 1 { pass = pass + 1 }
	if s8[2] == 3 { pass = pass + 1 }
	if s8[3] == 2 { pass = pass + 1 }

	// Latency-like distribution (100 samples).
	var lat []int = new(100) []int {}
	for i := 0; i < 100; i++ { lat[i] = i + 1 }
	if slices.SpreadInt(lat) == 99 { pass = pass + 1 }
	var lat2 []int = new(100) []int {}
	for i := 0; i < 100; i++ { lat2[i] = i + 1 }
	// q1=25, q3=75 → IQR=50.
	if slices.IQRInt(lat2) == 50 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 20 { ret 42 }
	ret 0
}
