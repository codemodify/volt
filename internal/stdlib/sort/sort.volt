// Package sort: minimal in-place sorting + sortedness predicates.
//
// Surface:
//   IntsAsc(s) []int          — sort []int ascending; returns the same slice
//   StringsAsc(s) []string    — sort []string ascending (lexicographic)
//   IntsAreSorted(s) bool     — true iff s is non-decreasing
//   StringsAreSorted(s) bool  — true iff s is non-decreasing
//
// Volt's ownership rules MOVE a slice when passed to a function, so
// the mutating helpers return the slice for the caller to rebind:
//
//   a = sort.IntsAsc(a)
//
// The sort runs in place on the underlying buffer — the returned
// slice points at the same memory.
//
// Algorithm: insertion sort. O(n²) worst case but each element
// movement is one assignment; for the small / medium slices typical
// of volt code today this beats the bookkeeping cost of a recursive
// quicksort. (A future v2 can swap in iterative quicksort with the
// slice threaded through partition by reference.)

package sort

// IntsAsc sorts `s` in ascending order, in place, and returns it
// so the caller can rebind across the move:
//   a = sort.IntsAsc(a)
fun IntsAsc(s []int) []int {
    var n int = len(s)
    for i:=1; i < n; i++ {
        var x int = s[i]
        var j int = i - 1
        for j >= 0 {
            if s[j] <= x { break }
            s[j+1] = s[j]
            j = j - 1
        }
        s[j+1] = x
    }
    ret s
}

// IntsAreSorted reports whether s is in non-decreasing order.
fun IntsAreSorted(s []int) bool {
    var n int = len(s)
    for i:=1; i < n; i++ {
        if s[i] < s[i-1] { ret false }
    }
    ret true
}

// StringsAsc sorts `s` in lexicographic ascending order, in place,
// and returns it for rebinding (see IntsAsc).
fun StringsAsc(s []string) []string {
    var n int = len(s)
    for i:=1; i < n; i++ {
        var x string = s[i]
        var j int = i - 1
        for j >= 0 {
            // Inline lex-compare: stop when s[j] <= x.
            var le bool = true
            var sj string = s[j]
            var lsj int = len(sj)
            var lx int = len(x)
            var m int = lsj
            if lx < m { m = lx }
            var k int = 0
            for k < m {
                var a int = sj[k] & 255
                var b int = x[k]  & 255
                if a < b { le = true;  break }
                if a > b { le = false; break }
                k = k + 1
            }
            if k == m {
                // Prefix tie — shorter (or equal) loses or ties.
                if lsj > lx { le = false }
            }
            if le { break }
            s[j+1] = s[j]
            j = j - 1
        }
        s[j+1] = x
    }
    ret s
}

// StringsAreSorted reports whether s is in non-decreasing
// lexicographic order.
fun StringsAreSorted(s []string) bool {
    var n int = len(s)
    for i:=1; i < n; i++ {
        // s[i] < s[i-1] inline check (returns true on first mismatch
        // where the current is smaller).
        var a string = s[i-1]
        var b string = s[i]
        var la int = len(a)
        var lb int = len(b)
        var m int = la
        if lb < m { m = lb }
        var lt bool = false
        var k int = 0
        for k < m {
            var ai int = a[k] & 255
            var bi int = b[k] & 255
            if bi < ai { lt = true;  break }
            if ai < bi { lt = false; break }
            k = k + 1
        }
        if k == m {
            if lb < la { lt = true }
        }
        if lt { ret false }
    }
    ret true
}

// IntsBy sorts `s` in place using `less(a, b)` to order pairs.
// Returns the same slice for rebinding. Stable insertion sort —
// equal elements keep their relative order.
fun IntsBy(s []int, less fun(int, int) bool) []int {
    var n int = len(s)
    for i := 1; i < n; i++ {
        var x int = s[i]
        var j int = i - 1
        for j >= 0 {
            // Break when s[j] is not greater than x (i.e. !less(x, s[j])).
            // This preserves stability — equal elements keep their order.
            if !less(x, s[j]) { break }
            s[j+1] = s[j]
            j = j - 1
        }
        s[j+1] = x
    }
    ret s
}

// StringsBy sorts `s` in place using `less(a, b)` to order pairs.
// Returns the same slice for rebinding. Stable insertion sort.
fun StringsBy(s []string, less fun(string, string) bool) []string {
    var n int = len(s)
    for i := 1; i < n; i++ {
        var x string = s[i]
        var j int = i - 1
        for j >= 0 {
            if !less(x, s[j]) { break }
            s[j+1] = s[j]
            j = j - 1
        }
        s[j+1] = x
    }
    ret s
}

