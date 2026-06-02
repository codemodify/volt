// Package slices: type-specific helpers for the common slice
// shapes. Volt doesn't yet have generics, so the surface is paired
// `IntsXxx` / `StringsXxx` instead of `Xxx[T]`.
//
// Mutating helpers (`ReverseInts`, `ReverseStrings`) return the slice
// so callers can rebind across the ownership move:
//   a = slices.ReverseInts(a)

package slices

import "crypto/rand"
import "strconv"
import "sort"

// ContainsAnyInt reports whether at least one element of `candidates`
// appears in s. Returns false on either empty input. O(n*m) worst
// case (linear scan per candidate); for many candidates against a
// large s, build a `map[string]bool` of s first via Itoa keys.
fun ContainsAnyInt(s []int, candidates []int) bool {
    var n int = len(s)
    var m int = len(candidates)
    for i := 0; i < m; i++ {
        var v int = candidates[i]
        for j := 0; j < n; j++ {
            if s[j] == v { ret true }
        }
    }
    ret false
}

// ContainsAnyString reports whether at least one element of
// `candidates` appears in s. Returns false on either empty input.
fun ContainsAnyString(s []string, candidates []string) bool {
    var n int = len(s)
    var m int = len(candidates)
    for i := 0; i < m; i++ {
        var v string = candidates[i]
        for j := 0; j < n; j++ {
            if s[j] == v { ret true }
        }
    }
    ret false
}

// UpsertInt appends v to s only if v is not already present.
// Returns a fresh slice (caller rebinds: `s = UpsertInt(s, v)`).
// Useful for maintaining a set-like collection over a []int —
// idempotent inserts without dropping the original order.
fun UpsertInt(s []int, v int) []int {
    var n int = len(s)
    var out []int = new(n) []int {}
    for i := 0; i < n; i++ {
        out[i] = s[i]
        if s[i] == v {
            // Already present; finish the copy and return.
            for j := i + 1; j < n; j++ { out[j] = s[j] }
            ret out
        }
    }
    ret append(out, v)
}

// UpsertString is the []string counterpart of UpsertInt.
fun UpsertString(s []string, v string) []string {
    var n int = len(s)
    var out []string = new(n) []string {}
    for i := 0; i < n; i++ {
        out[i] = "" + s[i]
        if s[i] == v {
            for j := i + 1; j < n; j++ { out[j] = "" + s[j] }
            ret out
        }
    }
    ret append(out, "" + v)
}

// ContainsInt reports whether v is present in s.
fun ContainsInt(s []int, v int) bool {
    var n int = len(s)
    for i:=0; i < n; i++ {
        if s[i] == v { ret true }
    }
    ret false
}

// IndexInt returns the position of the first occurrence of v in s,
// or -1 if not present.
fun IndexInt(s []int, v int) int {
    var n int = len(s)
    for i:=0; i < n; i++ {
        if s[i] == v { ret i }
    }
    ret -1
}

// ContainsString reports whether v is present in s (byte-equal).
fun ContainsString(s []string, v string) bool {
    var n int = len(s)
    for i:=0; i < n; i++ {
        if s[i] == v { ret true }
    }
    ret false
}

// IndexString returns the position of the first occurrence of v in s,
// or -1 if not present.
fun IndexString(s []string, v string) int {
    var n int = len(s)
    for i:=0; i < n; i++ {
        if s[i] == v { ret i }
    }
    ret -1
}

// LastIndexInt returns the position of the last occurrence of v in
// s, or -1 if not present. Right-to-left mirror of IndexInt.
fun LastIndexInt(s []int, v int) int {
    for i := len(s) - 1; i >= 0; i-- {
        if s[i] == v { ret i }
    }
    ret -1
}

// LastIndexString returns the position of the last occurrence of v
// in s, or -1 if not present. Right-to-left mirror of IndexString.
fun LastIndexString(s []string, v string) int {
    for i := len(s) - 1; i >= 0; i-- {
        if s[i] == v { ret i }
    }
    ret -1
}

// PadLeftInt returns a fresh slice of length max(n, len(s)). When
// padding is needed (n > len(s)), pad-value `v` is prepended so the
// total length reaches n. When n <= len(s), returns a copy of s
// unchanged. Useful for fixed-width numeric buffer preparation and
// right-aligning data into a sized window.
fun PadLeftInt(s []int, n int, v int) []int {
    var sl int = len(s)
    if n <= sl {
        var copy []int = new(sl) []int {}
        for i := 0; i < sl; i++ { copy[i] = s[i] }
        ret copy
    }
    var out []int = new(n) []int {}
    var padN int = n - sl
    for i := 0; i < padN; i++ { out[i] = v }
    for i := 0; i < sl; i++ { out[padN + i] = s[i] }
    ret out
}

// PadRightInt mirrors PadLeftInt — pad-value `v` is appended so
// the total length reaches n. Useful for left-aligning data into
// a sized window, batching to a fixed length.
fun PadRightInt(s []int, n int, v int) []int {
    var sl int = len(s)
    if n <= sl {
        var copy []int = new(sl) []int {}
        for i := 0; i < sl; i++ { copy[i] = s[i] }
        ret copy
    }
    var out []int = new(n) []int {}
    for i := 0; i < sl; i++ { out[i] = s[i] }
    for i := sl; i < n; i++ { out[i] = v }
    ret out
}

// TrimLeftInt returns a fresh slice with leading occurrences of v
// removed. Empty s returns empty. All elements equal to v returns
// empty. Useful for stripping leading zeros / sentinels / padding.
fun TrimLeftInt(s []int, v int) []int {
    var n int = len(s)
    var start int = 0
    for start < n {
        if s[start] != v { break }
        start = start + 1
    }
    var out []int = new(n - start) []int {}
    for i := start; i < n; i++ { out[i - start] = s[i] }
    ret out
}

// TrimRightInt returns a fresh slice with trailing occurrences of
// v removed. Mirror of TrimLeftInt.
fun TrimRightInt(s []int, v int) []int {
    var n int = len(s)
    var end int = n
    for end > 0 {
        if s[end - 1] != v { break }
        end = end - 1
    }
    var out []int = new(end) []int {}
    for i := 0; i < end; i++ { out[i] = s[i] }
    ret out
}

// TrimInt returns a fresh slice with leading and trailing
// occurrences of v removed. Composes TrimLeftInt + TrimRightInt
// without an intermediate alloc.
fun TrimInt(s []int, v int) []int {
    var n int = len(s)
    var start int = 0
    for start < n {
        if s[start] != v { break }
        start = start + 1
    }
    var end int = n
    for end > start {
        if s[end - 1] != v { break }
        end = end - 1
    }
    var out []int = new(end - start) []int {}
    for i := start; i < end; i++ { out[i - start] = s[i] }
    ret out
}

// TrimLeftString is the []string counterpart of TrimLeftInt —
// strips leading occurrences of v.
fun TrimLeftString(s []string, v string) []string {
    var n int = len(s)
    var start int = 0
    for start < n {
        if s[start] != v { break }
        start = start + 1
    }
    var out []string = new(n - start) []string {}
    for i := start; i < n; i++ { out[i - start] = "" + s[i] }
    ret out
}

// TrimRightString is the []string counterpart of TrimRightInt.
fun TrimRightString(s []string, v string) []string {
    var n int = len(s)
    var end int = n
    for end > 0 {
        if s[end - 1] != v { break }
        end = end - 1
    }
    var out []string = new(end) []string {}
    for i := 0; i < end; i++ { out[i] = "" + s[i] }
    ret out
}

// TrimString is the []string counterpart of TrimInt — strips
// leading and trailing occurrences of v.
fun TrimString(s []string, v string) []string {
    var n int = len(s)
    var start int = 0
    for start < n {
        if s[start] != v { break }
        start = start + 1
    }
    var end int = n
    for end > start {
        if s[end - 1] != v { break }
        end = end - 1
    }
    var out []string = new(end - start) []string {}
    for i := start; i < end; i++ { out[i - start] = "" + s[i] }
    ret out
}

// PadLeftString is the []string counterpart of PadLeftInt — pads
// with value `v` on the left to reach length n.
fun PadLeftString(s []string, n int, v string) []string {
    var sl int = len(s)
    if n <= sl {
        var copy []string = new(sl) []string {}
        for i := 0; i < sl; i++ { copy[i] = "" + s[i] }
        ret copy
    }
    var out []string = new(n) []string {}
    var padN int = n - sl
    for i := 0; i < padN; i++ { out[i] = "" + v }
    for i := 0; i < sl; i++ { out[padN + i] = "" + s[i] }
    ret out
}

// PadRightString is the []string counterpart of PadRightInt.
fun PadRightString(s []string, n int, v string) []string {
    var sl int = len(s)
    if n <= sl {
        var copy []string = new(sl) []string {}
        for i := 0; i < sl; i++ { copy[i] = "" + s[i] }
        ret copy
    }
    var out []string = new(n) []string {}
    for i := 0; i < sl; i++ { out[i] = "" + s[i] }
    for i := sl; i < n; i++ { out[i] = "" + v }
    ret out
}

// HasPrefixInts reports whether s starts with the element-wise
// sequence `prefix`. Empty `prefix` matches any s (vacuous truth).
// `prefix` longer than s returns false. Useful for "is this an
// expected ID sequence start?" and pattern-matching opening bytes
// / tokens / IDs.
fun HasPrefixInts(s []int, prefix []int) bool {
    var ls int = len(s)
    var lp int = len(prefix)
    if lp > ls { ret false }
    for i := 0; i < lp; i++ {
        if s[i] != prefix[i] { ret false }
    }
    ret true
}

// HasSuffixInts reports whether s ends with the element-wise
// sequence `suffix`. Empty `suffix` matches any s. `suffix` longer
// than s returns false.
fun HasSuffixInts(s []int, suffix []int) bool {
    var ls int = len(s)
    var lp int = len(suffix)
    if lp > ls { ret false }
    var off int = ls - lp
    for i := 0; i < lp; i++ {
        if s[off + i] != suffix[i] { ret false }
    }
    ret true
}

// CommonPrefixLenInt returns the length of the longest common
// prefix of a and b. Empty inputs → 0. Bounded by
// min(len(a), len(b)). Useful for trie-like comparisons,
// path-prefix length checks, "how far do these sequences agree?"
// diff heuristics.
fun CommonPrefixLenInt(a []int, b []int) int {
    var na int = len(a)
    var nb int = len(b)
    var n int = na
    if nb < n { n = nb }
    var k int = 0
    for k < n {
        if a[k] != b[k] { break }
        k = k + 1
    }
    ret k
}

// CommonSuffixLenInt returns the length of the longest common
// suffix of a and b. Empty inputs → 0. Bounded by
// min(len(a), len(b)).
fun CommonSuffixLenInt(a []int, b []int) int {
    var na int = len(a)
    var nb int = len(b)
    var n int = na
    if nb < n { n = nb }
    var k int = 0
    for k < n {
        if a[na - 1 - k] != b[nb - 1 - k] { break }
        k = k + 1
    }
    ret k
}

// CommonPrefixLenString is the []string counterpart of
// CommonPrefixLenInt — counts the leading elements where two
// string slices agree element-by-element.
fun CommonPrefixLenString(a []string, b []string) int {
    var na int = len(a)
    var nb int = len(b)
    var n int = na
    if nb < n { n = nb }
    var k int = 0
    for k < n {
        if a[k] != b[k] { break }
        k = k + 1
    }
    ret k
}

// CommonSuffixLenString is the []string counterpart of
// CommonSuffixLenInt.
fun CommonSuffixLenString(a []string, b []string) int {
    var na int = len(a)
    var nb int = len(b)
    var n int = na
    if nb < n { n = nb }
    var k int = 0
    for k < n {
        if a[na - 1 - k] != b[nb - 1 - k] { break }
        k = k + 1
    }
    ret k
}

// HasPrefixStrings is the []string counterpart of HasPrefixInts.
fun HasPrefixStrings(s []string, prefix []string) bool {
    var ls int = len(s)
    var lp int = len(prefix)
    if lp > ls { ret false }
    for i := 0; i < lp; i++ {
        if s[i] != prefix[i] { ret false }
    }
    ret true
}

// HasSuffixStrings is the []string counterpart of HasSuffixInts.
fun HasSuffixStrings(s []string, suffix []string) bool {
    var ls int = len(s)
    var lp int = len(suffix)
    if lp > ls { ret false }
    var off int = ls - lp
    for i := 0; i < lp; i++ {
        if s[off + i] != suffix[i] { ret false }
    }
    ret true
}

// AtOrInt returns s[i] if i is in [0, len(s)), else `defaultValue`.
// Bounds-checked access without the panic / abort path — useful for
// "give me element N if it exists, else fall back" patterns over
// optional positional config, CLI arg lookups, default-tabulated
// values. Negative i is treated as out of bounds.
fun AtOrInt(s []int, i int, defaultValue int) int {
    if i < 0 { ret defaultValue }
    if i >= len(s) { ret defaultValue }
    ret s[i]
}

// AtOrString is the []string counterpart of AtOrInt.
fun AtOrString(s []string, i int, defaultValue string) string {
    if i < 0 { ret defaultValue }
    if i >= len(s) { ret defaultValue }
    ret "" + s[i]
}

// GatherInt returns a new slice containing `s[indices[i]]` for each
// i, in order. Out-of-bounds indices (negative or >= len(s)) emit 0
// in the corresponding output slot — total function, no error path.
// Useful for reordering / re-projection by a precomputed index list
// (e.g. `SortIndicesInt(x)` + `Gather(x, idx)` to materialize the
// sorted view), columnar lookups, sampling at specific positions.
fun GatherInt(s []int, indices []int) []int {
    var n int = len(indices)
    var sl int = len(s)
    var out []int = new(n) []int {}
    for i := 0; i < n; i++ {
        var idx int = indices[i]
        if idx < 0 { continue }
        if idx >= sl { continue }
        out[i] = s[idx]
    }
    ret out
}

// SameMultisetInt reports whether `a` and `b` contain the same
// values with the same multiplicities (order ignored). Equivalent
// to `IsAnagram` for ints — like comparing two histograms. Length
// mismatch is an immediate false. O(n + distinct) via two
// `map[string]int` tallies. Useful for unordered-equality testing
// (deterministic-shuffle verification, multiset diff).
fun SameMultisetInt(a []int, b []int) bool {
    var na int = len(a)
    var nb int = len(b)
    if na != nb { ret false }
    var counts map[string]int = new map[string]int
    for i := 0; i < na; i++ {
        var k string = strconv.Itoa(a[i])
        counts[k] = counts[k] + 1
    }
    for i := 0; i < nb; i++ {
        var k string = strconv.Itoa(b[i])
        counts[k] = counts[k] - 1
    }
    for _, v := range counts {
        if v != 0 { ret false }
    }
    ret true
}

// SameMultisetString is the []string counterpart of SameMultisetInt.
fun SameMultisetString(a []string, b []string) bool {
    var na int = len(a)
    var nb int = len(b)
    if na != nb { ret false }
    var counts map[string]int = new map[string]int
    for i := 0; i < na; i++ {
        var k string = "" + a[i]
        counts[k] = counts[k] + 1
    }
    for i := 0; i < nb; i++ {
        var k string = "" + b[i]
        counts[k] = counts[k] - 1
    }
    for _, v := range counts {
        if v != 0 { ret false }
    }
    ret true
}

// GatherString is the []string counterpart of GatherInt. Out-of-
// bounds indices emit "" in the corresponding slot.
fun GatherString(s []string, indices []int) []string {
    var n int = len(indices)
    var sl int = len(s)
    var out []string = new(n) []string {}
    for i := 0; i < n; i++ {
        var idx int = indices[i]
        if idx < 0 { continue }
        if idx >= sl { continue }
        out[i] = "" + s[idx]
    }
    ret out
}

// FirstInt returns the first element of s and true, or (0, false)
// if s is empty. The safe-access primitive — avoids the
// `if len(s) > 0 { x := s[0] }` guard at every call site.
fun FirstInt(s []int) (int, bool) {
    if len(s) == 0 { ret 0, false }
    ret s[0], true
}

// LastInt returns the last element of s and true, or (0, false)
// if s is empty. Counterpart to FirstInt.
fun LastInt(s []int) (int, bool) {
    var n int = len(s)
    if n == 0 { ret 0, false }
    ret s[n - 1], true
}

// FirstString returns the first element of s and true, or
// ("", false) if s is empty. The []string counterpart of FirstInt.
fun FirstString(s []string) (string, bool) {
    if len(s) == 0 { ret "", false }
    ret "" + s[0], true
}

// LastString returns the last element of s and true, or ("", false)
// if s is empty. Counterpart to FirstString.
fun LastString(s []string) (string, bool) {
    var n int = len(s)
    if n == 0 { ret "", false }
    ret "" + s[n - 1], true
}

// ReverseInts reverses s in place and returns it for rebinding.
fun ReverseInts(s []int) []int {
    var n int = len(s)
    var i int = 0
    var j int = n - 1
    for i < j {
        var t int = s[i]; s[i] = s[j]; s[j] = t
        i = i + 1
        j = j - 1
    }
    ret s
}

// ReverseStrings reverses s in place and returns it for rebinding.
fun ReverseStrings(s []string) []string {
    var n int = len(s)
    var i int = 0
    var j int = n - 1
    for i < j {
        var t string = s[i]; s[i] = s[j]; s[j] = t
        i = i + 1
        j = j - 1
    }
    ret s
}

// SumInts returns the integer sum of s (overflow wraps silently).
fun SumInts(s []int) int {
    var total int = 0
    var n int = len(s)
    for i:=0; i < n; i++ {
        total = total + s[i]
    }
    ret total
}

// PrefixSumInt returns the cumulative-sum prefix table — out[i] is
// the sum of s[0..i] inclusive. Same length as s. Empty slice
// returns empty. Enables O(1) range-sum queries:
// `sum(s[i..j]) == prefix[j] - prefix[i-1]` (with `prefix[-1] = 0`).
// Useful for prefix-sum sliding-window aggregates, range-sum DP.
fun PrefixSumInt(s []int) []int {
    var n int = len(s)
    var out []int = new(n) []int {}
    var running int = 0
    for i := 0; i < n; i++ {
        running = running + s[i]
        out[i] = running
    }
    ret out
}

// PairwiseSumInt returns the slice of adjacent-pair sums:
// out[i] = s[i] + s[i+1]. Length = max(0, len(s) - 1). Useful for
// integration-like cumulative aggregates, edge-weight summing over
// path arrays.
fun PairwiseSumInt(s []int) []int {
    var n int = len(s)
    if n < 2 { ret new(0) []int {} }
    var out []int = new(n - 1) []int {}
    for i := 0; i < n - 1; i++ {
        out[i] = s[i] + s[i + 1]
    }
    ret out
}

// PairwiseMaxInt returns the slice of adjacent-pair maxima:
// out[i] = max(s[i], s[i+1]). Length = max(0, len(s) - 1). Useful
// for pointwise envelope construction, sliding-max with k=2.
fun PairwiseMaxInt(s []int) []int {
    var n int = len(s)
    if n < 2 { ret new(0) []int {} }
    var out []int = new(n - 1) []int {}
    for i := 0; i < n - 1; i++ {
        if s[i] >= s[i + 1] { out[i] = s[i] } else { out[i] = s[i + 1] }
    }
    ret out
}

// PairwiseMinInt returns the slice of adjacent-pair minima:
// out[i] = min(s[i], s[i+1]). Length = max(0, len(s) - 1).
// Counterpart to PairwiseMaxInt — pointwise lower-envelope.
fun PairwiseMinInt(s []int) []int {
    var n int = len(s)
    if n < 2 { ret new(0) []int {} }
    var out []int = new(n - 1) []int {}
    for i := 0; i < n - 1; i++ {
        if s[i] <= s[i + 1] { out[i] = s[i] } else { out[i] = s[i + 1] }
    }
    ret out
}

// PairwiseAvgInt returns the slice of adjacent-pair integer
// averages: `(s[i] + s[i+1]) / 2` via the overflow-safe form
// `s[i] + (s[i+1] - s[i]) / 2` (same trick as MidpointInt). Floor
// toward zero per volt's int division.
fun PairwiseAvgInt(s []int) []int {
    var n int = len(s)
    if n < 2 { ret new(0) []int {} }
    var out []int = new(n - 1) []int {}
    for i := 0; i < n - 1; i++ {
        out[i] = s[i] + (s[i + 1] - s[i]) / 2
    }
    ret out
}

// DifferencesInt returns the slice of adjacent-pair differences:
// out[i] = s[i+1] - s[i]. Result has length max(0, len(s) - 1).
// Discrete derivative of a sample sequence. Useful for gap analysis,
// monotonicity checking, derivative-style transforms.
fun DifferencesInt(s []int) []int {
    var n int = len(s)
    if n < 2 { ret new(0) []int {} }
    var out []int = new(n - 1) []int {}
    for i := 0; i < n - 1; i++ {
        out[i] = s[i + 1] - s[i]
    }
    ret out
}

// IsMonotonicInt reports whether s is non-decreasing OR non-
// increasing. Returns true for slices of length 0 or 1 (vacuously
// monotonic). Distinct from `IsStrictlyIncreasing` / `IsStrictly-
// Decreasing` — equal-adjacent values are tolerated. Useful for
// "this series goes one way" checks without insisting on strict.
fun IsMonotonicInt(s []int) bool {
    var n int = len(s)
    if n < 2 { ret true }
    var nondec bool = true
    var noninc bool = true
    for i := 1; i < n; i++ {
        if s[i] < s[i - 1] { nondec = false }
        if s[i] > s[i - 1] { noninc = false }
    }
    if nondec { ret true }
    if noninc { ret true }
    ret false
}

// AddInt returns a fresh slice with element-wise sum of a and b.
// Result length = min(len(a), len(b)) — extra elements in the
// longer slice are dropped. Useful for: vector addition, paired
// counter merging, residual computation. Overflow wraps silently.
fun AddInt(a []int, b []int) []int {
    var na int = len(a)
    var nb int = len(b)
    var n int = na
    if nb < n { n = nb }
    var out []int = new(n) []int {}
    for i := 0; i < n; i++ {
        out[i] = a[i] + b[i]
    }
    ret out
}

// ZipWithInt returns a fresh slice with element-wise application of
// `fn(a[i], b[i])`. Result length = min(len(a), len(b)) — extra
// elements dropped. Generalizes AddInt / SubInt / MulInt to any
// pairwise reduction. Useful for: vector dot intermediate (then
// reduce-sum), bit-OR / bit-AND pairs, custom blend / mix ops.
fun ZipWithInt(a []int, b []int, fn fun(int, int) int) []int {
    var na int = len(a)
    var nb int = len(b)
    var n int = na
    if nb < n { n = nb }
    var out []int = new(n) []int {}
    for i := 0; i < n; i++ {
        out[i] = fn(a[i], b[i])
    }
    ret out
}

// ZipWithString returns a fresh `[]string` with element-wise
// application of `fn(a[i], b[i])`. Counterpart to ZipWithInt for
// string slices — useful for "format each pair" patterns
// (`"k=v"`-style joins, concatenation, custom diff display).
// Result length = `min(len(a), len(b))`.
fun ZipWithString(a []string, b []string, fn fun(string, string) string) []string {
    var na int = len(a)
    var nb int = len(b)
    var n int = na
    if nb < n { n = nb }
    var out []string = new(n) []string {}
    for i := 0; i < n; i++ {
        out[i] = fn(a[i], b[i])
    }
    ret out
}

// RankInt returns the competition rank of each element of s. The
// smallest value gets rank 1; ties share their rank (e.g. two
// elements tied for first both get rank 1, and the next distinct
// value gets rank 3 — "1, 1, 3" style). Result length equals input.
// Empty slice returns empty. O(n²) — for n large enough that
// performance matters, callers should sort + walk instead.
fun RankInt(s []int) []int {
    var n int = len(s)
    var out []int = new(n) []int {}
    for i := 0; i < n; i++ {
        var r int = 1
        for j := 0; j < n; j++ {
            if s[j] < s[i] { r = r + 1 }
        }
        out[i] = r
    }
    ret out
}

// IsPermutationInt reports whether s is a permutation of {1, 2, ...,
// len(s)}. Each value in 1..n must appear exactly once. Empty slice
// returns true (vacuous). O(n) via a seen-bitmap. Useful for puzzle
// validation, anagram-of-numbers checks.
fun IsPermutationInt(s []int) bool {
    var n int = len(s)
    if n == 0 { ret true }
    var seen []bool = new(n) []bool {}
    for i := 0; i < n; i++ {
        var v int = s[i]
        if v < 1 { ret false }
        if v > n { ret false }
        if seen[v - 1] { ret false }
        seen[v - 1] = true
    }
    ret true
}

// SquareInt returns a fresh slice with every element squared
// (`s[i] * s[i]`). Length preserved. Overflow wraps silently.
// Useful for: SSE / variance precomputation, energy / power
// transforms, magnitude-squared distance metrics.
fun SquareInt(s []int) []int {
    var n int = len(s)
    var out []int = new(n) []int {}
    for i := 0; i < n; i++ {
        out[i] = s[i] * s[i]
    }
    ret out
}

// SignInt returns a fresh slice mapping each element to -1 / 0 / 1
// based on its sign. Useful for: extracting direction-only series
// from signed data, building selector masks from comparisons,
// step-function thresholding.
fun SignInt(s []int) []int {
    var n int = len(s)
    var out []int = new(n) []int {}
    for i := 0; i < n; i++ {
        if s[i] > 0 { out[i] = 1 }
        if s[i] < 0 { out[i] = -1 }
    }
    ret out
}

// NegateInt returns a fresh slice with the sign flipped on every
// element (`-s[i]`). Length preserved; original unchanged. Useful
// for: flipping the direction of a delta series, "subtract these
// from running total" prep, sign-inversion in pair arithmetic.
fun NegateInt(s []int) []int {
    var n int = len(s)
    var out []int = new(n) []int {}
    for i := 0; i < n; i++ {
        out[i] = -s[i]
    }
    ret out
}

// AbsValuesInt returns a fresh slice with the absolute value of
// every element. Counterpart to NegateInt. Useful for: magnitude-
// only views of signed data, distance-like aggregations.
fun AbsValuesInt(s []int) []int {
    var n int = len(s)
    var out []int = new(n) []int {}
    for i := 0; i < n; i++ {
        var v int = s[i]
        if v < 0 { v = -v }
        out[i] = v
    }
    ret out
}

