package main
import "log"
import "math"

// Positive test: math.NumDivisors + math.Divisors.

fun main() int {
	var pass int = 0

	// NumDivisors — basic.
	if math.NumDivisors(1) == 1 { pass = pass + 1 }
	if math.NumDivisors(2) == 2 { pass = pass + 1 }    // 1, 2
	if math.NumDivisors(6) == 4 { pass = pass + 1 }    // 1,2,3,6
	if math.NumDivisors(12) == 6 { pass = pass + 1 }   // 1,2,3,4,6,12
	if math.NumDivisors(36) == 9 { pass = pass + 1 }   // 36 = 6^2 has 9 divisors
	if math.NumDivisors(100) == 9 { pass = pass + 1 }

	// NumDivisors — primes always have 2 divisors.
	if math.NumDivisors(7) == 2 { pass = pass + 1 }
	if math.NumDivisors(13) == 2 { pass = pass + 1 }
	if math.NumDivisors(97) == 2 { pass = pass + 1 }

	// NumDivisors — perfect squares have odd count.
	if math.NumDivisors(9) == 3 { pass = pass + 1 }    // 1,3,9
	if math.NumDivisors(25) == 3 { pass = pass + 1 }   // 1,5,25
	if math.NumDivisors(49) == 3 { pass = pass + 1 }   // 1,7,49

	// NumDivisors — domain edges.
	if math.NumDivisors(0) == 0 { pass = pass + 1 }
	if math.NumDivisors(-5) == 0 { pass = pass + 1 }

	// Divisors — sorted ascending.
	var d12 []int = math.Divisors(12)
	if len(d12) == 6 { pass = pass + 1 }
	if d12[0] == 1 { pass = pass + 1 }
	if d12[1] == 2 { pass = pass + 1 }
	if d12[2] == 3 { pass = pass + 1 }
	if d12[3] == 4 { pass = pass + 1 }
	if d12[4] == 6 { pass = pass + 1 }
	if d12[5] == 12 { pass = pass + 1 }

	// Divisors — square (odd count).
	var d36 []int = math.Divisors(36)
	if len(d36) == 9 { pass = pass + 1 }
	if d36[0] == 1 { pass = pass + 1 }
	if d36[4] == 6 { pass = pass + 1 }    // sqrt(36)
	if d36[8] == 36 { pass = pass + 1 }

	// Divisors — prime → {1, p}.
	var d7 []int = math.Divisors(7)
	if len(d7) == 2 { pass = pass + 1 }
	if d7[0] == 1 { pass = pass + 1 }
	if d7[1] == 7 { pass = pass + 1 }

	// Divisors — 1 → {1}.
	var d1 []int = math.Divisors(1)
	if len(d1) == 1 { pass = pass + 1 }
	if d1[0] == 1 { pass = pass + 1 }

	// Divisors — domain edge.
	var d0 []int = math.Divisors(0)
	if len(d0) == 0 { pass = pass + 1 }

	// Identity: SumInts(Divisors(n)) == SumDivisors(n).
	if math.SumDivisors(60) == 168 { pass = pass + 1 }   // 1+2+3+4+5+6+10+12+15+20+30+60 = 168
	if math.NumDivisors(60) == 12 { pass = pass + 1 }
	var d60 []int = math.Divisors(60)
	var sum int = 0
	for i := 0; i < len(d60); i++ { sum = sum + d60[i] }
	if sum == math.SumDivisors(60) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 34 { ret 42 }
	ret 0
}