// StringsAscCI sorts s ascending under case-INSENSITIVE byte-wise
// comparison ('A'..'Z' folded to 'a'..'z'). Stable — equal-fold
// pairs (e.g. "Alice" / "alice") keep their original order. In-
// place; returns s for rebinding. Useful for human-facing lists
// where "alice", "Bob", "Carol" should appear in that order.
fun StringsAscCI(s []string) []string {
    var n int = len(s)
    for i := 1; i < n; i++ {
        var x string = "" + s[i]
        var j int = i - 1
        for j >= 0 {
            if !stringLessCI(x, s[j]) { break }
            s[j + 1] = "" + s[j]
            j = j - 1
        }
        s[j + 1] = x
    }
    ret s
}

// StringsDescCI sorts s descending under case-INSENSITIVE compare.
// Stable.
fun StringsDescCI(s []string) []string {
    var n int = len(s)
    for i := 1; i < n; i++ {
        var x string = "" + s[i]
        var j int = i - 1
        for j >= 0 {
            if !stringLessCI(s[j], x) { break }
            s[j + 1] = "" + s[j]
            j = j - 1
        }
        s[j + 1] = x
    }
    ret s
}

// stringLessCI: byte-wise lex compare with ASCII case folding.
// 'A'..'Z' (65..90) → 'a'..'z' (97..122) for comparison only.
fun stringLessCI(a string, b string) bool {
    var la int = len(a)
    var lb int = len(b)
    var m int = la
    if lb < m { m = lb }
    var i int = 0
    for i < m {
        var ca int = a[i] & 255
        var cb int = b[i] & 255
        if ca >= 65 {
            if ca <= 90 { ca = ca + 32 }
        }
        if cb >= 65 {
            if cb <= 90 { cb = cb + 32 }
        }
        if ca < cb { ret true }
        if ca > cb { ret false }
        i = i + 1
    }
    if la < lb { ret true }
    ret false
}

// IntsByAbs sorts s ascending by absolute value. Stable —
// equal-magnitude entries (e.g. -3 and 3) retain their original
// order. In-place; returns s for rebinding. Useful for "closest-to-
// zero first" ranking (smallest deviation first, smallest residual
// first) where the sign is incidental.
fun IntsByAbs(s []int) []int {
    var n int = len(s)
    for i := 1; i < n; i++ {
        var x int = s[i]
        var xa int = x
        if xa < 0 { xa = -xa }
        var j int = i - 1
        for j >= 0 {
            var ya int = s[j]
            if ya < 0 { ya = -ya }
            if ya <= xa { break }
            s[j + 1] = s[j]
            j = j - 1
        }
        s[j + 1] = x
    }
    ret s
}

// IntsByAbsDesc sorts s descending by absolute value — largest
// magnitude first. Stable.
fun IntsByAbsDesc(s []int) []int {
    var n int = len(s)
    for i := 1; i < n; i++ {
        var x int = s[i]
        var xa int = x
        if xa < 0 { xa = -xa }
        var j int = i - 1
        for j >= 0 {
            var ya int = s[j]
            if ya < 0 { ya = -ya }
            if ya >= xa { break }
            s[j + 1] = s[j]
            j = j - 1
        }
        s[j + 1] = x
    }
    ret s
}

// StringsByLen sorts s ascending by byte length. Stable —
// equal-length strings retain their original order. Sorts in place
// and returns s for rebinding. Useful when callers want shortest-
// first table rendering or longest-first heuristic tries.
fun StringsByLen(s []string) []string {
    var n int = len(s)
    for i := 1; i < n; i++ {
        var x string = "" + s[i]
        var xn int = len(s[i])
        var j int = i - 1
        for j >= 0 {
            if len(s[j]) <= xn { break }
            s[j + 1] = "" + s[j]
            j = j - 1
        }
        s[j + 1] = x
    }
    ret s
}

// StringsByLenDesc sorts s descending by byte length. Stable.
fun StringsByLenDesc(s []string) []string {
    var n int = len(s)
    for i := 1; i < n; i++ {
        var x string = "" + s[i]
        var xn int = len(s[i])
        var j int = i - 1
        for j >= 0 {
            if len(s[j]) >= xn { break }
            s[j + 1] = "" + s[j]
            j = j - 1
        }
        s[j + 1] = x
    }
    ret s
}

