package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty → 0.
	var e []int = new(0) []int {}
	if slices.KthSmallestInt(e, 0) == 0 { pass = pass + 1 }
	var e2 []int = new(0) []int {}
	if slices.KthLargestInt(e2, 0) == 0 { pass = pass + 1 }

	// Single element.
	var s1 []int = new(1) []int { 42 }
	if slices.KthSmallestInt(s1, 0) == 42 { pass = pass + 1 }
	var s1b []int = new(1) []int { 42 }
	if slices.KthLargestInt(s1b, 0) == 42 { pass = pass + 1 }

	// Sorted ascending.
	var s2 []int = new(5) []int { 1, 2, 3, 4, 5 }
	if slices.KthSmallestInt(s2, 0) == 1 { pass = pass + 1 }
	var s2b []int = new(5) []int { 1, 2, 3, 4, 5 }
	if slices.KthSmallestInt(s2b, 2) == 3 { pass = pass + 1 }
	var s2c []int = new(5) []int { 1, 2, 3, 4, 5 }
	if slices.KthSmallestInt(s2c, 4) == 5 { pass = pass + 1 }

	// k=0 is max for KthLargest.
	var s3 []int = new(5) []int { 1, 2, 3, 4, 5 }
	if slices.KthLargestInt(s3, 0) == 5 { pass = pass + 1 }
	var s3b []int = new(5) []int { 1, 2, 3, 4, 5 }
	if slices.KthLargestInt(s3b, 1) == 4 { pass = pass + 1 }   // silver
	var s3c []int = new(5) []int { 1, 2, 3, 4, 5 }
	if slices.KthLargestInt(s3c, 2) == 3 { pass = pass + 1 }   // bronze
	var s3d []int = new(5) []int { 1, 2, 3, 4, 5 }
	if slices.KthLargestInt(s3d, 4) == 1 { pass = pass + 1 }

	// Unsorted input.
	var s4 []int = new(5) []int { 30, 10, 50, 20, 40 }
	if slices.KthSmallestInt(s4, 0) == 10 { pass = pass + 1 }
	var s4b []int = new(5) []int { 30, 10, 50, 20, 40 }
	if slices.KthSmallestInt(s4b, 2) == 30 { pass = pass + 1 }
	var s4c []int = new(5) []int { 30, 10, 50, 20, 40 }
	if slices.KthLargestInt(s4c, 0) == 50 { pass = pass + 1 }

	// Duplicates.
	var s5 []int = new(7) []int { 5, 3, 5, 1, 3, 5, 1 }
	// sorted: 1,1,3,3,5,5,5
	if slices.KthSmallestInt(s5, 0) == 1 { pass = pass + 1 }
	var s5b []int = new(7) []int { 5, 3, 5, 1, 3, 5, 1 }
	if slices.KthSmallestInt(s5b, 3) == 3 { pass = pass + 1 }
	var s5c []int = new(7) []int { 5, 3, 5, 1, 3, 5, 1 }
	if slices.KthSmallestInt(s5c, 6) == 5 { pass = pass + 1 }
	var s5d []int = new(7) []int { 5, 3, 5, 1, 3, 5, 1 }
	if slices.KthLargestInt(s5d, 0) == 5 { pass = pass + 1 }

	// k out of range → 0.
	var s6 []int = new(3) []int { 1, 2, 3 }
	if slices.KthSmallestInt(s6, -1) == 0 { pass = pass + 1 }
	var s6b []int = new(3) []int { 1, 2, 3 }
	if slices.KthSmallestInt(s6b, 5) == 0 { pass = pass + 1 }
	var s6c []int = new(3) []int { 1, 2, 3 }
	if slices.KthLargestInt(s6c, 99) == 0 { pass = pass + 1 }

	// Doesn't mutate s.
	var s7 []int = new(4) []int { 4, 1, 3, 2 }
	var _r int = slices.KthSmallestInt(s7, 1)
	if s7[0] == 4 { pass = pass + 1 }
	if s7[1] == 1 { pass = pass + 1 }
	if s7[2] == 3 { pass = pass + 1 }
	if s7[3] == 2 { pass = pass + 1 }

	// Cross-property: KthSmallest(s, k) == KthLargest(s, n-1-k).
	var s8 []int = new(5) []int { 30, 10, 50, 20, 40 }
	var s8b []int = new(5) []int { 30, 10, 50, 20, 40 }
	var sm int = slices.KthSmallestInt(s8, 1)
	var lg int = slices.KthLargestInt(s8b, 3)
	if sm == lg { pass = pass + 1 }

	// "Silver medal" use case.
	var scores []int = new(6) []int { 87, 92, 78, 95, 88, 91 }
	if slices.KthLargestInt(scores, 1) == 92 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 27 { ret 42 }
	ret 0
}
