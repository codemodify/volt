package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Basic: triangle wave 1,2,4,8,4,2,1 with max=8, ramp=".:-=+*#%@" (9 chars).
	// Indices = v*8/8: 1*8/8=1(':'), 2*8/8=2('-'), 4*8/8=4('+'), 8*8/8=8('@'), 4=+, 2=-, 1=:
	var v1 []int = new(7) []int {1, 2, 4, 8, 4, 2, 1}
	if strings.Sparkline(v1) == ":-+@+-:" { pass = pass + 1 }

	// Empty input.
	var v2 []int = new(0) []int {}
	if strings.Sparkline(v2) == "" { pass = pass + 1 }

	// All zeros → all "." (lowest ramp char).
	var v3 []int = new(5) []int {0, 0, 0, 0, 0}
	if strings.Sparkline(v3) == "....." { pass = pass + 1 }

	// Single value → single char.
	var v4 []int = new(1) []int {42}
	// max=42, only value=42 → idx = 42*8/42 = 8 → '@'
	if strings.Sparkline(v4) == "@" { pass = pass + 1 }

	// Negative clamps to 0.
	var v5 []int = new(3) []int {-5, 0, 10}
	// max=10, -5→0(.), 0→0(.), 10→8(@)
	if strings.Sparkline(v5) == "..@" { pass = pass + 1 }

	// Monotonically increasing 0..8 → maps to 0..8 ramp indices exactly.
	var v6 []int = new(9) []int {0, 1, 2, 3, 4, 5, 6, 7, 8}
	// max=8: idx = v*8/8 = v → ".:-=+*#%@"
	if strings.Sparkline(v6) == ".:-=+*#%@" { pass = pass + 1 }

	// All same non-zero values → all max char ('@').
	var v7 []int = new(4) []int {5, 5, 5, 5}
	// max=5, each → 5*8/5=8('@')
	if strings.Sparkline(v7) == "@@@@" { pass = pass + 1 }

	// Single dominant outlier flattens the others.
	var v8 []int = new(4) []int {1, 1, 1, 100}
	// max=100, 1*8/100=0('.'), 100→8('@')
	if strings.Sparkline(v8) == "...@" { pass = pass + 1 }

	// Mid-range values.
	var v9 []int = new(5) []int {2, 4, 6, 8, 10}
	// max=10: 2*8/10=1(':'), 4*8/10=3('='), 6*8/10=4('+'), 8*8/10=6('#'), 10*8/10=8('@')
	if strings.Sparkline(v9) == ":=+#@" { pass = pass + 1 }

	// Length matches input length.
	var vA []int = new(20) []int {}
	for i := 0; i < 20; i++ { vA[i] = i + 1 }
	var rA string = strings.Sparkline(vA)
	if len(rA) == 20 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 10 { ret 42 }
	ret 0
}