// SubInt returns a fresh slice with element-wise `a[i] - b[i]`.
// Length = min(len(a), len(b)). Useful for residual / delta vector
// computation between two parallel measurements.
fun SubInt(a []int, b []int) []int {
    var na int = len(a)
    var nb int = len(b)
    var n int = na
    if nb < n { n = nb }
    var out []int = new(n) []int {}
    for i := 0; i < n; i++ {
        out[i] = a[i] - b[i]
    }
    ret out
}

// MulInt returns the Hadamard (element-wise) product of a and b.
// Length = min(len(a), len(b)). Useful for weighted masks (multiply
// values by a 0/1 selector), gain application, point-wise vector
// scaling. Overflow wraps silently.
fun MulInt(a []int, b []int) []int {
    var na int = len(a)
    var nb int = len(b)
    var n int = na
    if nb < n { n = nb }
    var out []int = new(n) []int {}
    for i := 0; i < n; i++ {
        out[i] = a[i] * b[i]
    }
    ret out
}

// DotInt returns the inner / dot product of a and b: the sum of
// element-wise products over the first min(len(a), len(b))
// positions. Empty operand → 0. Useful for: vector projection,
// weighted sums, similarity / correlation primitives.
fun DotInt(a []int, b []int) int {
    var na int = len(a)
    var nb int = len(b)
    var n int = na
    if nb < n { n = nb }
    var total int = 0
    for i := 0; i < n; i++ {
        total = total + a[i] * b[i]
    }
    ret total
}

// ScaleInt returns a fresh slice with every element multiplied by
// factor. Length preserved. Useful for unit conversion (ms → ns),
// signal scaling, percent → permille transforms. Overflow wraps
// silently per int64 semantics.
fun ScaleInt(s []int, factor int) []int {
    var n int = len(s)
    var out []int = new(n) []int {}
    for i := 0; i < n; i++ {
        out[i] = s[i] * factor
    }
    ret out
}

// AddVecInt returns a fresh slice containing a[i] + b[i] for i in
// [0, min(len(a), len(b))). The longer-input tail is silently
// dropped — caller is responsible for length matching. Empty
// inputs return empty. Overflow wraps silently. Useful for
// time-series superposition (signal A + signal B), running-total
// merges, position-wise vector addition.
fun AddVecInt(a []int, b []int) []int {
    var na int = len(a)
    var nb int = len(b)
    var n int = na
    if nb < n { n = nb }
    var out []int = new(n) []int {}
    for i := 0; i < n; i++ {
        out[i] = a[i] + b[i]
    }
    ret out
}

// SubVecInt returns a fresh slice containing a[i] - b[i] for i in
// [0, min(len(a), len(b))). Same length-handling rules as
// AddVecInt. Useful for time-series differences (today - yesterday),
// residual signals, displacement vectors.
fun SubVecInt(a []int, b []int) []int {
    var na int = len(a)
    var nb int = len(b)
    var n int = na
    if nb < n { n = nb }
    var out []int = new(n) []int {}
    for i := 0; i < n; i++ {
        out[i] = a[i] - b[i]
    }
    ret out
}

// MulVecInt returns a fresh slice containing a[i] * b[i] for i in
// [0, min(len(a), len(b))) — element-wise (Hadamard) product.
// Distinct from DotProductInt which sums the products. Useful for
// weighted-channel scaling and masking (multiply by 0/1 mask).
fun MulVecInt(a []int, b []int) []int {
    var na int = len(a)
    var nb int = len(b)
    var n int = na
    if nb < n { n = nb }
    var out []int = new(n) []int {}
    for i := 0; i < n; i++ {
        out[i] = a[i] * b[i]
    }
    ret out
}

// ClampEachInt returns a fresh slice where every element is clamped
// to [lo, hi] using math.ClampInt semantics. Length preserved. If
// hi < lo (degenerate range) every element is replaced with lo —
// matches ClampInt's behavior for the degenerate case. Useful for
// saturating numeric ranges (audio dB, color channels, gauge
// readings) without writing the obvious for-loop at every call site.
fun ClampEachInt(s []int, lo int, hi int) []int {
    var n int = len(s)
    var out []int = new(n) []int {}
    for i := 0; i < n; i++ {
        var v int = s[i]
        if hi < lo {
            out[i] = lo
        } else {
            if v < lo { v = lo }
            if v > hi { v = hi }
            out[i] = v
        }
    }
    ret out
}

// ShiftInt returns a fresh slice with offset added to every
// element. Length preserved. Useful for re-basing index arrays,
// rendering coordinate shifts, time-offset adjustment.
fun ShiftInt(s []int, offset int) []int {
    var n int = len(s)
    var out []int = new(n) []int {}
    for i := 0; i < n; i++ {
        out[i] = s[i] + offset
    }
    ret out
}

// PrefixProductInt returns the cumulative-product prefix table —
// out[i] is the product of s[0..i] inclusive. Same length as s.
// Empty slice returns empty. Overflow wraps silently per int64
// semantics. Useful for range-product queries (where any prefix
// has no zeros): `product(s[i..j]) == prefix[j] / prefix[i-1]`.
// When zeros are present, division-based range queries fail —
// caller's responsibility to validate.
fun PrefixProductInt(s []int) []int {
    var n int = len(s)
    var out []int = new(n) []int {}
    if n == 0 { ret out }
    var running int = 1
    for i := 0; i < n; i++ {
        running = running * s[i]
        out[i] = running
    }
    ret out
}

// SuffixProductInt returns the suffix-product table — out[i] is the
// product of s[i..len-1] inclusive. Symmetric to PrefixProductInt.
fun SuffixProductInt(s []int) []int {
    var n int = len(s)
    var out []int = new(n) []int {}
    if n == 0 { ret out }
    var running int = 1
    for i := n - 1; i >= 0; i = i - 1 {
        running = running * s[i]
        out[i] = running
    }
    ret out
}

// TopNInt returns the n largest elements of s in descending order.
// Stable for ties (relative order from s preserved among equals).
// n <= 0 or empty s returns empty. n >= len(s) returns all of s
// sorted descending. O(n²) — for small n this is the right
// algorithm; callers with hot paths and large n should sort.
fun TopNInt(s []int, n int) []int {
    var ns int = len(s)
    if n <= 0 { ret new(0) []int {} }
    if ns == 0 { ret new(0) []int {} }
    var k int = n
    if k > ns { k = ns }
    var taken []bool = new(ns) []bool {}
    var out []int = new(k) []int {}
    for round := 0; round < k; round++ {
        var bestIdx int = -1
        for i := 0; i < ns; i++ {
            if taken[i] { continue }
            if bestIdx < 0 { bestIdx = i; continue }
            if s[i] > s[bestIdx] { bestIdx = i }
        }
        taken[bestIdx] = true
        out[round] = s[bestIdx]
    }
    ret out
}

// IndicesOfTopNInt returns the indices (into the original s) of the
// n largest elements, ordered by value descending. Same selection
// loop as TopNInt — only the recorded output differs. The companion
// to TopNInt for callers who have a PARALLEL slice they want to
// project alongside (typical use: labels []string + counts []int →
// take labels by the returned indices to render a top-N dashboard).
// Empty / n<=0 returns empty. n>len(s) clamps. Stable tie-break
// (earliest index wins on ties).
fun IndicesOfTopNInt(s []int, n int) []int {
    var ns int = len(s)
    if n <= 0 { ret new(0) []int {} }
    if ns == 0 { ret new(0) []int {} }
    var k int = n
    if k > ns { k = ns }
    var taken []bool = new(ns) []bool {}
    var out []int = new(k) []int {}
    for round := 0; round < k; round++ {
        var bestIdx int = -1
        for i := 0; i < ns; i++ {
            if taken[i] { continue }
            if bestIdx < 0 { bestIdx = i; continue }
            if s[i] > s[bestIdx] { bestIdx = i }
        }
        taken[bestIdx] = true
        out[round] = bestIdx
    }
    ret out
}

// BottomNInt returns the n smallest elements of s in ascending order.
// Mirrors TopNInt. Empty / n<=0 returns empty.
fun BottomNInt(s []int, n int) []int {
    var ns int = len(s)
    if n <= 0 { ret new(0) []int {} }
    if ns == 0 { ret new(0) []int {} }
    var k int = n
    if k > ns { k = ns }
    var taken []bool = new(ns) []bool {}
    var out []int = new(k) []int {}
    for round := 0; round < k; round++ {
        var bestIdx int = -1
        for i := 0; i < ns; i++ {
            if taken[i] { continue }
            if bestIdx < 0 { bestIdx = i; continue }
            if s[i] < s[bestIdx] { bestIdx = i }
        }
        taken[bestIdx] = true
        out[round] = s[bestIdx]
    }
    ret out
}

// KthSmallestInt returns the k-th smallest element of s (0-indexed:
// k=0 is the min, k=len(s)-1 is the max). Equivalent to
// `sort(s)[k]` but without exposing a sorted-copy alloc to the
// caller — sorts internally, doesn't mutate s. k out of range
// returns 0; empty s returns 0. O(n²) via the package insertion
// sort. Useful for "find the median / quartile / N-th-place"
// selection without explicit Percentile arithmetic.
fun KthSmallestInt(s []int, k int) int {
    var n int = len(s)
    if n == 0 { ret 0 }
    if k < 0 { ret 0 }
    if k >= n { ret 0 }
    var copyS []int = new(n) []int {}
    for i := 0; i < n; i++ {
        copyS[i] = s[i]
    }
    copyS = sort.IntsAsc(copyS)
    ret copyS[k]
}

// KthLargestInt returns the k-th largest element of s (0-indexed:
// k=0 is the max, k=len(s)-1 is the min). Companion to
// KthSmallestInt — equivalent to `KthSmallestInt(s, len(s)-1-k)`
// but spelled directly for "top-K-th" use cases (silver medal,
// 5th-best score, etc.).
fun KthLargestInt(s []int, k int) int {
    var n int = len(s)
    if n == 0 { ret 0 }
    if k < 0 { ret 0 }
    if k >= n { ret 0 }
    var copyS []int = new(n) []int {}
    for i := 0; i < n; i++ {
        copyS[i] = s[i]
    }
    copyS = sort.IntsAsc(copyS)
    ret copyS[n - 1 - k]
}

// TopNString is the []string counterpart of TopNInt. Order:
// descending byte-wise lex compare (via shared stringLess).
fun TopNString(s []string, n int) []string {
    var ns int = len(s)
    if n <= 0 { ret new(0) []string {} }
    if ns == 0 { ret new(0) []string {} }
    var k int = n
    if k > ns { k = ns }
    var taken []bool = new(ns) []bool {}
    var out []string = new(k) []string {}
    for round := 0; round < k; round++ {
        var bestIdx int = -1
        for i := 0; i < ns; i++ {
            if taken[i] { continue }
            if bestIdx < 0 { bestIdx = i; continue }
            if stringLess(s[bestIdx], s[i]) { bestIdx = i }
        }
        taken[bestIdx] = true
        out[round] = "" + s[bestIdx]
    }
    ret out
}

// BottomNString is the []string counterpart of BottomNInt — n
// smallest in ascending lex order.
fun BottomNString(s []string, n int) []string {
    var ns int = len(s)
    if n <= 0 { ret new(0) []string {} }
    if ns == 0 { ret new(0) []string {} }
    var k int = n
    if k > ns { k = ns }
    var taken []bool = new(ns) []bool {}
    var out []string = new(k) []string {}
    for round := 0; round < k; round++ {
        var bestIdx int = -1
        for i := 0; i < ns; i++ {
            if taken[i] { continue }
            if bestIdx < 0 { bestIdx = i; continue }
            if stringLess(s[i], s[bestIdx]) { bestIdx = i }
        }
        taken[bestIdx] = true
        out[round] = "" + s[bestIdx]
    }
    ret out
}

// KthSmallestString returns the k-th smallest element of s under
// byte-wise lex order (0-indexed: k=0 is the min, k=len(s)-1 is
// the max). Sorts a copy via sort.StringsAsc, doesn't mutate s.
// k out of range returns "". Empty s returns "". String
// counterpart of KthSmallestInt.
fun KthSmallestString(s []string, k int) string {
    var n int = len(s)
    if n == 0 { ret "" }
    if k < 0 { ret "" }
    if k >= n { ret "" }
    var copyS []string = new(n) []string {}
    for i := 0; i < n; i++ {
        copyS[i] = "" + s[i]
    }
    copyS = sort.StringsAsc(copyS)
    ret "" + copyS[k]
}

// KthLargestString returns the k-th largest element of s under
// byte-wise lex order (0-indexed: k=0 is the max, k=len(s)-1 is
// the min). String counterpart of KthLargestInt — useful for
// "second-newest log file" / "third-tallest username" picks
// without explicit reverse sorting.
fun KthLargestString(s []string, k int) string {
    var n int = len(s)
    if n == 0 { ret "" }
    if k < 0 { ret "" }
    if k >= n { ret "" }
    var copyS []string = new(n) []string {}
    for i := 0; i < n; i++ {
        copyS[i] = "" + s[i]
    }
    copyS = sort.StringsAsc(copyS)
    ret "" + copyS[n - 1 - k]
}

// PrefixMaxInt returns a "best so far" running maximum — out[i] is
// max(s[0..i]) inclusive. Same length as s. Empty slice returns
// empty. Result is monotonically non-decreasing. Useful for stock-
// price high-watermark, score-progress visualizations, monotonic-
// stack preprocessing.
fun PrefixMaxInt(s []int) []int {
    var n int = len(s)
    var out []int = new(n) []int {}
    if n == 0 { ret out }
    var cur int = s[0]
    out[0] = cur
    for i := 1; i < n; i++ {
        if s[i] > cur { cur = s[i] }
        out[i] = cur
    }
    ret out
}

// PrefixMinInt returns a "worst so far" running minimum — out[i] is
// min(s[0..i]) inclusive. Symmetric to PrefixMaxInt; result is
// monotonically non-increasing.
fun PrefixMinInt(s []int) []int {
    var n int = len(s)
    var out []int = new(n) []int {}
    if n == 0 { ret out }
    var cur int = s[0]
    out[0] = cur
    for i := 1; i < n; i++ {
        if s[i] < cur { cur = s[i] }
        out[i] = cur
    }
    ret out
}

// SuffixSumInt returns the suffix-sum table — out[i] is the sum of
// s[i..len-1] inclusive. Same length as s. Empty slice returns
// empty. Symmetric counterpart to PrefixSumInt.
fun SuffixSumInt(s []int) []int {
    var n int = len(s)
    var out []int = new(n) []int {}
    if n == 0 { ret out }
    var running int = 0
    for i := n - 1; i >= 0; i = i - 1 {
        running = running + s[i]
        out[i] = running
    }
    ret out
}

// MinInts returns the smallest element of s. Empty slice returns 0
// (caller should check len(s) before relying on the result).
fun MinInts(s []int) int {
    var n int = len(s)
    if n == 0 { ret 0 }
    var best int = s[0]
    for i:=1; i < n; i++ {
        if s[i] < best { best = s[i] }
    }
    ret best
}

// MaxInts returns the largest element of s. Empty slice returns 0.
fun MaxInts(s []int) int {
    var n int = len(s)
    if n == 0 { ret 0 }
    var best int = s[0]
    for i:=1; i < n; i++ {
        if s[i] > best { best = s[i] }
    }
    ret best
}

// MinMaxInts returns (min, max) of s in a single pass — cheaper
// than calling MinInts then MaxInts (one walk, ~2 compares per
// element instead of 2 walks of 1 compare each). Empty slice
// returns (0, 0). Useful when the caller needs both extremes
// (range-of, normalize-to range, sparkline scaling).
fun MinMaxInts(s []int) (int, int) {
    var n int = len(s)
    if n == 0 { ret 0, 0 }
    var lo int = s[0]
    var hi int = s[0]
    for i := 1; i < n; i++ {
        var v int = s[i]
        if v < lo { lo = v }
        if v > hi { hi = v }
    }
    ret lo, hi
}

// MinMaxStrings returns (min, max) of s by byte-wise lexicographic
// order in a single pass. Empty slice returns ("", "").
fun MinMaxStrings(s []string) (string, string) {
    var n int = len(s)
    if n == 0 { ret "", "" }
    var lo string = "" + s[0]
    var hi string = "" + s[0]
    for i := 1; i < n; i++ {
        if stringLess(s[i], lo) { lo = "" + s[i] }
        if stringLess(hi, s[i]) { hi = "" + s[i] }
    }
    ret lo, hi
}

// LongestCommonPrefixInt returns the length of the longest prefix
// shared by a and b (count of leading elements that match). 0 when
// the first elements disagree or either is empty. Useful for diff
// algorithms / trie-style indexing of integer-keyed data.
fun LongestCommonPrefixInt(a []int, b []int) int {
    var na int = len(a)
    var nb int = len(b)
    var lim int = na
    if nb < lim { lim = nb }
    var k int = 0
    for k < lim {
        if a[k] != b[k] { break }
        k = k + 1
    }
    ret k
}

// LongestCommonSuffixInt returns the length of the longest suffix
// shared by a and b. Counterpart to LongestCommonPrefixInt.
fun LongestCommonSuffixInt(a []int, b []int) int {
    var na int = len(a)
    var nb int = len(b)
    var lim int = na
    if nb < lim { lim = nb }
    var k int = 0
    for k < lim {
        if a[na - 1 - k] != b[nb - 1 - k] { break }
        k = k + 1
    }
    ret k
}

// LongestCommonPrefixString is the []string counterpart of
// LongestCommonPrefixInt.
fun LongestCommonPrefixString(a []string, b []string) int {
    var na int = len(a)
    var nb int = len(b)
    var lim int = na
    if nb < lim { lim = nb }
    var k int = 0
    for k < lim {
        if a[k] != b[k] { break }
        k = k + 1
    }
    ret k
}

// LongestCommonSuffixString is the []string counterpart of
// LongestCommonSuffixInt.
fun LongestCommonSuffixString(a []string, b []string) int {
    var na int = len(a)
    var nb int = len(b)
    var lim int = na
    if nb < lim { lim = nb }
    var k int = 0
    for k < lim {
        if a[na - 1 - k] != b[nb - 1 - k] { break }
        k = k + 1
    }
    ret k
}

// TakeWhileInt returns the longest prefix of s for which pred is
// true on every element. Stops at (and excludes) the first element
// where pred is false. Empty when pred fails on s[0]. Useful for
// parsing "while still numeric" / "while still ascending" prefixes.
fun TakeWhileInt(s []int, pred fun(x int) bool) []int {
    var n int = len(s)
    var stop int = n
    for i := 0; i < n; i++ {
        if !pred(s[i]) { stop = i; break }
    }
    var out []int = new(stop) []int {}
    for i := 0; i < stop; i++ { out[i] = s[i] }
    ret out
}

// DropWhileInt returns the suffix of s starting at the first
// element where pred is false. Complement of TakeWhileInt — together
// they partition s. Useful for stripping leading sentinels / zeros /
// whitespace-equivalents.
fun DropWhileInt(s []int, pred fun(x int) bool) []int {
    var n int = len(s)
    var start int = n
    for i := 0; i < n; i++ {
        if !pred(s[i]) { start = i; break }
    }
    var out []int = new(n - start) []int {}
    for i := 0; i < (n - start); i++ { out[i] = s[start + i] }
    ret out
}

// TakeWhileString is the []string counterpart of TakeWhileInt.
fun TakeWhileString(s []string, pred fun(x string) bool) []string {
    var n int = len(s)
    var stop int = n
    for i := 0; i < n; i++ {
        if !pred(s[i]) { stop = i; break }
    }
    var out []string = new(stop) []string {}
    for i := 0; i < stop; i++ { out[i] = "" + s[i] }
    ret out
}

// DropWhileString is the []string counterpart of DropWhileInt.
fun DropWhileString(s []string, pred fun(x string) bool) []string {
    var n int = len(s)
    var start int = n
    for i := 0; i < n; i++ {
        if !pred(s[i]) { start = i; break }
    }
    var out []string = new(n - start) []string {}
    for i := 0; i < (n - start); i++ { out[i] = "" + s[start + i] }
    ret out
}

// CountInRangeInt returns the count of elements of s that fall in
// the inclusive range [lo, hi]. Degenerate hi<lo returns 0.
// Empty s returns 0. O(n). Saves the manual FilterInts + len ceremony
// for the common "how many values are in this range?" tally.
fun CountInRangeInt(s []int, lo int, hi int) int {
    if hi < lo { ret 0 }
    var n int = len(s)
    var k int = 0
    for i := 0; i < n; i++ {
        if s[i] >= lo {
            if s[i] <= hi { k = k + 1 }
        }
    }
    ret k
}

// FilterInRangeInt returns a fresh slice containing only the
// elements of s in [lo, hi] (inclusive). Order preserved.
// Degenerate hi<lo returns empty. Doesn't mutate s. O(n) — two-pass
// (count then collect) so the output is exactly sized.
fun FilterInRangeInt(s []int, lo int, hi int) []int {
    if hi < lo { ret new(0) []int {} }
    var n int = len(s)
    var k int = 0
    for i := 0; i < n; i++ {
        if s[i] >= lo {
            if s[i] <= hi { k = k + 1 }
        }
    }
    var out []int = new(k) []int {}
    var idx int = 0
    for i := 0; i < n; i++ {
        if s[i] >= lo {
            if s[i] <= hi {
                out[idx] = s[i]
                idx = idx + 1
            }
        }
    }
    ret out
}

// FilterInts returns a new slice containing the elements of s for
// which keep(x) returns true. Original order preserved.
fun FilterInts(s []int, keep fun(x int) bool) []int {
    var n int = len(s)
    // First pass: count survivors so we can size the result exactly.
    var kept int = 0
    for i:=0; i < n; i++ {
        if keep(s[i]) { kept = kept + 1 }
    }
    var out []int = new(kept) []int {}
    var idx int = 0
    for i:=0; i < n; i++ {
        if keep(s[i]) {
            out[idx] = s[i]
            idx = idx + 1
        }
    }
    ret out
}

// MapInts returns a new slice where each element is fn(s[i]).
// ClampInts returns a fresh slice with each element of s clamped to
// [lo, hi]. Values below lo become lo; values above hi become hi.
// Equivalent to mapping `math.ClampInt(v, lo, hi)` across s.
// Use case: bounding metric streams before display, sanitizing
// noisy sensor data, capping outliers for chart rendering.
fun ClampInts(s []int, lo int, hi int) []int {
    var n int = len(s)
    var out []int = new(n) []int {}
    for i := 0; i < n; i++ {
        var v int = s[i]
        if v < lo { v = lo }
        if v > hi { v = hi }
        out[i] = v
    }
    ret out
}

fun MapInts(s []int, fn fun(x int) int) []int {
    var n int = len(s)
    var out []int = new(n) []int {}
    for i:=0; i < n; i++ {
        out[i] = fn(s[i])
    }
    ret out
}

// AnyInt returns true iff at least one element satisfies pred.
fun AnyInt(s []int, pred fun(x int) bool) bool {
    var n int = len(s)
    for i:=0; i < n; i++ {
        if pred(s[i]) { ret true }
    }
    ret false
}

// AllInt returns true iff every element satisfies pred. Empty slice
// returns true (vacuous truth, matches Go's slices.All-style helpers).
fun AllInt(s []int, pred fun(x int) bool) bool {
    var n int = len(s)
    for i:=0; i < n; i++ {
        if !pred(s[i]) { ret false }
    }
    ret true
}

// NoneInt returns true iff zero elements satisfy pred — the
// complement of AnyInt (`NoneInt(s, p) == !AnyInt(s, p)`). Empty
// slice returns true (vacuous truth). Reads more directly than
// `!AnyInt(...)` at call sites where the negative is the intent —
// "no errors", "no overdue items".
fun NoneInt(s []int, pred fun(x int) bool) bool {
    var n int = len(s)
    for i:=0; i < n; i++ {
        if pred(s[i]) { ret false }
    }
    ret true
}

// FilterStrings is the string counterpart of FilterInts.
fun FilterStrings(s []string, keep fun(x string) bool) []string {
    var n int = len(s)
    var kept int = 0
    for i:=0; i < n; i++ {
        if keep(s[i]) { kept = kept + 1 }
    }
    var out []string = new(kept) []string {}
    var idx int = 0
    for i:=0; i < n; i++ {
        if keep(s[i]) {
            out[idx] = s[i]
            idx = idx + 1
        }
    }
    ret out
}

// MapStrings applies fn to every element and returns a new slice of
// the (possibly different) projected strings.
fun MapStrings(s []string, fn fun(x string) string) []string {
    var n int = len(s)
    var out []string = new(n) []string {}
    for i:=0; i < n; i++ {
        out[i] = fn(s[i])
    }
    ret out
}

// AnyString reports whether any element of s satisfies pred.
fun AnyString(s []string, pred fun(x string) bool) bool {
    var n int = len(s)
    for i:=0; i < n; i++ {
        if pred(s[i]) { ret true }
    }
    ret false
}

// AllString reports whether every element of s satisfies pred.
// Empty slice returns true (vacuous truth).
fun AllString(s []string, pred fun(x string) bool) bool {
    var n int = len(s)
    for i:=0; i < n; i++ {
        if !pred(s[i]) { ret false }
    }
    ret true
}

// NoneString returns true iff zero elements satisfy pred — the
// complement of AnyString. Empty slice returns true (vacuous truth).
// Reads more directly than `!AnyString(...)` when the negative is
// the intent.
fun NoneString(s []string, pred fun(x string) bool) bool {
    var n int = len(s)
    for i:=0; i < n; i++ {
        if pred(s[i]) { ret false }
    }
    ret true
}

// ConcatInts returns a fresh slice containing the elements of a
// followed by the elements of b. Inputs are not modified (the
// underlying buffers may share if either is empty).
fun ConcatInts(a []int, b []int) []int {
    var la int = len(a)
    var lb int = len(b)
    var out []int = new(la + lb) []int {}
    for i:=0; i < la; i++ { out[i] = a[i] }
    for j:=0; j < lb; j++ { out[la + j] = b[j] }
    ret out
}

// ConcatStrings is the []string companion to ConcatInts.
fun ConcatStrings(a []string, b []string) []string {
    var la int = len(a)
    var lb int = len(b)
    var out []string = new(la + lb) []string {}
    for i:=0; i < la; i++ { out[i] = a[i] }
    for j:=0; j < lb; j++ { out[la + j] = b[j] }
    ret out
}

