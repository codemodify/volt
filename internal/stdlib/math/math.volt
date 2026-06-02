// Package math: integer-focused numeric helpers.
//
// Volt's float surface is still weak (no float-conversion casts at
// runtime), so this package focuses on the int operations that
// nearly every program needs: absolute value, min/max, integer
// power, integer square root, GCD, positive modulo. Float-only
// functions (Sqrt, Pi, E, Sin, Log …) are deferred until the
// runtime exposes the relevant intrinsics.
//
// All functions are pure — they neither allocate nor read global
// state — so they're safe to call from any thread without
// synchronization.

package math

// MaxInt and MinInt are the bounds of volt's 64-bit signed int.
// MinInt is expressed as `-MaxInt - 1` because the lexer can't parse
// 9223372036854775808 as a positive literal (it overflows int64).
const MaxInt int = 9223372036854775807
const MinInt int = -9223372036854775807 - 1

// AbsInt returns |x|. Returns MinInt unchanged (no representable
// positive value — Go's `math/bits` documents this same overflow).
fun AbsInt(x int) int {
    if x < 0 {
        if x == MinInt { ret MinInt }
        ret -x
    }
    ret x
}

// MinInt2 returns the smaller of a and b.
fun MinInt2(a int, b int) int {
    if a < b { ret a }
    ret b
}

// MaxInt2 returns the larger of a and b.
fun MaxInt2(a int, b int) int {
    if a > b { ret a }
    ret b
}

// ClampInt clamps v to the inclusive range [lo, hi]. Caller must
// ensure lo <= hi; the function does not validate.
fun ClampInt(v int, lo int, hi int) int {
    if v < lo { ret lo }
    if v > hi { ret hi }
    ret v
}

// InRange reports whether v falls within the inclusive range
// [lo, hi]. Returns false when lo > hi (degenerate range). The
// predicate counterpart to ClampInt — useful for bounds-checking
// without modifying the value: `if !InRange(idx, 0, len(s) - 1)
// { ... }` pattern.
fun InRange(v int, lo int, hi int) bool {
    if hi < lo { ret false }
    if v < lo { ret false }
    if v > hi { ret false }
    ret true
}

// WrapInt wraps v into the inclusive range [lo, hi] using modular
// arithmetic (the cyclic counterpart to ClampInt's saturation).
// Out-of-range values cycle: WrapInt(-1, 0, 10) → 10, WrapInt(11,
// 0, 10) → 0, WrapInt(22, 0, 10) → 0 (two full cycles). Degenerate
// range (hi < lo) returns lo. Single-point range (lo == hi)
// returns lo. Useful for angles (0..359), day-of-week, circular
// buffer indices, and any periodic quantity. Built on FloorModInt
// so it handles negative v cleanly.
fun WrapInt(v int, lo int, hi int) int {
    if hi < lo { ret lo }
    if lo == hi { ret lo }
    var span int = hi - lo + 1
    ret lo + FloorModInt(v - lo, span)
}

// MinInt3 returns the smallest of three values. Saves the
// `MinInt2(a, MinInt2(b, c))` nesting at call sites for the common
// 3-way reduction (e.g. RGB-min for grayscale, triangle-side
// minimum, bounding-box corner picks).
fun MinInt3(a int, b int, c int) int {
    var m int = a
    if b < m { m = b }
    if c < m { m = c }
    ret m
}

// MaxInt3 returns the largest of three values. Companion to MinInt3.
fun MaxInt3(a int, b int, c int) int {
    var m int = a
    if b > m { m = b }
    if c > m { m = c }
    ret m
}

// ManhattanDist returns the L1 (taxicab) distance between two 2D
// integer points: `|x1 - x2| + |y1 - y2|`. Always non-negative.
// Useful for grid-based pathfinding (A* heuristic on 4-connected
// grids), board-game move costs, raster-pixel distance.
fun ManhattanDist(x1 int, y1 int, x2 int, y2 int) int {
    ret AbsInt(x1 - x2) + AbsInt(y1 - y2)
}

// ChebyshevDist returns the L∞ (chessboard / king-move) distance
// between two 2D integer points: `max(|x1 - x2|, |y1 - y2|)`. Useful
// for 8-connected grid pathfinding heuristics, chess-king move-count
// estimates, "minimum number of king-moves" puzzles.
fun ChebyshevDist(x1 int, y1 int, x2 int, y2 int) int {
    var dx int = AbsInt(x1 - x2)
    var dy int = AbsInt(y1 - y2)
    if dx > dy { ret dx }
    ret dy
}

// EuclideanSquaredDist returns `(x1-x2)² + (y1-y2)²` — squared
// Euclidean distance. Skips the costly square root needed for true
// distance and stays in pure int arithmetic, so it's the right
// primitive for *comparing* distances (which is closer? — both
// squares preserve ordering since they're non-negative). Caller
// can take IsqrtFloor of the result for an integer Euclidean
// distance. Overflow wraps silently. Useful for spatial sorting,
// nearest-neighbor selection, collision broad-phase culling.
fun EuclideanSquaredDist(x1 int, y1 int, x2 int, y2 int) int {
    var dx int = x1 - x2
    var dy int = y1 - y2
    ret dx * dx + dy * dy
}

// EuclideanDist returns floor(sqrt((x1-x2)² + (y1-y2)²)) — the
// integer Euclidean distance via IsqrtFloor. Returns the true
// distance when it lands on an exact integer (e.g. Pythagorean
// triples). Useful when an actual length is needed rather than
// a ranking; prefer EuclideanSquaredDist for comparisons.
fun EuclideanDist(x1 int, y1 int, x2 int, y2 int) int {
    ret IsqrtFloor(EuclideanSquaredDist(x1, y1, x2, y2))
}

// PowInt returns base^exp for non-negative exp. Returns 1 when
// exp == 0 (including 0^0). Overflow wraps silently — caller must
// keep magnitudes within the int range. Uses exponentiation by
// squaring: O(log exp) multiplications.
fun PowInt(base int, exp int) int {
    if exp <= 0 { ret 1 }
    var result int = 1
    var b int = base
    var e int = exp
    for e > 0 {
        if (e & 1) != 0 { result = result * b }
        e = e >> 1
        if e > 0 { b = b * b }
    }
    ret result
}

// IsqrtFloor returns floor(sqrt(x)) for x >= 0. Returns 0 for
// negative inputs. Implemented via Newton's method on integers;
// converges in O(log log x) iterations and never overshoots.
fun IsqrtFloor(x int) int {
    if x <= 0 { ret 0 }
    if x < 4 { ret 1 }
    var r int = x
    var rNew int = (r + x / r) / 2
    for rNew < r {
        r = rNew
        rNew = (r + x / r) / 2
    }
    ret r
}

// GcdInt returns the greatest common divisor of |a| and |b|.
// gcd(0, 0) = 0. Uses the Euclidean algorithm; pre-normalizes to
// absolute values so negative inputs work.
fun GcdInt(a int, b int) int {
    var x int = AbsInt(a)
    var y int = AbsInt(b)
    for y != 0 {
        var t int = x % y
        x = y
        y = t
    }
    ret x
}

