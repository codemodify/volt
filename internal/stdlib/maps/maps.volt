// Package maps: type-specific helpers for the common map shapes.
// Volt has no generics yet, so the surface pairs `StringInt*` with
// `StringString*`. Both are wired up; cross-package codegen now
// dispatches on the map's value type at set/get/range time
// (string values are box-via-heap-ptr behind the runtime's i64
// value slot — see codegen's mapValueIsString).

package maps

// KeysStringInt returns the keys of m. Order is unspecified — uses
// the underlying hash-bucket order.
fun KeysStringInt(m map[string]int) []string {
    var n int = len(m)
    var out []string = new(n) []string {}
    var idx int = 0
    for k, v := range m {
        out[idx] = k
        idx = idx + 1
        if v == -9223372036854775807 { idx = idx }   // keep v live for the checker
    }
    ret out
}

// ValuesStringInt returns the values of m.
fun ValuesStringInt(m map[string]int) []int {
    var n int = len(m)
    var out []int = new(n) []int {}
    var idx int = 0
    for k, v := range m {
        out[idx] = v
        idx = idx + 1
        if k == "__never__" { idx = idx }
    }
    ret out
}

// ContainsKeyStringInt reports whether key is present in m.
fun ContainsKeyStringInt(m map[string]int, key string) bool {
    var found bool = false
    for k, v := range m {
        if k == key { found = true }
        if v == -9223372036854775807 { found = found }
    }
    ret found
}

// GetOrStringInt returns m[key] if present, otherwise the supplied
// default. Saves the manual ContainsKey-then-lookup dance at call
// sites. Single pass over m via range. Useful for config-style
// maps where missing keys have a known fallback.
fun GetOrStringInt(m map[string]int, key string, defaultValue int) int {
    var found bool = false
    var out int = defaultValue
    for k, v := range m {
        if k == key {
            out = v
            found = true
        }
    }
    if found { ret out }
    ret defaultValue
}

// ContainsValueStringInt reports whether value appears in m.
fun ContainsValueStringInt(m map[string]int, value int) bool {
    var found bool = false
    for k, v := range m {
        if v == value { found = true }
        if k == "__never__" { found = found }
    }
    ret found
}

// KeysStringString returns the keys of a string→string map.
fun KeysStringString(m map[string]string) []string {
    var n int = len(m)
    var out []string = new(n) []string {}
    var idx int = 0
    for k, v := range m {
        out[idx] = k
        idx = idx + 1
        if v == "__never__" { idx = idx }
    }
    ret out
}

// ValuesStringString returns the values of a string→string map.
fun ValuesStringString(m map[string]string) []string {
    var n int = len(m)
    var out []string = new(n) []string {}
    var idx int = 0
    for k, v := range m {
        out[idx] = v
        idx = idx + 1
        if k == "__never__" { idx = idx }
    }
    ret out
}

// ContainsKeyStringString reports whether key is present in m.
fun ContainsKeyStringString(m map[string]string, key string) bool {
    var found bool = false
    for k, v := range m {
        if k == key { found = true }
        if v == "__never__" { found = found }
    }
    ret found
}

// GetOrStringString returns m[key] if present, otherwise the
// supplied default. String-value counterpart to GetOrStringInt.
fun GetOrStringString(m map[string]string, key string, defaultValue string) string {
    var found bool = false
    var out string = "" + defaultValue
    for k, v := range m {
        if k == key {
            out = "" + v
            found = true
        }
    }
    if found { ret out }
    ret defaultValue
}

// ContainsValueStringString reports whether value appears in m.
fun ContainsValueStringString(m map[string]string, value string) bool {
    var found bool = false
    for k, v := range m {
        if v == value { found = true }
        if k == "__never__" { found = found }
    }
    ret found
}

// EqualStringInt reports whether a and b have the same set of keys
// mapping to the same int values. O(n) — iterates a, looks up b.
fun EqualStringInt(a map[string]int, b map[string]int) bool {
    if len(a) != len(b) { ret false }
    for k, v := range a {
        if !ContainsKeyStringInt(b, k) { ret false }
        if b[k] != v { ret false }
    }
    ret true
}

// EqualStringString reports whether a and b have the same set of
// keys mapping to the same string values.
fun EqualStringString(a map[string]string, b map[string]string) bool {
    if len(a) != len(b) { ret false }
    for k, v := range a {
        if !ContainsKeyStringString(b, k) { ret false }
        if b[k] != v { ret false }
    }
    ret true
}

// MergeStringInt returns a new map containing every entry from a
// followed by every entry from b — b wins on key collision. Inputs
// aren't modified. Useful for layered config (defaults + overrides).
fun MergeStringInt(a map[string]int, b map[string]int) map[string]int {
    var out map[string]int = new map[string]int
    for k, v := range a {
        out[k] = v
    }
    for k, v := range b {
        out[k] = v
    }
    ret out
}