// CountInt returns how many elements of s equal v.
fun CountInt(s []int, v int) int {
    var n int = len(s)
    var c int = 0
    for i:=0; i < n; i++ {
        if s[i] == v { c = c + 1 }
    }
    ret c
}

// CountString returns how many elements of s equal v.
fun CountString(s []string, v string) int {
    var n int = len(s)
    var c int = 0
    for i:=0; i < n; i++ {
        if s[i] == v { c = c + 1 }
    }
    ret c
}

// EqualInts reports whether a and b have the same length and the
// same int values at each index.
fun EqualInts(a []int, b []int) bool {
    var na int = len(a)
    var nb int = len(b)
    if na != nb { ret false }
    for i := 0; i < na; i++ {
        if a[i] != b[i] { ret false }
    }
    ret true
}

// EqualStrings reports whether a and b have the same length and the
// same string values at each index (byte-equal).
fun EqualStrings(a []string, b []string) bool {
    var na int = len(a)
    var nb int = len(b)
    if na != nb { ret false }
    for i := 0; i < na; i++ {
        if a[i] != b[i] { ret false }
    }
    ret true
}

// EqualFuncInt reports whether a and b have the same length and
// `eq(a[i], b[i])` is true for every i. Predicate-based equality —
// useful for fuzzy / approximate matching (e.g. equal-within-
// tolerance for int-encoded fixed-point, equal-mod-N).
fun EqualFuncInt(a []int, b []int, eq fun(int, int) bool) bool {
    var na int = len(a)
    var nb int = len(b)
    if na != nb { ret false }
    for i := 0; i < na; i++ {
        if !eq(a[i], b[i]) { ret false }
    }
    ret true
}

// EqualFuncString reports whether a and b have the same length and
// `eq(a[i], b[i])` is true for every i. String counterpart of
// EqualFuncInt — useful for case-insensitive equality, equal-mod-
// trim, equal-after-normalization checks.
fun EqualFuncString(a []string, b []string, eq fun(string, string) bool) bool {
    var na int = len(a)
    var nb int = len(b)
    if na != nb { ret false }
    for i := 0; i < na; i++ {
        if !eq(a[i], b[i]) { ret false }
    }
    ret true
}

// stringLess reports whether a is lexicographically less than b
// (byte-wise compare; ties broken by shorter wins). String `<` is
// not directly supported by codegen, so the lex-compare is inlined
// — matches the pattern used by sort.StringsAsc.
fun stringLess(a string, b string) bool {
    var la int = len(a)
    var lb int = len(b)
    var m int = la
    if lb < m { m = lb }
    var k int = 0
    for k < m {
        var ai int = a[k] & 255
        var bi int = b[k] & 255
        if ai < bi { ret true }
        if ai > bi { ret false }
        k = k + 1
    }
    // Prefix tie — shorter string is "less".
    if la < lb { ret true }
    ret false
}

// MinString returns the lexicographically smallest string in s, or
// "" if s is empty.
fun MinString(s []string) string {
    var n int = len(s)
    if n == 0 { ret "" }
    var m string = s[0]
    for i := 1; i < n; i++ {
        if stringLess(s[i], m) { m = s[i] }
    }
    ret m
}

// MaxString returns the lexicographically largest string in s, or
// "" if s is empty.
fun MaxString(s []string) string {
    var n int = len(s)
    if n == 0 { ret "" }
    var m string = s[0]
    for i := 1; i < n; i++ {
        if stringLess(m, s[i]) { m = s[i] }
    }
    ret m
}

// IndexFuncInt returns the index of the first element of s for
// which pred(x) is true, or -1 if no element satisfies pred.
fun IndexFuncInt(s []int, pred fun(x int) bool) int {
    var n int = len(s)
    for i := 0; i < n; i++ {
        if pred(s[i]) { ret i }
    }
    ret -1
}

// IndexFuncString returns the index of the first string in s for
// which pred(x) is true, or -1 if no string satisfies pred.
fun IndexFuncString(s []string, pred fun(x string) bool) int {
    var n int = len(s)
    for i := 0; i < n; i++ {
        if pred(s[i]) { ret i }
    }
    ret -1
}

// InsertInt returns a new slice with v inserted at position i.
// Index must be in [0, len(s)]; out-of-range returns s unchanged.
fun InsertInt(s []int, i int, v int) []int {
    var n int = len(s)
    if i < 0 {
        var copy []int = new(n) []int {}
        for k := 0; k < n; k++ { copy[k] = s[k] }
        ret copy
    }
    if i > n {
        var copy []int = new(n) []int {}
        for k := 0; k < n; k++ { copy[k] = s[k] }
        ret copy
    }
    var out []int = new(n + 1) []int {}
    for k := 0; k < i; k++ { out[k] = s[k] }
    out[i] = v
    for k := i; k < n; k++ { out[k+1] = s[k] }
    ret out
}

// DeleteInt returns a new slice with the elements at indices [i, j)
// removed. Out-of-range or i >= j returns a copy of s unchanged.
fun DeleteInt(s []int, i int, j int) []int {
    var n int = len(s)
    if i < 0 { i = 0 }
    if j > n { j = n }
    if i >= j {
        var copy []int = new(n) []int {}
        for k := 0; k < n; k++ { copy[k] = s[k] }
        ret copy
    }
    var removed int = j - i
    var out []int = new(n - removed) []int {}
    for k := 0; k < i; k++ { out[k] = s[k] }
    for k := j; k < n; k++ { out[k - removed] = s[k] }
    ret out
}

// InsertString returns a new slice with v inserted at position i.
fun InsertString(s []string, i int, v string) []string {
    var n int = len(s)
    if i < 0 {
        var copy []string = new(n) []string {}
        for k := 0; k < n; k++ { copy[k] = s[k] }
        ret copy
    }
    if i > n {
        var copy []string = new(n) []string {}
        for k := 0; k < n; k++ { copy[k] = s[k] }
        ret copy
    }
    var out []string = new(n + 1) []string {}
    for k := 0; k < i; k++ { out[k] = s[k] }
    out[i] = v
    for k := i; k < n; k++ { out[k+1] = s[k] }
    ret out
}

// DeleteString returns a new slice with the elements at indices
// [i, j) removed.
fun DeleteString(s []string, i int, j int) []string {
    var n int = len(s)
    if i < 0 { i = 0 }
    if j > n { j = n }
    if i >= j {
        var copy []string = new(n) []string {}
        for k := 0; k < n; k++ { copy[k] = s[k] }
        ret copy
    }
    var removed int = j - i
    var out []string = new(n - removed) []string {}
    for k := 0; k < i; k++ { out[k] = s[k] }
    for k := j; k < n; k++ { out[k - removed] = s[k] }
    ret out
}

// RepeatInt returns a new slice consisting of `count` copies of s
// concatenated end-to-end. Negative or zero count returns an empty
// slice. Mirrors Go 1.23's slices.Repeat for []int.
// FilledInt returns a fresh slice of n copies of v. n<=0 → empty.
// Different from RepeatInt (which tiles a SLICE n times); this fills
// with a single scalar. Useful for: zero-padded buffers, default-
// value initialization, test fixtures. O(n).
fun FilledInt(v int, n int) []int {
    if n <= 0 {
        var empty []int = new(0) []int {}
        ret empty
    }
    var out []int = new(n) []int {}
    for i := 0; i < n; i++ { out[i] = v }
    ret out
}

// FilledString returns a fresh slice of n copies of v. n<=0 → empty.
// Counterpart to FilledInt for []string.
fun FilledString(v string, n int) []string {
    if n <= 0 {
        var empty []string = new(0) []string {}
        ret empty
    }
    var out []string = new(n) []string {}
    for i := 0; i < n; i++ { out[i] = "" + v }
    ret out
}

fun RepeatInt(s []int, count int) []int {
    if count <= 0 {
        var empty []int = new(0) []int {}
        ret empty
    }
    var n int = len(s)
    var total int = n * count
    var out []int = new(total) []int {}
    for c := 0; c < count; c++ {
        var off int = c * n
        for i := 0; i < n; i++ {
            out[off + i] = s[i]
        }
    }
    ret out
}

// InterleaveInts returns `[a[0], b[0], a[1], b[1], ...]`. When the
// inputs differ in length, the common prefix interleaves, then the
// remaining tail of the longer slice is appended. Empty inputs:
// `InterleaveInts(a, [])` returns a copy of a. Useful for merging
// alternating data streams, weaving two parallel lists, "round-robin"
// orderings.
fun InterleaveInts(a []int, b []int) []int {
    var na int = len(a)
    var nb int = len(b)
    var total int = na + nb
    var out []int = new(total) []int {}
    var m int = na
    if nb < m { m = nb }
    for i := 0; i < m; i++ {
        out[2*i] = a[i]
        out[2*i + 1] = b[i]
    }
    if na > m {
        var off int = 2 * m
        for i := m; i < na; i++ {
            out[off + (i - m)] = a[i]
        }
    }
    if nb > m {
        var off int = 2 * m
        for i := m; i < nb; i++ {
            out[off + (i - m)] = b[i]
        }
    }
    ret out
}

// InterleaveStrings is the []string counterpart of InterleaveInts.
fun InterleaveStrings(a []string, b []string) []string {
    var na int = len(a)
    var nb int = len(b)
    var total int = na + nb
    var out []string = new(total) []string {}
    var m int = na
    if nb < m { m = nb }
    for i := 0; i < m; i++ {
        out[2*i] = "" + a[i]
        out[2*i + 1] = "" + b[i]
    }
    if na > m {
        var off int = 2 * m
        for i := m; i < na; i++ {
            out[off + (i - m)] = "" + a[i]
        }
    }
    if nb > m {
        var off int = 2 * m
        for i := m; i < nb; i++ {
            out[off + (i - m)] = "" + b[i]
        }
    }
    ret out
}

// TabulateInt returns `[fn(0), fn(1), ..., fn(n-1)]`. Non-positive
// n returns an empty slice. The functional inverse of a `for` loop
// that builds a list — useful for generating sequences (squares,
// fibonacci first-N, identity, evens/odds, lookup tables).
fun TabulateInt(n int, fn fun(int) int) []int {
    if n <= 0 {
        var empty []int = new(0) []int {}
        ret empty
    }
    var out []int = new(n) []int {}
    for i := 0; i < n; i++ {
        out[i] = fn(i)
    }
    ret out
}

// TabulateString returns `[fn(0), fn(1), ..., fn(n-1)]` as a
// []string. Useful for generating string sequences like labels
// ("row-0", "row-1", ...), padded-index lists, alphabet runs.
fun TabulateString(n int, fn fun(int) string) []string {
    if n <= 0 {
        var empty []string = new(0) []string {}
        ret empty
    }
    var out []string = new(n) []string {}
    for i := 0; i < n; i++ {
        out[i] = fn(i)
    }
    ret out
}

// RepeatString is the []string counterpart of RepeatInt.
fun RepeatString(s []string, count int) []string {
    if count <= 0 {
        var empty []string = new(0) []string {}
        ret empty
    }
    var n int = len(s)
    var total int = n * count
    var out []string = new(total) []string {}
    for c := 0; c < count; c++ {
        var off int = c * n
        for i := 0; i < n; i++ {
            out[off + i] = s[i]
        }
    }
    ret out
}

// FilterMapInt applies `keep` to each element and, when it returns
// true, applies `mapper` to produce the kept result. Combines filter
// + map into a single result allocation (two passes over s — count
// then collect). Volt's function-value types don't currently accept
// multi-return signatures, so the predicate and mapper are passed
// separately rather than as a single `fun(int) (int, bool)` value.
// Useful for "transform-and-skip" patterns.
fun FilterMapInt(s []int, keep fun(int) bool, mapper fun(int) int) []int {
    var n int = len(s)
    var kept int = 0
    for i := 0; i < n; i++ {
        if keep(s[i]) { kept = kept + 1 }
    }
    var out []int = new(kept) []int {}
    var idx int = 0
    for i := 0; i < n; i++ {
        if keep(s[i]) {
            out[idx] = mapper(s[i])
            idx = idx + 1
        }
    }
    ret out
}

// FilterMapString is the []string counterpart of FilterMapInt.
fun FilterMapString(s []string, keep fun(string) bool, mapper fun(string) string) []string {
    var n int = len(s)
    var kept int = 0
    for i := 0; i < n; i++ {
        if keep(s[i]) { kept = kept + 1 }
    }
    var out []string = new(kept) []string {}
    var idx int = 0
    for i := 0; i < n; i++ {
        if keep(s[i]) {
            out[idx] = mapper(s[i])
            idx = idx + 1
        }
    }
    ret out
}

// CompactInt returns a new slice with consecutive duplicate elements
// of s removed. The first occurrence of each run is kept; only
// adjacent duplicates collapse (so `[1, 1, 2, 1]` becomes `[1, 2, 1]`,
// not `[1, 2]`). Mirrors Go 1.21's slices.Compact.
fun CompactInt(s []int) []int {
    var n int = len(s)
    if n == 0 {
        var empty []int = new(0) []int {}
        ret empty
    }
    // First pass: count survivors so the output is exact-size.
    var kept int = 1
    for i := 1; i < n; i++ {
        if s[i] != s[i-1] { kept = kept + 1 }
    }
    var out []int = new(kept) []int {}
    out[0] = s[0]
    var idx int = 1
    for i := 1; i < n; i++ {
        if s[i] != s[i-1] {
            out[idx] = s[i]
            idx = idx + 1
        }
    }
    ret out
}

// CompactString is the []string counterpart of CompactInt.
// DropBlankStrings returns a fresh slice containing only the non-empty
// elements of s. Order preserved. Useful after splitting strings on
// multiple delimiters (where empty fields appear between consecutive
// separators) or filtering user input. Different from CompactString
// which drops adjacent duplicates (any value); this drops only "".
fun DropBlankStrings(s []string) []string {
    var n int = len(s)
    var kept int = 0
    for i := 0; i < n; i++ {
        if len(s[i]) > 0 { kept = kept + 1 }
    }
    var out []string = new(kept) []string {}
    var idx int = 0
    for i := 0; i < n; i++ {
        if len(s[i]) > 0 {
            out[idx] = "" + s[i]
            idx = idx + 1
        }
    }
    ret out
}

fun CompactString(s []string) []string {
    var n int = len(s)
    if n == 0 {
        var empty []string = new(0) []string {}
        ret empty
    }
    var kept int = 1
    for i := 1; i < n; i++ {
        if s[i] != s[i-1] { kept = kept + 1 }
    }
    var out []string = new(kept) []string {}
    out[0] = s[0]
    var idx int = 1
    for i := 1; i < n; i++ {
        if s[i] != s[i-1] {
            out[idx] = s[i]
            idx = idx + 1
        }
    }
    ret out
}

// BinarySearchInt searches the sorted slice s for v and returns the
// position where v is (or would be inserted to keep s sorted) and a
// bool indicating whether v was found. Caller is responsible for
// keeping s sorted ascending — the search is undefined otherwise.
// Mirrors Go 1.21's slices.BinarySearch.
fun BinarySearchInt(s []int, v int) (int, bool) {
    var lo int = 0
    var hi int = len(s)
    for lo < hi {
        var mid int = (lo + hi) / 2
        if s[mid] < v {
            lo = mid + 1
        } else {
            hi = mid
        }
    }
    var found bool = false
    if lo < len(s) {
        if s[lo] == v { found = true }
    }
    ret lo, found
}

// LowerBoundInt returns the leftmost index in the sorted slice s
// where v could be inserted while keeping s sorted. Equivalently,
// the first index i with s[i] >= v (or len(s) if v exceeds every
// element). Caller is responsible for keeping s sorted ascending.
// Mirrors C++'s std::lower_bound.
fun LowerBoundInt(s []int, v int) int {
    var lo int = 0
    var hi int = len(s)
    for lo < hi {
        var mid int = (lo + hi) / 2
        if s[mid] < v {
            lo = mid + 1
        } else {
            hi = mid
        }
    }
    ret lo
}

// UpperBoundInt returns the rightmost-equivalent insertion point —
// the first index i with s[i] > v. Difference from LowerBoundInt
// counts how many elements equal v: `UpperBound(s, v) -
// LowerBound(s, v) == frequency-of-v`. Mirrors C++'s
// std::upper_bound.
fun UpperBoundInt(s []int, v int) int {
    var lo int = 0
    var hi int = len(s)
    for lo < hi {
        var mid int = (lo + hi) / 2
        if s[mid] <= v {
            lo = mid + 1
        } else {
            hi = mid
        }
    }
    ret lo
}

// LowerBoundString is the []string counterpart of LowerBoundInt —
// leftmost insertion point in a byte-wise lex-sorted slice.
fun LowerBoundString(s []string, v string) int {
    var lo int = 0
    var hi int = len(s)
    for lo < hi {
        var mid int = (lo + hi) / 2
        if stringLess(s[mid], v) {
            lo = mid + 1
        } else {
            hi = mid
        }
    }
    ret lo
}

// UpperBoundString is the []string counterpart of UpperBoundInt —
// first index strictly greater than v.
fun UpperBoundString(s []string, v string) int {
    var lo int = 0
    var hi int = len(s)
    for lo < hi {
        var mid int = (lo + hi) / 2
        if stringLess(v, s[mid]) {
            hi = mid
        } else {
            lo = mid + 1
        }
    }
    ret lo
}

// CountSortedInt returns the count of occurrences of v in the
// sorted slice s in O(log n). Equivalent to
// `UpperBoundInt(s, v) - LowerBoundInt(s, v)`. Caller is responsible
// for keeping s sorted ascending. Useful for: frequency lookup
// when you have a pre-sorted index, multiset count operations.
fun CountSortedInt(s []int, v int) int {
    ret UpperBoundInt(s, v) - LowerBoundInt(s, v)
}

// CountSortedString is the []string counterpart of CountSortedInt.
fun CountSortedString(s []string, v string) int {
    ret UpperBoundString(s, v) - LowerBoundString(s, v)
}

// BinarySearchString is the []string counterpart of BinarySearchInt.
// Uses byte-wise lex comparison via the shared stringLess helper.
fun BinarySearchString(s []string, v string) (int, bool) {
    var lo int = 0
    var hi int = len(s)
    for lo < hi {
        var mid int = (lo + hi) / 2
        if stringLess(s[mid], v) {
            lo = mid + 1
        } else {
            hi = mid
        }
    }
    var found bool = false
    if lo < len(s) {
        if s[lo] == v { found = true }
    }
    ret lo, found
}

// ChunkInt splits s into consecutive chunks of `size` elements each.
// The last chunk may be shorter if len(s) doesn't divide evenly by
// size. Returns an empty slice when size <= 0 or s is empty.
// Mirrors Go 1.23's slices.Chunk (which returns an iter.Seq —
// we return the materialized [][]int slice).
fun ChunkInt(s []int, size int) [][]int {
    var out [][]int = new(0) [][]int {}
    if size <= 0 { ret out }
    var n int = len(s)
    if n == 0 { ret out }
    var i int = 0
    for i < n {
        var end int = i + size
        if end > n { end = n }
        var chunk []int = new(end - i) []int {}
        for k := i; k < end; k++ {
            chunk[k - i] = s[k]
        }
        out = append(out, chunk)
        i = end
    }
    ret out
}

// JoinByInt concatenates parts inserting `sep` between adjacent
// sub-slices. Inverse of SplitByInt — `Join(Split(s, sep), sep) == s`
// for any s. Useful for re-encoding integer streams after per-
// segment processing.
fun JoinByInt(parts [][]int, sep int) []int {
    var n int = len(parts)
    if n == 0 { ret new(0) []int {} }
    var total int = 0
    for i := 0; i < n; i++ { total = total + len(parts[i]) }
    if n > 1 { total = total + (n - 1) }
    var out []int = new(total) []int {}
    var idx int = 0
    for i := 0; i < n; i++ {
        if i > 0 {
            out[idx] = sep
            idx = idx + 1
        }
        var part []int = parts[i]
        var pn int = len(part)
        for k := 0; k < pn; k++ {
            out[idx] = part[k]
            idx = idx + 1
        }
    }
    ret out
}

// JoinByString is the []string counterpart of JoinByInt.
fun JoinByString(parts [][]string, sep string) []string {
    var n int = len(parts)
    if n == 0 { ret new(0) []string {} }
    var total int = 0
    for i := 0; i < n; i++ { total = total + len(parts[i]) }
    if n > 1 { total = total + (n - 1) }
    var out []string = new(total) []string {}
    var idx int = 0
    for i := 0; i < n; i++ {
        if i > 0 {
            out[idx] = "" + sep
            idx = idx + 1
        }
        var part []string = parts[i]
        var pn int = len(part)
        for k := 0; k < pn; k++ {
            out[idx] = "" + part[k]
            idx = idx + 1
        }
    }
    ret out
}

// SplitByInt splits s into runs of consecutive elements that don't
// equal `sep`. The separator itself is dropped. Empty sub-runs from
// adjacent separators or leading/trailing separators are kept as
// empty slices. Counterpart to strings.Split — useful for tokenizing
// integer-encoded streams (split on sentinel value).
fun SplitByInt(s []int, sep int) [][]int {
    var out [][]int = new(0) [][]int {}
    var n int = len(s)
    var start int = 0
    for i := 0; i < n; i++ {
        if s[i] == sep {
            var chunk []int = new(i - start) []int {}
            for k := 0; k < (i - start); k++ { chunk[k] = s[start + k] }
            out = append(out, chunk)
            start = i + 1
        }
    }
    var last []int = new(n - start) []int {}
    for k := 0; k < (n - start); k++ { last[k] = s[start + k] }
    out = append(out, last)
    ret out
}

// SplitByString is the []string counterpart of SplitByInt.
fun SplitByString(s []string, sep string) [][]string {
    var out [][]string = new(0) [][]string {}
    var n int = len(s)
    var start int = 0
    for i := 0; i < n; i++ {
        if s[i] == sep {
            var chunk []string = new(i - start) []string {}
            for k := 0; k < (i - start); k++ { chunk[k] = "" + s[start + k] }
            out = append(out, chunk)
            start = i + 1
        }
    }
    var last []string = new(n - start) []string {}
    for k := 0; k < (n - start); k++ { last[k] = "" + s[start + k] }
    out = append(out, last)
    ret out
}

// IndicesOfInt returns every position in s where the element
// equals v, in ascending order. Returns an empty slice when v
// doesn't appear or s is empty. Companion to ContainsInt /
// IndexInt — useful when you need ALL matching positions, not
// just the first.
fun IndicesOfInt(s []int, v int) []int {
    var n int = len(s)
    var out []int = new(0) []int {}
    for i := 0; i < n; i++ {
        if s[i] == v { out = append(out, i) }
    }
    ret out
}

// IndexNthInt returns the index of the n-th occurrence (0-indexed:
// n=0 is the first match) of v in s, or -1 if there are fewer than
// n+1 occurrences. n < 0 returns -1. Useful when callers need
// "the second comma", "the third newline" etc. without
// materializing the full IndicesOfInt slice.
fun IndexNthInt(s []int, v int, n int) int {
    if n < 0 { ret -1 }
    var ns int = len(s)
    var k int = 0
    for i := 0; i < ns; i++ {
        if s[i] == v {
            if k == n { ret i }
            k = k + 1
        }
    }
    ret -1
}

// IndexNthString is the []string counterpart of IndexNthInt.
fun IndexNthString(s []string, v string, n int) int {
    if n < 0 { ret -1 }
    var ns int = len(s)
    var k int = 0
    for i := 0; i < ns; i++ {
        if s[i] == v {
            if k == n { ret i }
            k = k + 1
        }
    }
    ret -1
}

// IndicesOfString is the []string counterpart of IndicesOfInt.
fun IndicesOfString(s []string, v string) []int {
    var n int = len(s)
    var out []int = new(0) []int {}
    for i := 0; i < n; i++ {
        if s[i] == v { out = append(out, i) }
    }
    ret out
}

// IndicesWhereInt returns the positions of every element of s where
// pred(x) returns true, in ascending order. Predicate-based variant
// of IndicesOfInt — useful when you need ALL positions matching a
// rule (e.g. "all even numbers", "all negative entries").
fun IndicesWhereInt(s []int, pred fun(int) bool) []int {
    var n int = len(s)
    var out []int = new(0) []int {}
    for i := 0; i < n; i++ {
        if pred(s[i]) { out = append(out, i) }
    }
    ret out
}

// IndicesWhereString is the []string counterpart of IndicesWhereInt.
fun IndicesWhereString(s []string, pred fun(string) bool) []int {
    var n int = len(s)
    var out []int = new(0) []int {}
    for i := 0; i < n; i++ {
        if pred(s[i]) { out = append(out, i) }
    }
    ret out
}

// WindowsInt returns every contiguous sub-slice of s of length k,
// stepping by 1 (sliding window). Distinct from ChunkInt — Chunks
// are non-overlapping and partition s; Windows overlap by k-1.
// k <= 0, k > len(s) → empty. Number of windows = max(0, len(s) -
// k + 1). Each window is a fresh copy. Useful for: n-gram
// extraction, sliding-stat preprocessing, time-series feature
// engineering.
fun WindowsInt(s []int, k int) [][]int {
    var out [][]int = new(0) [][]int {}
    var n int = len(s)
    if k <= 0 { ret out }
    if k > n { ret out }
    var count int = n - k + 1
    for i := 0; i < count; i++ {
        var w []int = new(k) []int {}
        for j := 0; j < k; j++ {
            w[j] = s[i + j]
        }
        out = append(out, w)
    }
    ret out
}

// ChunkString is the []string counterpart of ChunkInt.
fun ChunkString(s []string, size int) [][]string {
    var out [][]string = new(0) [][]string {}
    if size <= 0 { ret out }
    var n int = len(s)
    if n == 0 { ret out }
    var i int = 0
    for i < n {
        var end int = i + size
        if end > n { end = n }
        var chunk []string = new(end - i) []string {}
        for k := i; k < end; k++ {
            chunk[k - i] = s[k]
        }
        out = append(out, chunk)
        i = end
    }
    ret out
}

// WindowsString is the []string counterpart of WindowsInt.
fun WindowsString(s []string, k int) [][]string {
    var out [][]string = new(0) [][]string {}
    var n int = len(s)
    if k <= 0 { ret out }
    if k > n { ret out }
    var count int = n - k + 1
    for i := 0; i < count; i++ {
        var w []string = new(k) []string {}
        for j := 0; j < k; j++ {
            w[j] = "" + s[i + j]
        }
        out = append(out, w)
    }
    ret out
}