// ModInt returns the always-non-negative remainder of a/m. Useful
// for hash bucket indices and circular-buffer math. m must be > 0;
// the function returns 0 if m <= 0.
fun ModInt(a int, m int) int {
    if m <= 0 { ret 0 }
    var r int = a % m
    if r < 0 { r = r + m }
    ret r
}

// Sign returns -1 if x < 0, 0 if x == 0, +1 if x > 0.
fun Sign(x int) int {
    if x < 0 { ret -1 }
    if x > 0 { ret 1 }
    ret 0
}

// LcmInt returns the least common multiple of a and b, treating
// both as their absolute values. Returns 0 when either operand is
// 0 (no positive integer is divisible by 0). Computed as
// |a|/gcd(a,b) * |b| (the |a|/gcd part avoids overflow on
// multiplying first then dividing).
fun LcmInt(a int, b int) int {
    if a == 0 { ret 0 }
    if b == 0 { ret 0 }
    var x int = AbsInt(a)
    var y int = AbsInt(b)
    var g int = GcdInt(x, y)
    ret (x / g) * y
}

// Pow2 returns 2^n as an int (i.e. 1 << n). n must be in [0, 62];
// out-of-range values return 0.
fun Pow2(n int) int {
    if n < 0 { ret 0 }
    if n > 62 { ret 0 }
    ret 1 << n
}

// IsPrime reports whether n is a positive prime. Trial division
// against odd candidates up to sqrt(n). n < 2 returns false; 2 and
// 3 are handled directly. Negative input returns false (primes are
// positive by convention).
fun IsPrime(n int) bool {
    if n < 2 { ret false }
    if n < 4 { ret true }
    if (n % 2) == 0 { ret false }
    var i int = 3
    for (i * i) <= n {
        if (n % i) == 0 { ret false }
        i = i + 2
    }
    ret true
}

// NumDigits returns the number of decimal digits needed to print
// AbsInt(n). NumDigits(0) is 1 (the digit '0'). NumDigits(-123) is
// 3 (the minus sign is not counted). Useful for column alignment
// of integer columns.
fun NumDigits(n int) int {
    if n == 0 { ret 1 }
    var x int = AbsInt(n)
    var d int = 0
    for x > 0 {
        d = d + 1
        x = x / 10
    }
    ret d
}

// PrimeFactorsInt returns the prime factors of n in ascending order
// WITH multiplicity. PrimeFactorsInt(12) = {2, 2, 3}; n < 2 returns
// an empty slice; primes return a single-element slice. O(sqrt(n))
// trial division — fine for any int that fits in an int64 (sqrt is
// at most ~3e9).
fun PrimeFactorsInt(n int) []int {
    if n < 2 { ret new(0) []int {} }
    var out []int = new(0) []int {}
    var x int = n
    for (x % 2) == 0 {
        out = append(out, 2)
        x = x / 2
    }
    var i int = 3
    for (i * i) <= x {
        for (x % i) == 0 {
            out = append(out, i)
            x = x / i
        }
        i = i + 2
    }
    if x > 1 { out = append(out, x) }
    ret out
}

// IsPowerOfTwo reports whether n is a positive power of two
// (1, 2, 4, 8, …). Uses the standard `n > 0 && (n & (n-1)) == 0`
// bit trick. n ≤ 0 returns false.
fun IsPowerOfTwo(n int) bool {
    if n <= 0 { ret false }
    if (n & (n - 1)) == 0 { ret true }
    ret false
}

// PopCount returns the number of 1-bits in the binary representation
// of |n|. Brian Kernighan's trick: each iteration clears the lowest
// set bit. For n = 0 returns 0. Negative inputs use |n| (the sign
// isn't a bit). Useful for Hamming weight, sparse-bitset cardinality,
// hash-mixing checks.
fun PopCount(n int) int {
    var v int = n
    if v < 0 { v = -v }
    var c int = 0
    for v != 0 {
        v = v & (v - 1)
        c = c + 1
    }
    ret c
}

// TrailingZeros returns the number of trailing zero bits in the
// binary representation of |n|. TrailingZeros(0) = 0 (no bits set
// at all — convention; some libs return 64). TrailingZeros(1) = 0,
// TrailingZeros(2) = 1, TrailingZeros(8) = 3, TrailingZeros(12) = 2
// (12 = 0b1100). Negative inputs use |n|. Useful for alignment
// detection, the v2 of factor-of-2 extraction in number theory.
fun TrailingZeros(n int) int {
    var v int = n
    if v < 0 { v = -v }
    if v == 0 { ret 0 }
    var c int = 0
    for (v & 1) == 0 {
        v = v / 2
        c = c + 1
    }
    ret c
}

// BitLen returns the number of bits required to represent |n|.
// BitLen(0) = 0, BitLen(1) = 1, BitLen(2) = BitLen(3) = 2,
// BitLen(255) = 8, BitLen(256) = 9. Equivalent to
// `floor(log2(|n|)) + 1` for n != 0. Negative inputs use |n|.
// Useful for: bucket sizing (need at least BitLen(n) bits for n
// values), radix selection, hash-table capacity estimation.
fun BitLen(n int) int {
    var v int = n
    if v < 0 { v = -v }
    var c int = 0
    for v > 0 {
        v = v / 2
        c = c + 1
    }
    ret c
}

// LeadingZeros returns the number of leading zero bits in a 64-bit
// representation of |n|. LeadingZeros(0) = 64 (no bits set means
// every bit is a leading zero). LeadingZeros(1) = 63. LeadingZeros
// of the largest int64 magnitude returns 1. Equivalent to
// `64 - BitLen(|n|)`. Useful for log2 floors, normalization in
// float-emulation routines, count-leading-zeros bit-tricks.
fun LeadingZeros(n int) int {
    ret 64 - BitLen(n)
}

// RotateLeft64 rotates the 64-bit representation of n left by k bits.
// k is reduced modulo 64 (negative k flipped to positive). Bits
// shifted off the high end wrap into the low end. Works on the full
// 64-bit two's-complement representation so negative inputs are
// handled identically to their unsigned bit pattern. Useful for
// hashing rounds, bit-permutation steps in crypto, ring buffers.
fun RotateLeft64(n int, k int) int {
    var s int = k % 64
    if s < 0 { s = s + 64 }
    if s == 0 { ret n }
    var s2 int = 64 - s
    var lo int = n << s
    var hi int = ((n >> 1) & MaxInt) >> (s2 - 1)
    ret lo | hi
}

// RotateRight64 rotates the 64-bit representation of n right by k
// bits. Counterpart to RotateLeft64; equivalent to
// `RotateLeft64(n, 64 - k)` for k in [1, 63].
fun RotateRight64(n int, k int) int {
    var s int = k % 64
    if s < 0 { s = s + 64 }
    if s == 0 { ret n }
    var lo int = ((n >> 1) & MaxInt) >> (s - 1)
    var hi int = n << (64 - s)
    ret lo | hi
}

