package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// First slot wins.
	var a []int = new(3) []int { 5, 10, 15 }
	if slices.FirstNonZeroInt(a) == 5 { pass = pass + 1 }

	// Skip leading zeros.
	var b []int = new(4) []int { 0, 0, 7, 9 }
	if slices.FirstNonZeroInt(b) == 7 { pass = pass + 1 }

	// Only last is non-zero.
	var c []int = new(3) []int { 0, 0, 42 }
	if slices.FirstNonZeroInt(c) == 42 { pass = pass + 1 }

	// All zero → 0.
	var d []int = new(3) []int { 0, 0, 0 }
	if slices.FirstNonZeroInt(d) == 0 { pass = pass + 1 }

	// Empty slice → 0.
	var e []int = new(0) []int {}
	if slices.FirstNonZeroInt(e) == 0 { pass = pass + 1 }

	// Single non-zero.
	var f []int = new(1) []int { 99 }
	if slices.FirstNonZeroInt(f) == 99 { pass = pass + 1 }

	// Single zero.
	var g []int = new(1) []int { 0 }
	if slices.FirstNonZeroInt(g) == 0 { pass = pass + 1 }

	// Negative values are non-zero.
	var h []int = new(3) []int { 0, -5, 10 }
	if slices.FirstNonZeroInt(h) == -5 { pass = pass + 1 }

	// Config-fallback chain.
	var defaultPort int = 8080
	var envPort int = 0           // unset
	var cfgPort int = 9090
	var chain []int = new(3) []int { envPort, cfgPort, defaultPort }
	if slices.FirstNonZeroInt(chain) == 9090 { pass = pass + 1 }

	// All-zero chain falls to default.
	var emptyChain []int = new(3) []int { 0, 0, defaultPort }
	if slices.FirstNonZeroInt(emptyChain) == 8080 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 10 { ret 42 }
	ret 0
}