// LastIndexFuncInt returns the index of the last element of s for
// which pred(x) is true, or -1 if no element satisfies pred.
fun LastIndexFuncInt(s []int, pred fun(x int) bool) int {
    for i := len(s) - 1; i >= 0; i = i - 1 {
        if pred(s[i]) { ret i }
    }
    ret -1
}

// LastIndexFuncString returns the last index whose element satisfies
// pred, or -1 if no element does.
fun LastIndexFuncString(s []string, pred fun(x string) bool) int {
    for i := len(s) - 1; i >= 0; i = i - 1 {
        if pred(s[i]) { ret i }
    }
    ret -1
}

// CountFuncInt returns how many elements of s satisfy pred.
fun CountFuncInt(s []int, pred fun(x int) bool) int {
    var n int = len(s)
    var c int = 0
    for i := 0; i < n; i++ {
        if pred(s[i]) { c = c + 1 }
    }
    ret c
}

// CountFuncString returns how many string elements of s satisfy pred.
fun CountFuncString(s []string, pred fun(x string) bool) int {
    var n int = len(s)
    var c int = 0
    for i := 0; i < n; i++ {
        if pred(s[i]) { c = c + 1 }
    }
    ret c
}

// ConcatAllInts joins every slice in parts into a single flat
// []int. Same semantics as Go 1.22's slices.Concat (which takes
// variadic arguments — volt has no variadic so we accept a
// materialized [][]int). Computes total length first, allocates
// exact-size, copies each part.
fun ConcatAllInts(parts [][]int) []int {
    var np int = len(parts)
    if np == 0 {
        var empty []int = new(0) []int {}
        ret empty
    }
    var total int = 0
    for i := 0; i < np; i++ { total = total + len(parts[i]) }
    var out []int = new(total) []int {}
    var off int = 0
    for i := 0; i < np; i++ {
        var pl int = len(parts[i])
        for k := 0; k < pl; k++ {
            out[off + k] = parts[i][k]
        }
        off = off + pl
    }
    ret out
}

// FlatMapInt applies `fn` to each element of s (which produces a
// `[]int`) and concatenates all results into a single flat slice.
// Equivalent to `ConcatAllInts(MapInts(s, ...))` but skips the
// intermediate `[][]int` allocation. Useful for "expand each item
// into multiple items" — e.g. dependencies → transitive deps,
// path → its components, parent → its children.
fun FlatMapInt(s []int, fn fun(int) []int) []int {
    var n int = len(s)
    var total int = 0
    var pieces [][]int = new(n) [][]int {}
    for i := 0; i < n; i++ {
        pieces[i] = fn(s[i])
        total = total + len(pieces[i])
    }
    var out []int = new(total) []int {}
    var off int = 0
    for i := 0; i < n; i++ {
        var pl int = len(pieces[i])
        for k := 0; k < pl; k++ {
            out[off + k] = pieces[i][k]
        }
        off = off + pl
    }
    ret out
}

// FlatMapString is the []string counterpart of FlatMapInt.
fun FlatMapString(s []string, fn fun(string) []string) []string {
    var n int = len(s)
    var total int = 0
    var pieces [][]string = new(n) [][]string {}
    for i := 0; i < n; i++ {
        pieces[i] = fn(s[i])
        total = total + len(pieces[i])
    }
    var out []string = new(total) []string {}
    var off int = 0
    for i := 0; i < n; i++ {
        var pl int = len(pieces[i])
        for k := 0; k < pl; k++ {
            out[off + k] = pieces[i][k]
        }
        off = off + pl
    }
    ret out
}

// ConcatAllStrings is the []string counterpart of ConcatAllInts.
fun ConcatAllStrings(parts [][]string) []string {
    var np int = len(parts)
    if np == 0 {
        var empty []string = new(0) []string {}
        ret empty
    }
    var total int = 0
    for i := 0; i < np; i++ { total = total + len(parts[i]) }
    var out []string = new(total) []string {}
    var off int = 0
    for i := 0; i < np; i++ {
        var pl int = len(parts[i])
        for k := 0; k < pl; k++ {
            out[off + k] = parts[i][k]
        }
        off = off + pl
    }
    ret out
}

// RangeInts returns the slice [start, start+1, ..., end-1]. When
// start >= end the result is empty. Useful for `for i := range`
// loops over a known integer range.
fun RangeInts(start int, end int) []int {
    if start >= end {
        var empty []int = new(0) []int {}
        ret empty
    }
    var n int = end - start
    var out []int = new(n) []int {}
    for i := 0; i < n; i++ {
        out[i] = start + i
    }
    ret out
}

// RangeIntsStep returns start, start+step, start+2*step, ... while
// the value is < end (for positive step) or > end (for negative
// step). step == 0 returns an empty slice (cannot make progress).
fun RangeIntsStep(start int, end int, step int) []int {
    if step == 0 {
        var empty []int = new(0) []int {}
        ret empty
    }
    // First pass: count survivors so result is exact-size.
    var count int = 0
    if step > 0 {
        var v int = start
        for v < end {
            count = count + 1
            v = v + step
        }
    } else {
        var v int = start
        for v > end {
            count = count + 1
            v = v + step
        }
    }
    var out []int = new(count) []int {}
    var idx int = 0
    var v int = start
    if step > 0 {
        for v < end {
            out[idx] = v
            idx = idx + 1
            v = v + step
        }
    } else {
        for v > end {
            out[idx] = v
            idx = idx + 1
            v = v + step
        }
    }
    ret out
}

// CountUniqueInt returns the number of distinct values in s. Empty
// slice returns 0. O(n) using a `map[string]bool` keyed by Itoa'd
// values (since volt maps are string-keyed). Useful when callers
// only need the cardinality, not the unique elements themselves —
// avoids the O(n²) allocation of UniqueInts.
fun CountUniqueInt(s []int) int {
    var n int = len(s)
    if n == 0 { ret 0 }
    var seen map[string]bool = new map[string]bool
    var count int = 0
    for i := 0; i < n; i++ {
        var k string = strconv.Itoa(s[i])
        if !seen[k] {
            seen[k] = true
            count = count + 1
        }
    }
    ret count
}

// CountUniqueString returns the number of distinct strings in s.
// O(n) — same map-based dedup approach as CountUniqueInt but uses
// the string directly as the seen-set key.
fun CountUniqueString(s []string) int {
    var n int = len(s)
    if n == 0 { ret 0 }
    var seen map[string]bool = new map[string]bool
    var count int = 0
    for i := 0; i < n; i++ {
        var k string = "" + s[i]
        if !seen[k] {
            seen[k] = true
            count = count + 1
        }
    }
    ret count
}

// UniqueInts returns a new slice containing the elements of s in
// original order with all duplicates removed (not just consecutive
// — Compact does that). O(n²) worst case via linear-scan
// membership check; sufficient for small/medium slices.
fun UniqueInts(s []int) []int {
    var n int = len(s)
    var out []int = new(0) []int {}
    for i := 0; i < n; i++ {
        var v int = s[i]
        var seen bool = false
        var olen int = len(out)
        for j := 0; j < olen; j++ {
            if out[j] == v { seen = true; break }
        }
        if !seen { out = append(out, v) }
    }
    ret out
}

// UniqueStrings is the []string counterpart of UniqueInts.
fun UniqueStrings(s []string) []string {
    var n int = len(s)
    var out []string = new(0) []string {}
    for i := 0; i < n; i++ {
        var v string = s[i]
        var seen bool = false
        var olen int = len(out)
        for j := 0; j < olen; j++ {
            if out[j] == v { seen = true; break }
        }
        if !seen { out = append(out, v) }
    }
    ret out
}

// HasDuplicatesInt reports whether any value appears more than once
// in s. Equivalent to `len(UniqueInts(s)) != len(s)` but bails out
// on first duplicate, so it's typically faster on slices that
// contain dups. Empty or single-element s returns false. O(n²) —
// fine for small/mid slices. Useful for input validation guards
// (e.g. "are all IDs distinct?").
fun HasDuplicatesInt(s []int) bool {
    var n int = len(s)
    for i := 0; i < n; i++ {
        for j := i + 1; j < n; j++ {
            if s[i] == s[j] { ret true }
        }
    }
    ret false
}

// HasDuplicatesString is the []string counterpart of
// HasDuplicatesInt. Useful for "are all names distinct?" /
// "no duplicate keys?" checks.
fun HasDuplicatesString(s []string) bool {
    var n int = len(s)
    for i := 0; i < n; i++ {
        for j := i + 1; j < n; j++ {
            if s[i] == s[j] { ret true }
        }
    }
    ret false
}

// FirstDuplicateInt returns the FIRST value in s that has another
// occurrence later in the slice, along with a found flag. Useful
// for validation error messages where you need to name the offending
// value (e.g. "duplicate user_id: 42"). On empty / single-element s
// returns (0, false). O(n²). Early-exits at first duplicate.
fun FirstDuplicateInt(s []int) (int, bool) {
    var n int = len(s)
    for i := 0; i < n; i++ {
        for j := i + 1; j < n; j++ {
            if s[i] == s[j] { ret s[i], true }
        }
    }
    ret 0, false
}

// FirstDuplicateString is the []string counterpart of
// FirstDuplicateInt — returns the first duplicate name / key
// found, along with a found flag.
fun FirstDuplicateString(s []string) (string, bool) {
    var n int = len(s)
    for i := 0; i < n; i++ {
        for j := i + 1; j < n; j++ {
            if s[i] == s[j] { ret "" + s[i], true }
        }
    }
    ret "", false
}

// NumDistinctInt returns the count of distinct values in s.
// Equivalent to `len(UniqueInts(s))` but never materializes the
// unique slice — useful when you just need the count and want to
// avoid the alloc. O(n²). Empty s returns 0.
fun NumDistinctInt(s []int) int {
    var n int = len(s)
    var k int = 0
    for i := 0; i < n; i++ {
        var seen bool = false
        for j := 0; j < i; j++ {
            if s[j] == s[i] { seen = true; break }
        }
        if !seen { k = k + 1 }
    }
    ret k
}

// NumDistinctString is the []string counterpart of NumDistinctInt.
fun NumDistinctString(s []string) int {
    var n int = len(s)
    var k int = 0
    for i := 0; i < n; i++ {
        var seen bool = false
        for j := 0; j < i; j++ {
            if s[j] == s[i] { seen = true; break }
        }
        if !seen { k = k + 1 }
    }
    ret k
}

// AverageInt returns the integer average (truncated toward zero) of
// s. Empty slice returns 0. Overflow on the running sum wraps
// silently — matches SumInts semantics.
fun AverageInt(s []int) int {
    var n int = len(s)
    if n == 0 { ret 0 }
    var total int = 0
    for i := 0; i < n; i++ {
        total = total + s[i]
    }
    ret total / n
}

// PercentOfMaxInt returns each element rescaled so the maximum
// equals `scale`. Negative elements are scaled the same way (output
// preserves sign). Empty s returns empty. All-zero s returns
// all-zero. If max(|s|) is 0 (all values zero), returns all-zero.
// Useful for bar-chart rendering where you want the longest bar to
// be full-scale and others proportional. Uses MaxAbsInt internally
// so a single very-negative value can saturate the bar.
fun PercentOfMaxInt(s []int, scale int) []int {
    var n int = len(s)
    var out []int = new(n) []int {}
    if n == 0 { ret out }
    var m int = MaxAbsInt(s)
    if m == 0 { ret out }
    for i := 0; i < n; i++ {
        out[i] = s[i] * scale / m
    }
    ret out
}

// PercentOfTotalInt returns each element of s rescaled so the sum
// equals `scale` (e.g. scale=100 for percentages, scale=1000 for
// permille). Empty s returns empty. If the total of s is 0, all
// outputs are 0. Uses integer division (truncation toward zero) per
// position; the sum of outputs may be 1-2 short of `scale` due to
// rounding. Useful for portion-of-total displays (budget splits,
// vote-share bars).
// NormalizeRangeInt rescales each element of s so the input range
// [min(s), max(s)] linearly maps to [lo, hi]. min → lo, max → hi.
// Empty input → empty. Constant input (min == max) → all `lo`
// (everything degenerate but still in [lo,hi]). Useful for compressing
// arbitrary value ranges into a fixed render window — e.g. before
// strings.Sparkline expects a 0..N magnitude range.
//
//   NormalizeRangeInt([10, 20, 30, 40], 0, 100)  →  [0, 33, 66, 100]
//
// Integer division per cell so the output may be 1-2 short on edges;
// the endpoints are clamped exactly to (lo, hi).
fun NormalizeRangeInt(s []int, lo int, hi int) []int {
    var n int = len(s)
    var out []int = new(n) []int {}
    if n == 0 { ret out }
    var mn int = s[0]
    var mx int = s[0]
    for i := 1; i < n; i++ {
        var v int = s[i]
        if v < mn { mn = v }
        if v > mx { mx = v }
    }
    var span int = mx - mn
    var range_out int = hi - lo
    if span == 0 {
        for i := 0; i < n; i++ { out[i] = lo }
        ret out
    }
    for i := 0; i < n; i++ {
        out[i] = lo + ((s[i] - mn) * range_out) / span
    }
    ret out
}

// IsConstantInt reports whether all elements of s are equal. Empty
// or single-element slices return true vacuously. Useful as a guard
// before chart-rendering (sparkline of a constant series is just a
// flat line) or change-detection in metric streams.
fun IsConstantInt(s []int) bool {
    var n int = len(s)
    if n < 2 { ret true }
    var first int = s[0]
    for i := 1; i < n; i++ {
        if s[i] != first { ret false }
    }
    ret true
}

fun PercentOfTotalInt(s []int, scale int) []int {
    var n int = len(s)
    var out []int = new(n) []int {}
    if n == 0 { ret out }
    var total int = SumInts(s)
    if total == 0 { ret out }
    for i := 0; i < n; i++ {
        out[i] = s[i] * scale / total
    }
    ret out
}

// ShuffleInts shuffles s in place using Fisher-Yates with a
// crypto-strong random source. Returns the same slice for
// rebinding across the move. Empty / single-element slices are
// returned unchanged.
fun ShuffleInts(s []int) []int {
    var n int = len(s)
    var i int = n - 1
    for i > 0 {
        var j int = rand.Int(i + 1)
        var t int = s[i]
        s[i] = s[j]
        s[j] = t
        i = i - 1
    }
    ret s
}

// ShuffleStrings is the []string counterpart of ShuffleInts.
fun ShuffleStrings(s []string) []string {
    var n int = len(s)
    var i int = n - 1
    for i > 0 {
        var j int = rand.Int(i + 1)
        var t string = s[i]
        s[i] = s[j]
        s[j] = t
        i = i - 1
    }
    ret s
}

// ChooseInt returns a uniformly random element of s using
// crypto/rand. Empty slice returns 0 (caller should check len first).
fun ChooseInt(s []int) int {
    var n int = len(s)
    if n == 0 { ret 0 }
    var idx int = rand.Int(n)
    ret s[idx]
}

// ChooseString returns a uniformly random element of s. Empty
// slice returns "".
fun ChooseString(s []string) string {
    var n int = len(s)
    if n == 0 { ret "" }
    var idx int = rand.Int(n)
    ret s[idx]
}

// PartitionBySignInt splits s into three slices: positives, zeros,
// negatives — in original order. Useful for stratified processing
// (different rules for credits vs debits vs zero entries) without
// writing three FilterInts calls. Empty s returns three empty
// slices. Doesn't mutate s.
fun PartitionBySignInt(s []int) ([]int, []int, []int) {
    var n int = len(s)
    var nPos int = 0
    var nZero int = 0
    var nNeg int = 0
    for i := 0; i < n; i++ {
        if s[i] > 0 { nPos = nPos + 1 }
        if s[i] == 0 { nZero = nZero + 1 }
        if s[i] < 0 { nNeg = nNeg + 1 }
    }
    var pos []int = new(nPos) []int {}
    var zero []int = new(nZero) []int {}
    var neg []int = new(nNeg) []int {}
    var pi int = 0
    var zi int = 0
    var ni int = 0
    for i := 0; i < n; i++ {
        var v int = s[i]
        if v > 0 {
            pos[pi] = v
            pi = pi + 1
        }
        if v == 0 {
            zero[zi] = v
            zi = zi + 1
        }
        if v < 0 {
            neg[ni] = v
            ni = ni + 1
        }
    }
    ret pos, zero, neg
}

// PartitionInts splits s into two slices: matches (elements for
// which keep(x) is true, in original order) and rest (the others).
// Two-pass to size both outputs exactly.
fun PartitionInts(s []int, keep fun(x int) bool) ([]int, []int) {
    var n int = len(s)
    var nMatch int = 0
    for i := 0; i < n; i++ {
        if keep(s[i]) { nMatch = nMatch + 1 }
    }
    var matches []int = new(nMatch) []int {}
    var rest []int = new(n - nMatch) []int {}
    var mi int = 0
    var ri int = 0
    for i := 0; i < n; i++ {
        var v int = s[i]
        if keep(v) {
            matches[mi] = v
            mi = mi + 1
        } else {
            rest[ri] = v
            ri = ri + 1
        }
    }
    ret matches, rest
}

// PartitionStrings is the []string counterpart of PartitionInts.
fun PartitionStrings(s []string, keep fun(x string) bool) ([]string, []string) {
    var n int = len(s)
    var nMatch int = 0
    for i := 0; i < n; i++ {
        if keep(s[i]) { nMatch = nMatch + 1 }
    }
    var matches []string = new(nMatch) []string {}
    var rest []string = new(n - nMatch) []string {}
    var mi int = 0
    var ri int = 0
    for i := 0; i < n; i++ {
        var v string = s[i]
        if keep(v) {
            matches[mi] = v
            mi = mi + 1
        } else {
            rest[ri] = v
            ri = ri + 1
        }
    }
    ret matches, rest
}

// ToMapStringInt zips two slices into a `map[string]int`. If the
// slices have different lengths, only the shorter prefix is used.
// Later duplicate keys overwrite earlier ones (matches the natural
// loop-and-assign semantics).
fun ToMapStringInt(keys []string, values []int) map[string]int {
    var out map[string]int = new map[string]int
    var n int = len(keys)
    var nv int = len(values)
    if nv < n { n = nv }
    for i := 0; i < n; i++ {
        out[keys[i]] = values[i]
    }
    ret out
}

// ToMapStringString is the []string-value counterpart of ToMapStringInt.
fun ToMapStringString(keys []string, values []string) map[string]string {
    var out map[string]string = new map[string]string
    var n int = len(keys)
    var nv int = len(values)
    if nv < n { n = nv }
    for i := 0; i < n; i++ {
        out[keys[i]] = values[i]
    }
    ret out
}

// GroupByStringInt groups elements of s by a computed key. Returns
// a map where each key bucket holds the elements (in original order)
// that mapped to that key. Mirrors the Python / Ruby / LINQ pattern.
//
// Implementation note: volt's checker moves a map on every read, so
// the natural "lookup → append → write" pattern doesn't typecheck.
// We work around with a three-pass build that only WRITES to the
// result map: (1) compute all per-element keys into a parallel
// slice; (2) collect unique keys in first-seen order; (3) for each
// unique key, count matches and copy them into an exact-size bucket,
// then write the bucket once. O(n * unique_keys).
fun GroupByStringInt(s []int, key fun(int) string) map[string][]int {
    var n int = len(s)
    var out map[string][]int = new map[string][]int
    if n == 0 { ret out }
    var keys []string = new(n) []string {}
    for i := 0; i < n; i++ {
        keys[i] = key(s[i])
    }
    var uniq []string = new(0) []string {}
    for i := 0; i < n; i++ {
        var k string = "" + keys[i]
        var seen bool = false
        var u int = len(uniq)
        for j := 0; j < u; j++ {
            if uniq[j] == k { seen = true; break }
        }
        if !seen { uniq = append(uniq, "" + k) }
    }
    var nu int = len(uniq)
    for u := 0; u < nu; u++ {
        var k string = "" + uniq[u]
        var cnt int = 0
        for i := 0; i < n; i++ {
            if keys[i] == k { cnt = cnt + 1 }
        }
        var bucket []int = new(cnt) []int {}
        var bi int = 0
        for i := 0; i < n; i++ {
            if keys[i] == k {
                bucket[bi] = s[i]
                bi = bi + 1
            }
        }
        out["" + k] = bucket
    }
    ret out
}

// GroupByStringString groups string elements of s by a computed
// string key. Same shape as GroupByStringInt.
fun GroupByStringString(s []string, key fun(string) string) map[string][]string {
    var n int = len(s)
    var out map[string][]string = new map[string][]string
    if n == 0 { ret out }
    var keys []string = new(n) []string {}
    for i := 0; i < n; i++ {
        keys[i] = key(s[i])
    }
    var uniq []string = new(0) []string {}
    for i := 0; i < n; i++ {
        var k string = "" + keys[i]
        var seen bool = false
        var u int = len(uniq)
        for j := 0; j < u; j++ {
            if uniq[j] == k { seen = true; break }
        }
        if !seen { uniq = append(uniq, "" + k) }
    }
    var nu int = len(uniq)
    for u := 0; u < nu; u++ {
        var k string = "" + uniq[u]
        var cnt int = 0
        for i := 0; i < n; i++ {
            if keys[i] == k { cnt = cnt + 1 }
        }
        var bucket []string = new(cnt) []string {}
        var bi int = 0
        for i := 0; i < n; i++ {
            if keys[i] == k {
                bucket[bi] = "" + s[i]
                bi = bi + 1
            }
        }
        out["" + k] = bucket
    }
    ret out
}

// WindowInts returns all overlapping windows of `size` consecutive
// elements from s. Empty result when size <= 0 or size > len(s).
// Useful for n-gram analysis, sliding-average computation, etc.
fun WindowInts(s []int, size int) [][]int {
    var out [][]int = new(0) [][]int {}
    if size <= 0 { ret out }
    var n int = len(s)
    if size > n { ret out }
    var count int = n - size + 1
    for i := 0; i < count; i++ {
        var w []int = new(size) []int {}
        for j := 0; j < size; j++ {
            w[j] = s[i + j]
        }
        out = append(out, w)
    }
    ret out
}

// WindowStrings is the []string counterpart of WindowInts.
fun WindowStrings(s []string, size int) [][]string {
    var out [][]string = new(0) [][]string {}
    if size <= 0 { ret out }
    var n int = len(s)
    if size > n { ret out }
    var count int = n - size + 1
    for i := 0; i < count; i++ {
        var w []string = new(size) []string {}
        for j := 0; j < size; j++ {
            w[j] = "" + s[i + j]
        }
        out = append(out, w)
    }
    ret out
}

// RotateInts returns a new slice that's s cyclically left-rotated
// by k positions. Negative k rotates right; k modulo len(s) is used
// so |k| can exceed len(s). Empty slice returns empty.
fun RotateInts(s []int, k int) []int {
    var n int = len(s)
    if n == 0 {
        var empty []int = new(0) []int {}
        ret empty
    }
    var off int = k % n
    if off < 0 { off = off + n }
    var out []int = new(n) []int {}
    for i := 0; i < n; i++ {
        out[i] = s[(i + off) % n]
    }
    ret out
}

// RotateStrings is the []string counterpart of RotateInts.
fun RotateStrings(s []string, k int) []string {
    var n int = len(s)
    if n == 0 {
        var empty []string = new(0) []string {}
        ret empty
    }
    var off int = k % n
    if off < 0 { off = off + n }
    var out []string = new(n) []string {}
    for i := 0; i < n; i++ {
        out[i] = "" + s[(i + off) % n]
    }
    ret out
}

// ProductInts returns the product of all elements of s. Empty slice
// returns 1 (vacuous identity, matches Python's math.prod default).
// Overflow wraps silently.
fun ProductInts(s []int) int {
    var p int = 1
    var n int = len(s)
    for i := 0; i < n; i++ {
        p = p * s[i]
    }
    ret p
}

// DotProductInt returns the standard linear-algebra dot product:
// sum of a[i]*b[i] for i in [0, min(len(a), len(b))). When the
// slices differ in length the longer tail is silently ignored
// (caller is responsible for length matching). Empty inputs return
// 0. O(min(len(a), len(b))). Overflow wraps silently. Useful for
// weighted sums, geometric inner products, ML feature scoring.
fun DotProductInt(a []int, b []int) int {
    var na int = len(a)
    var nb int = len(b)
    var n int = na
    if nb < n { n = nb }
    var s int = 0
    for i := 0; i < n; i++ {
        s = s + a[i] * b[i]
    }
    ret s
}

// SumAbsInt returns the L1 norm: Σ |s[i]|. Empty s returns 0. O(n).
// Overflow wraps silently. The Σ|x|-style version of SumInt; useful
// for total-magnitude / movement-from-zero / signal-energy stats,
// and as the L1-norm half of the Manhattan / cosine-similarity
// vocabulary together with DotProductInt and SumSquaresInt.
fun SumAbsInt(s []int) int {
    var n int = len(s)
    var t int = 0
    for i := 0; i < n; i++ {
        var v int = s[i]
        if v < 0 { v = -v }
        t = t + v
    }
    ret t
}

// SumSquaresInt returns the squared L2 norm: Σ s[i]² (also known
// as DotProductInt(s, s)). Empty s returns 0. O(n). Overflow wraps
// silently. Useful for "is this vector nonzero?" gates and as the
// numerator of cosine-similarity. Saves having to clone s and call
// DotProductInt(s, s) — fewer moves through the ownership checker.
fun SumSquaresInt(s []int) int {
    var n int = len(s)
    var t int = 0
    for i := 0; i < n; i++ {
        t = t + s[i] * s[i]
    }
    ret t
}

// IntsToStrings projects every int in s to its decimal string
// representation. Result has the same length as s; element order
// preserved. Useful for joining or pretty-printing int slices.
fun IntsToStrings(s []int) []string {
    var n int = len(s)
    var out []string = new(n) []string {}
    for i := 0; i < n; i++ {
        out[i] = strconv.Itoa(s[i])
    }
    ret out
}