// ReverseBits64 reverses the 64-bit representation of n — bit 0
// swaps with bit 63, bit 1 with bit 62, etc. ReverseBits64(0) = 0,
// ReverseBits64(-1) = -1 (all bits set), ReverseBits64(1) = MinInt
// (bit 0 moves to the sign-bit position). Useful for FFT bit-reverse
// reordering, certain hash mixing rounds, and bit-permutation crypto.
fun ReverseBits64(n int) int {
    var r int = 0
    var v int = n
    for i := 0; i < 64; i++ {
        r = (r << 1) | (v & 1)
        v = (v >> 1) & MaxInt          // logical right shift (clear sign bit)
    }
    ret r
}

// SwapBytes64 reverses the 8-byte order of n (endian swap). Byte 0
// swaps with byte 7, byte 1 with byte 6, etc. Useful for converting
// between big-endian and little-endian wire formats without going
// through a byte buffer.
fun SwapBytes64(n int) int {
    var r int = 0
    var v int = n
    for i := 0; i < 8; i++ {
        r = (r << 8) | (v & 255)
        v = ((v >> 1) & MaxInt) >> 7   // logical right shift by 8
    }
    ret r
}

// SortedPair returns (min, max) of two integers — one-compare
// version for tiny fixed-size sorts. The n=2 sibling of
// SortedTriple. Useful as a normalization step before doing
// range-checks or building interval bounds from unordered inputs.
fun SortedPair(a int, b int) (int, int) {
    if a > b { ret b, a }
    ret a, b
}

// SortedTriple returns (min, median, max) of three integers in
// ascending order. Useful when you need all three statistics in
// one pass (e.g. building a five-number summary from samples,
// sorting tiny fixed-size groups). Five-compare sort network —
// optimal for n=3.
fun SortedTriple(a int, b int, c int) (int, int, int) {
    var x int = a
    var y int = b
    var z int = c
    if x > y {
        var tmp int = x
        x = y
        y = tmp
    }
    if y > z {
        var tmp int = y
        y = z
        z = tmp
    }
    if x > y {
        var tmp int = x
        x = y
        y = tmp
    }
    ret x, y, z
}

// MedianOfThree returns the middle value of three integers — the
// one neither smallest nor largest. Useful as the pivot choice in
// quickselect / quicksort for sturdier worst-case behavior than
// "always pick first". Five comparisons via branchless-ish ladder.
fun MedianOfThree(a int, b int, c int) int {
    if a > b {
        if b > c { ret b }
        if a > c { ret c }
        ret a
    }
    if a > c { ret a }
    if b > c { ret c }
    ret b
}

// MidpointInt returns the integer midpoint of a and b — i.e.
// floor((a + b) / 2) computed in an overflow-safe way for large
// magnitudes. Uses `a + (b - a) / 2` instead of the naive
// `(a + b) / 2` to dodge int64 overflow when |a| and |b| are both
// near MaxInt. Useful as the standard binary-search midpoint.
fun MidpointInt(a int, b int) int {
    ret a + (b - a) / 2
}

// IsqrtCeil returns the smallest integer k such that k * k >= x.
// IsqrtCeil(0) = 0; negative inputs return 0 (no real ceiling square
// root). Companion to IsqrtFloor. Useful for capacity planning
// where you need *at least* enough rows/buckets to cover x items.
fun IsqrtCeil(x int) int {
    if x <= 0 { ret 0 }
    var f int = IsqrtFloor(x)
    if (f * f) == x { ret f }
    ret f + 1
}

// NextPrime returns the smallest prime strictly greater than n.
// Negative inputs and 0/1 return 2. O(P(n) * sqrt(n)) where P(n) is
// the prime gap at n (small for n in normal int range — ~log(n)
// average). Useful for "give me the next hash-table size",
// generating primes in sequence.
fun NextPrime(n int) int {
    if n < 2 { ret 2 }
    var p int = n + 1
    for !IsPrime(p) {
        p = p + 1
    }
    ret p
}

// PrevPrime returns the largest prime strictly less than n. Returns
// 0 when no smaller prime exists (n <= 2). Walks downward from n-1
// using IsPrime. The walk distance is bounded by the prime gap at
// n (small in the normal int range). Useful for binning / bucket
// sizing where you want the prime ≤ a target.
fun PrevPrime(n int) int {
    if n <= 2 { ret 0 }
    var p int = n - 1
    for p > 1 {
        if IsPrime(p) { ret p }
        p = p - 1
    }
    ret 0
}

// NthPrime returns the nth prime (1-indexed): NthPrime(1) = 2,
// NthPrime(2) = 3, NthPrime(3) = 5, NthPrime(10) = 29,
// NthPrime(100) = 541. n <= 0 returns 0 (out of domain). Sieve-of-
// Eratosthenes would be faster for many calls; for occasional use
// the simple trial-division walk via NextPrime stays well under a
// millisecond for n <= 10000 (and is linear-allocation-free).
fun NthPrime(n int) int {
    if n <= 0 { ret 0 }
    var count int = 0
    var p int = 1
    for count < n {
        p = NextPrime(p)
        count = count + 1
    }
    ret p
}

// Factorial returns n! for n in [0, 20]. n = 0 returns 1 (vacuous
// identity). Negative n returns 0 (factorial isn't defined for
// negatives). n > 20 returns 0 (21! overflows int64). Callers
// needing big-int factorials should compute via a bignum package.
fun Factorial(n int) int {
    if n < 0 { ret 0 }
    if n > 20 { ret 0 }
    var r int = 1
    var i int = 2
    for i <= n {
        r = r * i
        i = i + 1
    }
    ret r
}

// Binomial returns the binomial coefficient C(n, k) = n! / (k!(n-k)!).
// Computed iteratively to avoid the bignum factorials. Returns 0 if
// k < 0 or k > n or n < 0. Equivalent to `math.Comb` in Python.
// Useful for combinatorial counts, probability calculations.
fun Binomial(n int, k int) int {
    if n < 0 { ret 0 }
    if k < 0 { ret 0 }
    if k > n { ret 0 }
    var kk int = k
    if (n - kk) < kk { kk = n - kk }   // C(n,k) = C(n, n-k); use the smaller for speed
    if kk == 0 { ret 1 }
    var r int = 1
    var i int = 1
    for i <= kk {
        r = r * (n - kk + i)
        r = r / i
        i = i + 1
    }
    ret r
}

// Fibonacci returns F(n) where F(0)=0, F(1)=1, F(n)=F(n-1)+F(n-2).
// Computed iteratively. Negative n returns 0 (the Fibonacci sequence
// is conventionally defined for n >= 0 only). int64 overflows at
// n = 93 (F(92) = 7540113804746346429 is the largest representable);
// n > 92 returns 0 to signal the overflow.
fun Fibonacci(n int) int {
    if n < 0 { ret 0 }
    if n > 92 { ret 0 }
    if n == 0 { ret 0 }
    if n == 1 { ret 1 }
    var a int = 0
    var b int = 1
    var i int = 2
    for i <= n {
        var c int = a + b
        a = b
        b = c
        i = i + 1
    }
    ret b
}

