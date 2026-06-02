package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty → 0.
	var e []int = new(0) []int {}
	if slices.PercentileInt(e, 50) == 0 { pass = pass + 1 }

	// Single element → that element regardless of p.
	var s1 []int = new(1) []int { 42 }
	if slices.PercentileInt(s1, 0) == 42 { pass = pass + 1 }
	var s1b []int = new(1) []int { 42 }
	if slices.PercentileInt(s1b, 50) == 42 { pass = pass + 1 }
	var s1c []int = new(1) []int { 42 }
	if slices.PercentileInt(s1c, 100) == 42 { pass = pass + 1 }

	// Two elements.
	var s2 []int = new(2) []int { 10, 20 }
	if slices.PercentileInt(s2, 0) == 10 { pass = pass + 1 }
	var s2b []int = new(2) []int { 10, 20 }
	if slices.PercentileInt(s2b, 50) == 10 { pass = pass + 1 }
	var s2c []int = new(2) []int { 10, 20 }
	if slices.PercentileInt(s2c, 100) == 20 { pass = pass + 1 }

	// Already-sorted, n=10 (1..10).
	var s3 []int = new(10) []int { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
	// p=10 → rank=1 → 1
	if slices.PercentileInt(s3, 10) == 1 { pass = pass + 1 }
	var s3b []int = new(10) []int { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
	// p=50 → rank=5 → 5
	if slices.PercentileInt(s3b, 50) == 5 { pass = pass + 1 }
	var s3c []int = new(10) []int { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
	// p=90 → rank=9 → 9
	if slices.PercentileInt(s3c, 90) == 9 { pass = pass + 1 }
	var s3d []int = new(10) []int { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
	// p=95 → rank=ceil(9.5)=10 → 10
	if slices.PercentileInt(s3d, 95) == 10 { pass = pass + 1 }
	var s3e []int = new(10) []int { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
	// p=99 → rank=ceil(9.9)=10 → 10
	if slices.PercentileInt(s3e, 99) == 10 { pass = pass + 1 }
	var s3f []int = new(10) []int { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
	// p=100 → max
	if slices.PercentileInt(s3f, 100) == 10 { pass = pass + 1 }
	var s3g []int = new(10) []int { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
	// p=0 → min
	if slices.PercentileInt(s3g, 0) == 1 { pass = pass + 1 }

	// Unsorted input — should still work (sorts internally).
	var s4 []int = new(5) []int { 50, 10, 30, 20, 40 }
	if slices.PercentileInt(s4, 50) == 30 { pass = pass + 1 }
	var s4b []int = new(5) []int { 50, 10, 30, 20, 40 }
	if slices.PercentileInt(s4b, 0) == 10 { pass = pass + 1 }
	var s4c []int = new(5) []int { 50, 10, 30, 20, 40 }
	if slices.PercentileInt(s4c, 100) == 50 { pass = pass + 1 }

	// Doesn't mutate s.
	var s5 []int = new(4) []int { 4, 1, 3, 2 }
	var _ int = slices.PercentileInt(s5, 50)
	if s5[0] == 4 { pass = pass + 1 }
	if s5[1] == 1 { pass = pass + 1 }
	if s5[2] == 3 { pass = pass + 1 }
	if s5[3] == 2 { pass = pass + 1 }

	// p out of [0,100] clamps.
	var s6 []int = new(5) []int { 1, 2, 3, 4, 5 }
	if slices.PercentileInt(s6, -10) == 1 { pass = pass + 1 }
	var s6b []int = new(5) []int { 1, 2, 3, 4, 5 }
	if slices.PercentileInt(s6b, 200) == 5 { pass = pass + 1 }

	// Latency p50/p95/p99 use case (e.g. 100 sample ms latencies 1..100).
	var lat []int = new(100) []int {}
	for i := 0; i < 100; i++ { lat[i] = i + 1 }
	var p50 int = slices.PercentileInt(lat, 50)
	if p50 == 50 { pass = pass + 1 }
	var lat2 []int = new(100) []int {}
	for i := 0; i < 100; i++ { lat2[i] = i + 1 }
	var p95 int = slices.PercentileInt(lat2, 95)
	if p95 == 95 { pass = pass + 1 }
	var lat3 []int = new(100) []int {}
	for i := 0; i < 100; i++ { lat3[i] = i + 1 }
	var p99 int = slices.PercentileInt(lat3, 99)
	if p99 == 99 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 26 { ret 42 }
	ret 0
}