// StringsToInts parses each string in s via strconv.Atoi. Returns
// the int slice and nil on success; on the FIRST parse error
// returns (nil, error) so the caller knows which call failed via
// the error message.
fun StringsToInts(s []string) ([]int, error) {
    var n int = len(s)
    var out []int = new(n) []int {}
    for i := 0; i < n; i++ {
        var v int = 0
        var e error = nil
        v, e = strconv.Atoi(s[i])
        if e != nil {
            var empty []int = new(0) []int {}
            ret empty, e
        }
        out[i] = v
    }
    ret out, nil
}

// HeadInts returns the first `n` elements of s as a fresh slice.
// If n >= len(s), returns a copy of s. n <= 0 returns an empty
// slice. Useful for pagination, previewing.
fun HeadInts(s []int, n int) []int {
    if n <= 0 {
        var empty []int = new(0) []int {}
        ret empty
    }
    var sl int = len(s)
    if n > sl { n = sl }
    var out []int = new(n) []int {}
    for i := 0; i < n; i++ {
        out[i] = s[i]
    }
    ret out
}

// TailInts returns the last `n` elements of s. n >= len(s) → copy
// of s; n <= 0 → empty.
fun TailInts(s []int, n int) []int {
    if n <= 0 {
        var empty []int = new(0) []int {}
        ret empty
    }
    var sl int = len(s)
    if n > sl { n = sl }
    var out []int = new(n) []int {}
    var off int = sl - n
    for i := 0; i < n; i++ {
        out[i] = s[off + i]
    }
    ret out
}

// HeadStrings is the []string counterpart of HeadInts.
fun HeadStrings(s []string, n int) []string {
    if n <= 0 {
        var empty []string = new(0) []string {}
        ret empty
    }
    var sl int = len(s)
    if n > sl { n = sl }
    var out []string = new(n) []string {}
    for i := 0; i < n; i++ {
        out[i] = "" + s[i]
    }
    ret out
}

// TailStrings is the []string counterpart of TailInts.
fun TailStrings(s []string, n int) []string {
    if n <= 0 {
        var empty []string = new(0) []string {}
        ret empty
    }
    var sl int = len(s)
    if n > sl { n = sl }
    var out []string = new(n) []string {}
    var off int = sl - n
    for i := 0; i < n; i++ {
        out[i] = "" + s[off + i]
    }
    ret out
}

// SplitAtInt splits s into two fresh slices: head = s[:n], tail =
// s[n:]. n clamped to [0, len(s)] so out-of-range inputs are safe
// — n<=0 returns (empty, copy-of-s); n>=len returns (copy-of-s,
// empty). Saves the manual `HeadInts(s,n) + TailInts(s,len(s)-n)`
// ceremony for the common "split a slice in half / at a known
// boundary" pattern. Doesn't mutate s.
fun SplitAtInt(s []int, n int) ([]int, []int) {
    var sl int = len(s)
    var k int = n
    if k < 0 { k = 0 }
    if k > sl { k = sl }
    var head []int = new(k) []int {}
    for i := 0; i < k; i++ { head[i] = s[i] }
    var tail []int = new(sl - k) []int {}
    for i := 0; i < sl - k; i++ { tail[i] = s[k + i] }
    ret head, tail
}

// SplitAtString is the []string counterpart of SplitAtInt.
fun SplitAtString(s []string, n int) ([]string, []string) {
    var sl int = len(s)
    var k int = n
    if k < 0 { k = 0 }
    if k > sl { k = sl }
    var head []string = new(k) []string {}
    for i := 0; i < k; i++ { head[i] = "" + s[i] }
    var tail []string = new(sl - k) []string {}
    for i := 0; i < sl - k; i++ { tail[i] = "" + s[k + i] }
    ret head, tail
}

// SampleInts returns k random elements from s without replacement.
// If k >= len(s), returns a shuffled copy of s. k <= 0 returns
// empty. Uses crypto/rand for shuffling.
fun SampleInts(s []int, k int) []int {
    if k <= 0 {
        var empty []int = new(0) []int {}
        ret empty
    }
    var n int = len(s)
    if k > n { k = n }
    // Fresh copy then partial Fisher-Yates (k draws is enough).
    var pool []int = new(n) []int {}
    for i := 0; i < n; i++ { pool[i] = s[i] }
    // Draw k swaps from the front.
    for i := 0; i < k; i++ {
        var j int = i + rand.Int(n - i)
        var t int = pool[i]
        pool[i] = pool[j]
        pool[j] = t
    }
    var out []int = new(k) []int {}
    for i := 0; i < k; i++ {
        out[i] = pool[i]
    }
    ret out
}

// SampleStrings is the []string counterpart of SampleInts.
fun SampleStrings(s []string, k int) []string {
    if k <= 0 {
        var empty []string = new(0) []string {}
        ret empty
    }
    var n int = len(s)
    if k > n { k = n }
    var pool []string = new(n) []string {}
    for i := 0; i < n; i++ { pool[i] = "" + s[i] }
    for i := 0; i < k; i++ {
        var j int = i + rand.Int(n - i)
        var t string = "" + pool[i]
        pool[i] = "" + pool[j]
        pool[j] = "" + t
    }
    var out []string = new(k) []string {}
    for i := 0; i < k; i++ {
        out[i] = "" + pool[i]
    }
    ret out
}

// StringsToSet projects s into a `map[string]bool` where every
// element of s is mapped to true. Useful for fast membership tests
// without scanning the slice each time. Duplicates collapse
// (collision overwrite with the same value).
fun StringsToSet(s []string) map[string]bool {
    var out map[string]bool = new map[string]bool
    var n int = len(s)
    for i := 0; i < n; i++ {
        out["" + s[i]] = true
    }
    ret out
}

// SetContainsString reports whether set has key. Convenience wrapper
// so callers don't have to remember `set[k]` returns false for
// missing keys.
fun SetContainsString(set map[string]bool, key string) bool {
    ret set[key]
}

// SetUnionStrings returns a fresh set containing every key present
// in a OR b. Both inputs are unchanged.
fun SetUnionStrings(a map[string]bool, b map[string]bool) map[string]bool {
    var out map[string]bool = new map[string]bool
    for k, v := range a {
        if v { out[k] = true }
    }
    for k, v := range b {
        if v { out[k] = true }
    }
    ret out
}

// SetIntersectionStrings returns the keys present in both a AND b.
fun SetIntersectionStrings(a map[string]bool, b map[string]bool) map[string]bool {
    var out map[string]bool = new map[string]bool
    for k, v := range a {
        if v {
            if b[k] { out[k] = true }
        }
    }
    ret out
}

// SetDifferenceStrings returns the keys in a but not in b.
fun SetDifferenceStrings(a map[string]bool, b map[string]bool) map[string]bool {
    var out map[string]bool = new map[string]bool
    for k, v := range a {
        if v {
            if !b[k] { out[k] = true }
        }
    }
    ret out
}

// MinByInt returns the element of s for which key(x) is smallest.
// Ties resolve to the first occurrence (stable). Empty slice
// returns 0.
fun MinByInt(s []int, key fun(int) int) int {
    var n int = len(s)
    if n == 0 { ret 0 }
    var best int = s[0]
    var bestKey int = key(s[0])
    for i := 1; i < n; i++ {
        var k int = key(s[i])
        if k < bestKey {
            best = s[i]
            bestKey = k
        }
    }
    ret best
}

// MaxByInt returns the element of s for which key(x) is largest.
fun MaxByInt(s []int, key fun(int) int) int {
    var n int = len(s)
    if n == 0 { ret 0 }
    var best int = s[0]
    var bestKey int = key(s[0])
    for i := 1; i < n; i++ {
        var k int = key(s[i])
        if k > bestKey {
            best = s[i]
            bestKey = k
        }
    }
    ret best
}

// MinIndexByInt returns the INDEX (not value) of the element of s
// with the smallest key(x). Ties resolve to the first occurrence.
// Empty slice returns -1. Useful when callers need to identify the
// POSITION of an extremum (for paired-slice lookup, ranking, edit).
fun MinIndexByInt(s []int, key fun(int) int) int {
    var n int = len(s)
    if n == 0 { ret -1 }
    var bestIdx int = 0
    var bestKey int = key(s[0])
    for i := 1; i < n; i++ {
        var k int = key(s[i])
        if k < bestKey {
            bestIdx = i
            bestKey = k
        }
    }
    ret bestIdx
}

// MaxIndexByInt is the max-key counterpart of MinIndexByInt.
fun MaxIndexByInt(s []int, key fun(int) int) int {
    var n int = len(s)
    if n == 0 { ret -1 }
    var bestIdx int = 0
    var bestKey int = key(s[0])
    for i := 1; i < n; i++ {
        var k int = key(s[i])
        if k > bestKey {
            bestIdx = i
            bestKey = k
        }
    }
    ret bestIdx
}

// MinIndexByString is the index-returning counterpart of MinByString.
fun MinIndexByString(s []string, key fun(string) int) int {
    var n int = len(s)
    if n == 0 { ret -1 }
    var bestIdx int = 0
    var bestKey int = key(s[0])
    for i := 1; i < n; i++ {
        var k int = key(s[i])
        if k < bestKey {
            bestIdx = i
            bestKey = k
        }
    }
    ret bestIdx
}

// MaxIndexByString is the index-returning counterpart of MaxByString.
fun MaxIndexByString(s []string, key fun(string) int) int {
    var n int = len(s)
    if n == 0 { ret -1 }
    var bestIdx int = 0
    var bestKey int = key(s[0])
    for i := 1; i < n; i++ {
        var k int = key(s[i])
        if k > bestKey {
            bestIdx = i
            bestKey = k
        }
    }
    ret bestIdx
}

// MinByString / MaxByString: same shape for []string slices with
// an int-key projection.
fun MinByString(s []string, key fun(string) int) string {
    var n int = len(s)
    if n == 0 { ret "" }
    var best string = s[0]
    var bestKey int = key(s[0])
    for i := 1; i < n; i++ {
        var k int = key(s[i])
        if k < bestKey {
            best = "" + s[i]
            bestKey = k
        }
    }
    ret best
}

fun MaxByString(s []string, key fun(string) int) string {
    var n int = len(s)
    if n == 0 { ret "" }
    var best string = s[0]
    var bestKey int = key(s[0])
    for i := 1; i < n; i++ {
        var k int = key(s[i])
        if k > bestKey {
            best = "" + s[i]
            bestKey = k
        }
    }
    ret best
}

// LongestString returns the string with the most bytes in s. Ties
// go to the EARLIEST occurrence (stable). Empty s returns "".
// O(n). Saves the `MaxByString(s, len)` indirection — common
// enough to deserve a direct entry point. Useful for table column-
// width calculation, summary length stats.
fun LongestString(s []string) string {
    var n int = len(s)
    if n == 0 { ret "" }
    var bestIdx int = 0
    var best int = len(s[0])
    for i := 1; i < n; i++ {
        if len(s[i]) > best {
            best = len(s[i])
            bestIdx = i
        }
    }
    ret "" + s[bestIdx]
}

// ShortestString returns the string with the fewest bytes in s.
// Stable tie-breaking (earliest occurrence). Empty s returns "".
fun ShortestString(s []string) string {
    var n int = len(s)
    if n == 0 { ret "" }
    var bestIdx int = 0
    var best int = len(s[0])
    for i := 1; i < n; i++ {
        if len(s[i]) < best {
            best = len(s[i])
            bestIdx = i
        }
    }
    ret "" + s[bestIdx]
}

// MaxLenString returns the byte-length of the longest string in s.
// Empty s returns 0. Companion to LongestString — useful when you
// only need the width, not the string itself (table-column sizing).
fun MaxLenString(s []string) int {
    var n int = len(s)
    if n == 0 { ret 0 }
    var best int = len(s[0])
    for i := 1; i < n; i++ {
        if len(s[i]) > best { best = len(s[i]) }
    }
    ret best
}

// MinLenString returns the byte-length of the shortest string in s.
// Empty s returns 0.
fun MinLenString(s []string) int {
    var n int = len(s)
    if n == 0 { ret 0 }
    var best int = len(s[0])
    for i := 1; i < n; i++ {
        if len(s[i]) < best { best = len(s[i]) }
    }
    ret best
}

// IndexOfLongestString returns the index of the longest string in s
// (stable: earliest tied position wins). Empty s returns -1.
// Companion to LongestString when callers need the position too
// (e.g. to read a sibling field at the same index).
fun IndexOfLongestString(s []string) int {
    var n int = len(s)
    if n == 0 { ret -1 }
    var bestIdx int = 0
    var best int = len(s[0])
    for i := 1; i < n; i++ {
        if len(s[i]) > best {
            best = len(s[i])
            bestIdx = i
        }
    }
    ret bestIdx
}

// IndexOfShortestString returns the index of the shortest string in
// s (stable). Empty s returns -1.
fun IndexOfShortestString(s []string) int {
    var n int = len(s)
    if n == 0 { ret -1 }
    var bestIdx int = 0
    var best int = len(s[0])
    for i := 1; i < n; i++ {
        if len(s[i]) < best {
            best = len(s[i])
            bestIdx = i
        }
    }
    ret bestIdx
}

// LengthsString projects every element of s to its byte length,
// preserving order. Companion to MaxLenString/MinLenString — yields
// the full length distribution when callers need stats beyond
// max/min (avg, median, histogram, variance). Empty s returns
// empty.
fun LengthsString(s []string) []int {
    var n int = len(s)
    var out []int = new(n) []int {}
    for i := 0; i < n; i++ {
        out[i] = len(s[i])
    }
    ret out
}

// TotalLenString returns Σ len(s[i]) — total byte count across
// every string in s. Useful for "how big is this batch in bytes?"
// pre-flight checks before serialization or buffer allocation.
// Empty s returns 0.
fun TotalLenString(s []string) int {
    var n int = len(s)
    var t int = 0
    for i := 0; i < n; i++ {
        t = t + len(s[i])
    }
    ret t
}

// IntersperseInt returns a new slice with `sep` inserted between
// each adjacent pair of elements. Empty / single-element input is
// copied through unchanged (no sep needed). Result length is
// 2*n - 1 for n >= 2.
fun IntersperseInt(s []int, sep int) []int {
    var n int = len(s)
    if n == 0 { ret new(0) []int {} }
    if n == 1 {
        var out1 []int = new(1) []int {}
        out1[0] = s[0]
        ret out1
    }
    var out []int = new(2*n - 1) []int {}
    out[0] = s[0]
    for i := 1; i < n; i++ {
        out[2*i - 1] = sep
        out[2*i] = s[i]
    }
    ret out
}

// IntersperseString is the []string counterpart of IntersperseInt.
fun IntersperseString(s []string, sep string) []string {
    var n int = len(s)
    if n == 0 { ret new(0) []string {} }
    if n == 1 {
        var out1 []string = new(1) []string {}
        out1[0] = "" + s[0]
        ret out1
    }
    var out []string = new(2*n - 1) []string {}
    out[0] = "" + s[0]
    for i := 1; i < n; i++ {
        out[2*i - 1] = "" + sep
        out[2*i] = "" + s[i]
    }
    ret out
}

// ReduceInt left-folds s into a single accumulator. Starts with
// init; for each element x of s, replaces acc with fn(acc, x).
// Empty slice returns init unchanged. Equivalent to:
//   acc := init
//   for x := range s { acc = fn(acc, x) }
//   return acc
// Common uses: custom sums, products, max-with-default, building
// hash digests.
fun ReduceInt(s []int, init int, fn fun(int, int) int) int {
    var acc int = init
    var n int = len(s)
    for i := 0; i < n; i++ {
        acc = fn(acc, s[i])
    }
    ret acc
}

// ReduceString is the []string counterpart of ReduceInt.
fun ReduceString(s []string, init string, fn fun(string, string) string) string {
    var acc string = init
    var n int = len(s)
    for i := 0; i < n; i++ {
        acc = fn(acc, s[i])
    }
    ret acc
}

// AccumulateInt returns the running totals (prefix sums) of s.
// Result has the same length as s. out[i] = s[0] + s[1] + ... + s[i].
// Empty slice returns an empty slice. Equivalent to numpy's
// cumsum / Python's itertools.accumulate (with default operator.add).
// Useful for cumulative distribution functions, sliding-window
// preprocessing, histogram bucketing.
fun AccumulateInt(s []int) []int {
    var n int = len(s)
    var out []int = new(n) []int {}
    var sum int = 0
    for i := 0; i < n; i++ {
        sum = sum + s[i]
        out[i] = sum
    }
    ret out
}

// AccumulateMaxInt returns the running maxima of s. Result has the
// same length as s. out[i] = max(s[0]..s[i]).
fun AccumulateMaxInt(s []int) []int {
    var n int = len(s)
    var out []int = new(n) []int {}
    if n == 0 { ret out }
    var best int = s[0]
    out[0] = best
    for i := 1; i < n; i++ {
        if s[i] > best { best = s[i] }
        out[i] = best
    }
    ret out
}

// MedianInt returns the median of s. Sorts a copy of s ascending
// and returns the middle element (for odd n) or the average of the
// two middle elements (for even n; truncated toward zero per int
// division). Empty slice returns 0. Does not mutate s.
//
// O(n²) — uses the package's insertion-sort via sort.IntsAsc.
fun MedianInt(s []int) int {
    var n int = len(s)
    if n == 0 { ret 0 }
    var copyS []int = new(n) []int {}
    for i := 0; i < n; i++ {
        copyS[i] = s[i]
    }
    copyS = sort.IntsAsc(copyS)
    if n % 2 == 1 {
        ret copyS[n / 2]
    }
    var lo int = copyS[n/2 - 1]
    var hi int = copyS[n/2]
    ret (lo + hi) / 2
}

// MedianString returns the lex-order median element of s. For odd
// n returns the middle element; for even n returns the LOWER of
// the two middle elements (strings don't average meaningfully, so
// the convention is the same as `KthSmallestString(s, (n-1)/2)`).
// Empty slice returns "". Sorts a copy via sort.StringsAsc, doesn't
// mutate s. O(n²) via the package insertion sort.
fun MedianString(s []string) string {
    var n int = len(s)
    if n == 0 { ret "" }
    var copyS []string = new(n) []string {}
    for i := 0; i < n; i++ {
        copyS[i] = "" + s[i]
    }
    copyS = sort.StringsAsc(copyS)
    if n % 2 == 1 {
        ret "" + copyS[n / 2]
    }
    ret "" + copyS[n/2 - 1]
}

// PercentileInt returns the p-th percentile of s (p in 0..100),
// using nearest-rank (the C = 1 / "older Excel" definition that
// avoids interpolation, so all returned values are actual elements
// of s). Sorts a copy of s ascending and selects element at rank
// `ceil(p/100 * n)`, clamped to [1, n]. Special cases: empty s
// returns 0; p<=0 returns the min; p>=100 returns the max. Does
// not mutate s. O(n²) via the package insertion sort. Useful for
// latency p50/p95/p99-style summary stats.
fun PercentileInt(s []int, p int) int {
    var n int = len(s)
    if n == 0 { ret 0 }
    var copyS []int = new(n) []int {}
    for i := 0; i < n; i++ {
        copyS[i] = s[i]
    }
    copyS = sort.IntsAsc(copyS)
    if p <= 0 { ret copyS[0] }
    if p >= 100 { ret copyS[n - 1] }
    // nearest-rank: rank = ceil(p/100 * n), 1-based.
    var rank int = (p * n + 99) / 100
    if rank < 1 { rank = 1 }
    if rank > n { rank = n }
    ret copyS[rank - 1]
}

// IQRInt returns the interquartile range of s — the spread of the
// middle 50% of values, computed as PercentileInt(s, 75) -
// PercentileInt(s, 25). A standard robust-spread statistic (less
// affected by outliers than max-min). Empty s and single-element
// s both return 0. Does not mutate s. Note: uses nearest-rank
// percentile (PercentileInt), so the quartile cuts may shift by
// up to one element vs. interpolated definitions for small n.
fun IQRInt(s []int) int {
    var n int = len(s)
    if n < 2 { ret 0 }
    var q3 int = PercentileInt(s, 75)
    var q1 int = PercentileInt(s, 25)
    ret q3 - q1
}

// OutlierBoundsInt returns the Tukey fence (lo, hi) for outlier
// detection. lo = Q1 - 1.5*IQR; hi = Q3 + 1.5*IQR. Any value in s
// outside [lo, hi] is conventionally considered an outlier. Empty
// or single-element s returns (0, 0). Use case: anomaly filtering,
// metric-stream pre-processing, dashboard auto-zoom.
//
// IQR uses nearest-rank percentile so the bounds shift by up to one
// element vs. interpolated definitions for small n. Multiplier is
// fixed at 1.5 (the standard Tukey value) — for "extreme outliers"
// the user multiplies by 3 manually.
fun OutlierBoundsInt(s []int) (int, int) {
    var n int = len(s)
    if n < 2 { ret 0, 0 }
    var q1 int = PercentileInt(s, 25)
    var q3 int = PercentileInt(s, 75)
    var iqr int = q3 - q1
    // 1.5 * IQR = IQR + IQR/2; do it in integer math to avoid float.
    var fence int = iqr + iqr / 2
    ret q1 - fence, q3 + fence
}

// IsOutlierInt reports whether `v` lies outside the Tukey fence
// computed from s (see OutlierBoundsInt). Convenience for the
// common "is this point anomalous" check during streaming
// metric processing.
fun IsOutlierInt(s []int, v int) bool {
    var lo int = 0
    var hi int = 0
    lo, hi = OutlierBoundsInt(s)
    if hi == 0 {
        if lo == 0 { ret false }
    }
    ret v < lo || v > hi
}

// SpreadInt returns max(s) - min(s), the simplest dispersion stat.
// Empty s and single-element s both return 0. Does not mutate s.
// O(n). Less robust than IQRInt — a single outlier can balloon
// the result — but cheaper and a natural sanity-check companion.
fun SpreadInt(s []int) int {
    var n int = len(s)
    if n < 2 { ret 0 }
    var mn int = s[0]
    var mx int = s[0]
    for i := 1; i < n; i++ {
        if s[i] < mn { mn = s[i] }
        if s[i] > mx { mx = s[i] }
    }
    ret mx - mn
}

// ModeInt returns the most-common element of s. When several values
// tie for the highest count, the one that appears EARLIEST in s
// wins. Empty slice returns 0. O(n²) — fine for small/mid slices;
// build a `map[int]int` histogram by hand if you need O(n).
fun ModeInt(s []int) int {
    var n int = len(s)
    if n == 0 { ret 0 }
    var bestIdx int = 0
    var bestCount int = 0
    for i := 0; i < n; i++ {
        var count int = 0
        for j := 0; j < n; j++ {
            if s[j] == s[i] { count = count + 1 }
        }
        if count > bestCount {
            bestCount = count
            bestIdx = i
        }
    }
    ret s[bestIdx]
}

// ModeString is the []string counterpart of ModeInt.
fun ModeString(s []string) string {
    var n int = len(s)
    if n == 0 { ret "" }
    var bestIdx int = 0
    var bestCount int = 0
    for i := 0; i < n; i++ {
        var count int = 0
        for j := 0; j < n; j++ {
            if s[j] == s[i] { count = count + 1 }
        }
        if count > bestCount {
            bestCount = count
            bestIdx = i
        }
    }
    ret "" + s[bestIdx]
}

// HistogramString returns a map from each distinct string in s to
// the number of times it appears. Equivalent to a tally / frequency
// table. O(n) time, O(distinct) space. Useful for word counts,
// vote tallying, GroupBy aggregates with single-value buckets.
fun HistogramString(s []string) map[string]int {
    var out map[string]int = new map[string]int
    var n int = len(s)
    for i := 0; i < n; i++ {
        var k string = "" + s[i]
        out[k] = out[k] + 1
    }
    ret out
}

// HistogramInt returns a map from each distinct int in s (rendered
// as decimal-string via strconv.Itoa) to its occurrence count. Volt
// maps only support string keys, so the int values are stringified
// — recover them at consumption time via strconv.Atoi or just emit
// the keys directly for display. O(n) time, O(distinct) space.
fun HistogramInt(s []int) map[string]int {
    var out map[string]int = new map[string]int
    var n int = len(s)
    for i := 0; i < n; i++ {
        var k string = strconv.Itoa(s[i])
        out[k] = out[k] + 1
    }
    ret out
}

// BucketCountInt distributes elements of s into `n` equal-width
// buckets covering [lo, hi] inclusive and returns the per-bucket
// counts. Elements outside [lo, hi] are silently dropped; elements
// equal to hi go into the last bucket. n <= 0 or hi <= lo returns
// an empty slice. Useful for fixed-width histograms over numeric
// data — e.g. latency-percentile bins, score distributions.
fun BucketCountInt(s []int, lo int, hi int, n int) []int {
    if n <= 0 { ret new(0) []int {} }
    if hi <= lo { ret new(0) []int {} }
    var counts []int = new(n) []int {}
    var width int = (hi - lo + 1)
    var sn int = len(s)
    for i := 0; i < sn; i++ {
        var v int = s[i]
        if v < lo { continue }
        if v > hi { continue }
        // Map v into bucket index: 0..n-1. Use integer division.
        var off int = v - lo
        var idx int = off * n / width
        if idx >= n { idx = n - 1 }
        counts[idx] = counts[idx] + 1
    }
    ret counts
}

// RunLengthEncodeInt compresses s into (values, counts) such that
// for each i, the element values[i] appears counts[i] times in a
// row at that position in s. Adjacent equal runs collapse into one
// (values, count) pair. Empty slice returns two empty slices. The
// invariant `RunLengthDecodeInt(RunLengthEncodeInt(s)) == s` holds.
// Useful for: simple compression, streak compaction, sparse-pattern
// analysis.
fun RunLengthEncodeInt(s []int) ([]int, []int) {
    var n int = len(s)
    var values []int = new(0) []int {}
    var counts []int = new(0) []int {}
    if n == 0 { ret values, counts }
    var cur int = s[0]
    var runLen int = 1
    for i := 1; i < n; i++ {
        if s[i] == cur {
            runLen = runLen + 1
        } else {
            values = append(values, cur)
            counts = append(counts, runLen)
            cur = s[i]
            runLen = 1
        }
    }
    values = append(values, cur)
    counts = append(counts, runLen)
    ret values, counts
}