// Lucas returns the nth Lucas number — companion sequence to
// Fibonacci with L(0) = 2, L(1) = 1, L(n) = L(n-1) + L(n-2).
// First few: 2, 1, 3, 4, 7, 11, 18, 29, 47, 76, 123. Grows as
// the golden ratio raised to the n. Negative n returns 0; n > 90
// returns 0 (L(91) overflows int64).
fun Lucas(n int) int {
    if n < 0 { ret 0 }
    if n > 90 { ret 0 }
    if n == 0 { ret 2 }
    if n == 1 { ret 1 }
    var a int = 2
    var b int = 1
    var i int = 2
    for i <= n {
        var c int = a + b
        a = b
        b = c
        i = i + 1
    }
    ret b
}

// Tribonacci returns the nth Tribonacci number with the OEIS
// A000073 convention: T(0) = 0, T(1) = 1, T(2) = 1, T(n) = T(n-1)
// + T(n-2) + T(n-3). First few: 0, 1, 1, 2, 4, 7, 13, 24, 44, 81,
// 149, 274, 504, 927. Negative n returns 0; n > 75 returns 0
// (growth rate ≈ 1.839^n, exceeds int64 around n = 76).
fun Tribonacci(n int) int {
    if n < 0 { ret 0 }
    if n > 75 { ret 0 }
    if n == 0 { ret 0 }
    if n == 1 { ret 1 }
    if n == 2 { ret 1 }
    var a int = 0
    var b int = 1
    var c int = 1
    var i int = 3
    for i <= n {
        var d int = a + b + c
        a = b
        b = c
        c = d
        i = i + 1
    }
    ret c
}

// Catalan returns the nth Catalan number — the count of valid
// balanced-parenthesis strings of n pairs, binary tree shapes with
// n+1 leaves, monotone lattice paths, etc. C(0)=1, C(1)=1, C(2)=2,
// C(3)=5, C(4)=14, C(5)=42, C(10)=16796. Iterative via the
// recurrence C(n) = C(n-1) * 2 * (2n-1) / (n+1) to avoid the
// `Binomial(2n, n) / (n+1)` intermediate that overflows much
// earlier. Returns 0 for n < 0 or n > 33 (C(34) overflows int64).
fun Catalan(n int) int {
    if n < 0 { ret 0 }
    if n > 33 { ret 0 }
    var c int = 1
    var i int = 1
    for i <= n {
        c = c * 2 * (2 * i - 1) / (i + 1)
        i = i + 1
    }
    ret c
}

// GcdInts returns the GCD of every element in s, taken as absolute
// values. Empty slice returns 0 (GCD identity). Walks the slice
// folding GcdInt, with an early exit when the running GCD becomes
// 1 (no smaller divisor is possible). Useful for finding the
// largest common divisor of any number of measurements / counts.
fun GcdInts(s []int) int {
    var n int = len(s)
    if n == 0 { ret 0 }
    var g int = AbsInt(s[0])
    for i := 1; i < n; i++ {
        g = GcdInt(g, s[i])
        if g == 1 { ret 1 }
    }
    ret g
}

// LcmInts returns the LCM of every element in s, taken as absolute
// values. Empty slice returns 0 (vacuous). Any zero element makes
// the LCM 0 (no positive integer is divisible by 0). Folds via
// LcmInt — overflow wraps silently. Useful for finding the smallest
// period that aligns N independent cycles.
fun LcmInts(s []int) int {
    var n int = len(s)
    if n == 0 { ret 0 }
    var l int = AbsInt(s[0])
    for i := 1; i < n; i++ {
        l = LcmInt(l, s[i])
        if l == 0 { ret 0 }
    }
    ret l
}

// NextPow2 returns the smallest power of two >= n. n <= 1 returns
// 1. n > 2^62 (the largest power of two that fits int64) returns 0
// to flag overflow. Useful for sizing hash tables, ring buffers,
// any "round up to a nice power of 2" capacity decision.
fun NextPow2(n int) int {
    if n <= 1 { ret 1 }
    var maxPow int = 1 << 62
    if n > maxPow { ret 0 }
    var p int = 1
    for p < n {
        p = p * 2
    }
    ret p
}

// IsPerfectSquare reports whether n is the square of some
// non-negative integer. n < 0 returns false. Computed via
// `IsqrtFloor(n)` — squaring the floor sqrt back exactly matches
// n iff n is a perfect square.
fun IsPerfectSquare(n int) bool {
    if n < 0 { ret false }
    var r int = IsqrtFloor(n)
    if (r * r) == n { ret true }
    ret false
}

// IsPowerOf reports whether `value` is an exact power of `base`
// (i.e. value == base^k for some integer k >= 0). 1 is always a
// power (base^0). base must be >= 2; bases <= 1 return false.
// value <= 0 returns false. Useful for testing arbitrary integer
// bases (companion to IsPowerOfTwo for the special-case 2).
fun IsPowerOf(value int, base int) bool {
    if base < 2 { ret false }
    if value <= 0 { ret false }
    var x int = value
    for x > 1 {
        if (x % base) != 0 { ret false }
        x = x / base
    }
    ret true
}

// IsCoprime reports whether GCD(|a|, |b|) == 1 — i.e. a and b share
// no common factor other than 1. By convention IsCoprime(0, 0)
// is false (gcd is 0); IsCoprime(0, n) is true iff |n| == 1.
// Useful for fraction reduction, modular inverse preconditions,
// random-modulus selection.
fun IsCoprime(a int, b int) bool {
    if GcdInt(a, b) == 1 { ret true }
    ret false
}

// SumOfDigits returns the sum of the decimal digits of AbsInt(n).
// SumOfDigits(0) is 0. SumOfDigits(-123) is 6 (digits of 123).
// Useful for digital-root computations, checksum validators,
// digit-frequency analyses.
fun SumOfDigits(n int) int {
    var x int = AbsInt(n)
    var s int = 0
    for x > 0 {
        s = s + (x % 10)
        x = x / 10
    }
    ret s
}

// PowMod returns (base^exp) mod m using square-and-multiply (modular
// exponentiation). exp must be >= 0; m must be >= 1. Returns 0 on
// invalid input. Avoids overflow on intermediate `base^exp` by
// reducing every step. O(log exp) time. Useful for cryptographic
// primitives, RSA-style operations, modular invariants.
fun PowMod(base int, exp int, m int) int {
    if exp < 0 { ret 0 }
    if m < 1 { ret 0 }
    if m == 1 { ret 0 }
    var result int = 1
    var b int = base % m
    if b < 0 { b = b + m }
    var e int = exp
    for e > 0 {
        if (e & 1) == 1 {
            result = (result * b) % m
        }
        b = (b * b) % m
        e = e >> 1
    }
    ret result
}

// DigitalRoot repeatedly sums the decimal digits of |n| until a
// single digit remains. DigitalRoot(38) = 3 + 8 = 11 → 1 + 1 = 2.
// Equivalent to `1 + ((|n| - 1) % 9)` for n != 0, but the iterative
// form mirrors the standard definition. DigitalRoot(0) = 0.
fun DigitalRoot(n int) int {
    var x int = AbsInt(n)
    for x >= 10 {
        x = SumOfDigits(x)
    }
    ret x
}