// MergeStringString is the string-valued counterpart.
fun MergeStringString(a map[string]string, b map[string]string) map[string]string {
    var out map[string]string = new map[string]string
    for k, v := range a {
        out[k] = v
    }
    for k, v := range b {
        out[k] = v
    }
    ret out
}

// FilterStringInt returns a new map containing entries of m for
// which keep(k, v) returns true.
fun FilterStringInt(m map[string]int, keep fun(string, int) bool) map[string]int {
    var out map[string]int = new map[string]int
    for k, v := range m {
        if keep(k, v) { out[k] = v }
    }
    ret out
}

// FilterStringString returns a new map containing entries of m for
// which keep(k, v) returns true.
fun FilterStringString(m map[string]string, keep fun(string, string) bool) map[string]string {
    var out map[string]string = new map[string]string
    for k, v := range m {
        if keep(k, v) { out[k] = v }
    }
    ret out
}

// AnyStringInt reports whether at least one entry of m satisfies
// pred(k, v). Empty map returns false. Parallels slices.AnyInt for
// the (key, value) predicate case.
fun AnyStringInt(m map[string]int, pred fun(string, int) bool) bool {
    for k, v := range m {
        if pred(k, v) { ret true }
    }
    ret false
}

// AllStringInt reports whether every entry of m satisfies pred(k, v).
// Empty map returns true (vacuous truth, matches slices.AllInt).
fun AllStringInt(m map[string]int, pred fun(string, int) bool) bool {
    for k, v := range m {
        if !pred(k, v) { ret false }
    }
    ret true
}

// CountStringInt returns the number of entries of m satisfying
// pred(k, v). 0 for an empty map.
fun CountStringInt(m map[string]int, pred fun(string, int) bool) int {
    var n int = 0
    for k, v := range m {
        if pred(k, v) { n = n + 1 }
    }
    ret n
}

// AnyStringString reports whether at least one entry of m satisfies
// pred(k, v). Empty map returns false. String-valued counterpart to
// AnyStringInt.
fun AnyStringString(m map[string]string, pred fun(string, string) bool) bool {
    for k, v := range m {
        if pred(k, v) { ret true }
    }
    ret false
}

// AllStringString reports whether every entry of m satisfies
// pred(k, v). Empty map returns true (vacuous truth).
fun AllStringString(m map[string]string, pred fun(string, string) bool) bool {
    for k, v := range m {
        if !pred(k, v) { ret false }
    }
    ret true
}

// CountStringString returns the number of entries of m satisfying
// pred(k, v). 0 for an empty map.
fun CountStringString(m map[string]string, pred fun(string, string) bool) int {
    var n int = 0
    for k, v := range m {
        if pred(k, v) { n = n + 1 }
    }
    ret n
}

// MapValuesStringInt returns a new map with every value transformed
// by fn; keys are preserved. Useful for projection / unit-conversion.
fun MapValuesStringInt(m map[string]int, fn fun(int) int) map[string]int {
    var out map[string]int = new map[string]int
    for k, v := range m {
        out[k] = fn(v)
    }
    ret out
}

// KeyOfMaxStringInt returns the key in m whose value is largest.
// Ties resolve by the *first key* encountered during the range —
// since map iteration order is not specified, callers should treat
// ties as undefined-but-deterministic-per-process. Empty map returns "".
fun KeyOfMaxStringInt(m map[string]int) string {
    var bestKey string = ""
    var bestVal int = 0
    var first bool = true
    for k, v := range m {
        if first {
            bestKey = "" + k
            bestVal = v
            first = false
            continue
        }
        if v > bestVal {
            bestKey = "" + k
            bestVal = v
        }
    }
    ret bestKey
}

// KeyOfMinStringInt returns the key in m whose value is smallest.
// Same tie-break caveat as KeyOfMaxStringInt. Empty map returns "".
fun KeyOfMinStringInt(m map[string]int) string {
    var bestKey string = ""
    var bestVal int = 0
    var first bool = true
    for k, v := range m {
        if first {
            bestKey = "" + k
            bestVal = v
            first = false
            continue
        }
        if v < bestVal {
            bestKey = "" + k
            bestVal = v
        }
    }
    ret bestKey
}

// SumValuesStringInt returns the sum of all int values in m. Empty
// map returns 0. Useful for tallying word-count / frequency /
// histogram maps in a single call.
fun SumValuesStringInt(m map[string]int) int {
    var total int = 0
    for _, v := range m {
        total = total + v
    }
    ret total
}

