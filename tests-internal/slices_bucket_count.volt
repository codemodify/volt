package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty s → all-zero buckets.
	var e []int = new(0) []int {}
	var r1 []int = slices.BucketCountInt(e, 0, 99, 10)
	if len(r1) == 10 { pass = pass + 1 }
	if r1[0] == 0 { pass = pass + 1 }
	if r1[9] == 0 { pass = pass + 1 }

	// n <= 0 → empty.
	var s1 []int = new(3) []int { 1, 2, 3 }
	var r2 []int = slices.BucketCountInt(s1, 0, 10, 0)
	if len(r2) == 0 { pass = pass + 1 }
	var s1b []int = new(3) []int { 1, 2, 3 }
	var r3 []int = slices.BucketCountInt(s1b, 0, 10, -5)
	if len(r3) == 0 { pass = pass + 1 }

	// Degenerate range → empty.
	var s2 []int = new(3) []int { 1, 2, 3 }
	var r4 []int = slices.BucketCountInt(s2, 10, 5, 5)
	if len(r4) == 0 { pass = pass + 1 }

	// Single bucket.
	var s3 []int = new(5) []int { 0, 1, 2, 3, 4 }
	var r5 []int = slices.BucketCountInt(s3, 0, 4, 1)
	if len(r5) == 1 { pass = pass + 1 }
	if r5[0] == 5 { pass = pass + 1 }

	// Uniform distribution.
	var s4 []int = new(10) []int { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 }
	var r6 []int = slices.BucketCountInt(s4, 0, 9, 10)
	if len(r6) == 10 { pass = pass + 1 }
	if r6[0] == 1 { pass = pass + 1 }
	if r6[9] == 1 { pass = pass + 1 }

	// Two-bucket split.
	var s5 []int = new(6) []int { 0, 0, 0, 5, 5, 5 }
	var r7 []int = slices.BucketCountInt(s5, 0, 5, 2)
	// width = 6, n = 2, bucket width = 3. 0,0,0 → idx 0; 5 → idx 5*2/6 = 1.
	if r7[0] == 3 { pass = pass + 1 }
	if r7[1] == 3 { pass = pass + 1 }

	// hi maps into last bucket.
	var s6 []int = new(1) []int { 10 }
	var r8 []int = slices.BucketCountInt(s6, 0, 10, 5)
	if r8[4] == 1 { pass = pass + 1 }

	// Out-of-range silently dropped.
	var s7 []int = new(4) []int { -5, 0, 5, 99 }
	var r9 []int = slices.BucketCountInt(s7, 0, 5, 2)
	// Only 0 and 5 fit; counts should sum to 2.
	if r9[0] + r9[1] == 2 { pass = pass + 1 }

	// Cross-property: sum of buckets equals count of in-range elements.
	var s8 []int = new(6) []int { 0, 2, 4, 6, 8, 10 }
	var s8b []int = new(6) []int { 0, 2, 4, 6, 8, 10 }
	var r10 []int = slices.BucketCountInt(s8, 0, 10, 5)
	var total int = 0
	for i := 0; i < 5; i++ { total = total + r10[i] }
	var inRange int = slices.CountInRangeInt(s8b, 0, 10)
	if total == inRange { pass = pass + 1 }

	// Doesn't mutate s.
	var s9 []int = new(3) []int { 1, 2, 3 }
	var _r []int = slices.BucketCountInt(s9, 0, 10, 5)
	if s9[0] == 1 { pass = pass + 1 }
	if s9[1] == 2 { pass = pass + 1 }
	if s9[2] == 3 { pass = pass + 1 }

	// Score-distribution use case.
	var scores []int = new(10) []int { 5, 22, 47, 65, 78, 81, 88, 92, 95, 99 }
	var dist []int = slices.BucketCountInt(scores, 0, 99, 10)
	// 10 buckets of width 10. 5 → bucket 0; 22 → 2; 47 → 4; 65 → 6; 78,81,88 → 7,8,8;
	// 92,95,99 → 9. Should have 10 entries summing to 10.
	if len(dist) == 10 { pass = pass + 1 }
	var sumDist int = 0
	for i := 0; i < 10; i++ { sumDist = sumDist + dist[i] }
	if sumDist == 10 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 21 { ret 42 }
	ret 0
}