// IsArmstrong (or narcissistic number) reports whether n equals the
// sum of its decimal digits each raised to the power of the number
// of digits. Examples: 1, 9, 153, 9474. n < 0 returns false. Useful
// for recreational-math problems, demo / puzzle generation.
fun IsArmstrong(n int) bool {
    if n < 0 { ret false }
    var d int = NumDigits(n)
    var x int = n
    var total int = 0
    for x > 0 {
        var digit int = x % 10
        total = total + PowInt(digit, d)
        x = x / 10
    }
    if total == n { ret true }
    ret false
}

// IsPalindromeInt reports whether the decimal representation of
// AbsInt(n) reads the same forwards and backwards. 0 and any
// single digit return true. Negatives ignore sign (the minus
// isn't a digit). Computed by reversing the digits and comparing.
fun IsPalindromeInt(n int) bool {
    var x int = AbsInt(n)
    var orig int = x
    var rev int = 0
    for x > 0 {
        rev = rev * 10 + (x % 10)
        x = x / 10
    }
    if rev == orig { ret true }
    ret false
}

// NextMultipleOf returns the smallest multiple of m that is >= n.
// m must be > 0; m <= 0 returns 0 (sentinel). When n is already a
// multiple of m, returns n unchanged. Handles negative n by
// rounding up toward zero / past zero correctly.
fun NextMultipleOf(n int, m int) int {
    if m <= 0 { ret 0 }
    var r int = n % m
    if r == 0 { ret n }
    if n >= 0 { ret n + (m - r) }
    ret n - r
}

// PrevMultipleOf returns the largest multiple of m that is <= n.
// m <= 0 returns 0. When n is already a multiple of m, returns n.
// Negative n rounds down (more negative).
fun PrevMultipleOf(n int, m int) int {
    if m <= 0 { ret 0 }
    var r int = n % m
    if r == 0 { ret n }
    if n >= 0 { ret n - r }
    ret n - r - m
}

// SumDivisors returns the sum of all positive divisors of n
// (including 1 and n itself). SumDivisors(0) = 0; negatives return
// 0. O(sqrt(n)) — pairs i with n/i so we only iterate up to sqrt.
// Useful for perfect / abundant / deficient number tests, sigma
// function evaluations.
fun SumDivisors(n int) int {
    if n <= 0 { ret 0 }
    var total int = 0
    var i int = 1
    for (i * i) <= n {
        if (n % i) == 0 {
            total = total + i
            var paired int = n / i
            if paired != i { total = total + paired }
        }
        i = i + 1
    }
    ret total
}

// NumDivisors returns the count of positive divisors of n. n <= 0
// returns 0. O(sqrt(n)) via the same paired-iteration trick as
// SumDivisors. Useful for: prime detection (NumDivisors == 2),
// number-of-divisors arithmetic, OEIS-style divisor analysis.
fun NumDivisors(n int) int {
    if n <= 0 { ret 0 }
    var count int = 0
    var i int = 1
    for (i * i) <= n {
        if (n % i) == 0 {
            count = count + 1
            var paired int = n / i
            if paired != i { count = count + 1 }
        }
        i = i + 1
    }
    ret count
}

// Divisors returns a sorted ascending slice of every positive
// divisor of n. n <= 0 returns an empty slice. O(sqrt(n)) collection
// with a pair-merge pass to keep the result in order without sort.
fun Divisors(n int) []int {
    if n <= 0 { ret new(0) []int {} }
    var lows []int = new(0) []int {}
    var highs []int = new(0) []int {}
    var i int = 1
    for (i * i) <= n {
        if (n % i) == 0 {
            lows = append(lows, i)
            var paired int = n / i
            if paired != i { highs = append(highs, paired) }
        }
        i = i + 1
    }
    var nl int = len(lows)
    var nh int = len(highs)
    var out []int = new(nl + nh) []int {}
    for k := 0; k < nl; k++ { out[k] = lows[k] }
    // highs were collected in ascending-paired order (1's pair, 2's pair, ...)
    // which corresponds to descending divisor order — reverse during copy.
    for k := 0; k < nh; k++ { out[nl + k] = highs[nh - 1 - k] }
    ret out
}

// BigOmega returns Ω(n) — the count of prime factors of n WITH
// multiplicity (uppercase Greek). Ω(1) = 0; Ω(p) = 1 for any
// prime; Ω(12) = 3 (factors 2, 2, 3). n <= 0 returns 0. Companion
// to LittleOmega (distinct). Equals `len(PrimeFactorsInt(n))`.
fun BigOmega(n int) int {
    if n <= 0 { ret 0 }
    if n == 1 { ret 0 }
    ret len(PrimeFactorsInt(n))
}

// LiouvilleInt returns λ(n) = (-1)^Ω(n) — the Liouville function.
// λ(1) = 1 (Ω=0, even). λ is +1 when n has an even total prime-
// factor count (with multiplicity), -1 when odd. Distinct from
// Möbius — λ doesn't zero out on squared factors. n <= 0 returns 0.
// Useful for: λ-summation problems, Riemann-hypothesis-adjacent
// experiments, arithmetic-function lookup tables.
fun LiouvilleInt(n int) int {
    if n <= 0 { ret 0 }
    var k int = BigOmega(n)
    if (k % 2) == 0 { ret 1 }
    ret -1
}

// MoebiusInt returns μ(n) — the classical Möbius function:
//   +1 if n is squarefree with an EVEN number of prime factors
//   -1 if n is squarefree with an ODD number of prime factors
//    0 if n has a squared prime factor
// μ(1) = 1 (vacuous-even count). n <= 0 returns 0 (out of domain).
// Useful for: Möbius inversion sums, primality / divisor-sum
// identities, sieve-of-divisor problems.
fun MoebiusInt(n int) int {
    if n <= 0 { ret 0 }
    if n == 1 { ret 1 }
    if !IsSquarefree(n) { ret 0 }
    var k int = LittleOmega(n)
    if (k % 2) == 0 { ret 1 }
    ret -1
}

// LittleOmega returns ω(n) — the count of DISTINCT prime factors
// of n. ω(1) = 0; ω(p) = 1 for any prime; ω(12) = 2 (primes 2, 3).
// n <= 0 returns 0. Companion (lowercase) to Omega (big-Ω) which
// counts WITH multiplicity. Useful for arithmetic-function value
// tables, asymptotic-density estimates.
fun LittleOmega(n int) int {
    if n <= 0 { ret 0 }
    if n == 1 { ret 0 }
    ret len(DistinctPrimeFactors(n))
}

// IsSquarefree reports whether n has no repeated prime factor —
// i.e. no prime divides n more than once. n == 1 returns true
// (vacuous). n <= 0 returns false (domain). Examples: 1, 2, 3, 5,
// 6, 7, 10, 11, 13, 14, 15, 17, ... are squarefree; 4, 8, 9, 12,
// 16, 18, 20, ... are not.
fun IsSquarefree(n int) bool {
    if n <= 0 { ret false }
    if n == 1 { ret true }
    var pf []int = PrimeFactorsInt(n)
    var np int = len(pf)
    for i := 1; i < np; i++ {
        if pf[i] == pf[i-1] { ret false }
    }
    ret true
}