// RunLengthDecodeInt is the inverse of RunLengthEncodeInt. For each
// position i, it emits values[i] repeated counts[i] times. If the
// two input slices have different lengths, decoding stops at the
// shorter one (no error, defensive). Negative counts contribute 0
// elements (treated as zero-run).
fun RunLengthDecodeInt(values []int, counts []int) []int {
    var nv int = len(values)
    var nc int = len(counts)
    var pairs int = nv
    if nc < pairs { pairs = nc }
    var total int = 0
    for i := 0; i < pairs; i++ {
        if counts[i] > 0 { total = total + counts[i] }
    }
    var out []int = new(total) []int {}
    var idx int = 0
    for i := 0; i < pairs; i++ {
        var c int = counts[i]
        if c <= 0 { continue }
        var v int = values[i]
        for k := 0; k < c; k++ {
            out[idx] = v
            idx = idx + 1
        }
    }
    ret out
}

// RunLengthEncodeString is the []string counterpart of
// RunLengthEncodeInt. Same (values, counts) shape.
fun RunLengthEncodeString(s []string) ([]string, []int) {
    var n int = len(s)
    var values []string = new(0) []string {}
    var counts []int = new(0) []int {}
    if n == 0 { ret values, counts }
    var cur string = "" + s[0]
    var runLen int = 1
    for i := 1; i < n; i++ {
        if s[i] == cur {
            runLen = runLen + 1
        } else {
            values = append(values, "" + cur)
            counts = append(counts, runLen)
            cur = "" + s[i]
            runLen = 1
        }
    }
    values = append(values, "" + cur)
    counts = append(counts, runLen)
    ret values, counts
}

// RunLengthDecodeString is the inverse of RunLengthEncodeString.
fun RunLengthDecodeString(values []string, counts []int) []string {
    var nv int = len(values)
    var nc int = len(counts)
    var pairs int = nv
    if nc < pairs { pairs = nc }
    var total int = 0
    for i := 0; i < pairs; i++ {
        if counts[i] > 0 { total = total + counts[i] }
    }
    var out []string = new(total) []string {}
    var idx int = 0
    for i := 0; i < pairs; i++ {
        var c int = counts[i]
        if c <= 0 { continue }
        for k := 0; k < c; k++ {
            out[idx] = "" + values[i]
            idx = idx + 1
        }
    }
    ret out
}

// LongestRunInt returns the length of the longest run of
// consecutive equal elements in s. Empty slice returns 0;
// non-empty slice with all distinct elements returns 1. Useful
// for streak detection, run-length encoding analysis.
fun LongestRunInt(s []int) int {
    var n int = len(s)
    if n == 0 { ret 0 }
    var best int = 1
    var current int = 1
    for i := 1; i < n; i++ {
        if s[i] == s[i-1] {
            current = current + 1
            if current > best { best = current }
        } else {
            current = 1
        }
    }
    ret best
}

// LongestRunValueInt returns the (value, length) of the longest
// run of consecutive equal elements in s. Ties go to the run that
// STARTS earlier (stable). Empty s returns (0, 0). Useful when you
// need to know WHAT value formed the streak (e.g. "we had 7 wins
// in a row by team Red" — Red and 7 both surface).
fun LongestRunValueInt(s []int) (int, int) {
    var n int = len(s)
    if n == 0 { ret 0, 0 }
    var bestVal int = s[0]
    var best int = 1
    var current int = 1
    for i := 1; i < n; i++ {
        if s[i] == s[i-1] {
            current = current + 1
            if current > best {
                best = current
                bestVal = s[i]
            }
        } else {
            current = 1
        }
    }
    ret bestVal, best
}

// LongestRunValueString is the []string counterpart of
// LongestRunValueInt.
fun LongestRunValueString(s []string) (string, int) {
    var n int = len(s)
    if n == 0 { ret "", 0 }
    var bestVal string = "" + s[0]
    var best int = 1
    var current int = 1
    for i := 1; i < n; i++ {
        if s[i] == s[i-1] {
            current = current + 1
            if current > best {
                best = current
                bestVal = "" + s[i]
            }
        } else {
            current = 1
        }
    }
    ret bestVal, best
}

// LongestRunString is the []string counterpart of LongestRunInt.
fun LongestRunString(s []string) int {
    var n int = len(s)
    if n == 0 { ret 0 }
    var best int = 1
    var current int = 1
    for i := 1; i < n; i++ {
        if s[i] == s[i-1] {
            current = current + 1
            if current > best { best = current }
        } else {
            current = 1
        }
    }
    ret best
}

// MaxMinInt returns (max, min) of s in a single pass. Empty slice
// returns (0, 0). Saves a second pass when the caller needs both
// extremes — useful for normalization / range queries.
fun MaxMinInt(s []int) (int, int) {
    var n int = len(s)
    if n == 0 { ret 0, 0 }
    var mx int = s[0]
    var mn int = s[0]
    for i := 1; i < n; i++ {
        if s[i] > mx { mx = s[i] }
        if s[i] < mn { mn = s[i] }
    }
    ret mx, mn
}

// AccumulateMinInt returns the running minima of s. Result has the
// same length as s. out[i] = min(s[0]..s[i]). Empty slice returns
// an empty slice. Counterpart to AccumulateMaxInt (STDLIB.112).
fun AccumulateMinInt(s []int) []int {
    var n int = len(s)
    var out []int = new(n) []int {}
    if n == 0 { ret out }
    var best int = s[0]
    out[0] = best
    for i := 1; i < n; i++ {
        if s[i] < best { best = s[i] }
        out[i] = best
    }
    ret out
}

// AccumulateProductInt returns the running products (prefix products)
// of s. Result has the same length as s. out[i] = s[0]*s[1]*..*s[i].
// Empty slice returns an empty slice. Overflow wraps silently.
// Counterpart to AccumulateInt (running sums).
fun AccumulateProductInt(s []int) []int {
    var n int = len(s)
    var out []int = new(n) []int {}
    var prod int = 1
    for i := 0; i < n; i++ {
        prod = prod * s[i]
        out[i] = prod
    }
    ret out
}

// MovingAverageInt returns the k-element sliding-window arithmetic
// means of s. Result length is n - k + 1 (the number of full
// windows). Returns an empty slice when k <= 0 or n < k. Each
// output is `sum(window) / k` with integer truncation toward zero.
// Useful for smoothing noisy time series, signal preprocessing.
// ExpAvgInt computes an exponentially weighted moving average over s.
// alpha100 is the smoothing factor expressed as percent (0..100): a
// value of 30 means each new sample contributes 30% and the prior
// EMA contributes 70%. The first output equals s[0]; each subsequent
// out[i] = (alpha100 * s[i] + (100 - alpha100) * out[i-1]) / 100.
// Empty input → empty. alpha100 clamped to [0, 100].
// Use case: smoothing noisy time-series for charts, signal denoising,
// metric streams where recency matters more than equal-weighted means.
fun ExpAvgInt(s []int, alpha100 int) []int {
    var n int = len(s)
    var out []int = new(n) []int {}
    if n == 0 { ret out }
    var a int = alpha100
    if a < 0 { a = 0 }
    if a > 100 { a = 100 }
    var b int = 100 - a
    out[0] = s[0]
    for i := 1; i < n; i++ {
        out[i] = (a * s[i] + b * out[i-1]) / 100
    }
    ret out
}

// IsAlternatingInt reports whether s strictly alternates direction
// — every adjacent pair changes sign of difference. [1, 5, 2, 7, 3]
// alternates (up, down, up, down); [1, 2, 3, 4] doesn't. Empty +
// single-element slices return true vacuously. Equal adjacent values
// break the alternation. Use case: zigzag/sawtooth detection in
// signal streams, oscillation tests in metric data.
fun IsAlternatingInt(s []int) bool {
    var n int = len(s)
    if n < 3 { ret true }
    var prevSign int = 0
    if s[1] > s[0] { prevSign = 1 } else if s[1] < s[0] { prevSign = -1 } else { ret false }
    for i := 2; i < n; i++ {
        var sign int = 0
        if s[i] > s[i-1] { sign = 1 } else if s[i] < s[i-1] { sign = -1 } else { ret false }
        if sign == prevSign { ret false }
        prevSign = sign
    }
    ret true
}

// PeaksInt returns indices of LOCAL MAXIMA in s — positions i where
// s[i-1] < s[i] > s[i+1]. Edge positions are never peaks (no left or
// right neighbor). Empty + small slices return empty. Plateaus
// (consecutive equal values) are NOT peaks. Use case: anomaly
// detection in time-series, signal-peak picking, chart annotations.
fun PeaksInt(s []int) []int {
    var n int = len(s)
    if n < 3 {
        var empty []int = new(0) []int {}
        ret empty
    }
    var count int = 0
    for i := 1; i < n - 1; i++ {
        if s[i] > s[i-1] {
            if s[i] > s[i+1] { count = count + 1 }
        }
    }
    var out []int = new(count) []int {}
    var idx int = 0
    for i := 1; i < n - 1; i++ {
        if s[i] > s[i-1] {
            if s[i] > s[i+1] {
                out[idx] = i
                idx = idx + 1
            }
        }
    }
    ret out
}

// ValleysInt returns indices of LOCAL MINIMA — counterpart to
// PeaksInt. Position i where s[i-1] > s[i] < s[i+1]. Same edge +
// plateau rules apply.
fun ValleysInt(s []int) []int {
    var n int = len(s)
    if n < 3 {
        var empty []int = new(0) []int {}
        ret empty
    }
    var count int = 0
    for i := 1; i < n - 1; i++ {
        if s[i] < s[i-1] {
            if s[i] < s[i+1] { count = count + 1 }
        }
    }
    var out []int = new(count) []int {}
    var idx int = 0
    for i := 1; i < n - 1; i++ {
        if s[i] < s[i-1] {
            if s[i] < s[i+1] {
                out[idx] = i
                idx = idx + 1
            }
        }
    }
    ret out
}

// CountIfInt returns the number of elements in s that satisfy pred.
// Predicate-driven counterpart to CountInt (which counts a fixed
// value). O(n). Use case: streaming filters, threshold tallies,
// histogram bucket prep when the rule is non-trivial.
fun CountIfInt(s []int, pred fun(int) bool) int {
    var n int = len(s)
    var count int = 0
    for i := 0; i < n; i++ {
        if pred(s[i]) { count = count + 1 }
    }
    ret count
}

// CountIfString is the []string counterpart of CountIfInt.
fun CountIfString(s []string, pred fun(string) bool) int {
    var n int = len(s)
    var count int = 0
    for i := 0; i < n; i++ {
        if pred(s[i]) { count = count + 1 }
    }
    ret count
}

// LinearRegressionInt fits a line y = slope*x + intercept to the given
// (xs, ys) sample. Returns (slope*1000, intercept*1000) — both scaled
// by 1000 since volt's integers can't represent fractions directly.
// Empty input or mismatched lengths → (0, 0). Use case: trend lines
// for terminal charts, simple curve fitting in metric streams.
//
// Math: slope = (n*Σxy - Σx*Σy) / (n*Σx² - (Σx)²)
//       intercept = (Σy - slope*Σx) / n
// Scale the result by 1000 to preserve 3 decimal digits of precision.
fun LinearRegressionInt(xs []int, ys []int) (int, int) {
    var n int = len(xs)
    if n == 0 { ret 0, 0 }
    if n != len(ys) { ret 0, 0 }
    var sx int = 0
    var sy int = 0
    var sxy int = 0
    var sxx int = 0
    for i := 0; i < n; i++ {
        sx = sx + xs[i]
        sy = sy + ys[i]
        sxy = sxy + xs[i] * ys[i]
        sxx = sxx + xs[i] * xs[i]
    }
    var denom int = n * sxx - sx * sx
    if denom == 0 { ret 0, sy * 1000 / n }
    var slopeScaled int = (n * sxy - sx * sy) * 1000 / denom
    // intercept = mean(y) - slope * mean(x); express scaled.
    // mean(y) = sy/n; slope = slopeScaled/1000.
    // intercept = sy/n - (slopeScaled/1000) * (sx/n)
    // intercept * 1000 = (sy * 1000)/n - slopeScaled * sx / n
    var interceptScaled int = (sy * 1000 - slopeScaled * sx) / n
    ret slopeScaled, interceptScaled
}

// MovingMedianInt returns the rolling median over a window of size k.
// Output length = len(s); the first k-1 positions reuse the median
// of the available prefix. Empty input → empty. k<=0 or k>len(s) →
// clamped to a sane window. Robust against outliers (unlike
// MovingAverageInt — a single spike doesn't pull the median). Use
// case: filtering noisy sensor streams, smoothing logs.
//
// O(n*k*log k) via per-window sort. Fine for small k; for large k
// consider a heap-based two-balanced-heap approach (future work).
fun MovingMedianInt(s []int, k int) []int {
    var n int = len(s)
    var out []int = new(n) []int {}
    if n == 0 { ret out }
    var w int = k
    if w <= 0 { w = 1 }
    if w > n { w = n }
    for i := 0; i < n; i++ {
        var lo int = i - w + 1
        if lo < 0 { lo = 0 }
        var sz int = i - lo + 1
        var win []int = new(sz) []int {}
        for j := 0; j < sz; j++ { win[j] = s[lo + j] }
        out[i] = MedianInt(win)
    }
    ret out
}

fun MovingAverageInt(s []int, k int) []int {
    var n int = len(s)
    if k <= 0 { ret new(0) []int {} }
    if n < k { ret new(0) []int {} }
    var out []int = new(n - k + 1) []int {}
    var sum int = 0
    for i := 0; i < k; i++ {
        sum = sum + s[i]
    }
    out[0] = sum / k
    for i := k; i < n; i++ {
        sum = sum + s[i] - s[i - k]
        out[i - k + 1] = sum / k
    }
    ret out
}

// MovingSumInt returns the rolling k-element sum: out[i] is
// sum(s[i .. i+k-1]) for i in [0, n-k]. Result length n-k+1.
// k<=0 or n<k → empty. O(n). Useful for cumulative sliding-window
// counts, signal energy windows.
fun MovingSumInt(s []int, k int) []int {
    var n int = len(s)
    if k <= 0 { ret new(0) []int {} }
    if n < k { ret new(0) []int {} }
    var out []int = new(n - k + 1) []int {}
    var sum int = 0
    for i := 0; i < k; i++ {
        sum = sum + s[i]
    }
    out[0] = sum
    for i := k; i < n; i++ {
        sum = sum + s[i] - s[i - k]
        out[i - k + 1] = sum
    }
    ret out
}

// SumIntFunc returns the sum of fn(s[i]) over all elements. The
// projection lets callers tally derived values without a separate
// MapInts pass — e.g. total length of strings, sum of squares,
// running totals weighted by index. Empty slice returns 0.
fun SumIntFunc(s []int, fn fun(int) int) int {
    var total int = 0
    var n int = len(s)
    for i := 0; i < n; i++ {
        total = total + fn(s[i])
    }
    ret total
}

// SumStringFunc is the []string counterpart of SumIntFunc — the
// projection still returns int (e.g. lengths, word counts).
fun SumStringFunc(s []string, fn fun(string) int) int {
    var total int = 0
    var n int = len(s)
    for i := 0; i < n; i++ {
        total = total + fn(s[i])
    }
    ret total
}

// PartitionAtInt splits s at index i, returning (left, right) where
// left = s[0..i] and right = s[i..n]. Both slices are fresh copies
// (s is not mutated). Negative i is clamped to 0; i > n is clamped
// to n. Useful for "split at this position" patterns without manual
// double-allocation.
fun PartitionAtInt(s []int, i int) ([]int, []int) {
    var n int = len(s)
    var k int = i
    if k < 0 { k = 0 }
    if k > n { k = n }
    var left []int = new(k) []int {}
    var right []int = new(n - k) []int {}
    for j := 0; j < k; j++ {
        left[j] = s[j]
    }
    for j := k; j < n; j++ {
        right[j - k] = s[j]
    }
    ret left, right
}

// PartitionAtString is the []string counterpart of PartitionAtInt.
fun PartitionAtString(s []string, i int) ([]string, []string) {
    var n int = len(s)
    var k int = i
    if k < 0 { k = 0 }
    if k > n { k = n }
    var left []string = new(k) []string {}
    var right []string = new(n - k) []string {}
    for j := 0; j < k; j++ {
        left[j] = "" + s[j]
    }
    for j := k; j < n; j++ {
        right[j - k] = "" + s[j]
    }
    ret left, right
}

// MovingMaxInt returns the k-element sliding-window maxima of s.
// Result length is n - k + 1 (the number of full windows). Returns
// empty when k <= 0 or n < k. O(n*k) — fine for small k. Useful for
// peak-detection in noisy data, sliding max for online queries.
fun MovingMaxInt(s []int, k int) []int {
    var n int = len(s)
    if k <= 0 { ret new(0) []int {} }
    if n < k { ret new(0) []int {} }
    var out []int = new(n - k + 1) []int {}
    for i := 0; i <= n - k; i++ {
        var best int = s[i]
        for j := 1; j < k; j++ {
            if s[i + j] > best { best = s[i + j] }
        }
        out[i] = best
    }
    ret out
}

// MovingMinInt is the symmetric counterpart to MovingMaxInt.
fun MovingMinInt(s []int, k int) []int {
    var n int = len(s)
    if k <= 0 { ret new(0) []int {} }
    if n < k { ret new(0) []int {} }
    var out []int = new(n - k + 1) []int {}
    for i := 0; i <= n - k; i++ {
        var best int = s[i]
        for j := 1; j < k; j++ {
            if s[i + j] < best { best = s[i + j] }
        }
        out[i] = best
    }
    ret out
}

// SortIndicesInt returns the permutation `p` such that
// `s[p[0]] <= s[p[1]] <= ... <= s[p[n-1]]`. The input is NOT
// modified. Stable insertion sort — ties preserve the original
// index order. Useful for "sort one slice and apply the same
// permutation to a parallel slice" patterns (e.g. sort users by
// score while keeping the corresponding names aligned).
fun SortIndicesInt(s []int) []int {
    var n int = len(s)
    var idx []int = new(n) []int {}
    for i := 0; i < n; i++ {
        idx[i] = i
    }
    for i := 1; i < n; i++ {
        var x int = idx[i]
        var v int = s[x]
        var j int = i - 1
        for j >= 0 {
            if s[idx[j]] <= v { break }
            idx[j+1] = idx[j]
            j = j - 1
        }
        idx[j+1] = x
    }
    ret idx
}

// SortIndicesString is the []string counterpart of SortIndicesInt.
// Uses the same byte-wise lex compare the rest of the package uses.
fun SortIndicesString(s []string) []int {
    var n int = len(s)
    var idx []int = new(n) []int {}
    for i := 0; i < n; i++ {
        idx[i] = i
    }
    for i := 1; i < n; i++ {
        var x int = idx[i]
        var v string = s[x]
        var j int = i - 1
        for j >= 0 {
            if !stringLess(v, s[idx[j]]) { break }
            idx[j+1] = idx[j]
            j = j - 1
        }
        idx[j+1] = x
    }
    ret idx
}

// AllSameInt reports whether every element of s equals s[0].
// Empty slice returns true (vacuous truth). Single-element returns
// true. Useful for "did the input change?" / "is this column
// constant?" detection.
fun AllSameInt(s []int) bool {
    var n int = len(s)
    if n <= 1 { ret true }
    var first int = s[0]
    for i := 1; i < n; i++ {
        if s[i] != first { ret false }
    }
    ret true
}

// AllSameString is the []string counterpart of AllSameInt.
fun AllSameString(s []string) bool {
    var n int = len(s)
    if n <= 1 { ret true }
    var first string = s[0]
    for i := 1; i < n; i++ {
        if s[i] != first { ret false }
    }
    ret true
}

// UniqueByInt returns a new slice with duplicates removed, where
// "duplicate" means `key(x)` matches a previous element's key.
// Preserves first occurrence order. Empty slice returns empty.
// Uses a `map[string]bool` seen-set on the stringified key — for
// int keys, `strconv.Itoa` makes a stable string. Useful for "one
// row per user ID", "first event per session" patterns.
fun UniqueByInt(s []int, key fun(int) int) []int {
    var n int = len(s)
    var out []int = new(0) []int {}
    var seen map[string]bool = new map[string]bool
    for i := 0; i < n; i++ {
        var k string = strconv.Itoa(key(s[i]))
        if seen[k] { continue }
        seen[k] = true
        out = append(out, s[i])
    }
    ret out
}

// UniqueByString is the []string counterpart of UniqueByInt — the
// key projection still returns int (use it for a string-of-int
// stringification or a derived numeric key like length, hash).
fun UniqueByString(s []string, key fun(string) int) []string {
    var n int = len(s)
    var out []string = new(0) []string {}
    var seen map[string]bool = new map[string]bool
    for i := 0; i < n; i++ {
        var k string = strconv.Itoa(key(s[i]))
        if seen[k] { continue }
        seen[k] = true
        out = append(out, s[i])
    }
    ret out
}

// UniqueByStringKey is the variant where the projection returns
// a string directly — common when grouping by name / category.
fun UniqueByStringKey(s []string, key fun(string) string) []string {
    var n int = len(s)
    var out []string = new(0) []string {}
    var seen map[string]bool = new map[string]bool
    for i := 0; i < n; i++ {
        var k string = "" + key(s[i])
        if seen[k] { continue }
        seen[k] = true
        out = append(out, s[i])
    }
    ret out
}

// DropInts returns a fresh slice containing s with the first n
// elements removed. n <= 0 returns a full copy of s; n >= len(s)
// returns an empty slice. Complement to HeadInts. Useful for
// pagination — `DropInts(items, pageSize * pageNum)` gives the
// remainder beyond the current page.
fun DropInts(s []int, n int) []int {
    var sl int = len(s)
    if n <= 0 {
        var out []int = new(sl) []int {}
        for i := 0; i < sl; i++ { out[i] = s[i] }
        ret out
    }
    if n >= sl { ret new(0) []int {} }
    var out []int = new(sl - n) []int {}
    for i := 0; i < sl - n; i++ {
        out[i] = s[n + i]
    }
    ret out
}

// DropStrings is the []string counterpart of DropInts.
fun DropStrings(s []string, n int) []string {
    var sl int = len(s)
    if n <= 0 {
        var out []string = new(sl) []string {}
        for i := 0; i < sl; i++ { out[i] = "" + s[i] }
        ret out
    }
    if n >= sl { ret new(0) []string {} }
    var out []string = new(sl - n) []string {}
    for i := 0; i < sl - n; i++ {
        out[i] = "" + s[n + i]
    }
    ret out
}

// DropLastInts returns s without its last n elements. n <= 0 returns
// a fresh copy of s unchanged; n >= len(s) returns empty. Counterpart
// to DropInts (which drops from the front). Useful for trimming a
// trailing sentinel / footer, "all but the last" iteration, undo-N.
fun DropLastInts(s []int, n int) []int {
    var sl int = len(s)
    if n <= 0 {
        var out []int = new(sl) []int {}
        for i := 0; i < sl; i++ { out[i] = s[i] }
        ret out
    }
    if n >= sl { ret new(0) []int {} }
    var out []int = new(sl - n) []int {}
    for i := 0; i < sl - n; i++ {
        out[i] = s[i]
    }
    ret out
}

// DropLastStrings is the []string counterpart of DropLastInts.
fun DropLastStrings(s []string, n int) []string {
    var sl int = len(s)
    if n <= 0 {
        var out []string = new(sl) []string {}
        for i := 0; i < sl; i++ { out[i] = "" + s[i] }
        ret out
    }
    if n >= sl { ret new(0) []string {} }
    var out []string = new(sl - n) []string {}
    for i := 0; i < sl - n; i++ {
        out[i] = "" + s[i]
    }
    ret out
}

// LongestStreakInt returns the length of the longest run of
// consecutive elements satisfying `pred`. Empty slice returns 0.
// Companion to LongestRunInt (STDLIB.122) but with a predicate
// instead of equality. Useful for "longest streak of correct
// answers", "longest sequence of positives", run-length analyses
// where the criterion isn't simple value equality.
fun LongestStreakInt(s []int, pred fun(int) bool) int {
    var n int = len(s)
    var best int = 0
    var current int = 0
    for i := 0; i < n; i++ {
        if pred(s[i]) {
            current = current + 1
            if current > best { best = current }
        } else {
            current = 0
        }
    }
    ret best
}

// LongestStreakString is the []string counterpart.
fun LongestStreakString(s []string, pred fun(string) bool) int {
    var n int = len(s)
    var best int = 0
    var current int = 0
    for i := 0; i < n; i++ {
        if pred(s[i]) {
            current = current + 1
            if current > best { best = current }
        } else {
            current = 0
        }
    }
    ret best
}

// GroupAdjacentInt splits s into runs of consecutive equal
// elements. Returns the runs as a slice-of-slices in source order.
// Empty input returns an empty outer slice. Useful for run-length
// encoding, batched aggregation by run-boundary, anomaly framing.
// Each inner slice is a fresh copy — modifying the result doesn't
// alias s.
fun GroupAdjacentInt(s []int) [][]int {
    var n int = len(s)
    var out [][]int = new(0) [][]int {}
    if n == 0 { ret out }
    var start int = 0
    for i := 1; i < n; i++ {
        if s[i] != s[i-1] {
            var grp []int = new(i - start) []int {}
            for j := 0; j < i - start; j++ {
                grp[j] = s[start + j]
            }
            out = append(out, grp)
            start = i
        }
    }
    var tail []int = new(n - start) []int {}
    for j := 0; j < n - start; j++ {
        tail[j] = s[start + j]
    }
    out = append(out, tail)
    ret out
}

// GroupAdjacentString is the []string counterpart of
// GroupAdjacentInt. Groups runs of consecutive equal strings.
fun GroupAdjacentString(s []string) [][]string {
    var n int = len(s)
    var out [][]string = new(0) [][]string {}
    if n == 0 { ret out }
    var start int = 0
    for i := 1; i < n; i++ {
        if s[i] != s[i-1] {
            var grp []string = new(i - start) []string {}
            for j := 0; j < i - start; j++ {
                grp[j] = "" + s[start + j]
            }
            out = append(out, grp)
            start = i
        }
    }
    var tail []string = new(n - start) []string {}
    for j := 0; j < n - start; j++ {
        tail[j] = "" + s[start + j]
    }
    out = append(out, tail)
    ret out
}