// MaxValueStringInt returns the largest value in m. Empty map
// returns 0 — callers needing to distinguish "no entries" from
// "max is 0" should check `len(m) == 0` first. Companion to
// KeyOfMaxStringInt (which returns the key holding the max).
fun MaxValueStringInt(m map[string]int) int {
    var best int = 0
    var first bool = true
    for _, v := range m {
        if first {
            best = v
            first = false
            continue
        }
        if v > best { best = v }
    }
    ret best
}

// MinValueStringInt returns the smallest value in m. Empty map
// returns 0 — same disambiguation caveat as MaxValueStringInt.
fun MinValueStringInt(m map[string]int) int {
    var best int = 0
    var first bool = true
    for _, v := range m {
        if first {
            best = v
            first = false
            continue
        }
        if v < best { best = v }
    }
    ret best
}

// InvertStringString returns a new map where keys and values are
// swapped. Useful for "name → id" ↔ "id → name" lookups. If the
// input has duplicate values, later-key-wins per iteration order
// (which is unspecified — duplicates make the inversion lossy and
// caller should ensure the original map's values are unique).
fun InvertStringString(m map[string]string) map[string]string {
    var out map[string]string = new map[string]string
    for k, v := range m {
        out[v] = "" + k
    }
    ret out
}

// MapValuesStringString returns a new map with every value
// transformed by fn; keys preserved. Companion to
// MapValuesStringInt. Useful for: per-value normalization
// (TrimSpace, ToLower, ...), formatting, error-string remapping.
fun MapValuesStringString(m map[string]string, fn fun(string) string) map[string]string {
    var out map[string]string = new map[string]string
    for k, v := range m {
        out[k] = fn(v)
    }
    ret out
}

// MapKeysStringInt returns a new map with every key transformed by
// fn; values preserved. If fn collapses two distinct keys to the
// same string, later-key-wins per the unspecified map iteration
// order — caller should ensure fn is injective on the input's
// keyset when that matters. Useful for case-normalization
// (`ToLower`), prefix stripping, namespace remapping.
fun MapKeysStringInt(m map[string]int, fn fun(string) string) map[string]int {
    var out map[string]int = new map[string]int
    for k, v := range m {
        out[fn(k)] = v
    }
    ret out
}

// MapKeysStringString is the string-valued counterpart.
fun MapKeysStringString(m map[string]string, fn fun(string) string) map[string]string {
    var out map[string]string = new map[string]string
    for k, v := range m {
        out[fn(k)] = "" + v
    }
    ret out
}

// TopNKeysStringInt returns the top-n keys of m ordered by their
// values descending, alongside the matching values. Use case: pair a
// frequency map (slices.HistogramString) with strings.AsciiHistogram
// to render a top-N word/event count dashboard in one pipeline:
//
//   var freq map[string]int = slices.HistogramString(events)
//   var labels, counts = maps.TopNKeysStringInt(freq, 10)
//   log.Println(strings.AsciiHistogram(labels, counts, 30, 35, 46))
//
// n<=0 returns empty paired slices. n>len(m) clamps. Stable
// tie-break: when two keys share a value, earlier-discovered (range
// iteration order, which is bucket-traversal) wins. Doesn't mutate m.
fun TopNKeysStringInt(m map[string]int, n int) ([]string, []int) {
    if n <= 0 {
        var ek []string = new(0) []string {}
        var ev []int = new(0) []int {}
        ret ek, ev
    }
    // Snapshot map into parallel slices.
    var size int = 0
    for k, _v := range m {
        var _useK string = "" + k
        var _useV int = _v
        size = size + 1
    }
    if size == 0 {
        var ek []string = new(0) []string {}
        var ev []int = new(0) []int {}
        ret ek, ev
    }
    var keys []string = new(size) []string {}
    var vals []int = new(size) []int {}
    var idx int = 0
    for k, v := range m {
        keys[idx] = "" + k
        vals[idx] = v
        idx = idx + 1
    }
    var k_clamped int = n
    if k_clamped > size { k_clamped = size }
    // Selection of top-k by value descending. O(k*n) — fine for the
    // dashboard use case where k is small.
    var outK []string = new(k_clamped) []string {}
    var outV []int = new(k_clamped) []int {}
    var taken []bool = new(size) []bool {}
    for round := 0; round < k_clamped; round++ {
        var bestIdx int = -1
        for i := 0; i < size; i++ {
            if taken[i] { continue }
            if bestIdx < 0 { bestIdx = i; continue }
            if vals[i] > vals[bestIdx] { bestIdx = i }
        }
        taken[bestIdx] = true
        outK[round] = "" + keys[bestIdx]
        outV[round] = vals[bestIdx]
    }
    ret outK, outV
}