// RadicalInt returns the radical of n — the product of distinct
// prime divisors of n. rad(1) = 1; rad(n ≤ 0) = 0. Examples:
// rad(12) = 2*3 = 6, rad(30) = 30 (squarefree), rad(72) = 6
// (72 = 2^3 * 3^2 → 2*3). Useful in abc-conjecture investigations
// and Möbius-like sums.
fun RadicalInt(n int) int {
    if n <= 0 { ret 0 }
    if n == 1 { ret 1 }
    var primes []int = DistinctPrimeFactors(n)
    var nz int = len(primes)
    var r int = 1
    for i := 0; i < nz; i++ {
        r = r * primes[i]
    }
    ret r
}

// DistinctPrimeFactors returns the unique prime factors of n in
// ascending order. n < 2 returns empty. Wraps PrimeFactorsInt and
// dedupes. Useful for: Möbius / radical-style number theory,
// "what primes divide n?" enumeration.
fun DistinctPrimeFactors(n int) []int {
    var pf []int = PrimeFactorsInt(n)
    var out []int = new(0) []int {}
    var prev int = -1
    var np int = len(pf)
    for i := 0; i < np; i++ {
        if pf[i] != prev {
            out = append(out, pf[i])
            prev = pf[i]
        }
    }
    ret out
}

// Totient returns Euler's totient function φ(n) — the count of
// positive integers k ≤ n that are coprime with n. φ(1) = 1; n <= 0
// returns 0. Computed via the product formula
// `φ(n) = n * Π(1 - 1/p)` over distinct primes p dividing n, in
// integer form: `n * (p_i - 1) / p_i` accumulated. Useful for: RSA
// key-pair counts, multiplicative-group orders, fraction reduction.
fun Totient(n int) int {
    if n <= 0 { ret 0 }
    if n == 1 { ret 1 }
    var primes []int = DistinctPrimeFactors(n)
    var nz int = len(primes)
    var result int = n
    for i := 0; i < nz; i++ {
        var p int = primes[i]
        result = result / p * (p - 1)
    }
    ret result
}

// IsPerfect reports whether n is a perfect number — equal to the
// sum of its proper divisors (divisors of n excluding n itself).
// n < 2 returns false. Known perfect numbers: 6, 28, 496, 8128.
fun IsPerfect(n int) bool {
    if n < 2 { ret false }
    if (SumDivisors(n) - n) == n { ret true }
    ret false
}

// IsAbundant reports whether the sum of n's proper divisors
// (excluding n) is GREATER than n. n < 2 returns false. First
// few abundant numbers: 12, 18, 20, 24, 30. Companion to
// IsPerfect (proper sum == n) and IsDeficient (proper sum < n).
fun IsAbundant(n int) bool {
    if n < 2 { ret false }
    if (SumDivisors(n) - n) > n { ret true }
    ret false
}

// IsDeficient reports whether the sum of n's proper divisors is
// strictly LESS than n. Includes all primes. n < 2 returns false
// (out of the classification domain). Most numbers are deficient.
fun IsDeficient(n int) bool {
    if n < 2 { ret false }
    if (SumDivisors(n) - n) < n { ret true }
    ret false
}

// IsAutomorphic reports whether n is automorphic — i.e. n² ends
// with the base-10 digits of n. Examples: 0 (0²=0), 1 (1²=1),
// 5 (5²=25), 6 (6²=36), 25 (25²=625), 76 (76²=5776), 376, 625.
// Defined only for n >= 0; negative inputs return false. Useful
// for number-theory puzzles and Kaprekar / fixed-point arithmetic.
fun IsAutomorphic(n int) bool {
    if n < 0 { ret false }
    var sq int = n * n
    var d int = NumDigits(n)
    var p int = 1
    for i := 0; i < d; i++ { p = p * 10 }
    if (sq % p) == n { ret true }
    ret false
}

// IsKaprekar reports whether n is a Kaprekar number — i.e. its
// square can be split into two parts that sum to n. Examples:
// 1 (trivially, 1²=1), 9 (9²=81 → 8+1=9), 45 (2025 → 20+25),
// 55 (3025 → 30+25), 99, 297, 703, 999, 2223, 2728. Domain: n >= 1
// (n <= 0 returns false). The right-hand split must be > 0 (don't
// allow a trailing all-zero split). Caller's responsibility to
// keep n small enough that n*n doesn't overflow int64.
fun IsKaprekar(n int) bool {
    if n < 1 { ret false }
    if n == 1 { ret true }
    var sq int = n * n
    var p int = 10
    for p <= sq {
        var right int = sq % p
        var left int = sq / p
        if right > 0 {
            if (left + right) == n { ret true }
        }
        p = p * 10
    }
    ret false
}

// IsPandigital reports whether n contains every base-10 digit 0..9
// at least once. The minimum 10-digit pandigital is 1023456789;
// shorter n always returns false. Negative n returns false (sign
// isn't a digit, and the leading '-' makes the classification
// undefined). Useful for puzzle / lottery / permutation checks.
fun IsPandigital(n int) bool {
    if n < 0 { ret false }
    var seen []bool = new(10) []bool {}
    var v int = n
    if v == 0 { seen[0] = true }
    for v > 0 {
        seen[v % 10] = true
        v = v / 10
    }
    for i := 0; i < 10; i++ {
        if seen[i] == false { ret false }
    }
    ret true
}

// IsHarshad reports whether n is a Harshad (Niven) number — i.e.
// divisible by the sum of its base-10 digits. Defined for n > 0;
// n <= 0 returns false (SumDigits(0) == 0 would divide-by-zero,
// and the classification doesn't apply to negatives). First few:
// 1, 2, ..., 9, 10, 12, 18, 20, 21, 24, 27, 30. Every single-digit
// positive is trivially Harshad.
fun IsHarshad(n int) bool {
    if n <= 0 { ret false }
    var s int = SumDigits(n)
    if s == 0 { ret false }
    if (n % s) == 0 { ret true }
    ret false
}

// LogIntBase returns the largest integer k such that base^k <= n.
// Returns -1 if n <= 0 or base < 2 (no defined log). LogIntBase(1, b)
// is 0 (b^0 == 1). Equivalent to `floor(log_base(n))`. Useful for
// digit count in arbitrary bases, tree-depth bounds, capacity tiers.
fun LogIntBase(n int, base int) int {
    if n <= 0 { ret -1 }
    if base < 2 { ret -1 }
    var k int = 0
    var p int = 1
    for (p * base) <= n {
        p = p * base
        k = k + 1
    }
    ret k
}

// Log2Floor returns the largest integer k such that 2^k <= n.
// Returns -1 for n <= 0. Log2Floor(1) = 0. Equivalent to
// `BitLen(n) - 1` for n >= 1, or `LogIntBase(n, 2)`. Useful for:
// fast `is-a-power-of-two-cap` bound calculations, segment-tree
// height bounds, exponent-aligned offsets.
fun Log2Floor(n int) int {
    if n <= 0 { ret -1 }
    ret BitLen(n) - 1
}

// Log2Ceil returns the smallest integer k such that 2^k >= n.
// Returns -1 for n <= 0. Log2Ceil(1) = 0 (2^0 = 1 >= 1).
// Log2Ceil(2^k) == k (no rounding when n is exactly a power of two).
// Useful for: allocation rounding up to power-of-two capacity,
// tree-depth ceiling.
fun Log2Ceil(n int) int {
    if n <= 0 { ret -1 }
    if n == 1 { ret 0 }
    ret BitLen(n - 1)
}