// ChunkByInt groups consecutive elements that share the same `key`
// value into sub-slices. More flexible than GroupAdjacentInt (which
// groups by value identity) — useful for "group by parity", "group
// by sign", "group by classification function". Empty input returns
// an empty outer slice. Each inner slice is a fresh copy.
fun ChunkByInt(s []int, key fun(int) int) [][]int {
    var n int = len(s)
    var out [][]int = new(0) [][]int {}
    if n == 0 { ret out }
    var start int = 0
    var prevKey int = key(s[0])
    for i := 1; i < n; i++ {
        var k int = key(s[i])
        if k != prevKey {
            var grp []int = new(i - start) []int {}
            for j := 0; j < i - start; j++ {
                grp[j] = s[start + j]
            }
            out = append(out, grp)
            start = i
            prevKey = k
        }
    }
    var tail []int = new(n - start) []int {}
    for j := 0; j < n - start; j++ {
        tail[j] = s[start + j]
    }
    out = append(out, tail)
    ret out
}

// ChunkByString is the []string counterpart of ChunkByInt — groups
// consecutive elements sharing a `key(s)` int value.
fun ChunkByString(s []string, key fun(string) int) [][]string {
    var n int = len(s)
    var out [][]string = new(0) [][]string {}
    if n == 0 { ret out }
    var start int = 0
    var prevKey int = key(s[0])
    for i := 1; i < n; i++ {
        var k int = key(s[i])
        if k != prevKey {
            var grp []string = new(i - start) []string {}
            for j := 0; j < i - start; j++ {
                grp[j] = "" + s[start + j]
            }
            out = append(out, grp)
            start = i
            prevKey = k
        }
    }
    var tail []string = new(n - start) []string {}
    for j := 0; j < n - start; j++ {
        tail[j] = "" + s[start + j]
    }
    out = append(out, tail)
    ret out
}

// FindInt returns the first element of s for which pred(x) is true,
// along with a found-flag. Empty / no-match → (0, false). Differs
// from IndexFuncInt (returns index) by handing back the *value*
// directly — saves a re-index step at the call site.
fun FindInt(s []int, pred fun(int) bool) (int, bool) {
    var n int = len(s)
    for i := 0; i < n; i++ {
        if pred(s[i]) {
            ret s[i], true
        }
    }
    ret 0, false
}

// FindString is the []string counterpart of FindInt.
fun FindString(s []string, pred fun(string) bool) (string, bool) {
    var n int = len(s)
    for i := 0; i < n; i++ {
        if pred(s[i]) {
            ret "" + s[i], true
        }
    }
    ret "", false
}

// FindLastInt is the right-to-left counterpart of FindInt — returns
// the last element of s for which pred(x) is true, with a found-flag.
// Empty / no-match → (0, false). Useful for "most recent" / "deepest"
// matches in ordered slices (e.g. last error in a log, last completed
// step in a pipeline).
fun FindLastInt(s []int, pred fun(int) bool) (int, bool) {
    for i := len(s) - 1; i >= 0; i-- {
        if pred(s[i]) {
            ret s[i], true
        }
    }
    ret 0, false
}

// FindLastString is the []string counterpart of FindLastInt.
fun FindLastString(s []string, pred fun(string) bool) (string, bool) {
    for i := len(s) - 1; i >= 0; i-- {
        if pred(s[i]) {
            ret "" + s[i], true
        }
    }
    ret "", false
}

// IsSubsetInt reports whether every distinct value in `a` is also
// present somewhere in `b`. Element multiplicity is NOT considered
// (treats both as sets). Empty `a` is trivially a subset of any
// `b`. O(|a| * |b|) — for large inputs build a map[string]bool of
// b's values first.
fun IsSubsetInt(a []int, b []int) bool {
    var na int = len(a)
    var nb int = len(b)
    for i := 0; i < na; i++ {
        var found bool = false
        for j := 0; j < nb; j++ {
            if a[i] == b[j] { found = true; break }
        }
        if !found { ret false }
    }
    ret true
}

// IsSubsetString is the []string counterpart of IsSubsetInt.
fun IsSubsetString(a []string, b []string) bool {
    var na int = len(a)
    var nb int = len(b)
    for i := 0; i < na; i++ {
        var found bool = false
        for j := 0; j < nb; j++ {
            if a[i] == b[j] { found = true; break }
        }
        if !found { ret false }
    }
    ret true
}

// IntersectInt returns a fresh slice with the DISTINCT values that
// appear in BOTH a and b, in the order they first appear in a.
// Empty result if either input is empty. O(|a| * |b|) — large
// inputs should pre-build a map[string]bool of b's keys.
fun IntersectInt(a []int, b []int) []int {
    var out []int = new(0) []int {}
    var na int = len(a)
    var nb int = len(b)
    if na == 0 { ret out }
    if nb == 0 { ret out }
    var seen map[string]bool = new map[string]bool
    for i := 0; i < na; i++ {
        var k string = strconv.Itoa(a[i])
        if seen[k] { continue }
        for j := 0; j < nb; j++ {
            if a[i] == b[j] {
                seen[k] = true
                out = append(out, a[i])
                break
            }
        }
    }
    ret out
}

// IsDisjointInt reports whether a and b share NO element in
// common. Empty input on either side returns true (vacuously
// disjoint). O(|a| * |b|).
fun IsDisjointInt(a []int, b []int) bool {
    var na int = len(a)
    var nb int = len(b)
    for i := 0; i < na; i++ {
        for j := 0; j < nb; j++ {
            if a[i] == b[j] { ret false }
        }
    }
    ret true
}

// IsDisjointString is the []string counterpart of IsDisjointInt.
fun IsDisjointString(a []string, b []string) bool {
    var na int = len(a)
    var nb int = len(b)
    for i := 0; i < na; i++ {
        for j := 0; j < nb; j++ {
            if a[i] == b[j] { ret false }
        }
    }
    ret true
}

// UnionInt returns a fresh slice with the DISTINCT values that
// appear in EITHER a or b — elements of a first (in source order),
// then any new elements from b. Duplicates are dropped. Useful
// for combining feature flag sets, tag aggregation.
fun UnionInt(a []int, b []int) []int {
    var out []int = new(0) []int {}
    var seen map[string]bool = new map[string]bool
    var na int = len(a)
    for i := 0; i < na; i++ {
        var k string = strconv.Itoa(a[i])
        if seen[k] { continue }
        seen[k] = true
        out = append(out, a[i])
    }
    var nb int = len(b)
    for i := 0; i < nb; i++ {
        var k string = strconv.Itoa(b[i])
        if seen[k] { continue }
        seen[k] = true
        out = append(out, b[i])
    }
    ret out
}

// DifferenceInt returns a fresh slice with the DISTINCT values
// in a that are NOT in b. Source order preserved from a. Useful
// for "what's new", "what's removed" diff-style aggregates.
fun DifferenceInt(a []int, b []int) []int {
    var out []int = new(0) []int {}
    var seen map[string]bool = new map[string]bool
    var na int = len(a)
    var nb int = len(b)
    for i := 0; i < na; i++ {
        var k string = strconv.Itoa(a[i])
        if seen[k] { continue }
        var inB bool = false
        for j := 0; j < nb; j++ {
            if a[i] == b[j] { inB = true; break }
        }
        if !inB {
            seen[k] = true
            out = append(out, a[i])
        }
    }
    ret out
}

// IntersectString — distinct values present in BOTH a and b,
// ordered by first appearance in a. String counterpart to
// IntersectInt.
// SymmetricDifferenceInt returns the elements that appear in exactly
// one of a or b (set XOR). Order: a-only first (preserving a's
// order), then b-only (preserving b's order). Duplicates dropped.
// Useful for "what changed between these two sets" diffs.
fun SymmetricDifferenceInt(a []int, b []int) []int {
    var out []int = new(0) []int {}
    var na int = len(a)
    var nb int = len(b)
    for i := 0; i < na; i++ {
        if !ContainsInt(b, a[i]) {
            if !ContainsInt(out, a[i]) {
                out = append(out, a[i])
            }
        }
    }
    for j := 0; j < nb; j++ {
        if !ContainsInt(a, b[j]) {
            if !ContainsInt(out, b[j]) {
                out = append(out, b[j])
            }
        }
    }
    ret out
}

// DisjointInt reports whether a and b share no common elements.
// Linear-scan with early-exit on first hit. Empty operand makes
// disjoint trivially true. Useful for set-conflict checks.
fun DisjointInt(a []int, b []int) bool {
    var na int = len(a)
    for i := 0; i < na; i++ {
        if ContainsInt(b, a[i]) { ret false }
    }
    ret true
}

// SymmetricDifferenceString is the []string counterpart of
// SymmetricDifferenceInt.
fun SymmetricDifferenceString(a []string, b []string) []string {
    var out []string = new(0) []string {}
    var na int = len(a)
    var nb int = len(b)
    for i := 0; i < na; i++ {
        if !ContainsString(b, a[i]) {
            if !ContainsString(out, a[i]) {
                out = append(out, "" + a[i])
            }
        }
    }
    for j := 0; j < nb; j++ {
        if !ContainsString(a, b[j]) {
            if !ContainsString(out, b[j]) {
                out = append(out, "" + b[j])
            }
        }
    }
    ret out
}

// DisjointString is the []string counterpart of DisjointInt.
fun DisjointString(a []string, b []string) bool {
    var na int = len(a)
    for i := 0; i < na; i++ {
        if ContainsString(b, a[i]) { ret false }
    }
    ret true
}

fun IntersectString(a []string, b []string) []string {
    var out []string = new(0) []string {}
    var na int = len(a)
    var nb int = len(b)
    if na == 0 { ret out }
    if nb == 0 { ret out }
    var seen map[string]bool = new map[string]bool
    for i := 0; i < na; i++ {
        var k string = "" + a[i]
        if seen[k] { continue }
        for j := 0; j < nb; j++ {
            if a[i] == b[j] {
                seen[k] = true
                out = append(out, a[i])
                break
            }
        }
    }
    ret out
}

// UnionString is the []string counterpart of UnionInt.
fun UnionString(a []string, b []string) []string {
    var out []string = new(0) []string {}
    var seen map[string]bool = new map[string]bool
    var na int = len(a)
    for i := 0; i < na; i++ {
        var k string = "" + a[i]
        if seen[k] { continue }
        seen[k] = true
        out = append(out, a[i])
    }
    var nb int = len(b)
    for i := 0; i < nb; i++ {
        var k string = "" + b[i]
        if seen[k] { continue }
        seen[k] = true
        out = append(out, b[i])
    }
    ret out
}

// DifferenceString is the []string counterpart of DifferenceInt.
fun DifferenceString(a []string, b []string) []string {
    var out []string = new(0) []string {}
    var seen map[string]bool = new map[string]bool
    var na int = len(a)
    var nb int = len(b)
    for i := 0; i < na; i++ {
        var k string = "" + a[i]
        if seen[k] { continue }
        var inB bool = false
        for j := 0; j < nb; j++ {
            if a[i] == b[j] { inB = true; break }
        }
        if !inB {
            seen[k] = true
            out = append(out, a[i])
        }
    }
    ret out
}

// WindowedSumInt returns the sums of each k-element sliding window
// of s. Result length is n - k + 1. Returns empty when k <= 0 or
// n < k. Companion to MovingAverageInt (STDLIB.127) without the
// final divide — useful when callers want raw rolling totals
// (event counts per window, accumulated change over period).
fun WindowedSumInt(s []int, k int) []int {
    var n int = len(s)
    if k <= 0 { ret new(0) []int {} }
    if n < k { ret new(0) []int {} }
    var out []int = new(n - k + 1) []int {}
    var sum int = 0
    for i := 0; i < k; i++ {
        sum = sum + s[i]
    }
    out[0] = sum
    for i := k; i < n; i++ {
        sum = sum + s[i] - s[i - k]
        out[i - k + 1] = sum
    }
    ret out
}

// ScanInt is the running-history variant of ReduceInt. Returns a
// slice of the running accumulator after each step:
//   out[i] = fn(fn(... fn(init, s[0]) ..., s[i-1]), s[i])
// Result length equals input length. Empty slice returns empty.
// Useful for: showing the running total at each step, building
// cumulative-sum / running-product / running-best charts.
fun ScanInt(s []int, init int, fn fun(int, int) int) []int {
    var n int = len(s)
    var out []int = new(n) []int {}
    var acc int = init
    for i := 0; i < n; i++ {
        acc = fn(acc, s[i])
        out[i] = acc
    }
    ret out
}

// ScanString is the []string counterpart of ScanInt.
fun ScanString(s []string, init string, fn fun(string, string) string) []string {
    var n int = len(s)
    var out []string = new(n) []string {}
    var acc string = "" + init
    for i := 0; i < n; i++ {
        acc = fn(acc, s[i])
        out[i] = "" + acc
    }
    ret out
}

// ZipStringInt returns "key=value" strings pairing each key with
// its corresponding value. When the two inputs differ in length,
// stops at the shorter. Useful for: printing config dumps,
// building URL query strings, log key/value lines.
fun ZipStringInt(keys []string, vals []int) []string {
    var nk int = len(keys)
    var nv int = len(vals)
    var n int = nk
    if nv < n { n = nv }
    var out []string = new(n) []string {}
    for i := 0; i < n; i++ {
        out[i] = keys[i] + "=" + strconv.Itoa(vals[i])
    }
    ret out
}

// ZipStringString returns "key=value" strings (both inputs are
// strings) — counterpart for fully-string key/value pairs.
fun ZipStringString(keys []string, vals []string) []string {
    var nk int = len(keys)
    var nv int = len(vals)
    var n int = nk
    if nv < n { n = nv }
    var out []string = new(n) []string {}
    for i := 0; i < n; i++ {
        out[i] = keys[i] + "=" + vals[i]
    }
    ret out
}

// AdjacentDiffsInt returns the pairwise differences `s[i+1] - s[i]`.
// Result length is n - 1 for n >= 1, empty for n < 2. Useful for
// sequence-analysis: detecting monotonic-up/down runs, spotting
// inflection points, computing instantaneous-change series.
fun AdjacentDiffsInt(s []int) []int {
    var n int = len(s)
    if n < 2 { ret new(0) []int {} }
    var out []int = new(n - 1) []int {}
    for i := 1; i < n; i++ {
        out[i - 1] = s[i] - s[i - 1]
    }
    ret out
}

// AdjacentEqualsInt returns the number of adjacent index pairs
// (i, i+1) for which s[i] == s[i+1]. Useful for: detecting
// stagnation streaks, computing the "duplicate count" without
// running through Compact. Empty / single-element input returns 0.
fun AdjacentEqualsInt(s []int) int {
    var n int = len(s)
    var count int = 0
    for i := 1; i < n; i++ {
        if s[i] == s[i - 1] { count = count + 1 }
    }
    ret count
}

// IsArithmeticInt reports whether s is an arithmetic progression
// (constant adjacent difference). Empty / single-element returns
// true vacuously. Equivalent to "every AdjacentDiffsInt(s) entry
// is equal." Useful for: detecting evenly-spaced indices, sequence-
// validator predicates.
fun IsArithmeticInt(s []int) bool {
    var n int = len(s)
    if n < 2 { ret true }
    var d int = s[1] - s[0]
    for i := 2; i < n; i++ {
        if (s[i] - s[i - 1]) != d { ret false }
    }
    ret true
}

// IsGeometricInt reports whether s is an integer geometric
// progression (constant ratio, with exact integer divisibility at
// every step). The ratio must be an integer — `[1, 2, 5]` is
// rejected because 5/2 is not exact. Returns true vacuously for
// empty / single-element. Returns false if any element is 0
// (ratio undefined). Useful for: powers-of-base detection,
// validating exponential growth.
fun IsGeometricInt(s []int) bool {
    var n int = len(s)
    if n < 2 { ret true }
    for i := 0; i < n; i++ {
        if s[i] == 0 { ret false }
    }
    if (s[1] % s[0]) != 0 { ret false }
    var r int = s[1] / s[0]
    for i := 2; i < n; i++ {
        if (s[i] % s[i - 1]) != 0 { ret false }
        if (s[i] / s[i - 1]) != r { ret false }
    }
    ret true
}

// IsStrictlyIncreasingInt reports whether s is strictly monotonic
// increasing — every element is greater than its predecessor.
// Complement to sort.IntsAreSorted (which allows equals). Empty
// or single-element returns true vacuously. Useful for: detecting
// no-duplicate sorted sequences, validating unique-index-set
// invariants.
fun IsStrictlyIncreasingInt(s []int) bool {
    var n int = len(s)
    for i := 1; i < n; i++ {
        if s[i] <= s[i - 1] { ret false }
    }
    ret true
}

// IsStrictlyDecreasingInt is the symmetric counterpart.
fun IsStrictlyDecreasingInt(s []int) bool {
    var n int = len(s)
    for i := 1; i < n; i++ {
        if s[i] >= s[i - 1] { ret false }
    }
    ret true
}

// MaxIndexInt returns the index of the largest element of s. Ties
// resolve to the FIRST occurrence (lowest index). Empty slice
// returns -1 (sentinel; the value at "no index" is meaningless).
// Companion to MaxInts which returns the value.
fun MaxIndexInt(s []int) int {
    var n int = len(s)
    if n == 0 { ret -1 }
    var bestIdx int = 0
    var best int = s[0]
    for i := 1; i < n; i++ {
        if s[i] > best {
            best = s[i]
            bestIdx = i
        }
    }
    ret bestIdx
}

// MinIndexInt returns the index of the smallest element. Ties to
// first occurrence; empty → -1.
fun MinIndexInt(s []int) int {
    var n int = len(s)
    if n == 0 { ret -1 }
    var bestIdx int = 0
    var best int = s[0]
    for i := 1; i < n; i++ {
        if s[i] < best {
            best = s[i]
            bestIdx = i
        }
    }
    ret bestIdx
}

// MaxAbsInt returns the largest absolute value in s — `max(|x|)`.
// Empty s returns 0. Useful for symmetric normalization (divide
// everything by MaxAbs to map into [-1, 1]), peak-amplitude
// detection, signal-magnitude metrics. Overflow on -MinInt is
// returned unchanged (matches AbsInt semantics).
fun MaxAbsInt(s []int) int {
    var n int = len(s)
    if n == 0 { ret 0 }
    var best int = s[0]
    if best < 0 { best = -best }
    for i := 1; i < n; i++ {
        var v int = s[i]
        if v < 0 { v = -v }
        if v > best { best = v }
    }
    ret best
}

// MinAbsInt returns the smallest absolute value in s — `min(|x|)`.
// Empty s returns 0. Useful for "closest-to-zero" picks (find the
// closest gain/loss, the smallest signed deviation, etc.).
fun MinAbsInt(s []int) int {
    var n int = len(s)
    if n == 0 { ret 0 }
    var best int = s[0]
    if best < 0 { best = -best }
    for i := 1; i < n; i++ {
        var v int = s[i]
        if v < 0 { v = -v }
        if v < best { best = v }
    }
    ret best
}

// IndexOfMaxAbsInt returns the index of the element with the largest
// absolute value (the peak position). Empty s returns -1. Stable
// tie-breaking (earliest wins). Companion to MaxAbsInt — useful when
// callers need both the peak magnitude AND its position (e.g. signal
// peak detection where the timestamp matters).
fun IndexOfMaxAbsInt(s []int) int {
    var n int = len(s)
    if n == 0 { ret -1 }
    var bestIdx int = 0
    var best int = s[0]
    if best < 0 { best = -best }
    for i := 1; i < n; i++ {
        var v int = s[i]
        if v < 0 { v = -v }
        if v > best {
            best = v
            bestIdx = i
        }
    }
    ret bestIdx
}

// IndexOfMinAbsInt returns the index of the element closest to zero
// (smallest absolute value). Empty s returns -1. Stable.
fun IndexOfMinAbsInt(s []int) int {
    var n int = len(s)
    if n == 0 { ret -1 }
    var bestIdx int = 0
    var best int = s[0]
    if best < 0 { best = -best }
    for i := 1; i < n; i++ {
        var v int = s[i]
        if v < 0 { v = -v }
        if v < best {
            best = v
            bestIdx = i
        }
    }
    ret bestIdx
}

// MaxIndexString is the []string counterpart of MaxIndexInt.
// Uses byte-wise lex compare via stringLess.
fun MaxIndexString(s []string) int {
    var n int = len(s)
    if n == 0 { ret -1 }
    var bestIdx int = 0
    for i := 1; i < n; i++ {
        if stringLess(s[bestIdx], s[i]) { bestIdx = i }
    }
    ret bestIdx
}

// MinIndexString is the []string counterpart of MinIndexInt.
fun MinIndexString(s []string) int {
    var n int = len(s)
    if n == 0 { ret -1 }
    var bestIdx int = 0
    for i := 1; i < n; i++ {
        if stringLess(s[i], s[bestIdx]) { bestIdx = i }
    }
    ret bestIdx
}

// SwapInt swaps s[i] and s[j] in place. Out-of-bounds i or j is a
// no-op (returns s unchanged). Returns s so callers can chain
// expressions like the existing in-place mutators.
fun SwapInt(s []int, i int, j int) []int {
    var n int = len(s)
    if i < 0 { ret s }
    if j < 0 { ret s }
    if i >= n { ret s }
    if j >= n { ret s }
    var t int = s[i]
    s[i] = s[j]
    s[j] = t
    ret s
}

// SwapString is the []string counterpart of SwapInt.
fun SwapString(s []string, i int, j int) []string {
    var n int = len(s)
    if i < 0 { ret s }
    if j < 0 { ret s }
    if i >= n { ret s }
    if j >= n { ret s }
    var t string = s[i]
    s[i] = s[j]
    s[j] = t
    ret s
}

// CompareInt returns -1, 0, or 1 indicating the lexicographic
// order of a vs b. Compares element-by-element; if all overlap
// elements equal, the shorter slice is less. Empty slices compare
// equal to other empty slices. Useful for sorting slice-of-slice,
// implementing slice keys in user code.
fun CompareInt(a []int, b []int) int {
    var la int = len(a)
    var lb int = len(b)
    var m int = la
    if lb < m { m = lb }
    for i := 0; i < m; i++ {
        if a[i] < b[i] { ret -1 }
        if a[i] > b[i] { ret 1 }
    }
    if la < lb { ret -1 }
    if la > lb { ret 1 }
    ret 0
}

// CompareString is the []string counterpart of CompareInt, using
// the existing stringLess byte-wise lex compare.
fun CompareString(a []string, b []string) int {
    var la int = len(a)
    var lb int = len(b)
    var m int = la
    if lb < m { m = lb }
    for i := 0; i < m; i++ {
        if stringLess(a[i], b[i]) { ret -1 }
        if stringLess(b[i], a[i]) { ret 1 }
    }
    if la < lb { ret -1 }
    if la > lb { ret 1 }
    ret 0
}

// MinMaxByInt returns (minElem, maxElem) of s by projecting each
// element through key. Single-pass — saves the duplicate scans
// when both extremes are needed (e.g. range normalization). Empty
// slice returns (0, 0). Ties resolve to the first occurrence.
fun MinMaxByInt(s []int, key fun(int) int) (int, int) {
    var n int = len(s)
    if n == 0 { ret 0, 0 }
    var mn int = s[0]
    var mx int = s[0]
    var kMn int = key(s[0])
    var kMx int = kMn
    for i := 1; i < n; i++ {
        var k int = key(s[i])
        if k < kMn {
            mn = s[i]
            kMn = k
        }
        if k > kMx {
            mx = s[i]
            kMx = k
        }
    }
    ret mn, mx
}

// MinMaxByString returns the strings with smallest / largest `key(s)`
// in one pass. Empty input returns ("", ""). Ties resolve to first
// occurrence. The []string counterpart of MinMaxByInt — useful for
// range normalization (shortest / longest), grouping endpoints, and
// "extremes by my custom criterion" reductions.
fun MinMaxByString(s []string, key fun(string) int) (string, string) {
    var n int = len(s)
    if n == 0 { ret "", "" }
    var mn string = "" + s[0]
    var mx string = "" + s[0]
    var kMn int = key(s[0])
    var kMx int = kMn
    for i := 1; i < n; i++ {
        var k int = key(s[i])
        if k < kMn {
            mn = "" + s[i]
            kMn = k
        }
        if k > kMx {
            mx = "" + s[i]
            kMx = k
        }
    }
    ret mn, mx
}

// PadInt returns a slice of length exactly n. If len(s) < n,
// trailing copies of v fill the deficit. If len(s) >= n, the
// first n elements are taken (truncation). n <= 0 returns an
// empty slice. Useful for: fixed-width formatting, batch-job
// padding-to-grid, building zero-extended bit vectors.
fun PadInt(s []int, n int, v int) []int {
    if n <= 0 { ret new(0) []int {} }
    var sl int = len(s)
    var out []int = new(n) []int {}
    var copyN int = sl
    if copyN > n { copyN = n }
    for i := 0; i < copyN; i++ {
        out[i] = s[i]
    }
    for i := copyN; i < n; i++ {
        out[i] = v
    }
    ret out
}

// PadString is the []string counterpart of PadInt.
fun PadString(s []string, n int, v string) []string {
    if n <= 0 { ret new(0) []string {} }
    var sl int = len(s)
    var out []string = new(n) []string {}
    var copyN int = sl
    if copyN > n { copyN = n }
    for i := 0; i < copyN; i++ {
        out[i] = "" + s[i]
    }
    for i := copyN; i < n; i++ {
        out[i] = "" + v
    }
    ret out
}

// MaxMinString returns (max, min) of s in a single pass via the
// byte-wise lex compare in stringLess. Empty slice returns ("", "").
// String counterpart to MaxMinInt.
fun MaxMinString(s []string) (string, string) {
    var n int = len(s)
    if n == 0 { ret "", "" }
    var mx string = "" + s[0]
    var mn string = "" + s[0]
    for i := 1; i < n; i++ {
        if stringLess(mx, s[i]) { mx = "" + s[i] }
        if stringLess(s[i], mn) { mn = "" + s[i] }
    }
    ret mx, mn
}

// VarianceIntScaled returns the sum of squared deviations from the
// integer-truncated mean: Σ(s[i] - mean)². NOT divided by n or n-1
// (caller decides between population / sample variance; integer
// division would lose too much precision here). Empty / single
// returns 0. Useful for: relative-spread comparisons, choosing
// among candidate distributions, building higher-level statistical
// helpers in user code.
fun VarianceIntScaled(s []int) int {
    var n int = len(s)
    if n < 2 { ret 0 }
    var mean int = AverageInt(s)
    var total int = 0
    for i := 0; i < n; i++ {
        var d int = s[i] - mean
        total = total + d * d
    }
    ret total
}