// MergeInts merges two pre-sorted ascending slices into a single
// sorted slice. O(la + lb) — exact-size allocation. Caller is
// responsible for the precondition: both inputs are already sorted.
fun MergeInts(a []int, b []int) []int {
    var la int = len(a)
    var lb int = len(b)
    var out []int = new(la + lb) []int {}
    var i int = 0
    var j int = 0
    var k int = 0
    for i < la {
        if j >= lb { break }
        if a[i] <= b[j] {
            out[k] = a[i]
            i = i + 1
        } else {
            out[k] = b[j]
            j = j + 1
        }
        k = k + 1
    }
    for i < la {
        out[k] = a[i]
        i = i + 1
        k = k + 1
    }
    for j < lb {
        out[k] = b[j]
        j = j + 1
        k = k + 1
    }
    ret out
}

// stringLeq reports whether a <= b (byte-wise lex; ties broken by
// shorter wins).
fun stringLeq(a string, b string) bool {
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
    if la <= lb { ret true }
    ret false
}

// MergeStrings merges two pre-sorted ascending []string slices.
fun MergeStrings(a []string, b []string) []string {
    var la int = len(a)
    var lb int = len(b)
    var out []string = new(la + lb) []string {}
    var i int = 0
    var j int = 0
    var k int = 0
    for i < la {
        if j >= lb { break }
        if stringLeq(a[i], b[j]) {
            out[k] = a[i]
            i = i + 1
        } else {
            out[k] = b[j]
            j = j + 1
        }
        k = k + 1
    }
    for i < la {
        out[k] = a[i]
        i = i + 1
        k = k + 1
    }
    for j < lb {
        out[k] = b[j]
        j = j + 1
        k = k + 1
    }
    ret out
}

// IntsDesc sorts s in descending order, in place, and returns it
// for rebinding. Insertion sort — same algorithm as IntsAsc with
// flipped comparison.
fun IntsDesc(s []int) []int {
    var n int = len(s)
    for i:=1; i < n; i++ {
        var x int = s[i]
        var j int = i - 1
        for j >= 0 {
            if s[j] >= x { break }
            s[j+1] = s[j]
            j = j - 1
        }
        s[j+1] = x
    }
    ret s
}

// StringsDesc sorts s in descending lex order, in place.
fun StringsDesc(s []string) []string {
    var n int = len(s)
    for i:=1; i < n; i++ {
        var x string = s[i]
        var j int = i - 1
        for j >= 0 {
            // Break when s[j] >= x ⟺ x <= s[j] ⟺ stringLeq(x, s[j]).
            if stringLeq(x, s[j]) { break }
            s[j+1] = s[j]
            j = j - 1
        }
        s[j+1] = x
    }
    ret s
}

// IntsAreSortedDesc reports whether s is in non-increasing order.
// Empty / single-element slices are trivially sorted.
fun IntsAreSortedDesc(s []int) bool {
    var n int = len(s)
    for i := 1; i < n; i++ {
        if s[i] > s[i-1] { ret false }
    }
    ret true
}

// IntsAreSortedBy reports whether s is in the order defined by
// `less(a, b)` — equivalent to "every adjacent pair (s[i-1], s[i])
// would be left untouched by IntsBy". Empty / single-element
// slices return true (vacuous truth). Useful for "is this already
// sorted by my custom comparator?" checks without paying the cost
// of a re-sort.
fun IntsAreSortedBy(s []int, less fun(int, int) bool) bool {
    var n int = len(s)
    for i := 1; i < n; i++ {
        // s is sorted iff !less(s[i], s[i-1]) for every adjacent pair —
        // the right element is never "less than" the left.
        if less(s[i], s[i-1]) { ret false }
    }
    ret true
}

// StringsAreSortedBy is the []string counterpart of IntsAreSortedBy.
fun StringsAreSortedBy(s []string, less fun(string, string) bool) bool {
    var n int = len(s)
    for i := 1; i < n; i++ {
        if less(s[i], s[i-1]) { ret false }
    }
    ret true
}

// StringsAreSortedDesc reports whether s is in non-increasing
// lexicographic order. Empty / single-element slices are trivially
// sorted.
fun StringsAreSortedDesc(s []string) bool {
    var n int = len(s)
    for i := 1; i < n; i++ {
        // Reject when s[i] > s[i-1] lexicographically.
        var a string = s[i-1]
        var b string = s[i]
        var la int = len(a)
        var lb int = len(b)
        var m int = la
        if lb < m { m = lb }
        var gt bool = false
        var k int = 0
        for k < m {
            var ai int = a[k] & 255
            var bi int = b[k] & 255
            if bi > ai { gt = true;  break }
            if ai > bi { gt = false; break }
            k = k + 1
        }
        if k == m {
            if lb > la { gt = true }
        }
        if gt { ret false }
    }
    ret true
}