// AlignUp returns the smallest multiple of k that is >= n. Useful
// for memory-layout alignment (page sizes, cache lines), buffer
// capacity ceilings, slot-grid placement. For n <= 0 or k <= 0
// returns n unchanged (degenerate cases). For n already a multiple
// of k, AlignUp(n, k) == n (fixed-point).
fun AlignUp(n int, k int) int {
    if k <= 0 { ret n }
    if n <= 0 { ret n }
    var rem int = n % k
    if rem == 0 { ret n }
    ret n + (k - rem)
}

// AlignDown returns the largest multiple of k that is <= n. Counter-
// part to AlignUp. Same fixed-point semantics when n is a multiple
// of k. n <= 0 or k <= 0 returns n unchanged. For n in (0, k),
// AlignDown returns 0.
fun AlignDown(n int, k int) int {
    if k <= 0 { ret n }
    if n <= 0 { ret n }
    ret n - (n % k)
}

// RoundToMultiple returns the multiple of k nearest to n
// (round-half-up). Distinct from AlignUp (always up) and AlignDown
// (always down) — this picks the closer of the two surrounding
// multiples and breaks ties by rounding up. k <= 0 returns n
// unchanged. Negative n: rounding is symmetric about zero (i.e.
// RoundToMultiple(-7, 5) == -5, matching the "round toward closer
// multiple" intuition). Useful for snap-to-grid, audio sample-rate
// alignment, paginated-offset rounding.
fun RoundToMultiple(n int, k int) int {
    if k <= 0 { ret n }
    if n == 0 { ret 0 }
    if n > 0 {
        var rem int = n % k
        if rem * 2 >= k { ret n + (k - rem) }
        ret n - rem
    }
    // n < 0: mirror.
    var m int = -n
    var rem int = m % k
    if rem * 2 >= k { ret -(m + (k - rem)) }
    ret -(m - rem)
}

// TriangularInt returns the nth triangular number: 1 + 2 + ... + n
// = n*(n+1)/2. Negative n returns 0 (out of domain). Useful for
// combinatorial counts, sum-of-natural-number formulas.
fun TriangularInt(n int) int {
    if n < 0 { ret 0 }
    ret (n * (n + 1)) / 2
}

// FibInt returns the nth Fibonacci number using the standard
// recurrence F(0) = 0, F(1) = 1, F(n) = F(n-1) + F(n-2). Computed
// iteratively in O(n) so n up to ~92 fits int64 (F(93) overflows).
// Negative n returns 0. Useful for golden-ratio-related problems,
// recurrence demos.
fun FibInt(n int) int {
    if n < 0 { ret 0 }
    if n < 2 { ret n }
    var a int = 0
    var b int = 1
    for i := 2; i <= n; i++ {
        var c int = a + b
        a = b
        b = c
    }
    ret b
}

// SumSquaresDigits returns the sum of squares of decimal digits of
// AbsInt(n). SumSquaresDigits(23) = 4 + 9 = 13. Useful building
// block for happy-number sequences and other digital-arithmetic
// puzzles.
fun SumSquaresDigits(n int) int {
    var x int = AbsInt(n)
    var s int = 0
    for x > 0 {
        var d int = x % 10
        s = s + d * d
        x = x / 10
    }
    ret s
}

// IsHappyNumber reports whether n is a happy number — repeatedly
// summing the squares of its decimal digits eventually reaches 1.
// All unhappy positive integers cycle through 4 → 16 → 37 → ... →
// 4 (the "sad" cycle), so Floyd's cycle detection (slow + fast
// pointer) terminates in O(log n) steps. n <= 0 returns false.
// Known happy numbers: 1, 7, 10, 13, 19, 23, 28, 31, 32, 44, ...
fun IsHappyNumber(n int) bool {
    if n <= 0 { ret false }
    var slow int = n
    var fast int = SumSquaresDigits(n)
    for fast != 1 {
        slow = SumSquaresDigits(slow)
        fast = SumSquaresDigits(SumSquaresDigits(fast))
        if slow == fast { ret false }
    }
    ret true
}

// LerpInt linearly interpolates between a and b by t/denom. When
// t == 0 returns a; when t == denom returns b. Result is
// `a + (b - a) * t / denom` with integer truncation. denom must be
// > 0; denom <= 0 returns a (degenerate). Useful for: integer-only
// animation steps, percentile scaling, integer easing.
fun LerpInt(a int, b int, t int, denom int) int {
    if denom <= 0 { ret a }
    ret a + ((b - a) * t) / denom
}

// MapRange linearly maps x from [srcLo, srcHi] to [dstLo, dstHi].
// `dstLo + (x - srcLo) * (dstHi - dstLo) / (srcHi - srcLo)` with
// integer truncation. Degenerate source range (srcLo == srcHi)
// returns dstLo. x outside source range extrapolates linearly.
// Useful for: UI sliders (pixel ↔ value), sensor calibration,
// histogram bucket projection.
fun MapRange(x int, srcLo int, srcHi int, dstLo int, dstHi int) int {
    if srcHi == srcLo { ret dstLo }
    ret dstLo + ((x - srcLo) * (dstHi - dstLo)) / (srcHi - srcLo)
}

// CeilDivInt returns ⌈a / b⌉ for non-negative a and positive b
// (matches the common pattern `(a + b - 1) / b`). Returns 0 on
// invalid input (a < 0 or b <= 0). Useful for: "how many pages
// to hold n items at b per page" capacity calculations.
fun CeilDivInt(a int, b int) int {
    if b <= 0 { ret 0 }
    if a < 0 { ret 0 }
    ret (a + b - 1) / b
}

// RoundDivInt returns a / b rounded to nearest, ties away from
// zero (round half-up): `(a + b/2) / b`. For non-negative a and
// positive b. Returns 0 on invalid input. Useful for: integer
// averaging without truncation bias, fixed-point rounding.
fun RoundDivInt(a int, b int) int {
    if b <= 0 { ret 0 }
    if a < 0 { ret 0 }
    ret (a + b / 2) / b
}

// FloorDivInt returns ⌊a / b⌋ — division rounded toward negative
// infinity (Python-style), not truncated toward zero as the native
// `/` does for negatives. For positive operands, equals `a / b`.
// For negative dividend: `FloorDivInt(-7, 2) == -4` (vs `-7/2 == -3`).
// Returns 0 when b == 0 (degenerate input; caller should validate).
// Useful for: circular-buffer indexing with negative offsets,
// time-bucket calculations that span before-epoch instants.
fun FloorDivInt(a int, b int) int {
    if b == 0 { ret 0 }
    var q int = a / b
    var r int = a % b
    if r != 0 {
        if (r < 0) != (b < 0) { q = q - 1 }
    }
    ret q
}