// SortedCopyInt returns a fresh ascending-sorted copy of s. The
// original is unchanged. Useful when callers want sorted output
// for one query while keeping s available for other purposes.
// Counterpart to sort.IntsAsc which sorts in place.
fun SortedCopyInt(s []int) []int {
    var n int = len(s)
    var c []int = new(n) []int {}
    for i := 0; i < n; i++ {
        c[i] = s[i]
    }
    ret sort.IntsAsc(c)
}

// SortedDescCopyInt is the descending counterpart.
fun SortedDescCopyInt(s []int) []int {
    var n int = len(s)
    var c []int = new(n) []int {}
    for i := 0; i < n; i++ {
        c[i] = s[i]
    }
    ret sort.IntsDesc(c)
}

// SortedCopyString returns a fresh ascending-lex-sorted copy of s.
fun SortedCopyString(s []string) []string {
    var n int = len(s)
    var c []string = new(n) []string {}
    for i := 0; i < n; i++ {
        c[i] = "" + s[i]
    }
    ret sort.StringsAsc(c)
}

// SortedDescCopyString is the descending counterpart.
fun SortedDescCopyString(s []string) []string {
    var n int = len(s)
    var c []string = new(n) []string {}
    for i := 0; i < n; i++ {
        c[i] = "" + s[i]
    }
    ret sort.StringsDesc(c)
}

// UniqueSortedInt returns a fresh slice containing every distinct
// int in s, sorted ascending. Equivalent to but more efficient
// than `UniqueInts(SortedCopyInt(s))` — single sort + linear dedup
// without the intermediate alloc. Empty / single-element returns
// a clean copy. Useful for: building set-like ordered collections
// from arbitrary input.
fun UniqueSortedInt(s []int) []int {
    var n int = len(s)
    if n == 0 { ret new(0) []int {} }
    var sorted []int = SortedCopyInt(s)
    var out []int = new(0) []int {}
    out = append(out, sorted[0])
    for i := 1; i < n; i++ {
        if sorted[i] != sorted[i - 1] {
            out = append(out, sorted[i])
        }
    }
    ret out
}

// UniqueSortedString is the []string counterpart of
// UniqueSortedInt.
fun UniqueSortedString(s []string) []string {
    var n int = len(s)
    if n == 0 { ret new(0) []string {} }
    var sorted []string = SortedCopyString(s)
    var out []string = new(0) []string {}
    out = append(out, sorted[0])
    for i := 1; i < n; i++ {
        if sorted[i] != sorted[i - 1] {
            out = append(out, sorted[i])
        }
    }
    ret out
}

// RemoveFirstInt returns a fresh slice with the first occurrence
// of v removed. No occurrence → fresh copy of s. Useful for
// "ack-one" patterns where each occurrence is a separately-handled
// event. Distinct from FilterInts (which is predicate-based and
// removes ALL matches).
fun RemoveFirstInt(s []int, v int) []int {
    var n int = len(s)
    var out []int = new(0) []int {}
    var removed bool = false
    for i := 0; i < n; i++ {
        if !removed {
            if s[i] == v {
                removed = true
                continue
            }
        }
        out = append(out, s[i])
    }
    ret out
}

// RemoveFirstString is the []string counterpart.
fun RemoveFirstString(s []string, v string) []string {
    var n int = len(s)
    var out []string = new(0) []string {}
    var removed bool = false
    for i := 0; i < n; i++ {
        if !removed {
            if s[i] == v {
                removed = true
                continue
            }
        }
        out = append(out, "" + s[i])
    }
    ret out
}

// RemoveAllInt returns a fresh slice with EVERY occurrence of v
// removed. Equivalent to filter-by-not-equal, but more direct at
// call sites.
fun RemoveAllInt(s []int, v int) []int {
    var n int = len(s)
    var out []int = new(0) []int {}
    for i := 0; i < n; i++ {
        if s[i] == v { continue }
        out = append(out, s[i])
    }
    ret out
}

// RemoveAllString is the []string counterpart.
fun RemoveAllString(s []string, v string) []string {
    var n int = len(s)
    var out []string = new(0) []string {}
    for i := 0; i < n; i++ {
        if s[i] == v { continue }
        out = append(out, "" + s[i])
    }
    ret out
}

// ReplaceAllInt returns a fresh slice with every occurrence of
// ReplaceFirstInt returns a fresh slice with the FIRST occurrence
// of `old` replaced by `repl`. Subsequent occurrences are left
// untouched. If `old` isn't present, returns a verbatim copy of s.
// Useful when each value is meant to appear once (unique IDs) and
// only one update is wanted.
fun ReplaceFirstInt(s []int, old int, repl int) []int {
    var n int = len(s)
    var out []int = new(n) []int {}
    var done bool = false
    for i := 0; i < n; i++ {
        if !done {
            if s[i] == old {
                out[i] = repl
                done = true
                continue
            }
        }
        out[i] = s[i]
    }
    ret out
}

// ReplaceFirstString is the []string counterpart of ReplaceFirstInt.
fun ReplaceFirstString(s []string, old string, repl string) []string {
    var n int = len(s)
    var out []string = new(n) []string {}
    var done bool = false
    for i := 0; i < n; i++ {
        if !done {
            if s[i] == old {
                out[i] = "" + repl
                done = true
                continue
            }
        }
        out[i] = "" + s[i]
    }
    ret out
}

// `old` replaced by `repl`. Element order preserved. Length
// unchanged. Useful for sentinel-value substitution (e.g. swap
// -1 for 0 in result arrays), normalization passes.
fun ReplaceAllInt(s []int, old int, repl int) []int {
    var n int = len(s)
    var out []int = new(n) []int {}
    for i := 0; i < n; i++ {
        if s[i] == old {
            out[i] = repl
        } else {
            out[i] = s[i]
        }
    }
    ret out
}

// ReplaceAllString is the []string counterpart.
fun ReplaceAllString(s []string, old string, repl string) []string {
    var n int = len(s)
    var out []string = new(n) []string {}
    for i := 0; i < n; i++ {
        if s[i] == old {
            out[i] = "" + repl
        } else {
            out[i] = "" + s[i]
        }
    }
    ret out
}

// InsertSortedInt returns a fresh slice with v inserted into s at
// the position that keeps the slice ascending-sorted. s SHOULD
// already be ascending-sorted; if it isn't, the result is
// undefined (but no crash). Duplicates are inserted before
// existing equal elements. O(n) linear scan; callers needing
// O(log n) can use BinarySearchInt + manual splice.
fun InsertSortedInt(s []int, v int) []int {
    var n int = len(s)
    var pos int = n
    for i := 0; i < n; i++ {
        if s[i] >= v {
            pos = i
            break
        }
    }
    var out []int = new(n + 1) []int {}
    for i := 0; i < pos; i++ {
        out[i] = s[i]
    }
    out[pos] = v
    for i := pos; i < n; i++ {
        out[i + 1] = s[i]
    }
    ret out
}

// InsertSortedString is the []string counterpart.
fun InsertSortedString(s []string, v string) []string {
    var n int = len(s)
    var pos int = n
    for i := 0; i < n; i++ {
        if !stringLess(s[i], v) {
            pos = i
            break
        }
    }
    var out []string = new(n + 1) []string {}
    for i := 0; i < pos; i++ {
        out[i] = "" + s[i]
    }
    out[pos] = "" + v
    for i := pos; i < n; i++ {
        out[i + 1] = "" + s[i]
    }
    ret out
}

// UpsertSortedInt returns a fresh sorted slice with v guaranteed
// present. If v is already in s (which MUST be ascending-sorted),
// returns a copy unchanged; otherwise inserts v in sorted position.
// Idempotent set-style insert on sorted slices — the sorted analog
// of UpsertInt. Useful for maintaining a sorted unique-IDs list.
fun UpsertSortedInt(s []int, v int) []int {
    var n int = len(s)
    for i := 0; i < n; i++ {
        if s[i] == v {
            var copy []int = new(n) []int {}
            for j := 0; j < n; j++ { copy[j] = s[j] }
            ret copy
        }
        if s[i] > v { break }
    }
    ret InsertSortedInt(s, v)
}

// UpsertSortedString is the []string counterpart of UpsertSortedInt.
fun UpsertSortedString(s []string, v string) []string {
    var n int = len(s)
    for i := 0; i < n; i++ {
        if s[i] == v {
            var copy []string = new(n) []string {}
            for j := 0; j < n; j++ { copy[j] = "" + s[j] }
            ret copy
        }
        if stringLess(v, s[i]) { break }
    }
    ret InsertSortedString(s, v)
}

// UpdateAtInt sets s[i] = v in place and returns s for chaining
// (matches the existing ReverseInts shape). Out-of-bounds i is a
// no-op (returns s unchanged) — safer than the implicit panic.
fun UpdateAtInt(s []int, i int, v int) []int {
    var n int = len(s)
    if i < 0 { ret s }
    if i >= n { ret s }
    s[i] = v
    ret s
}

// UpdateAtString is the []string counterpart.
fun UpdateAtString(s []string, i int, v string) []string {
    var n int = len(s)
    if i < 0 { ret s }
    if i >= n { ret s }
    s[i] = v
    ret s
}

// RemoveAtInt returns a fresh slice with the element at index `idx`
// removed. Out-of-bounds idx returns a clean copy of s. Useful for
// "remove the Nth row" patterns when the value isn't known
// up-front. Distinct from RemoveFirstInt which targets a value.
fun RemoveAtInt(s []int, idx int) []int {
    var n int = len(s)
    if idx < 0 || idx >= n {
        var copyS []int = new(n) []int {}
        for i := 0; i < n; i++ { copyS[i] = s[i] }
        ret copyS
    }
    var out []int = new(n - 1) []int {}
    for i := 0; i < idx; i++ {
        out[i] = s[i]
    }
    for i := idx + 1; i < n; i++ {
        out[i - 1] = s[i]
    }
    ret out
}

// RemoveAtString is the []string counterpart.
fun RemoveAtString(s []string, idx int) []string {
    var n int = len(s)
    if idx < 0 || idx >= n {
        var copyS []string = new(n) []string {}
        for i := 0; i < n; i++ { copyS[i] = "" + s[i] }
        ret copyS
    }
    var out []string = new(n - 1) []string {}
    for i := 0; i < idx; i++ {
        out[i] = "" + s[i]
    }
    for i := idx + 1; i < n; i++ {
        out[i - 1] = "" + s[i]
    }
    ret out
}

// MoveInt moves the element at index `from` to index `to`, shifting
// intervening elements to fill the gap. In-place; returns s for
// chaining. Out-of-bounds indices are no-ops. from == to is a
// no-op. Useful for: reordering lists in UIs (drag-drop), priority
// promotion, batch-reorder semantics without rebuilding.
fun MoveInt(s []int, from int, to int) []int {
    var n int = len(s)
    if from < 0 { ret s }
    if to < 0 { ret s }
    if from >= n { ret s }
    if to >= n { ret s }
    if from == to { ret s }
    var v int = s[from]
    if from < to {
        var i int = from
        for i < to {
            s[i] = s[i + 1]
            i = i + 1
        }
    } else {
        var i int = from
        for i > to {
            s[i] = s[i - 1]
            i = i - 1
        }
    }
    s[to] = v
    ret s
}

// MoveString is the []string counterpart of MoveInt.
fun MoveString(s []string, from int, to int) []string {
    var n int = len(s)
    if from < 0 { ret s }
    if to < 0 { ret s }
    if from >= n { ret s }
    if to >= n { ret s }
    if from == to { ret s }
    var v string = s[from]
    if from < to {
        var i int = from
        for i < to {
            s[i] = s[i + 1]
            i = i + 1
        }
    } else {
        var i int = from
        for i > to {
            s[i] = s[i - 1]
            i = i - 1
        }
    }
    s[to] = v
    ret s
}

// RotateRightInt cyclically rotates s by k positions to the
// RIGHT (counterpart to RotateInts which rotates LEFT). Negative k
// rotates left. Equivalent to RotateInts(s, -k) but reads more
// naturally at call sites. Useful for circular-buffer / shift-
// register patterns where right-shift is the intent.
fun RotateRightInt(s []int, k int) []int {
    ret RotateInts(s, -k)
}

// RotateRightString is the []string counterpart.
fun RotateRightString(s []string, k int) []string {
    ret RotateStrings(s, -k)
}

// IsAllPositiveInt reports whether every element of s is strictly
// greater than 0. Empty slice returns true (vacuous truth).
fun IsAllPositiveInt(s []int) bool {
    var n int = len(s)
    for i := 0; i < n; i++ {
        if s[i] <= 0 { ret false }
    }
    ret true
}

// IsAllNegativeInt reports whether every element of s is strictly
// less than 0. Empty slice returns true.
fun IsAllNegativeInt(s []int) bool {
    var n int = len(s)
    for i := 0; i < n; i++ {
        if s[i] >= 0 { ret false }
    }
    ret true
}

// IsAllZeroInt reports whether every element of s equals 0.
// Empty slice returns true (vacuous truth). Distinct from
// AllSameInt — this is fixed at 0, not "all equal to s[0]".
fun IsAllZeroInt(s []int) bool {
    var n int = len(s)
    for i := 0; i < n; i++ {
        if s[i] != 0 { ret false }
    }
    ret true
}

// FirstNonZeroInt returns the first non-zero element of s, or 0 if
// all entries (or the slice itself) are zero. The int counterpart
// to strings.FirstNonEmpty — useful for "first set port / first
// non-zero priority / first valid id" config-fallback chains:
// `port := FirstNonZeroInt([]int{ envPort, cfgPort, 8080 })`.
fun FirstNonZeroInt(s []int) int {
    var n int = len(s)
    for i := 0; i < n; i++ {
        if s[i] != 0 { ret s[i] }
    }
    ret 0
}

// AnyZeroInt reports whether s contains at least one 0 element.
// Empty slice returns false.
fun AnyZeroInt(s []int) bool {
    var n int = len(s)
    for i := 0; i < n; i++ {
        if s[i] == 0 { ret true }
    }
    ret false
}

// AllPositiveInt reports whether every element of s is strictly > 0.
// Empty slice returns true vacuously. Useful for "all amounts
// positive" / "no debits" / "all weights non-negative-strict"
// preconditions.
fun AllPositiveInt(s []int) bool {
    var n int = len(s)
    for i := 0; i < n; i++ {
        if s[i] <= 0 { ret false }
    }
    ret true
}

// AllNegativeInt reports whether every element of s is strictly < 0.
// Empty slice returns true vacuously.
fun AllNegativeInt(s []int) bool {
    var n int = len(s)
    for i := 0; i < n; i++ {
        if s[i] >= 0 { ret false }
    }
    ret true
}

// AllNonNegativeInt reports whether every element of s is >= 0.
// Empty slice returns true vacuously. Companion to AllPositiveInt
// for cases where zero is acceptable (counts, indices, lengths).
fun AllNonNegativeInt(s []int) bool {
    var n int = len(s)
    for i := 0; i < n; i++ {
        if s[i] < 0 { ret false }
    }
    ret true
}

// AllNonZeroInt reports whether every element of s is non-zero
// (positive or negative). Empty slice returns true vacuously.
// Useful for "no divide-by-zero risk" pre-flight checks.
fun AllNonZeroInt(s []int) bool {
    var n int = len(s)
    for i := 0; i < n; i++ {
        if s[i] == 0 { ret false }
    }
    ret true
}

// CountPositiveInt returns the number of strictly positive elements
// in s (x > 0). Empty → 0. Companion to AllPositiveInt for cases
// where you need a tally rather than a yes/no.
fun CountPositiveInt(s []int) int {
    var n int = len(s)
    var k int = 0
    for i := 0; i < n; i++ {
        if s[i] > 0 { k = k + 1 }
    }
    ret k
}

// CountNegativeInt returns the number of strictly negative elements
// in s (x < 0). Empty → 0.
fun CountNegativeInt(s []int) int {
    var n int = len(s)
    var k int = 0
    for i := 0; i < n; i++ {
        if s[i] < 0 { k = k + 1 }
    }
    ret k
}

// CountZeroInt returns the number of zero elements in s. Empty → 0.
// Useful for sparsity stats / signal-counting.
fun CountZeroInt(s []int) int {
    var n int = len(s)
    var k int = 0
    for i := 0; i < n; i++ {
        if s[i] == 0 { k = k + 1 }
    }
    ret k
}

// SumPositiveInt returns the sum of strictly positive elements of s
// (treats negatives and zero as 0). Empty → 0. Useful for
// "total deposits" / "gross gains" accounting splits.
fun SumPositiveInt(s []int) int {
    var n int = len(s)
    var t int = 0
    for i := 0; i < n; i++ {
        if s[i] > 0 { t = t + s[i] }
    }
    ret t
}

// SumNegativeInt returns the sum of strictly negative elements of s
// (treats positives and zero as 0; the returned sum is itself
// non-positive). Empty → 0. Useful for "total withdrawals" /
// "gross losses" accounting splits.
fun SumNegativeInt(s []int) int {
    var n int = len(s)
    var t int = 0
    for i := 0; i < n; i++ {
        if s[i] < 0 { t = t + s[i] }
    }
    ret t
}

// IsSetInt reports whether every element of s is distinct (no
// duplicates). Empty or single-element slices return true
// vacuously. O(n) via a stringified-key seen-set. Useful for:
// uniqueness invariant checks, validating ID generators.
fun IsSetInt(s []int) bool {
    var n int = len(s)
    var seen map[string]bool = new map[string]bool
    for i := 0; i < n; i++ {
        var k string = strconv.Itoa(s[i])
        if seen[k] { ret false }
        seen[k] = true
    }
    ret true
}

// IsSetString is the []string counterpart of IsSetInt — uses the
// strings themselves as the seen-set key (no Itoa needed).
fun IsSetString(s []string) bool {
    var n int = len(s)
    var seen map[string]bool = new map[string]bool
    for i := 0; i < n; i++ {
        var k string = "" + s[i]
        if seen[k] { ret false }
        seen[k] = true
    }
    ret true
}

// Swap2Ints exchanges the two int values addressed by `a` and `b`
// in place. Both parameters take exclusive write access (`&mut`).
// Because the borrows are "live for the duration of the call",
// this rejects at the call site if either source already has an
// active borrow elsewhere — that's the cross-package borrow check
// at work.
fun Swap2Ints(a &mut int, b &mut int) {
    var t int = *a
    *a = *b
    *b = t
}

// AddIntInPlace adds `by` to the int addressed by `p`. The single
// `&mut` parameter exercises the simplest cross-package borrow
// shape: caller passes `&mut x` and the call-site checker enforces
// that no other borrow of `x` is live.
fun AddIntInPlace(p &mut int, by int) {
    *p = *p + by
}

// MaxAssignInt assigns max(*p, v) into *p. Useful for accumulating
// a running maximum across a fold without a separate return value.
fun MaxAssignInt(p &mut int, v int) {
    if v > *p { *p = v }
}

// MinAssignInt is the dual of MaxAssignInt.
fun MinAssignInt(p &mut int, v int) {
    if v < *p { *p = v }
}

// WindowedInt returns every contiguous k-element view of s as a fresh
// []int. Result has len(s)-k+1 entries; len(s)<k → empty. Each window
// is independently allocated so callers can mutate them without
// aliasing the source. Useful for rolling-window analytics that need
// each window as its own slice (vs MovingAverage / MovingSum which
// fold a single number per step).
fun WindowedInt(s []int, k int) [][]int {
    var n int = len(s)
    if k <= 0 || n < k { ret new(0) [][]int {} }
    var count int = n - k + 1
    var out [][]int = new(count) [][]int {}
    for i := 0; i < count; i++ {
        var win []int = new(k) []int {}
        for j := 0; j < k; j++ { win[j] = s[i + j] }
        out[i] = win
    }
    ret out
}

// PairsInt returns adjacent (s[i], s[i+1]) pairs as a slice of length
// 2*(n-1): out[2i] = s[i], out[2i+1] = s[i+1]. Empty for n<2.
// Useful for diff/delta loops without an explicit index dance.
fun PairsInt(s []int) []int {
    var n int = len(s)
    if n < 2 { ret new(0) []int {} }
    var out []int = new(2 * (n - 1)) []int {}
    for i := 0; i < n - 1; i++ {
        out[2 * i]     = s[i]
        out[2 * i + 1] = s[i + 1]
    }
    ret out
}

// DeltasInt returns the consecutive-difference sequence: out[i] = s[i+1]-s[i].
// Length n-1; empty for n<2. The inverse of a cumulative-sum, useful
// for converting absolute samples into rate-of-change traces.
fun DeltasInt(s []int) []int {
    var n int = len(s)
    if n < 2 { ret new(0) []int {} }
    var out []int = new(n - 1) []int {}
    for i := 0; i < n - 1; i++ {
        out[i] = s[i + 1] - s[i]
    }
    ret out
}

// CumSumInt returns the running-sum trace: out[0]=s[0], out[i]=out[i-1]+s[i].
// Length matches the input; empty for empty input. The inverse of
// DeltasInt (sums the deltas back into absolute values).
fun CumSumInt(s []int) []int {
    var n int = len(s)
    if n == 0 { ret new(0) []int {} }
    var out []int = new(n) []int {}
    var acc int = 0
    for i := 0; i < n; i++ {
        acc = acc + s[i]
        out[i] = acc
    }
    ret out
}

// DedupAdjacentInt collapses each maximal run of equal values to a
// single element, preserving order: [1,1,2,2,2,1,3,3] → [1,2,1,3].
// Unlike a set-dedup it only removes CONSECUTIVE duplicates, so it's
// O(n) with no hashing. Empty input → empty output.
fun DedupAdjacentInt(s []int) []int {
    var n int = len(s)
    if n == 0 { ret new(0) []int {} }
    // First pass: count distinct-adjacent so we can size the output.
    var runs int = 1
    for i := 1; i < n; i++ {
        if s[i] != s[i - 1] { runs = runs + 1 }
    }
    var out []int = new(runs) []int {}
    out[0] = s[0]
    var w int = 1
    for i := 1; i < n; i++ {
        if s[i] != s[i - 1] {
            out[w] = s[i]
            w = w + 1
        }
    }
    ret out
}

// DedupAdjacentString is the []string counterpart of DedupAdjacentInt.
fun DedupAdjacentString(s []string) []string {
    var n int = len(s)
    if n == 0 { ret new(0) []string {} }
    var runs int = 1
    for i := 1; i < n; i++ {
        if s[i] != s[i - 1] { runs = runs + 1 }
    }
    var out []string = new(runs) []string {}
    out[0] = "" + s[0]
    var w int = 1
    for i := 1; i < n; i++ {
        if s[i] != s[i - 1] {
            out[w] = "" + s[i]
            w = w + 1
        }
    }
    ret out
}

// CountRunsInt returns the number of maximal equal-value runs in s.
// [1,1,2,2,2,1] has 3 runs (11 / 222 / 1). Equals len(DedupAdjacentInt(s)).
// 0 for empty input. Useful for run-length analysis without building
// the encoded slice.
fun CountRunsInt(s []int) int {
    var n int = len(s)
    if n == 0 { ret 0 }
    var runs int = 1
    for i := 1; i < n; i++ {
        if s[i] != s[i - 1] { runs = runs + 1 }
    }
    ret runs
}

// ZipSumInt returns the element-wise sum of a and b, truncated to the
// shorter length: out[i] = a[i] + b[i]. Length min(len(a), len(b)).
// The common case of ZipWithInt with a `+` projection, without the
// closure ceremony.
fun ZipSumInt(a []int, b []int) []int {
    var n int = len(a)
    if len(b) < n { n = len(b) }
    var out []int = new(n) []int {}
    for i := 0; i < n; i++ {
        out[i] = a[i] + b[i]
    }
    ret out
}

// HammingDistanceInt counts positions where a and b differ. Over the
// overlapping prefix (min length) it counts unequal elements; any
// extra elements in the longer slice each count as a difference.
// Equal-length equal slices → 0. Useful for diffing fixed-layout
// records or signal vectors.
fun HammingDistanceInt(a []int, b []int) int {
    var na int = len(a)
    var nb int = len(b)
    var n int = na
    if nb < n { n = nb }
    var d int = 0
    for i := 0; i < n; i++ {
        if a[i] != b[i] { d = d + 1 }
    }
    // Tail of the longer slice: each surplus position is a difference.
    if na > n { d = d + (na - n) }
    if nb > n { d = d + (nb - n) }
    ret d
}

// JaccardIndexPctInt returns the Jaccard set-similarity of a and b as
// an integer percentage: 100 * |A∩B| / |A∪B|, rounded toward zero.
// Both empty → 100 (identical empty sets). Values are treated as a
// SET (duplicates ignored). Handy for "how alike are these two tag
// lists / id sets" without floating point. Implemented via
// sort+dedup+merge — deliberately map-free so loop-local key strings
// can't be auto-freed mid-use (the failure mode of string-keyed set ops).
fun JaccardIndexPctInt(a []int, b []int) int {
    var da []int = DedupAdjacentInt(SortedCopyInt(a))   // distinct, sorted
    var db []int = DedupAdjacentInt(SortedCopyInt(b))
    var na int = len(da)
    var nb int = len(db)
    var i int = 0
    var j int = 0
    var inter int = 0
    var uni int = 0
    for i < na && j < nb {
        if da[i] == db[j] {
            inter = inter + 1
            uni = uni + 1
            i = i + 1
            j = j + 1
        } else if da[i] < db[j] {
            uni = uni + 1
            i = i + 1
        } else {
            uni = uni + 1
            j = j + 1
        }
    }
    uni = uni + (na - i) + (nb - j)
    if uni == 0 { ret 100 }
    ret (inter * 100) / uni
}

// IsMultisetEqualInt reports whether a and b contain the same multiset
// of values (same elements with the same multiplicities, any order).
// Different lengths → false. Empty + empty → true. O(n log n) via a
// sort-and-compare (deliberately avoids a string-keyed count map: a
// loop-local key string would be auto-freed while still referenced by
// the map, corrupting cross-iteration lookups). Distinct from
// IsPermutationInt, which checks for a permutation of 1..n. Useful for
// anagram-style "same bag of values" comparisons.
fun IsMultisetEqualInt(a []int, b []int) bool {
    var n int = len(a)
    if len(b) != n { ret false }
    var sa []int = SortedCopyInt(a)
    var sb []int = SortedCopyInt(b)
    for i := 0; i < n; i++ {
        if sa[i] != sb[i] { ret false }
    }
    ret true
}