// FloorModInt returns the floor-modulo `a - FloorDivInt(a, b) * b`
// — Python-style. The result always has the same sign as `b` (or
// 0). Examples: `FloorModInt(-7, 2) == 1` (vs `-7 % 2 == -1`).
// Returns 0 when b == 0. Useful for: ring-index wrap on negative
// rotation, day-of-week arithmetic across epoch boundary.
fun FloorModInt(a int, b int) int {
    if b == 0 { ret 0 }
    var r int = a % b
    if r != 0 {
        if (r < 0) != (b < 0) { r = r + b }
    }
    ret r
}

// IsTriangularInt reports whether n is a triangular number — equals
// k*(k+1)/2 for some non-negative integer k. Uses the identity:
// n is triangular iff 8n+1 is a perfect square. n < 0 returns
// false. Examples: 0, 1, 3, 6, 10, 15, 21, 28, 36, 45, 55, ...
fun IsTriangularInt(n int) bool {
    if n < 0 { ret false }
    if IsPerfectSquare(8 * n + 1) { ret true }
    ret false
}

// IsFibonacciInt reports whether n is a Fibonacci number. Uses the
// identity (Binet-based): n is Fibonacci iff 5n² + 4 OR 5n² - 4 is
// a perfect square. n < 0 returns false. Examples: 0, 1, 2, 3, 5,
// 8, 13, 21, 34, 55, 89, 144, ...
fun IsFibonacciInt(n int) bool {
    if n < 0 { ret false }
    var sq int = 5 * n * n
    if IsPerfectSquare(sq + 4) { ret true }
    if IsPerfectSquare(sq - 4) { ret true }
    ret false
}

// IsPentagonalInt reports whether n is a pentagonal number —
// equals k*(3k-1)/2 for some non-negative integer k. Identity:
// n is pentagonal iff 24n+1 is a perfect square AND its
// integer square root is congruent to 5 mod 6. First few:
// 0, 1, 5, 12, 22, 35, 51, 70, 92, 117, 145, ...
fun IsPentagonalInt(n int) bool {
    if n < 0 { ret false }
    if n == 0 { ret true }
    var m int = 24 * n + 1
    if !IsPerfectSquare(m) { ret false }
    var sq int = IsqrtFloor(m)
    if (sq % 6) == 5 { ret true }
    ret false
}

// IsHexagonalInt reports whether n is a hexagonal number —
// equals k*(2k-1) for some non-negative integer k. Identity:
// n is hexagonal iff 8n+1 is a perfect square AND `sqrt + 1`
// is divisible by 4 (so sqrt is 4k-1). First few:
// 0, 1, 6, 15, 28, 45, 66, 91, 120, 153, 190, 231, ...
// Note: every hexagonal number is also triangular.
fun IsHexagonalInt(n int) bool {
    if n < 0 { ret false }
    if n == 0 { ret true }
    var m int = 8 * n + 1
    if !IsPerfectSquare(m) { ret false }
    var sq int = IsqrtFloor(m)
    if ((sq + 1) % 4) == 0 { ret true }
    ret false
}

// IcbrtFloor returns the largest integer k such that k³ <= n,
// for non-negative n. n <= 0 returns 0. Computed via binary
// search bounded by 2097151 (the largest cube root that fits in
// int64). Useful for: capacity-volume calculations, integer
// cube-root extraction.
fun IcbrtFloor(n int) int {
    if n <= 0 { ret 0 }
    var lo int = 0
    var hi int = 2097151
    if hi > n { hi = n }
    for lo < hi {
        var mid int = (lo + hi + 1) / 2
        var cube int = mid * mid * mid
        if cube <= n {
            lo = mid
        } else {
            hi = mid - 1
        }
    }
    ret lo
}

// IsPerfectCube reports whether n is k³ for some non-negative
// integer k. Computed via cubing IcbrtFloor(n) back. n < 0
// returns false. Useful for: recreational number theory,
// volumetric integer puzzles.
fun IsPerfectCube(n int) bool {
    if n < 0 { ret false }
    var r int = IcbrtFloor(n)
    if (r * r * r) == n { ret true }
    ret false
}

// IsEven reports whether n is divisible by 2 (including 0 and
// negatives like -4, -2). Equivalent to `(n & 1) == 0`.
fun IsEven(n int) bool {
    if (n & 1) == 0 { ret true }
    ret false
}

// IsOdd reports whether n is NOT divisible by 2. Inverse of
// IsEven. Negative odd numbers (-1, -3, ...) return true.
fun IsOdd(n int) bool {
    if (n & 1) == 1 { ret true }
    ret false
}

// NextEvenInt returns the smallest even integer strictly greater
// than n. n is itself returned + 1 only when n is odd; otherwise
// n + 2. Examples: NextEvenInt(3) = 4, NextEvenInt(4) = 6,
// NextEvenInt(-3) = -2, NextEvenInt(-4) = -2.
fun NextEvenInt(n int) int {
    if IsEven(n) { ret n + 2 }
    ret n + 1
}

// NextOddInt returns the smallest odd integer strictly greater
// than n. NextOddInt(3) = 5, NextOddInt(4) = 5, NextOddInt(-1) = 1.
fun NextOddInt(n int) int {
    if IsOdd(n) { ret n + 2 }
    ret n + 1
}

// PrevEvenInt returns the largest even integer strictly LESS than
// n. Symmetric counterpart to NextEvenInt. Examples:
// PrevEvenInt(5) = 4, PrevEvenInt(4) = 2, PrevEvenInt(-3) = -4.
fun PrevEvenInt(n int) int {
    if IsEven(n) { ret n - 2 }
    ret n - 1
}

// PrevOddInt returns the largest odd integer strictly LESS than n.
fun PrevOddInt(n int) int {
    if IsOdd(n) { ret n - 2 }
    ret n - 1
}

// IsMultipleOf reports whether a is an exact multiple of b — i.e.
// b divides a. b must be != 0; b == 0 returns false (no integer is
// divisible by 0). 0 is a multiple of every non-zero b. Useful for
// alignment checks, "every k-th item" predicates.
fun IsMultipleOf(a int, b int) bool {
    if b == 0 { ret false }
    if (a % b) == 0 { ret true }
    ret false
}

// SumDigits returns the sum of base-10 digits of |n|. The sign is
// dropped: SumDigits(-123) == SumDigits(123) == 6. SumDigits(0) is
// 0. Useful for divisibility checks (3 divides n iff 3 divides
// SumDigits(n), recursively), Harshad/Niven number tests, casting
// out nines.
fun SumDigits(n int) int {
    var v int = n
    if v < 0 { v = -v }
    var s int = 0
    if v == 0 { ret 0 }
    for v > 0 {
        s = s + (v % 10)
        v = v / 10
    }
    ret s
}

// ReverseDigits returns n with its base-10 digits reversed. The
// sign is preserved: ReverseDigits(-123) == -321. Trailing zeros in
// the input become leading zeros in the reverse, which then drop:
// ReverseDigits(120) == 21. ReverseDigits(0) == 0. Overflow is
// possible only near the int64 limits; for typical use it stays
// within range.
fun ReverseDigits(n int) int {
    var sign int = 1
    var v int = n
    if v < 0 { sign = -1; v = -v }
    var r int = 0
    for v > 0 {
        r = r * 10 + (v % 10)
        v = v / 10
    }
    ret r * sign
}
