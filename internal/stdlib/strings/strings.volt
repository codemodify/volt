// Package strings: byte-level string operations.
//
// Scan operations: Equal, HasPrefix, HasSuffix, Index, Contains,
//   IndexByte, Count.
// Constructor operations (return a new string): ToLower, ToUpper,
//   TrimSpace, Trim, Replace, Split, Join.
//
// All operations work on UTF-8-encoded byte sequences at the byte
// level; no rune-aware helpers yet. Constructor functions are O(n)
// via bytes.Builder (Pass 108).

package strings

import "bytes"
import "errors"
import "strconv"
import "io"

// ---- Scan operations -------------------------------------------------

fun Equal(a string, b string) bool {
    var la int = len(a)
    if la != len(b) { ret false }
    for i:=0; i < la; i++ {
        if a[i] != b[i] { ret false }
    }
    ret true
}

fun HasPrefix(s string, prefix string) bool {
    var lp int = len(prefix)
    if lp > len(s) { ret false }
    for i:=0; i < lp; i++ {
        if s[i] != prefix[i] { ret false }
    }
    ret true
}

fun HasSuffix(s string, suffix string) bool {
    var lsuf int = len(suffix)
    var ls int = len(s)
    if lsuf > ls { ret false }
    var off int = ls - lsuf
    for i:=0; i < lsuf; i++ {
        if s[off + i] != suffix[i] { ret false }
    }
    ret true
}

// CommonSuffixLen returns the length of the longest byte suffix
// shared by a and b. Walks pairwise from the END of each,
// stopping at the first mismatch (or the shorter string's start).
// Companion to CommonPrefixLen.
fun CommonSuffixLen(a string, b string) int {
    var la int = len(a)
    var lb int = len(b)
    var m int = la
    if lb < m { m = lb }
    var k int = 1
    for k <= m {
        if a[la - k] != b[lb - k] { ret k - 1 }
        k = k + 1
    }
    ret m
}

// CommonPrefixLen returns the length of the longest byte prefix
// shared by a and b. Walks pairwise, stopping at the first
// mismatch (or the shorter string's end). Useful as a cheap
// length probe before deciding whether to materialize the full
// shared prefix via LongestCommonPrefix.
fun CommonPrefixLen(a string, b string) int {
    var la int = len(a)
    var lb int = len(b)
    var m int = la
    if lb < m { m = lb }
    for k := 0; k < m; k++ {
        if a[k] != b[k] { ret k }
    }
    ret m
}

// LongestCommonPrefix returns the longest byte string shared as a
// prefix by every element of strs. Empty input or any empty
// element returns "". Single-element input returns a copy of that
// element. Useful for command auto-complete, finding the unique
// disambiguator in a candidate list, trie-style aggregate roots.
fun LongestCommonPrefix(strs []string) string {
    var n int = len(strs)
    if n == 0 { ret "" }
    if n == 1 { ret "" + strs[0] }
    var first string = strs[0]
    var maxLen int = len(first)
    for i := 1; i < n; i++ {
        var lj int = len(strs[i])
        if lj < maxLen { maxLen = lj }
    }
    var b *bytes.Builder = bytes.NewBuilder()
    for k := 0; k < maxLen; k++ {
        var c byte = first[k]
        var match bool = true
        for i := 1; i < n; i++ {
            if strs[i][k] != c { match = false; break }
        }
        if !match { break }
        b.WriteByte(c)
    }
    ret b.String()
}

// LongestCommonSuffix returns the longest byte string shared as a
// suffix by every element of strs. Same edge-case semantics as
// LongestCommonPrefix.
fun LongestCommonSuffix(strs []string) string {
    var n int = len(strs)
    if n == 0 { ret "" }
    if n == 1 { ret "" + strs[0] }
    var first string = strs[0]
    var firstLen int = len(first)
    var maxLen int = firstLen
    for i := 1; i < n; i++ {
        var lj int = len(strs[i])
        if lj < maxLen { maxLen = lj }
    }
    // Walk from the end (k counts how many trailing bytes match).
    var matched int = 0
    for k := 1; k <= maxLen; k++ {
        var c byte = first[firstLen - k]
        var ok bool = true
        for i := 1; i < n; i++ {
            var slen int = len(strs[i])
            if strs[i][slen - k] != c { ok = false; break }
        }
        if !ok { break }
        matched = matched + 1
    }
    if matched == 0 { ret "" }
    // Slice the last `matched` bytes of first into a new string.
    var b *bytes.Builder = bytes.NewBuilder()
    for k := firstLen - matched; k < firstLen; k++ {
        b.WriteByte(first[k])
    }
    ret b.String()
}

// ContainsAll reports whether EVERY substring in subs appears
// (anywhere) in s. Empty subs returns true (vacuously all of an
// empty set). Useful for: required-keyword validation, "does this
// log line contain every expected marker?" checks.
fun ContainsAll(s string, subs []string) bool {
    var n int = len(subs)
    for i := 0; i < n; i++ {
        if !Contains(s, subs[i]) { ret false }
    }
    ret true
}

// ContainsAnyStr reports whether AT LEAST ONE substring in subs
// appears in s. Empty subs returns false. Companion to the
// existing byte-level `ContainsAny` (which checks single chars).
// Useful for: blocklist scanning, "does this message contain
// any of these keywords?" filters.
fun ContainsAnyStr(s string, subs []string) bool {
    var n int = len(subs)
    for i := 0; i < n; i++ {
        if Contains(s, subs[i]) { ret true }
    }
    ret false
}

// HasAnyPrefix reports whether s starts with ANY of the strings in
// prefixes. Returns false for an empty prefix list (vacuous "none
// match"). An empty prefix in the list always matches (consistent
// with HasPrefix's "" treatment).
fun HasAnyPrefix(s string, prefixes []string) bool {
    var n int = len(prefixes)
    for i := 0; i < n; i++ {
        if HasPrefix(s, prefixes[i]) { ret true }
    }
    ret false
}

// HasAnySuffix reports whether s ends with ANY of the strings in
// suffixes. Same vacuous-on-empty + empty-suffix-always-matches
// semantics as HasAnyPrefix.
fun HasAnySuffix(s string, suffixes []string) bool {
    var n int = len(suffixes)
    for i := 0; i < n; i++ {
        if HasSuffix(s, suffixes[i]) { ret true }
    }
    ret false
}

// TrimAnyPrefix returns s with the FIRST matching prefix from
// `prefixes` removed. If no prefix matches, returns s unchanged.
// Equivalent to calling TrimPrefix once with each candidate. First
// match wins — caller controls list order (or use TrimLongestPrefix
// for longest-match-wins).
fun TrimAnyPrefix(s string, prefixes []string) string {
    var n int = len(prefixes)
    for i := 0; i < n; i++ {
        if HasPrefix(s, prefixes[i]) {
            ret TrimPrefix(s, prefixes[i])
        }
    }
    ret "" + s
}

// TrimAnySuffix returns s with the FIRST matching suffix from
// `suffixes` removed. Mirror of TrimAnyPrefix.
fun TrimAnySuffix(s string, suffixes []string) string {
    var n int = len(suffixes)
    for i := 0; i < n; i++ {
        if HasSuffix(s, suffixes[i]) {
            ret TrimSuffix(s, suffixes[i])
        }
    }
    ret "" + s
}

// TrimLongestPrefix returns s with the LONGEST matching prefix from
// `prefixes` removed. Order-independent (vs TrimAnyPrefix). Useful
// for path normalization where the longest matching base path
// should win.
fun TrimLongestPrefix(s string, prefixes []string) string {
    var p string = LongestPrefixOf(s, prefixes)
    if len(p) == 0 { ret "" + s }
    ret TrimPrefix(s, p)
}

// TrimLongestSuffix returns s with the longest matching suffix
// stripped. Useful for extension classifiers where ".tar.gz" should
// strip both pieces, not just the trailing ".gz".
fun TrimLongestSuffix(s string, suffixes []string) string {
    var p string = LongestSuffixOf(s, suffixes)
    if len(p) == 0 { ret "" + s }
    ret TrimSuffix(s, p)
}

// LongestPrefixOf returns the LONGEST prefix from `prefixes` that s
// starts with, or "" if none match. Resolves the "list order vs
// match length" ambiguity that PrefixOf leaves to the caller —
// here, longest wins regardless of position. Stable tie-breaking
// (earlier wins on equal length).
fun LongestPrefixOf(s string, prefixes []string) string {
    var n int = len(prefixes)
    var bestIdx int = -1
    var bestLen int = -1
    for i := 0; i < n; i++ {
        if HasPrefix(s, prefixes[i]) {
            if len(prefixes[i]) > bestLen {
                bestLen = len(prefixes[i])
                bestIdx = i
            }
        }
    }
    if bestIdx < 0 { ret "" }
    ret "" + prefixes[bestIdx]
}

// LongestSuffixOf returns the longest matching suffix. Stable.
fun LongestSuffixOf(s string, suffixes []string) string {
    var n int = len(suffixes)
    var bestIdx int = -1
    var bestLen int = -1
    for i := 0; i < n; i++ {
        if HasSuffix(s, suffixes[i]) {
            if len(suffixes[i]) > bestLen {
                bestLen = len(suffixes[i])
                bestIdx = i
            }
        }
    }
    if bestIdx < 0 { ret "" }
    ret "" + suffixes[bestIdx]
}

// PrefixOf returns the FIRST prefix from `prefixes` that s starts
// with, or "" if none match. Useful for routing or scheme-detection
// where the caller needs the actual matched value:
//   PrefixOf(url, ["http://", "https://", "file://"]) → "https://"
// Empty `prefixes` returns "". Order matters — first match wins.
fun PrefixOf(s string, prefixes []string) string {
    var n int = len(prefixes)
    for i := 0; i < n; i++ {
        if HasPrefix(s, prefixes[i]) { ret "" + prefixes[i] }
    }
    ret ""
}

// SuffixOf returns the first matching suffix from `suffixes`, or ""
// if none match. Use case: file-extension classification.
//   SuffixOf(path, [".tar.gz", ".zip", ".jpg"]) → ".jpg"
fun SuffixOf(s string, suffixes []string) string {
    var n int = len(suffixes)
    for i := 0; i < n; i++ {
        if HasSuffix(s, suffixes[i]) { ret "" + suffixes[i] }
    }
    ret ""
}

fun Index(s string, sub string) int {
    var lsub int = len(sub)
    var ls int = len(s)
    if lsub == 0 { ret 0 }
    if lsub > ls { ret -1 }
    var last int = ls - lsub
    for i:=0; i <= last; i++ {
        var match bool = true
        for j:=0; j < lsub; j++ {
            if s[i + j] != sub[j] {
                match = false
                break
            }
        }
        if match { ret i }
    }
    ret -1
}

fun Contains(s string, sub string) bool {
    if Index(s, sub) >= 0 { ret true }
    ret false
}

// IndexAfter returns the absolute index of the first occurrence of
// sub in s at or after byte position `from`, or -1 if absent. A
// negative `from` is clamped to 0; `from >= len(s)` returns -1 (or 0
// for the empty-sub edge case where we still want to return `from`
// if it falls just past the end of an empty s). Empty sub returns
// `from` (clamped to len(s)). Useful for "find next" iteration —
// scanning s for repeated occurrences of sub without slicing.
fun IndexAfter(s string, sub string, from int) int {
    var ls int = len(s)
    var lsub int = len(sub)
    if from < 0 { from = 0 }
    if lsub == 0 {
        if from > ls { ret ls }
        ret from
    }
    if from > ls - lsub { ret -1 }
    var last int = ls - lsub
    for i := from; i <= last; i++ {
        var match bool = true
        for j := 0; j < lsub; j++ {
            if s[i + j] != sub[j] {
                match = false
                break
            }
        }
        if match { ret i }
    }
    ret -1
}

fun IndexByte(s string, c byte) int {
    var ls int = len(s)
    for i:=0; i < ls; i++ {
        if s[i] == c { ret i }
    }
    ret -1
}

// IndexByteAfter returns the absolute index of the first occurrence
// of byte c at or after position `from` in s, or -1 if absent.
// Negative `from` clamps to 0; `from >= len(s)` returns -1. Cheap
// byte-version of `IndexAfter` — useful for "find the next delimiter
// after position N" parser idioms without allocating a substring.
fun IndexByteAfter(s string, c byte, from int) int {
    var ls int = len(s)
    if from < 0 { from = 0 }
    if from >= ls { ret -1 }
    for i := from; i < ls; i++ {
        if s[i] == c { ret i }
    }
    ret -1
}

// LastIndexByte returns the index of the last occurrence of c in s,
// or -1 if c is absent. Mirrors bytes.LastIndexByte for the string
// case — useful for "find the rightmost separator byte" patterns
// like locating the final `.` of an extension or the trailing `/` of
// a path without the substring-match overhead of LastIndex.
fun LastIndexByte(s string, c byte) int {
    var ls int = len(s)
    for i := ls - 1; i >= 0; i-- {
        if s[i] == c { ret i }
    }
    ret -1
}

fun Count(s string, sub string) int {
    var lsub int = len(sub)
    if lsub == 0 { ret len(s) + 1 }
    var n int = 0
    var i int = 0
    var last int = len(s) - lsub
    for i <= last {
        var match bool = true
        for j:=0; j < lsub; j++ {
            if s[i + j] != sub[j] {
                match = false
                break
            }
        }
        if match {
            n = n + 1
            i = i + lsub
        } else {
            i = i + 1
        }
    }
    ret n
}

// ---- Constructor operations -----------------------------------------

// ToLower returns s with all ASCII uppercase letters folded to lowercase.
// Non-ASCII bytes pass through unchanged.
fun ToLower(s string) string {
    var b *bytes.Builder = bytes.NewBuilder()
    var n int = len(s)
    for i:=0; i < n; i++ {
        var c byte = s[i]
        if c >= 65 {                // 'A'
            if c <= 90 {            // 'Z'
                c = c + 32          // → 'a'..'z'
            }
        }
        b.WriteByte(c)
    }
    ret b.String()
}

// ToUpper returns s with all ASCII lowercase letters folded to uppercase.
fun ToUpper(s string) string {
    var b *bytes.Builder = bytes.NewBuilder()
    var n int = len(s)
    for i:=0; i < n; i++ {
        var c byte = s[i]
        if c >= 97 {                // 'a'
            if c <= 122 {           // 'z'
                c = c - 32          // → 'A'..'Z'
            }
        }
        b.WriteByte(c)
    }
    ret b.String()
}

// isSpace reports whether b is ASCII whitespace.
fun isSpace(b byte) bool {
    if b == 32 { ret true }         // ' '
    if b == 9  { ret true }         // '\t'
    if b == 10 { ret true }         // '\n'
    if b == 13 { ret true }         // '\r'
    ret false
}

// TrimSpace removes leading and trailing ASCII whitespace.
fun TrimSpace(s string) string {
    var n int = len(s)
    var lo int = 0
    for lo < n {
        if !isSpace(s[lo]) { break }
        lo = lo + 1
    }
    var hi int = n
    for hi > lo {
        if !isSpace(s[hi - 1]) { break }
        hi = hi - 1
    }
    var b *bytes.Builder = bytes.NewBuilder()
    for i:=lo; i < hi; i++ {
        b.WriteByte(s[i])
    }
    ret b.String()
}

// Replace returns a copy of s where every non-overlapping occurrence
// of old is replaced by repl. Empty old causes no substitution.
fun Replace(s string, old string, repl string) string {
    var lold int = len(old)
    if lold == 0 { ret s }
    var n int = len(s)
    var b *bytes.Builder = bytes.NewBuilder()
    var i int = 0
    var last int = n - lold
    for i <= last {
        var match bool = true
        for j:=0; j < lold; j++ {
            if s[i + j] != old[j] {
                match = false
                break
            }
        }
        if match {
            b.WriteString("" + repl)   // BinaryExpr keeps repl alive
            i = i + lold
        } else {
            b.WriteByte(s[i])
            i = i + 1
        }
    }
    // Append any trailing bytes that couldn't fit a match.
    for i < n {
        b.WriteByte(s[i])
        i = i + 1
    }
    ret b.String()
}

// Excerpt returns up to `radius` bytes before AND after the
// position `at` in s, separated by an arrow ("…before|HERE|after…").
// `at` is clamped to [0, len(s)]. Useful for error-context display:
// "syntax error at column 42:  …var x = 5 |<= here| + 'oops'"
// Ellipses are added only when content was truncated. The arrow
// marker exposes exactly where in s the position was.
fun Excerpt(s string, at int, radius int) string {
    var n int = len(s)
    var pos int = at
    if pos < 0 { pos = 0 }
    if pos > n { pos = n }
    var rad int = radius
    if rad < 0 { rad = 0 }
    var lo int = pos - rad
    var loTrunc bool = false
    if lo < 0 {
        lo = 0
    } else {
        if lo > 0 { loTrunc = true }
    }
    var hi int = pos + rad
    var hiTrunc bool = false
    if hi > n {
        hi = n
    } else {
        if hi < n { hiTrunc = true }
    }
    var b *bytes.Builder = bytes.NewBuilder()
    if loTrunc { b.WriteString("…") }
    for i := lo; i < pos; i++ { b.WriteByte(s[i]) }
    b.WriteString("|<=here|")
    for i := pos; i < hi; i++ { b.WriteByte(s[i]) }
    if hiTrunc { b.WriteString("…") }
    ret b.String()
}

// LineRange returns lines `from` (inclusive) through `to` (inclusive),
// 1-indexed, rejoined with '\n'. Out-of-range bounds are clamped to
// [1, lineCount]. from > to returns "". Useful for context windows
// around an error line. (Note: this is 1-indexed because it pairs
// with LineColAt — distinct from the 0-indexed existing `LineAt`.)
fun LineRange(s string, from int, to int) string {
    if from > to { ret "" }
    var ls []string = Lines(s)
    var n int = len(ls)
    if n == 0 { ret "" }
    var lo int = from
    if lo < 1 { lo = 1 }
    var hi int = to
    if hi > n { hi = n }
    if lo > n { ret "" }
    var b *bytes.Builder = bytes.NewBuilder()
    for i := lo; i <= hi; i++ {
        b.WriteString(ls[i - 1])
        if i < hi { b.WriteByte(10) }
    }
    ret b.String()
}

// CaretLine returns a two-line string: the source line followed by
// a caret-pointer line ("    ^"). Used to point at a specific column
// of a specific 1-indexed line in s. lineNo and col are both
// 1-indexed (line 1 col 1 = byte 0). Out-of-range lineNo returns "".
// col is clamped to >= 1; if col exceeds the line length, the caret
// sits one position past the end. Pairs naturally with LineColAt
// and LineRange for full error-context display.
fun CaretLine(s string, lineNo int, col int) string {
    if lineNo < 1 { ret "" }
    var ls []string = Lines(s)
    if lineNo > len(ls) { ret "" }
    var line string = "" + ls[lineNo - 1]
    var c int = col
    if c < 1 { c = 1 }
    var b *bytes.Builder = bytes.NewBuilder()
    b.WriteString(line)
    b.WriteByte(10)   // '\n'
    for i := 0; i < c - 1; i++ { b.WriteByte(32) }   // space pad
    b.WriteByte(94)   // '^'
    ret b.String()
}

// LineColAt returns the 1-indexed line and column number of byte
// position `at` in s (where col 1 is just after the line-start
// boundary). Useful for compiler error messages.
// `at` is clamped to [0, len(s)]. Empty s returns (1, 1).
fun LineColAt(s string, at int) (int, int) {
    var n int = len(s)
    if n == 0 { ret 1, 1 }
    var pos int = at
    if pos < 0 { pos = 0 }
    if pos > n { pos = n }
    var line int = 1
    var col int = 1
    for i := 0; i < pos; i++ {
        if s[i] == 10 {   // '\n'
            line = line + 1
            col = 1
        } else {
            col = col + 1
        }
    }
    ret line, col
}

// Hexdump returns a classic xxd-style hex dump of s:
//   "00000000  68 65 6c 6c 6f 20 77 6f  72 6c 64 0a              |hello world.|"
// 16 bytes per row: offset, hex bytes (split into two groups of 8
// with extra space), then printable-ASCII view (non-printable
// bytes shown as '.'). Useful for debugging binary input, comparing
// payloads, error-context diff dumps.
fun Hexdump(s string) string {
    if len(s) == 0 { ret "" }
    var n int = len(s)
    var b *bytes.Builder = bytes.NewBuilder()
    var off int = 0
    for off < n {
        // Offset (8 hex digits).
        b.WriteString(FormatHexPad8(off))
        b.WriteString("  ")
        // Hex columns.
        for i := 0; i < 16; i++ {
            if off + i < n {
                var by int = s[off + i] & 255
                b.WriteString(FormatHexPad2(by))
            } else {
                b.WriteString("  ")
            }
            if i == 7 { b.WriteString("  ") } else { b.WriteByte(32) }
        }
        b.WriteString(" |")
        // ASCII column.
        for i := 0; i < 16; i++ {
            if off + i < n {
                var c int = s[off + i] & 255
                if c < 32 {
                    b.WriteByte(46)   // '.'
                } else {
                    if c > 126 {
                        b.WriteByte(46)
                    } else {
                        b.WriteByte(s[off + i])
                    }
                }
            }
        }
        b.WriteByte(124)   // '|'
        if off + 16 < n { b.WriteByte(10) }
        off = off + 16
    }
    ret b.String()
}

// FormatHexPad2 is an inlined 2-digit zero-padded lowercase-hex
// helper for Hexdump. Avoids pulling strconv as a dep.
fun FormatHexPad2(n int) string {
    var hi int = (n >> 4) & 15
    var lo int = n & 15
    var b *bytes.Builder = bytes.NewBuilder()
    b.WriteByte(hexNibbleByte(hi))
    b.WriteByte(hexNibbleByte(lo))
    ret b.String()
}

// FormatHexPad8 is an inlined 8-digit zero-padded lowercase-hex
// helper for Hexdump's offset column.
fun FormatHexPad8(n int) string {
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 7; i >= 0; i-- {
        var nib int = (n >> (i * 4)) & 15
        b.WriteByte(hexNibbleByte(nib))
    }
    ret b.String()
}

// hexNibbleByte maps 0..15 → '0'..'9','a'..'f'.
fun hexNibbleByte(n int) byte {
    if n < 10 { ret ((48 + n) & 255) }   // '0' + n
    ret ((87 + n) & 255)                 // 'a' + (n-10)
}

// AsciiHistogramRow renders a labeled bar-chart row: a left-padded
// label (`labelWidth` chars), separator ` | `, then an AsciiBar.
// Composes Tabularize-like alignment with the bar rendering. Useful
// for terminal histogram dashboards:
//   AsciiHistogramRow("alice", 10, 7, 20, 35, 46)
//   →  "alice      | #######.............              "
fun AsciiHistogramRow(label string, labelWidth int, count int, barWidth int, fill byte, empty byte) string {
    var b *bytes.Builder = bytes.NewBuilder()
    b.WriteString(PadRight(label, labelWidth, 32))
    b.WriteString(" | ")
    b.WriteString(AsciiBar(count, barWidth, fill, empty))
    ret b.String()
}

// AsciiBar returns a string of `count` copies of byte `fill`
// followed by (width - count) copies of byte `empty`. count is
// clamped to [0, width]. width <= 0 returns "". Useful as the
// rendering primitive for bar charts:
//   AsciiBar(7, 10, 35, 46)  →  "#######..." ('#'=35, '.'=46)
fun AsciiBar(count int, width int, fill byte, empty byte) string {
    if width <= 0 { ret "" }
    var c int = count
    if c < 0 { c = 0 }
    if c > width { c = width }
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < c; i++ { b.WriteByte(fill) }
    for i := c; i < width; i++ { b.WriteByte(empty) }
    ret b.String()
}

// Banner renders `text` framed in a single-line ASCII box. Border is
// `fill` on all four sides; text is padded with two spaces (one each
// side of the border). Multi-line text is supported — each `\n`-
// separated line gets its own row inside the box, all aligned to the
// widest line. Empty text → empty banner (three rows of border-only).
// Use case: terminal section headers, "==== HEADER ====" style logs,
// CLI status divider blocks.
//
//   Banner("hello!", 35)
//   →  "##########\n# hello! #\n##########"
//
fun Banner(text string, fill byte) string {
    var lines []string = Split(text, "\n")
    var nLines int = len(lines)
    var maxW int = 0
    for i := 0; i < nLines; i++ {
        var L int = len(lines[i])
        if L > maxW { maxW = L }
    }
    var inner int = maxW + 2  // one space pad on each side
    var border string = RepeatByte(fill, inner + 2)
    var b *bytes.Builder = bytes.NewBuilder()
    b.WriteString(border)
    if nLines == 0 || (nLines == 1 && len(lines[0]) == 0) {
        // Empty content — just an empty middle row.
        b.WriteByte(10)
        b.WriteByte(fill)
        b.WriteString(RepeatByte(32, inner))
        b.WriteByte(fill)
        b.WriteByte(10)
        b.WriteString(border)
        ret b.String()
    }
    for i := 0; i < nLines; i++ {
        b.WriteByte(10)
        b.WriteByte(fill)
        b.WriteByte(32)
        b.WriteString(PadRight(lines[i], maxW, 32))
        b.WriteByte(32)
        b.WriteByte(fill)
    }
    b.WriteByte(10)
    b.WriteString(border)
    ret b.String()
}

// RepeatByte returns a string of `n` copies of byte `c`. n <= 0 → "".
// Faster than Repeat(chr(c), n) since it skips the heap-string-per-
// byte intermediate from chr(). Useful for ASCII borders / fills.
fun RepeatByte(c byte, n int) string {
    if n <= 0 { ret "" }
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < n; i++ { b.WriteByte(c) }
    ret b.String()
}

// Sparkline renders a single-line ASCII trend graph from a slice of
// values. Each value maps to one of 9 ramp characters (".:-=+*#%@")
// proportional to its magnitude vs the max. The result has exactly
// len(values) characters. Use case: terminal one-line time-series
// preview, log-line numeric summaries.
//
//   Sparkline([1,2,4,8,4,2,1])  →  ".-+#+-."
//
// Empty input → "". All-zero input → all-min-char ('.'). Negative
// values clamp to 0 for the ramp lookup (sparklines have no notion of
// below-zero — use NormalizeRangeInt first if you need that mapping).
fun Sparkline(values []int) string {
    var n int = len(values)
    if n == 0 { ret "" }
    var ramp string = ".:-=+*#%@"
    var rampN int = len(ramp)
    var maxV int = 0
    for i := 0; i < n; i++ {
        var v int = values[i]
        if v < 0 { v = 0 }
        if v > maxV { maxV = v }
    }
    var b *bytes.Builder = bytes.NewBuilder()
    if maxV == 0 {
        // Flat-zero series — emit n copies of the lowest ramp char.
        for i := 0; i < n; i++ { b.WriteByte(ramp[0]) }
        ret b.String()
    }
    for i := 0; i < n; i++ {
        var v int = values[i]
        if v < 0 { v = 0 }
        // Scale to ramp index [0, rampN-1]. Integer division: (v * (rampN-1)) / maxV.
        var idx int = (v * (rampN - 1)) / maxV
        if idx < 0 { idx = 0 }
        if idx >= rampN { idx = rampN - 1 }
        b.WriteByte(ramp[idx])
    }
    ret b.String()
}

// AsciiHistogram renders an entire labeled histogram in one call.
// labelWidth auto-fits to the longest label; counts auto-scale so the
// largest bar fills `barWidth`. Negative counts clamp to 0. Mismatched
// label/count length → "" (caller bug). Empty input → "". Rows joined
// with '\n', no trailing newline. Use cases: terminal dashboards, CLI
// status reports, quick log-line graphs.
fun AsciiHistogram(labels []string, counts []int, barWidth int, fill byte, empty byte) string {
    var n int = len(labels)
    if n == 0 { ret "" }
    if n != len(counts) { ret "" }
    var labelWidth int = 0
    for i := 0; i < n; i++ {
        var L int = len(labels[i])
        if L > labelWidth { labelWidth = L }
    }
    var maxCount int = 0
    for i := 0; i < n; i++ {
        var v int = counts[i]
        if v < 0 { v = 0 }
        if v > maxCount { maxCount = v }
    }
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < n; i++ {
        var raw int = counts[i]
        if raw < 0 { raw = 0 }
        var scaled int = 0
        if maxCount > 0 { scaled = (raw * barWidth) / maxCount }
        b.WriteString(AsciiHistogramRow(labels[i], labelWidth, scaled, barWidth, fill, empty))
        if i < n - 1 { b.WriteByte(10) }
    }
    ret b.String()
}

// BulletList renders `items` as a multi-line bulleted list. Each
// line gets the leading `marker` followed by a space, then the
// item. Lines joined with '\n'. Empty `items` returns "". Empty
// `marker` produces a "naked" list (item-per-line, no prefix).
// Useful for CLI status output, help summaries, error reports.
fun BulletList(items []string, marker string) string {
    var n int = len(items)
    if n == 0 { ret "" }
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < n; i++ {
        if len(marker) > 0 {
            b.WriteString(marker)
            b.WriteByte(32)
        }
        b.WriteString(items[i])
        if i < n - 1 { b.WriteByte(10) }
    }
    ret b.String()
}

// NumberedList renders `items` as a 1-indexed numbered list:
// "1. item one\n2. item two\n...". Useful for CLI step lists,
// ordered help/recipe output.
fun NumberedList(items []string) string {
    var n int = len(items)
    if n == 0 { ret "" }
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < n; i++ {
        b.WriteString(intDecimalStr(i + 1))
        b.WriteString(". ")
        b.WriteString(items[i])
        if i < n - 1 { b.WriteByte(10) }
    }
    ret b.String()
}

// Tabularize renders rows as a column-aligned text table. Each row
// is a slice of cells; cells in the same column are left-padded
// (PadRight space) to the width of the widest cell in that column.
// Rows are joined with '\n', columns within a row are joined with
// `sep` (typically " | " or "  "). Trailing column doesn't get
// padded (no wasted trailing space). Uneven row widths are handled —
// missing cells treated as "". Useful for CLI report tables /
// debug dumps of key-value lists.
fun Tabularize(rows [][]string, sep string) string {
    var nr int = len(rows)
    if nr == 0 { ret "" }
    // First pass: column-count and per-column widths.
    var ncols int = 0
    for i := 0; i < nr; i++ {
        var rn int = len(rows[i])
        if rn > ncols { ncols = rn }
    }
    if ncols == 0 { ret "" }
    var widths []int = new(ncols) []int {}
    for i := 0; i < nr; i++ {
        var rn int = len(rows[i])
        for j := 0; j < rn; j++ {
            var w int = len(rows[i][j])
            if w > widths[j] { widths[j] = w }
        }
    }
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < nr; i++ {
        var rn int = len(rows[i])
        for j := 0; j < ncols; j++ {
            var cell string = ""
            if j < rn { cell = "" + rows[i][j] }
            if j < ncols - 1 {
                b.WriteString(PadRight(cell, widths[j], 32))
                b.WriteString(sep)
            } else {
                b.WriteString(cell)
            }
        }
        if i < nr - 1 { b.WriteByte(10) }
    }
    ret b.String()
}

// SplitTrim splits s by sep and TrimSpaces each resulting piece.
// Useful for CSV-style input where whitespace around delimiters
// should be ignored ("a, b, c" → ["a","b","c"], not [" b","c"]).
// Empty sep returns s unchanged in a single-element slice (matches
// Split's convention).
fun SplitTrim(s string, sep string) []string {
    var parts []string = Split(s, sep)
    var n int = len(parts)
    for i := 0; i < n; i++ {
        parts[i] = TrimSpace(parts[i])
    }
    ret parts
}

// SplitTrimNonEmpty is SplitTrim with empty pieces removed after
// trimming. Useful for "a,, b ," → ["a","b"] (strip blank cells).
fun SplitTrimNonEmpty(s string, sep string) []string {
    var trimmed []string = SplitTrim(s, sep)
    var n int = len(trimmed)
    var out []string = new(0) []string {}
    for i := 0; i < n; i++ {
        if len(trimmed[i]) > 0 {
            out = append(out, "" + trimmed[i])
        }
    }
    ret out
}

// Split slices s around each occurrence of sep, returning the slice of
// substrings between them. An empty sep returns a single-element slice
// containing s (matches Go's convention well enough for v1).
fun Split(s string, sep string) []string {
    if len(sep) == 0 {
        var single []string = new(1) []string{}
        // "" + s is a BinaryExpr — bypasses the bare-IndexExpr/Ident
        // move trigger so s stays usable.
        single[0] = "" + s
        ret single
    }
    // First pass: count separator occurrences to size the output.
    var parts int = Count(s, sep) + 1
    var out []string = new(parts) []string{}
    var idx int = 0
    var lsep int = len(sep)
    var n int = len(s)
    var i int = 0
    var startPos int = 0
    var last int = n - lsep
    for i <= last {
        var match bool = true
        for j:=0; j < lsep; j++ {
            if s[i + j] != sep[j] {
                match = false
                break
            }
        }
        if match {
            // Build s[startPos:i] char by char into a Builder.
            var pb *bytes.Builder = bytes.NewBuilder()
            for k:=startPos; k < i; k++ {
                pb.WriteByte(s[k])
            }
            out[idx] = pb.String()
            idx = idx + 1
            i = i + lsep
            startPos = i
        } else {
            i = i + 1
        }
    }
    // Trailing piece.
    var tb *bytes.Builder = bytes.NewBuilder()
    for k:=startPos; k < n; k++ {
        tb.WriteByte(s[k])
    }
    out[idx] = tb.String()
    ret out
}

// Join concatenates the slice elements with sep between them.
fun Join(parts []string, sep string) string {
    var n int = len(parts)
    if n == 0 { ret "" }
    var b *bytes.Builder = bytes.NewBuilder()
    for i:=0; i < n; i++ {
        if i > 0 { b.WriteString("" + sep) }
        b.WriteString("" + parts[i])
    }
    ret b.String()
}

// JsonEscape returns s with the JSON-string-mandatory escapes
// applied: `\\`, `\"`, `\n`, `\r`, `\t`, `\f`, `\b`. Other control
// bytes (0x00..0x1F) become `\u00HH` (lowercase hex). Bytes above
// 0x7F pass through unchanged (UTF-8 high-bit sequences). Does NOT
// wrap in quotes — see JsonQuote for the full string-literal form.
fun JsonEscape(s string) string {
    var n int = len(s)
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < n; i++ {
        var c byte = s[i]
        if c == 92 { b.WriteString("\\\\"); continue }    // backslash
        if c == 34 { b.WriteString("\\\""); continue }    // double-quote
        if c == 10 { b.WriteString("\\n"); continue }
        if c == 13 { b.WriteString("\\r"); continue }
        if c == 9 { b.WriteString("\\t"); continue }
        if c == 12 { b.WriteString("\\f"); continue }
        if c == 8 { b.WriteString("\\b"); continue }
        var v int = c & 255
        if v < 32 {
            b.WriteString("\\u00")
            b.WriteByte(urlHexChar(v / 16))
            b.WriteByte(urlHexChar(v % 16))
            continue
        }
        b.WriteByte(c)
    }
    ret b.String()
}

// JsonUnescape returns s with JSON backslash escapes decoded.
// Handles `\\`, `\"`, `\/`, `\n`, `\r`, `\t`, `\f`, `\b`, and
// `\uHHHH` for code points up to U+FFFF (encoded as 1-3 UTF-8
// bytes; surrogate pairs not joined — each half emits its own
// 3-byte sequence). Bad / unknown escapes pass through literally.
fun JsonUnescape(s string) string {
    var n int = len(s)
    var b *bytes.Builder = bytes.NewBuilder()
    var i int = 0
    for i < n {
        var c byte = s[i]
        if c != 92 {
            b.WriteByte(c)
            i = i + 1
            continue
        }
        if i + 1 >= n {
            b.WriteByte(c)
            i = i + 1
            continue
        }
        var next byte = s[i + 1]
        if next == 92 { b.WriteByte(92); i = i + 2; continue }
        if next == 34 { b.WriteByte(34); i = i + 2; continue }
        if next == 47 { b.WriteByte(47); i = i + 2; continue }
        if next == 110 { b.WriteByte(10); i = i + 2; continue }
        if next == 114 { b.WriteByte(13); i = i + 2; continue }
        if next == 116 { b.WriteByte(9); i = i + 2; continue }
        if next == 102 { b.WriteByte(12); i = i + 2; continue }
        if next == 98 { b.WriteByte(8); i = i + 2; continue }
        if next == 117 {
            if i + 5 < n {
                var h0 int = nibbleFromHex(s[i + 2])
                var h1 int = nibbleFromHex(s[i + 3])
                var h2 int = nibbleFromHex(s[i + 4])
                var h3 int = nibbleFromHex(s[i + 5])
                if h0 >= 0 {
                    if h1 >= 0 {
                        if h2 >= 0 {
                            if h3 >= 0 {
                                var cp int = h0 * 4096 + h1 * 256 + h2 * 16 + h3
                                if cp < 128 {
                                    var v byte = cp
                                    b.WriteByte(v)
                                } else {
                                    if cp < 2048 {
                                        var b1 byte = 192 + (cp / 64)
                                        var b2 byte = 128 + (cp % 64)
                                        b.WriteByte(b1)
                                        b.WriteByte(b2)
                                    } else {
                                        var b1 byte = 224 + (cp / 4096)
                                        var b2 byte = 128 + ((cp / 64) % 64)
                                        var b3 byte = 128 + (cp % 64)
                                        b.WriteByte(b1)
                                        b.WriteByte(b2)
                                        b.WriteByte(b3)
                                    }
                                }
                                i = i + 6
                                continue
                            }
                        }
                    }
                }
            }
        }
        b.WriteByte(c)
        i = i + 1
    }
    ret b.String()
}

// JsonQuote returns JsonEscape(s) wrapped in double-quotes —
// produces a JSON-string literal suitable for inclusion in JSON
// output. The full form for emitting a string value.
fun JsonQuote(s string) string {
    var b *bytes.Builder = bytes.NewBuilder()
    b.WriteByte(34)
    b.WriteString(JsonEscape(s))
    b.WriteByte(34)
    ret b.String()
}

// ExpandTabs replaces each `\t` byte in s with the number of spaces
// needed to advance the column to the next multiple of tabSize. The
// column counter resets on `\n` / `\r`. If tabSize <= 0, s is
// returned unchanged.
fun ExpandTabs(s string, tabSize int) string {
    if tabSize <= 0 { ret s }
    var n int = len(s)
    var b *bytes.Builder = bytes.NewBuilder()
    var col int = 0
    var i int = 0
    for i < n {
        var c byte = s[i]
        if c == 9 {
            var pad int = tabSize - (col % tabSize)
            for j := 0; j < pad; j++ {
                b.WriteByte(32)
            }
            col = col + pad
        } else {
            b.WriteByte(c)
            if c == 10 {
                col = 0
            } else {
                if c == 13 {
                    col = 0
                } else {
                    col = col + 1
                }
            }
        }
        i = i + 1
    }
    ret b.String()
}

// StripAnsi removes ANSI escape sequences (CSI / OSC / single-shift)
// from s. CSI sequences begin with ESC `[` and end at any byte in
// 0x40..0x7E. Other ESC sequences drop ESC plus the next byte. Lone
// ESC at end of string is dropped. Useful for cleaning terminal
// output before logging or width measurement.
fun StripAnsi(s string) string {
    var n int = len(s)
    var b *bytes.Builder = bytes.NewBuilder()
    var i int = 0
    for i < n {
        var c byte = s[i]
        if c == 27 {
            if i + 1 >= n {
                i = i + 1
                continue
            }
            var next byte = s[i + 1]
            if next == 91 {
                i = i + 2
                for i < n {
                    var cc byte = s[i]
                    if cc >= 64 {
                        if cc <= 126 {
                            i = i + 1
                            break
                        }
                    }
                    i = i + 1
                }
                continue
            }
            i = i + 2
            continue
        }
        b.WriteByte(c)
        i = i + 1
    }
    ret b.String()
}

// CsvJoinRow encodes each cell via CsvEscape and joins with `,`.
// Complement of CsvSplitRow. Useful for emitting a single CSV
// record from a slice of cell values.
fun CsvJoinRow(cells []string) string {
    var n int = len(cells)
    if n == 0 { ret "" }
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < n; i++ {
        if i > 0 { b.WriteByte(44) }
        b.WriteString(CsvEscape(cells[i]))
    }
    ret b.String()
}

// CsvSplitRow parses a single CSV row into cells, honoring
// double-quoted segments (comma / quote / newline / CR inside
// quotes are literal; internal `""` decodes to `"`). Returns an
// empty slice for empty input. Lenient — no error for malformed.
fun CsvSplitRow(row string) []string {
    var n int = len(row)
    var out []string = new(0) []string {}
    if n == 0 { ret out }
    var current string = ""
    var inQuotes bool = false
    var i int = 0
    for i < n {
        var c byte = row[i]
        if inQuotes {
            if c == 34 {
                if i + 1 < n {
                    if row[i + 1] == 34 {
                        current = current + "\""
                        i = i + 2
                        continue
                    }
                }
                inQuotes = false
                i = i + 1
                continue
            }
            current = current + chr(c)
            i = i + 1
            continue
        }
        if c == 44 {
            out = append(out, current)
            current = ""
            i = i + 1
            continue
        }
        if c == 34 {
            if len(current) == 0 {
                inQuotes = true
                i = i + 1
                continue
            }
        }
        current = current + chr(c)
        i = i + 1
    }
    out = append(out, current)
    ret out
}

// CsvEscape returns s wrapped in double-quotes with embedded
// double-quotes doubled, but only when s contains a comma, double-
// quote, newline, or carriage return (per RFC 4180). Otherwise s
// is returned unchanged. Useful for emitting safe CSV cells.
fun CsvEscape(s string) string {
    var n int = len(s)
    var needsQuoting bool = false
    for i := 0; i < n; i++ {
        var c byte = s[i]
        if c == 44 { needsQuoting = true; break }    // ','
        if c == 34 { needsQuoting = true; break }    // '"'
        if c == 10 { needsQuoting = true; break }    // '\n'
        if c == 13 { needsQuoting = true; break }    // '\r'
    }
    if !needsQuoting { ret "" + s }
    var b *bytes.Builder = bytes.NewBuilder()
    b.WriteByte(34)
    for i := 0; i < n; i++ {
        var c byte = s[i]
        if c == 34 { b.WriteByte(34); b.WriteByte(34); continue }
        b.WriteByte(c)
    }
    b.WriteByte(34)
    ret b.String()
}

// CsvUnescape reverses CsvEscape — strips outer double-quotes if
// present and de-doubles internal quotes. Bare (unquoted) values
// pass through unchanged. Lenient — doesn't validate that all
// internal quotes are paired; an odd trailing quote is dropped.
fun CsvUnescape(s string) string {
    var n int = len(s)
    if n < 2 { ret "" + s }
    if s[0] != 34 { ret "" + s }                     // not quoted at start
    if s[n - 1] != 34 { ret "" + s }                 // not quoted at end
    var b *bytes.Builder = bytes.NewBuilder()
    var i int = 1
    for i < n - 1 {
        var c byte = s[i]
        if c == 34 {
            if i + 1 < n - 1 {
                if s[i + 1] == 34 {
                    b.WriteByte(34)
                    i = i + 2
                    continue
                }
            }
        }
        b.WriteByte(c)
        i = i + 1
    }
    ret b.String()
}

// urlIsUnreserved reports whether byte c is in the RFC 3986
// "unreserved" character set (A-Z, a-z, 0-9, '-', '_', '.', '~').
fun urlIsUnreserved(c byte) bool {
    if c >= 48 {
        if c <= 57 { ret true }
    }
    if c >= 65 {
        if c <= 90 { ret true }
    }
    if c >= 97 {
        if c <= 122 { ret true }
    }
    if c == 45 { ret true }
    if c == 95 { ret true }
    if c == 46 { ret true }
    if c == 126 { ret true }
    ret false
}

// urlHexChar returns the lowercase ASCII hex digit for n in [0, 16).
fun urlHexChar(n int) byte {
    if n < 10 { ret 48 + n }
    ret 87 + n
}

// UrlEscape returns s with every byte outside the RFC 3986
// "unreserved" set replaced by `%HH` percent-encoding. Useful for
// query-string value encoding, URL path-segment safety.
fun UrlEscape(s string) string {
    var n int = len(s)
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < n; i++ {
        var c byte = s[i]
        if urlIsUnreserved(c) {
            b.WriteByte(c)
            continue
        }
        b.WriteByte(37)
        var v int = c & 255
        b.WriteByte(urlHexChar(v / 16))
        b.WriteByte(urlHexChar(v % 16))
    }
    ret b.String()
}

// UrlUnescape returns s with every `%HH` sequence decoded. Bad hex
// (missing digits or non-hex chars) passes through unchanged. Does
// NOT decode `+` → space — caller should pre-process for form
// decoding.
fun UrlUnescape(s string) string {
    var n int = len(s)
    var b *bytes.Builder = bytes.NewBuilder()
    var i int = 0
    for i < n {
        if s[i] == 37 {
            if (i + 2) < n {
                var hi int = nibbleFromHex(s[i+1])
                var lo int = nibbleFromHex(s[i+2])
                if hi >= 0 {
                    if lo >= 0 {
                        var v byte = hi * 16 + lo
                        b.WriteByte(v)
                        i = i + 3
                        continue
                    }
                }
            }
        }
        b.WriteByte(s[i])
        i = i + 1
    }
    ret b.String()
}

// HtmlEscape returns s with the five standard HTML metacharacters
// replaced by their entity references: `&` → `&amp;`, `<` → `&lt;`,
// `>` → `&gt;`, `"` → `&quot;`, `'` → `&#39;`. Useful for safe
// HTML-attribute / text-node content emission.
fun HtmlEscape(s string) string {
    var n int = len(s)
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < n; i++ {
        var c byte = s[i]
        if c == 38 { b.WriteString("&amp;"); continue }
        if c == 60 { b.WriteString("&lt;"); continue }
        if c == 62 { b.WriteString("&gt;"); continue }
        if c == 34 { b.WriteString("&quot;"); continue }
        if c == 39 { b.WriteString("&#39;"); continue }
        b.WriteByte(c)
    }
    ret b.String()
}

// HtmlUnescape returns s with the five standard HTML entity
// references decoded back. Recognizes `&amp;`, `&lt;`, `&gt;`,
// `&quot;`, `&#39;`, `&apos;`, and `&#34;` — other entities pass
// through unchanged.
fun HtmlUnescape(s string) string {
    var n int = len(s)
    var b *bytes.Builder = bytes.NewBuilder()
    var i int = 0
    for i < n {
        if s[i] == 38 {
            if i + 6 <= n {
                if s[i+1] == 113 {
                    if s[i+2] == 117 {
                        if s[i+3] == 111 {
                            if s[i+4] == 116 {
                                if s[i+5] == 59 {
                                    b.WriteByte(34)
                                    i = i + 6
                                    continue
                                }
                            }
                        }
                    }
                }
                if s[i+1] == 97 {
                    if s[i+2] == 112 {
                        if s[i+3] == 111 {
                            if s[i+4] == 115 {
                                if s[i+5] == 59 {
                                    b.WriteByte(39)
                                    i = i + 6
                                    continue
                                }
                            }
                        }
                    }
                }
            }
            if i + 5 <= n {
                if s[i+1] == 97 {
                    if s[i+2] == 109 {
                        if s[i+3] == 112 {
                            if s[i+4] == 59 {
                                b.WriteByte(38)
                                i = i + 5
                                continue
                            }
                        }
                    }
                }
                if s[i+1] == 35 {
                    if s[i+2] == 51 {
                        if s[i+3] == 57 {
                            if s[i+4] == 59 {
                                b.WriteByte(39)
                                i = i + 5
                                continue
                            }
                        }
                        if s[i+3] == 52 {
                            if s[i+4] == 59 {
                                b.WriteByte(34)
                                i = i + 5
                                continue
                            }
                        }
                    }
                }
            }
            if i + 4 <= n {
                if s[i+1] == 108 {
                    if s[i+2] == 116 {
                        if s[i+3] == 59 {
                            b.WriteByte(60)
                            i = i + 4
                            continue
                        }
                    }
                }
                if s[i+1] == 103 {
                    if s[i+2] == 116 {
                        if s[i+3] == 59 {
                            b.WriteByte(62)
                            i = i + 4
                            continue
                        }
                    }
                }
            }
        }
        b.WriteByte(s[i])
        i = i + 1
    }
    ret b.String()
}

// LongestLine returns the byte-length of the longest line in s
// (lines separated by `\n`). Empty input returns 0. A trailing
// newline doesn't add a phantom empty line. Useful for: log-line
// width statistics, file-pretty-print column-width estimation.
fun LongestLine(s string) int {
    var n int = len(s)
    if n == 0 { ret 0 }
    var best int = 0
    var current int = 0
    for i := 0; i < n; i++ {
        if s[i] == 10 {
            if current > best { best = current }
            current = 0
        } else {
            current = current + 1
        }
    }
    if current > best { best = current }
    ret best
}

// ShortestLine returns the byte-length of the shortest line in s.
// Empty input returns 0. Empty lines (from consecutive `\n` or a
// leading/trailing `\n`) count as length 0 — useful as a sanity
// check for blank-line presence.
fun ShortestLine(s string) int {
    var n int = len(s)
    if n == 0 { ret 0 }
    var best int = -1
    var current int = 0
    for i := 0; i < n; i++ {
        if s[i] == 10 {
            if best < 0 { best = current }
            if current < best { best = current }
            current = 0
        } else {
            current = current + 1
        }
    }
    if best < 0 { best = current }
    if current < best { best = current }
    ret best
}

// SplitToInts splits s on sep and parses each piece via
// strconv.Atoi. Inverse of JoinInts. Returns (parsed slice, nil)
// on full success; the first parse error short-circuits with
// (empty, error). Useful for: CSV cell parsing, log-line numeric
// field extraction, configuration value decoding.
fun SplitToInts(s string, sep string) ([]int, error) {
    var parts []string = Split(s, sep)
    var n int = len(parts)
    var out []int = new(n) []int {}
    for i := 0; i < n; i++ {
        var v int = 0
        var err error = nil
        v, err = strconv.Atoi(parts[i])
        if err != nil {
            ret new(0) []int {}, err
        }
        out[i] = v
    }
    ret out, nil
}

// SplitToIntsLossy splits s on sep and parses each piece, silently
// skipping any piece that doesn't parse cleanly. Useful for lenient
// log-mining where some values may be sentinel strings.
fun SplitToIntsLossy(s string, sep string) []int {
    var parts []string = Split(s, sep)
    var n int = len(parts)
    var out []int = new(0) []int {}
    for i := 0; i < n; i++ {
        var v int = 0
        var err error = nil
        v, err = strconv.Atoi(parts[i])
        if err != nil { continue }
        out = append(out, v)
    }
    ret out
}

// JoinInts converts every int in s to its decimal representation
// (via strconv.Itoa) and joins them with sep. Useful for CSV / log
// / debug-print rendering of integer arrays. Empty input returns "".
fun JoinInts(s []int, sep string) string {
    var n int = len(s)
    if n == 0 { ret "" }
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < n; i++ {
        if i > 0 { b.WriteString("" + sep) }
        b.WriteString(strconv.Itoa(s[i]))
    }
    ret b.String()
}

// JoinIntsBracket wraps JoinInts in `open`/`close` markers, useful
// for "[1, 2, 3]" / "{1; 2; 3}" style pretty-printing.
fun JoinIntsBracket(s []int, sep string, open string, close string) string {
    var b *bytes.Builder = bytes.NewBuilder()
    b.WriteString(open)
    b.WriteString(JoinInts(s, sep))
    b.WriteString(close)
    ret b.String()
}

// JoinNonEmpty concatenates non-empty elements of parts with sep
// between them. Empty pieces are skipped (distinct from Join, which
// preserves them and surrounds with separators). Useful for: URL /
// path piece-joining where missing segments shouldn't produce
// double-slashes, breadcrumb generation skipping unset levels.
fun JoinNonEmpty(parts []string, sep string) string {
    var n int = len(parts)
    if n == 0 { ret "" }
    var b *bytes.Builder = bytes.NewBuilder()
    var first bool = true
    for i := 0; i < n; i++ {
        if len(parts[i]) == 0 { continue }
        if !first { b.WriteString("" + sep) }
        b.WriteString("" + parts[i])
        first = false
    }
    ret b.String()
}

// FirstNonEmpty returns the first non-empty string in parts, or ""
// if every entry (or the slice itself) is empty. The canonical
// config-fallback chain — `host := FirstNonEmpty([]string{ env, cfg,
// "localhost" })` reads as the intent: prefer env, then cfg, then
// the hard-coded default. Mirrors the `||`-fallback idiom common in
// other languages with truthy semantics.
fun FirstNonEmpty(parts []string) string {
    var n int = len(parts)
    for i := 0; i < n; i++ {
        if len(parts[i]) > 0 { ret parts[i] }
    }
    ret ""
}

// JoinLast concatenates parts with sep between all but the last
// pair, which uses lastSep instead. For 0 parts returns ""; for 1
// returns that element; for 2 uses lastSep only. Useful for
// Oxford-comma-style human lists ("a, b, and c"), conjunctive /
// disjunctive enumerations.
fun JoinLast(parts []string, sep string, lastSep string) string {
    var n int = len(parts)
    if n == 0 { ret "" }
    if n == 1 { ret "" + parts[0] }
    if n == 2 {
        var b *bytes.Builder = bytes.NewBuilder()
        b.WriteString(parts[0])
        b.WriteString(lastSep)
        b.WriteString(parts[1])
        ret b.String()
    }
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < n - 1; i++ {
        if i > 0 { b.WriteString("" + sep) }
        b.WriteString("" + parts[i])
    }
    b.WriteString(lastSep)
    b.WriteString(parts[n - 1])
    ret b.String()
}

// PadLeft returns s left-padded with byte c so the total byte
// length is at least n. If len(s) >= n, returns s unchanged.
// Useful for column-aligned output (e.g. PadLeft(strconv.Itoa(x), 6, 32)
// for right-justified decimal columns).
fun PadLeft(s string, n int, c byte) string {
    var sn int = len(s)
    if sn >= n { ret s }
    var b *bytes.Builder = bytes.NewBuilder()
    var pad int = n - sn
    for i := 0; i < pad; i++ {
        b.WriteByte(c)
    }
    b.WriteString(s)
    ret b.String()
}

// PadRight returns s right-padded with byte c so the total byte
// length is at least n. If len(s) >= n, returns s unchanged.
fun PadRight(s string, n int, c byte) string {
    var sn int = len(s)
    if sn >= n { ret s }
    var b *bytes.Builder = bytes.NewBuilder()
    b.WriteString(s)
    var pad int = n - sn
    for i := 0; i < pad; i++ {
        b.WriteByte(c)
    }
    ret b.String()
}

// NormalizeNewlines returns s with CRLF (\r\n) and lone CR (\r)
// sequences converted to LF (\n). Common pre-processing before
// parsing line-oriented text from Windows / classic-Mac origins.
fun NormalizeNewlines(s string) string {
    var n int = len(s)
    var b *bytes.Builder = bytes.NewBuilder()
    var i int = 0
    for i < n {
        var c byte = s[i]
        if c == 13 {                       // '\r'
            b.WriteByte(10)                // '\n'
            if (i + 1) < n {
                if s[i + 1] == 10 {
                    i = i + 2
                    continue
                }
            }
            i = i + 1
            continue
        }
        b.WriteByte(c)
        i = i + 1
    }
    ret b.String()
}

// NormalizeWhitespace returns s with leading/trailing whitespace
// stripped AND internal runs of whitespace collapsed to a single
// space byte (0x20). Useful for canonicalizing parsed text, log
// messages, free-form user input. Whitespace classification is the
// same as Fields/TrimSpace (space, tab, newline, CR, VT, FF).
fun NormalizeWhitespace(s string) string {
    var n int = len(s)
    var b *bytes.Builder = bytes.NewBuilder()
    var pendingSpace bool = false
    var hasOut bool = false
    for i := 0; i < n; i++ {
        var c byte = s[i]
        if isWhitespace(c) {
            if hasOut { pendingSpace = true }
            continue
        }
        if pendingSpace {
            b.WriteByte(32)
            pendingSpace = false
        }
        b.WriteByte(c)
        hasOut = true
    }
    ret b.String()
}

// hexNibbleUpper maps a 0..15 nibble value to its uppercase hex
// byte. Used by URLEncode (RFC 3986 recommends uppercase).
fun hexNibbleUpper(n int) byte {
    if n < 10 { ret 48 + n }   // '0' + n
    ret 55 + n                 // 'A' + (n-10)
}

// nibbleFromHex decodes one hex byte ('0'..'9' / 'a'..'f' / 'A'..'F')
// to its 0..15 value. Returns -1 on a non-hex byte.
fun nibbleFromHex(c byte) int {
    if c >= 48 {
        if c <= 57 { ret c - 48 }      // '0'..'9'
    }
    if c >= 97 {
        if c <= 102 { ret c - 87 }     // 'a'..'f'
    }
    if c >= 65 {
        if c <= 70 { ret c - 55 }      // 'A'..'F'
    }
    ret -1
}

// URLEncode returns s with RFC 3986 percent-encoding applied. Bytes
// in the unreserved set (A-Z, a-z, 0-9, '-', '_', '.', '~') pass
// through; everything else becomes `%HH` with uppercase hex digits.
// Note: this is the strict form — space becomes `%20`, NOT `+`
// (which is form-URL-encoded query semantics, not RFC 3986).
fun URLEncode(s string) string {
    var n int = len(s)
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < n; i++ {
        var c byte = s[i]
        if c >= 65 {
            if c <= 90 { b.WriteByte(c); continue }     // A-Z
        }
        if c >= 97 {
            if c <= 122 { b.WriteByte(c); continue }    // a-z
        }
        if c >= 48 {
            if c <= 57 { b.WriteByte(c); continue }     // 0-9
        }
        if c == 45 { b.WriteByte(c); continue }         // '-'
        if c == 95 { b.WriteByte(c); continue }         // '_'
        if c == 46 { b.WriteByte(c); continue }         // '.'
        if c == 126 { b.WriteByte(c); continue }        // '~'
        b.WriteByte(37)                                 // '%'
        var v int = c & 255
        b.WriteByte(hexNibbleUpper(v / 16))
        b.WriteByte(hexNibbleUpper(v % 16))
    }
    ret b.String()
}

// URLDecode is the inverse of URLEncode. Percent-escapes `%HH` are
// decoded to their byte; everything else passes through. Returns an
// error on a stray `%` (not followed by two hex digits) so callers
// can distinguish malformed input from valid encodings.
fun URLDecode(s string) (string, error) {
    var n int = len(s)
    var b *bytes.Builder = bytes.NewBuilder()
    var i int = 0
    for i < n {
        var c byte = s[i]
        if c != 37 {                                    // not '%'
            b.WriteByte(c)
            i = i + 1
            continue
        }
        if (i + 2) >= n {
            ret "", errors.New("strings: truncated percent-escape")
        }
        var hi int = nibbleFromHex(s[i+1])
        var lo int = nibbleFromHex(s[i+2])
        if hi < 0 { ret "", errors.New("strings: bad hex digit in percent-escape") }
        if lo < 0 { ret "", errors.New("strings: bad hex digit in percent-escape") }
        var bv byte = (hi << 4) | lo
        b.WriteByte(bv)
        i = i + 3
    }
    ret b.String(), nil
}

// EscapeHTML returns s with the five HTML-special bytes replaced
// by their entity references: '<' → &lt; '>' → &gt; '&' → &amp;
// '"' → &quot; "'" → &#39;. Mirrors Go's html.EscapeString. Other
// bytes pass through unchanged. Use this when interpolating
// user-controlled text into HTML body / attribute contexts.
fun EscapeHTML(s string) string {
    var n int = len(s)
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < n; i++ {
        var c byte = s[i]
        if c == 60 {
            b.WriteString("&lt;")
            continue
        }
        if c == 62 {
            b.WriteString("&gt;")
            continue
        }
        if c == 38 {
            b.WriteString("&amp;")
            continue
        }
        if c == 34 {
            b.WriteString("&quot;")
            continue
        }
        if c == 39 {
            b.WriteString("&#39;")
            continue
        }
        b.WriteByte(c)
    }
    ret b.String()
}

// UnescapeHTML returns s with the five common HTML entity references
// decoded back to their bytes: &lt; &gt; &amp; &quot; &#39; (and the
// alias &apos;). Anything that looks like an entity but doesn't
// match a known token passes through verbatim. Inverse of EscapeHTML
// on canonical inputs; general HTML decoding (numeric refs, named
// entities) is out of scope.
fun UnescapeHTML(s string) string {
    var n int = len(s)
    var b *bytes.Builder = bytes.NewBuilder()
    var i int = 0
    for i < n {
        if s[i] != 38 {                                // not '&'
            b.WriteByte(s[i])
            i = i + 1
            continue
        }
        // Try each known entity in order of length.
        if i + 4 <= n {
            if s[i+1] == 108 {
                if s[i+2] == 116 {
                    if s[i+3] == 59 {                  // &lt;
                        b.WriteByte(60)
                        i = i + 4
                        continue
                    }
                }
            }
            if s[i+1] == 103 {
                if s[i+2] == 116 {
                    if s[i+3] == 59 {                  // &gt;
                        b.WriteByte(62)
                        i = i + 4
                        continue
                    }
                }
            }
        }
        if i + 5 <= n {
            if s[i+1] == 97 {
                if s[i+2] == 109 {
                    if s[i+3] == 112 {
                        if s[i+4] == 59 {              // &amp;
                            b.WriteByte(38)
                            i = i + 5
                            continue
                        }
                    }
                }
            }
            if s[i+1] == 35 {
                if s[i+2] == 51 {
                    if s[i+3] == 57 {
                        if s[i+4] == 59 {              // &#39;
                            b.WriteByte(39)
                            i = i + 5
                            continue
                        }
                    }
                }
            }
        }
        if i + 6 <= n {
            if s[i+1] == 113 {
                if s[i+2] == 117 {
                    if s[i+3] == 111 {
                        if s[i+4] == 116 {
                            if s[i+5] == 59 {          // &quot;
                                b.WriteByte(34)
                                i = i + 6
                                continue
                            }
                        }
                    }
                }
            }
            if s[i+1] == 97 {
                if s[i+2] == 112 {
                    if s[i+3] == 111 {
                        if s[i+4] == 115 {
                            if s[i+5] == 59 {          // &apos;
                                b.WriteByte(39)
                                i = i + 6
                                continue
                            }
                        }
                    }
                }
            }
        }
        // Unknown entity-like token — pass the '&' through.
        b.WriteByte(s[i])
        i = i + 1
    }
    ret b.String()
}

// IsNumeric reports whether every byte of s is an ASCII decimal
// digit ('0'..'9'). Empty string returns false (no digits — caller
// asking "is this a number?" probably wants false on empty).
fun IsNumeric(s string) bool {
    var n int = len(s)
    if n == 0 { ret false }
    for i := 0; i < n; i++ {
        var c byte = s[i]
        if c < 48 { ret false }
        if c > 57 { ret false }
    }
    ret true
}

// IsAlpha reports whether every byte of s is an ASCII letter
// (A-Z or a-z). Empty string returns false.
fun IsAlpha(s string) bool {
    var n int = len(s)
    if n == 0 { ret false }
    for i := 0; i < n; i++ {
        var c byte = s[i]
        var isUpper bool = false
        if c >= 65 {
            if c <= 90 { isUpper = true }
        }
        var isLower bool = false
        if c >= 97 {
            if c <= 122 { isLower = true }
        }
        if !isUpper {
            if !isLower { ret false }
        }
    }
    ret true
}

// IsUpper reports whether every ASCII letter in s is uppercase AND
// s contains at least one letter. Non-letter bytes are neutral
// (digits, spaces, punctuation pass through without disqualifying).
// Empty string returns false. Mirrors Python's str.isupper semantics.
// Useful for "is this a constant identifier?" / "is this YELLING text?"
// classification.
fun IsUpper(s string) bool {
    var n int = len(s)
    if n == 0 { ret false }
    var hasLetter bool = false
    for i := 0; i < n; i++ {
        var c byte = s[i]
        if c >= 65 {
            if c <= 90 {
                hasLetter = true
                continue
            }
        }
        if c >= 97 {
            if c <= 122 { ret false }    // a lowercase letter disqualifies
        }
    }
    ret hasLetter
}

// IsLower is the counterpart to IsUpper — every ASCII letter is
// lowercase AND s contains at least one letter. Mirrors Python's
// str.islower semantics.
fun IsLower(s string) bool {
    var n int = len(s)
    if n == 0 { ret false }
    var hasLetter bool = false
    for i := 0; i < n; i++ {
        var c byte = s[i]
        if c >= 97 {
            if c <= 122 {
                hasLetter = true
                continue
            }
        }
        if c >= 65 {
            if c <= 90 { ret false }     // an uppercase letter disqualifies
        }
    }
    ret hasLetter
}

// IsAlphanumeric reports whether every byte of s is an ASCII
// letter or digit. Empty string returns false.
fun IsAlphanumeric(s string) bool {
    var n int = len(s)
    if n == 0 { ret false }
    for i := 0; i < n; i++ {
        var c byte = s[i]
        var ok bool = false
        if c >= 48 {
            if c <= 57 { ok = true }                // 0-9
        }
        if c >= 65 {
            if c <= 90 { ok = true }                // A-Z
        }
        if c >= 97 {
            if c <= 122 { ok = true }               // a-z
        }
        if !ok { ret false }
    }
    ret true
}

// IsBinary reports whether every byte of s is '0' or '1'.
// Empty string returns false. Useful for validating binary
// number tokens, bit-string parsing preconditions.
fun IsBinary(s string) bool {
    var n int = len(s)
    if n == 0 { ret false }
    for i := 0; i < n; i++ {
        var c byte = s[i]
        if c != 48 {
            if c != 49 { ret false }
        }
    }
    ret true
}

// SplitMap splits s on sep, then applies fn to every piece and
// returns the transformed slice. Equivalent to
// `MapStrings(Split(s, sep), fn)` but bundled into one call.
// Useful for: parse-and-trim pipelines, normalize-each-field
// patterns common in CSV / config parsing.
fun SplitMap(s string, sep string, fn fun(string) string) []string {
    var parts []string = Split(s, sep)
    var n int = len(parts)
    var out []string = new(n) []string {}
    for i := 0; i < n; i++ {
        out[i] = fn(parts[i])
    }
    ret out
}

// WordWrap returns s reflowed so no output line exceeds `width`
// bytes when possible. Words are split on whitespace (same
// classifier as Fields), then greedily packed into lines with
// single-space joins. A single word longer than `width` is placed
// on its own line and overflows (no mid-word splits). width <= 0
// returns the input unchanged. Empty / whitespace-only input
// returns "". Useful for terminal output, message formatting,
// commit-body wrapping.
fun WordWrap(s string, width int) string {
    if width <= 0 { ret "" + s }
    var words []string = Fields(s)
    var n int = len(words)
    if n == 0 { ret "" }
    var b *bytes.Builder = bytes.NewBuilder()
    b.WriteString(words[0])
    var col int = len(words[0])
    for i := 1; i < n; i++ {
        var w int = len(words[i])
        if (col + 1 + w) <= width {
            b.WriteByte(32)             // ' '
            b.WriteString(words[i])
            col = col + 1 + w
        } else {
            b.WriteByte(10)             // '\n'
            b.WriteString(words[i])
            col = w
        }
    }
    ret b.String()
}

// Dedent removes the longest leading-whitespace prefix common to
// every NON-blank line of s. Blank (all-whitespace) lines are
// preserved as-is and don't constrain the prefix. Mirrors Python's
// `textwrap.dedent`. Useful for embedded multi-line string
// literals where the indentation is purely for source readability.
// Inverse of Indent (STDLIB.170).
fun Dedent(s string) string {
    var n int = len(s)
    if n == 0 { ret "" }
    // Pass 1: find minimum leading-ws (space/tab) count over the
    // non-blank lines.
    var minWs int = -1
    var i int = 0
    for i < n {
        var lineStart int = i
        for i < n {
            if s[i] == 10 { break }
            i = i + 1
        }
        var ws int = 0
        var hasNonWs bool = false
        var j int = lineStart
        for j < i {
            var c byte = s[j]
            if c == 32 { ws = ws + 1; j = j + 1; continue }
            if c == 9 { ws = ws + 1; j = j + 1; continue }
            hasNonWs = true
            break
        }
        if hasNonWs {
            if minWs < 0 { minWs = ws }
            if ws < minWs { minWs = ws }
        }
        if i < n { i = i + 1 }
    }
    if minWs <= 0 { ret "" + s }
    // Pass 2: strip minWs leading bytes from each line.
    var b *bytes.Builder = bytes.NewBuilder()
    i = 0
    for i < n {
        var lineStart int = i
        for i < n {
            if s[i] == 10 { break }
            i = i + 1
        }
        var lineLen int = i - lineStart
        var ws int = 0
        var j int = lineStart
        for j < i {
            var c byte = s[j]
            if c == 32 { ws = ws + 1; j = j + 1; continue }
            if c == 9 { ws = ws + 1; j = j + 1; continue }
            break
        }
        var skip int = ws
        if skip > minWs { skip = minWs }
        if skip > lineLen { skip = lineLen }
        for k := lineStart + skip; k < i; k++ {
            b.WriteByte(s[k])
        }
        if i < n {
            b.WriteByte(10)
            i = i + 1
        }
    }
    ret b.String()
}

// LineCount returns the number of lines in s. Lines are separated
// by '\n'. An empty string has 0 lines. A string with a trailing
// newline counts the newline as a terminator (not a separator) so
// "a\nb\n" has 2 lines, not 3.
fun LineCount(s string) int {
    var n int = len(s)
    if n == 0 { ret 0 }
    var count int = 1
    for i := 0; i < n; i++ {
        if s[i] == 10 { count = count + 1 }
    }
    if s[n - 1] == 10 { count = count - 1 }
    ret count
}

// LineAt returns the line at index idx (0-based) within s. Out-of-
// range or negative idx returns "". The trailing newline (if any)
// is NOT included in the returned line. Equivalent to Lines(s)[idx]
// but skips constructing the full slice.
fun LineAt(s string, idx int) string {
    if idx < 0 { ret "" }
    var n int = len(s)
    var cur int = 0
    var start int = 0
    for i := 0; i < n; i++ {
        if s[i] == 10 {
            if cur == idx {
                var b *bytes.Builder = bytes.NewBuilder()
                for j := start; j < i; j++ {
                    b.WriteByte(s[j])
                }
                ret b.String()
            }
            cur = cur + 1
            start = i + 1
        }
    }
    // Final line that lacks a trailing newline.
    if cur == idx {
        if start >= n { ret "" }
        var b *bytes.Builder = bytes.NewBuilder()
        for j := start; j < n; j++ {
            b.WriteByte(s[j])
        }
        ret b.String()
    }
    ret ""
}

// Indent returns s with every line prepended by prefix. Lines are
// split on '\n' bytes; the trailing newline (if any) is preserved
// but NOT prefixed (no empty prefixed line at the end). An empty
// s returns "" unchanged. Useful for nesting log output, building
// code-generation blocks, formatting tree-style trace output.
fun Indent(s string, prefix string) string {
    var n int = len(s)
    if n == 0 { ret "" }
    var b *bytes.Builder = bytes.NewBuilder()
    var atLineStart bool = true
    for i := 0; i < n; i++ {
        if atLineStart {
            b.WriteString("" + prefix)
            atLineStart = false
        }
        var c byte = s[i]
        b.WriteByte(c)
        if c == 10 { atLineStart = true }   // '\n'
    }
    // If s ended with a newline, atLineStart is now true but we
    // don't add prefix — that would create a phantom empty line.
    ret b.String()
}

// IsValidIdentifier reports whether s is a Go-style identifier:
// non-empty, starts with an ASCII letter or '_', and every
// subsequent byte is a letter / digit / underscore. Useful for
// validating tokens before passing them to a parser or codegen.
fun IsValidIdentifier(s string) bool {
    var n int = len(s)
    if n == 0 { ret false }
    var first byte = s[0]
    var firstOk bool = false
    if first == 95 { firstOk = true }                    // '_'
    if first >= 65 {
        if first <= 90 { firstOk = true }                // A-Z
    }
    if first >= 97 {
        if first <= 122 { firstOk = true }               // a-z
    }
    if !firstOk { ret false }
    for i := 1; i < n; i++ {
        var c byte = s[i]
        var ok bool = false
        if c == 95 { ok = true }
        if c >= 48 {
            if c <= 57 { ok = true }                     // 0-9
        }
        if c >= 65 {
            if c <= 90 { ok = true }
        }
        if c >= 97 {
            if c <= 122 { ok = true }
        }
        if !ok { ret false }
    }
    ret true
}

// IsHex reports whether every byte of s is a hex digit
// (0-9, A-F, or a-f). Empty string returns false. Useful for
// validating tokens before passing to a parser, integrity check
// on hex-formatted hashes / colors / IDs.
fun IsHex(s string) bool {
    var n int = len(s)
    if n == 0 { ret false }
    for i := 0; i < n; i++ {
        var c byte = s[i]
        var ok bool = false
        if c >= 48 {
            if c <= 57 { ok = true }                // 0-9
        }
        if c >= 65 {
            if c <= 70 { ok = true }                // A-F
        }
        if c >= 97 {
            if c <= 102 { ok = true }               // a-f
        }
        if !ok { ret false }
    }
    ret true
}

// IsPalindrome reports whether s reads the same forwards and
// backwards (byte-wise). Empty string returns true (vacuous).
// Single byte returns true. Case-sensitive and whitespace-sensitive
// — callers wanting "ignore case" should pre-fold via ToLower; for
// "ignore non-letters" pre-filter the input.
fun IsPalindrome(s string) bool {
    var n int = len(s)
    var i int = 0
    var j int = n - 1
    for i < j {
        if s[i] != s[j] { ret false }
        i = i + 1
        j = j - 1
    }
    ret true
}

// Truncate clamps s to at most maxBytes total bytes, appending
// `ellipsis` when truncation actually happens. If len(s) fits
// within maxBytes, returns s unchanged (no ellipsis added). If
// the ellipsis alone is longer than maxBytes, returns the first
// maxBytes of the ellipsis (still bounded). maxBytes <= 0 → "".
// Byte-level only — does NOT respect UTF-8 boundaries. Useful
// for: "..." in UI strings, log-line clipping.
fun Truncate(s string, maxBytes int, ellipsis string) string {
    if maxBytes <= 0 { ret "" }
    var n int = len(s)
    if n <= maxBytes { ret "" + s }
    var eLen int = len(ellipsis)
    var b *bytes.Builder = bytes.NewBuilder()
    if eLen >= maxBytes {
        var i int = 0
        for i < maxBytes {
            b.WriteByte(ellipsis[i])
            i = i + 1
        }
        ret b.String()
    }
    var prefix int = maxBytes - eLen
    for i := 0; i < prefix; i++ {
        b.WriteByte(s[i])
    }
    b.WriteString(ellipsis)
    ret b.String()
}

// AbbreviateMiddle returns s clipped to at most maxBytes total
// bytes by replacing the middle with `ellipsis`. The remaining
// prefix and suffix of s are kept as balanced as possible (prefix
// gets the extra byte on odd `available = maxBytes - len(ellipsis)`).
// If len(s) fits within maxBytes, returns s unchanged. maxBytes <= 0
// returns "". If ellipsis alone is longer than maxBytes, returns
// the first maxBytes of s (head-truncation fallback). Byte-level
// (no UTF-8 awareness). Useful for path/URL/long-id shortening in
// fixed-width UIs ("/very/long/path/file.txt" → "/very...e.txt").
// AbbreviateLeft clips s to ≤ maxBytes total bytes by prepending
// `ellipsis` and keeping the rightmost portion. Counterpart to
// Truncate (which keeps the leftmost). Useful for path display
// where the leaf matters more than the parent dirs ("/.../bin/cmd").
// maxBytes ≤ 0 returns "". If ellipsis is longer than maxBytes,
// returns the last maxBytes of the ellipsis (tail-only fallback).
fun AbbreviateLeft(s string, maxBytes int, ellipsis string) string {
    if maxBytes <= 0 { ret "" }
    var n int = len(s)
    if n <= maxBytes { ret "" + s }
    var eLen int = len(ellipsis)
    var b *bytes.Builder = bytes.NewBuilder()
    if eLen >= maxBytes {
        for i := eLen - maxBytes; i < eLen; i++ {
            b.WriteByte(ellipsis[i])
        }
        ret b.String()
    }
    var suffix int = maxBytes - eLen
    b.WriteString(ellipsis)
    for i := n - suffix; i < n; i++ {
        b.WriteByte(s[i])
    }
    ret b.String()
}

fun AbbreviateMiddle(s string, maxBytes int, ellipsis string) string {
    if maxBytes <= 0 { ret "" }
    var n int = len(s)
    if n <= maxBytes { ret "" + s }
    var eLen int = len(ellipsis)
    if eLen >= maxBytes {
        var b *bytes.Builder = bytes.NewBuilder()
        for i := 0; i < maxBytes; i++ { b.WriteByte(s[i]) }
        ret b.String()
    }
    var available int = maxBytes - eLen
    var leftLen int = available / 2 + (available % 2)   // prefix gets the extra
    var rightLen int = available - leftLen
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < leftLen; i++ { b.WriteByte(s[i]) }
    b.WriteString(ellipsis)
    for i := n - rightLen; i < n; i++ { b.WriteByte(s[i]) }
    ret b.String()
}

// Pluralize returns word for n == 1 (and n == -1) or word + "s"
// otherwise. Pure English-style and very naive — no special-case
// handling for "child"/"children", "person"/"people", "-y"→"-ies",
// "-s"/"-x"/"-z"→"-es", etc. Use when the noun is known to be
// regular (counts of generic items, log labels). Useful for status
// strings like "5 items", "1 item", "0 items".
fun Pluralize(word string, n int) string {
    if n == 1 { ret "" + word }
    if n == -1 { ret "" + word }
    var b *bytes.Builder = bytes.NewBuilder()
    b.WriteString(word)
    b.WriteByte(115)   // 's'
    ret b.String()
}

// OrdinalSuffix returns the English ordinal suffix for n: "st",
// "nd", "rd", or "th". Negative n uses |n|'s suffix. The teens
// (11..19) all take "th" (so "11th", "12th", "13th"), not "1st",
// "2nd", "3rd". Useful for human-readable rank strings.
fun OrdinalSuffix(n int) string {
    var v int = n
    if v < 0 { v = -v }
    var lastTwo int = v % 100
    if lastTwo >= 11 {
        if lastTwo <= 13 { ret "th" }
    }
    var last int = v % 10
    if last == 1 { ret "st" }
    if last == 2 { ret "nd" }
    if last == 3 { ret "rd" }
    ret "th"
}

// Ordinal returns the English ordinal form of n: "1st", "2nd",
// "3rd", "11th", "21st", "-3rd", etc. Useful for rendering ranks
// (place finishes, paginated displays).
fun Ordinal(n int) string {
    var b *bytes.Builder = bytes.NewBuilder()
    b.WriteString(intDecimalStr(n))
    b.WriteString(OrdinalSuffix(n))
    ret b.String()
}

// ReplaceRune returns a fresh string with every occurrence of rune
// `old` in s replaced by `repl`. Old and repl can be any byte width
// (the substitution may shrink or grow the result). Empty old
// returns s unchanged. Useful for: sanitizing a single character
// (e.g. swap "/" → "_" in path-like keys), substituting an emoji
// for an ASCII placeholder, normalizing punctuation.
fun ReplaceRune(s string, old string, repl string) string {
    var ol int = len(old)
    if ol == 0 { ret "" + s }
    var n int = len(s)
    if n == 0 { ret "" }
    var b *bytes.Builder = bytes.NewBuilder()
    var i int = 0
    for i < n {
        var c int = s[i] & 255
        var step int = 1
        if c >= 192 {
            step = 2
            if c >= 224 { step = 3 }
            if c >= 240 { step = 4 }
        }
        var match bool = false
        if step == ol {
            match = true
            var k int = 0
            for k < ol {
                if s[i + k] != old[k] {
                    match = false
                    break
                }
                k = k + 1
            }
        }
        if match {
            b.WriteString(repl)
        } else {
            var lim int = i + step
            if lim > n { lim = n }
            for j := i; j < lim; j++ {
                b.WriteByte(s[j])
            }
        }
        i = i + step
    }
    ret b.String()
}

// IndexRune returns the 0-based rune-index of the first occurrence
// of rune `r` in s. r is passed as a string (its UTF-8 bytes — pass
// it like "a", "é", "世" etc., or as a hex-escaped literal). Empty
// r returns 0 (matches Go's strings.Index empty-substring rule).
// No match returns -1. Useful for "where is the comma rune?"
// without conflating multi-byte sequences with byte-index search.
fun IndexRune(s string, r string) int {
    var rl int = len(r)
    if rl == 0 { ret 0 }
    var n int = len(s)
    if n == 0 { ret -1 }
    var i int = 0
    var ri int = 0
    for i < n {
        var c int = s[i] & 255
        var step int = 1
        if c >= 192 {
            step = 2
            if c >= 224 { step = 3 }
            if c >= 240 { step = 4 }
        }
        if step == rl {
            var match bool = true
            var k int = 0
            for k < rl {
                if s[i + k] != r[k] {
                    match = false
                    break
                }
                k = k + 1
            }
            if match { ret ri }
        }
        i = i + step
        ri = ri + 1
    }
    ret -1
}

// LastIndexRune returns the 0-based rune-index of the last
// occurrence of `r` in s, or -1 if not found. Empty r returns
// `RuneCount(s)` (matches Go's "end of string" sentinel for
// empty substring). Single linear pass through s tracking the
// most-recent match.
fun LastIndexRune(s string, r string) int {
    var rl int = len(r)
    var n int = len(s)
    if rl == 0 {
        var rc int = 0
        var ii int = 0
        for ii < n {
            var c int = s[ii] & 255
            var step int = 1
            if c >= 192 {
                step = 2
                if c >= 224 { step = 3 }
                if c >= 240 { step = 4 }
            }
            ii = ii + step
            rc = rc + 1
        }
        ret rc
    }
    if n == 0 { ret -1 }
    var last int = -1
    var i int = 0
    var ri int = 0
    for i < n {
        var c int = s[i] & 255
        var step int = 1
        if c >= 192 {
            step = 2
            if c >= 224 { step = 3 }
            if c >= 240 { step = 4 }
        }
        if step == rl {
            var match bool = true
            var k int = 0
            for k < rl {
                if s[i + k] != r[k] {
                    match = false
                    break
                }
                k = k + 1
            }
            if match { last = ri }
        }
        i = i + step
        ri = ri + 1
    }
    ret last
}

// CountRune returns the number of times rune `r` appears in s.
// Empty r returns RuneCount(s) + 1 (matches Go's strings.Count
// behavior for empty substring — number of inter-rune gaps).
// Useful for: how-many-emojis counts, vote-tallying on a single
// rune, validation rules ("exactly one comma").
fun CountRune(s string, r string) int {
    var rl int = len(r)
    var n int = len(s)
    if rl == 0 {
        var rc int = 0
        var ii int = 0
        for ii < n {
            var c int = s[ii] & 255
            var step int = 1
            if c >= 192 {
                step = 2
                if c >= 224 { step = 3 }
                if c >= 240 { step = 4 }
            }
            ii = ii + step
            rc = rc + 1
        }
        ret rc + 1
    }
    var count int = 0
    var i int = 0
    for i < n {
        var c int = s[i] & 255
        var step int = 1
        if c >= 192 {
            step = 2
            if c >= 224 { step = 3 }
            if c >= 240 { step = 4 }
        }
        if step == rl {
            var match bool = true
            var k int = 0
            for k < rl {
                if s[i + k] != r[k] {
                    match = false
                    break
                }
                k = k + 1
            }
            if match { count = count + 1 }
        }
        i = i + step
    }
    ret count
}

// ContainsRune reports whether s contains the rune r anywhere.
// Wraps `IndexRune(s, r) >= 0`.
fun ContainsRune(s string, r string) bool {
    if IndexRune(s, r) >= 0 { ret true }
    ret false
}

// RuneSplit returns a fresh []string with one entry per UTF-8
// code point in s. Empty input returns an empty slice. Two-pass:
// first counts runes (so the result slice is exact-sized), then
// emits each rune's bytes. Useful for: iterating runes via
// for-range when index access is needed, building rune-keyed
// histograms, character-by-character UI rendering.
fun RuneSplit(s string) []string {
    var n int = len(s)
    if n == 0 { ret new(0) []string {} }
    var rc int = 0
    var i int = 0
    for i < n {
        var c int = s[i] & 255
        var step int = 1
        if c >= 192 {
            step = 2
            if c >= 224 { step = 3 }
            if c >= 240 { step = 4 }
        }
        i = i + step
        rc = rc + 1
    }
    var out []string = new(rc) []string {}
    var idx int = 0
    i = 0
    for i < n {
        var c int = s[i] & 255
        var step int = 1
        if c >= 192 {
            step = 2
            if c >= 224 { step = 3 }
            if c >= 240 { step = 4 }
        }
        var lim int = i + step
        if lim > n { lim = n }
        var b *bytes.Builder = bytes.NewBuilder()
        for j := i; j < lim; j++ {
            b.WriteByte(s[j])
        }
        out[idx] = b.String()
        idx = idx + 1
        i = lim
    }
    ret out
}

// RuneIndexFromByte returns the rune index that contains (or
// starts at) the given byte index. byteIdx must point AT the
// start of a rune (i.e. on a lead byte or len(s)); mid-rune
// positions return -1. byteIdx == len(s) returns RuneCount(s).
// Useful for converting back-from-byte-position to rune-position
// after a byte-level operation like Index / IndexByte.
fun RuneIndexFromByte(s string, byteIdx int) int {
    if byteIdx < 0 { ret -1 }
    var n int = len(s)
    if byteIdx > n { ret -1 }
    var i int = 0
    var rc int = 0
    for i < n {
        if i == byteIdx { ret rc }
        var c int = s[i] & 255
        var step int = 1
        if c >= 192 {
            step = 2
            if c >= 224 { step = 3 }
            if c >= 240 { step = 4 }
        }
        if (i + step) > byteIdx { ret -1 }
        i = i + step
        rc = rc + 1
    }
    if i == byteIdx { ret rc }
    ret -1
}

// RuneReverse returns s with rune order reversed. Multi-byte
// UTF-8 sequences stay intact (no mid-rune cuts) — bytes within
// a single code point keep their natural order, only the order
// of code points flips. Empty input returns "". Useful for
// palindrome construction over actual characters, RTL display
// preprocessing on byte buffers.
fun RuneReverse(s string) string {
    var n int = len(s)
    if n == 0 { ret "" }
    var starts []int = new(0) []int {}
    var i int = 0
    for i < n {
        starts = append(starts, i)
        var c int = s[i] & 255
        var step int = 1
        if c >= 192 {
            step = 2
            if c >= 224 { step = 3 }
            if c >= 240 { step = 4 }
        }
        i = i + step
    }
    var b *bytes.Builder = bytes.NewBuilder()
    var ns int = len(starts)
    var k int = ns - 1
    for k >= 0 {
        var rs int = starts[k]
        var re int = n
        if (k + 1) < ns { re = starts[k + 1] }
        for j := rs; j < re; j++ {
            b.WriteByte(s[j])
        }
        k = k - 1
    }
    ret b.String()
}

// ByteIndexRune returns the byte index at which the rune at
// 0-based index `runeIdx` begins. runeIdx == RuneCount(s) returns
// len(s) (one past the last rune — useful for slicing). Out-of-
// range / negative returns -1.
fun ByteIndexRune(s string, runeIdx int) int {
    if runeIdx < 0 { ret -1 }
    var n int = len(s)
    var i int = 0
    var rc int = 0
    for i < n {
        if rc == runeIdx { ret i }
        var c int = s[i] & 255
        var step int = 1
        if c >= 192 {
            step = 2
            if c >= 224 { step = 3 }
            if c >= 240 { step = 4 }
        }
        i = i + step
        rc = rc + 1
    }
    if rc == runeIdx { ret n }
    ret -1
}

// HumanBytes formats a byte count using IEC 1024-based suffixes —
// "B" (under 1024), "KB", "MB", "GB", "TB". Includes ONE decimal
// place when the value isn't a clean multiple of the unit
// boundary ("1.5 KB", "2.3 MB"). Negative inputs are prefixed with
// "-". Useful for file-size displays, memory monitors. Note: uses
// "KB" rather than the strict-IEC "KiB" for readability — most
// shipping software does the same.
fun HumanBytes(n int) string {
    if n < 0 {
        ret "-" + HumanBytes(-n)
    }
    if n < 1024 { ret strconv.Itoa(n) + " B" }
    if n < 1048576 {
        var v int = n / 1024
        var rem int = ((n % 1024) * 10) / 1024
        if rem == 0 { ret strconv.Itoa(v) + " KB" }
        ret strconv.Itoa(v) + "." + strconv.Itoa(rem) + " KB"
    }
    if n < 1073741824 {
        var v int = n / 1048576
        var rem int = ((n % 1048576) * 10) / 1048576
        if rem == 0 { ret strconv.Itoa(v) + " MB" }
        ret strconv.Itoa(v) + "." + strconv.Itoa(rem) + " MB"
    }
    if n < 1099511627776 {
        var v int = n / 1073741824
        var rem int = ((n % 1073741824) * 10) / 1073741824
        if rem == 0 { ret strconv.Itoa(v) + " GB" }
        ret strconv.Itoa(v) + "." + strconv.Itoa(rem) + " GB"
    }
    var v int = n / 1099511627776
    var rem int = ((n % 1099511627776) * 10) / 1099511627776
    if rem == 0 { ret strconv.Itoa(v) + " TB" }
    ret strconv.Itoa(v) + "." + strconv.Itoa(rem) + " TB"
}

// HumanCount returns a human-readable string for an integer count.
// Below 1000 returns the bare decimal. From 1K up to 999K it uses
// "K" with one decimal of precision when the hundreds digit is
// non-zero ("1.5K") and a bare integer when it's zero ("3K"). M
// (millions) and B (billions) tiers follow the same pattern.
// Negative inputs are formatted as "-X..." (sign + suffix-formatted
// magnitude). Useful for UI counters, dashboard badges.
// WithCommas renders n with comma thousand-separators
// (US convention). Negative n keeps the leading '-'. Useful for
// human-readable big integers in reports / logs ("1,234,567").
// Pairs naturally with HumanCount when you want the exact value
// rather than an abbreviated one. O(numdigits(n)).
fun WithCommas(n int) string {
    if n < 0 { ret "-" + WithCommas(-n) }
    var raw string = strconv.Itoa(n)
    var nlen int = len(raw)
    if nlen <= 3 { ret raw }
    var b *bytes.Builder = bytes.NewBuilder()
    var lead int = nlen % 3
    if lead == 0 { lead = 3 }
    for i := 0; i < lead; i++ { b.WriteByte(raw[i]) }
    var i int = lead
    for i < nlen {
        b.WriteByte(44)   // ','
        b.WriteByte(raw[i])
        b.WriteByte(raw[i + 1])
        b.WriteByte(raw[i + 2])
        i = i + 3
    }
    ret b.String()
}

// CommaInt formats `n` with grouping commas every 3 digits from the
// right. Negative inputs preserve the leading "-". 0..999 returns the
// number unchanged. Use case: human-readable numeric display in
// dashboards, logs, terminal UIs where HumanCount's letter suffixes
// (12.3K) are too lossy.
//
//   CommaInt(0)        → "0"
//   CommaInt(1234)     → "1,234"
//   CommaInt(1234567)  → "1,234,567"
//   CommaInt(-50000)   → "-50,000"
fun CommaInt(n int) string {
    if n < 0 {
        ret "-" + CommaInt(-n)
    }
    if n < 1000 { ret strconv.Itoa(n) }
    var digits string = strconv.Itoa(n)
    var dl int = len(digits)
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < dl; i++ {
        if i > 0 {
            // Insert a comma when the remaining digit count from this
            // position to the end is a positive multiple of 3.
            var fromEnd int = dl - i
            if fromEnd % 3 == 0 { b.WriteByte(44) }  // ','
        }
        b.WriteByte(digits[i])
    }
    ret b.String()
}

fun HumanCount(n int) string {
    if n < 0 {
        ret "-" + HumanCount(-n)
    }
    if n < 1000 { ret strconv.Itoa(n) }
    if n < 1000000 {
        var k int = n / 1000
        var rem int = (n % 1000) / 100
        if rem == 0 { ret strconv.Itoa(k) + "K" }
        ret strconv.Itoa(k) + "." + strconv.Itoa(rem) + "K"
    }
    if n < 1000000000 {
        var m int = n / 1000000
        var rem int = (n % 1000000) / 100000
        if rem == 0 { ret strconv.Itoa(m) + "M" }
        ret strconv.Itoa(m) + "." + strconv.Itoa(rem) + "M"
    }
    var b int = n / 1000000000
    var rem int = (n % 1000000000) / 100000000
    if rem == 0 { ret strconv.Itoa(b) + "B" }
    ret strconv.Itoa(b) + "." + strconv.Itoa(rem) + "B"
}

// RuneSlice returns the substring of s spanning runes [lo, hi)
// (half-open, like Go slicing). Out-of-range indices are clamped:
// lo < 0 becomes 0; hi past end stops at end-of-string. hi <= lo
// Slice returns the substring s[lo:hi] by BYTE index, with bounds
// clamping: lo < 0 becomes 0, hi > len(s) becomes len(s), hi < lo
// returns "". The natural primitive for substring extraction by
// byte position — volt doesn't have slice syntax for strings, so
// this fills the gap. NOT UTF-8 boundary-safe (use RuneSlice for
// rune-aware semantics); use this when you already know the byte
// offsets (e.g. from Index / IndexAfter / Cut output).
fun Slice(s string, lo int, hi int) string {
    var n int = len(s)
    if lo < 0 { lo = 0 }
    if hi > n { hi = n }
    if hi <= lo { ret "" }
    var b *bytes.Builder = bytes.NewBuilder()
    for i := lo; i < hi; i++ {
        b.WriteByte(s[i])
    }
    ret b.String()
}

// Left returns the first n bytes of s. n <= 0 returns ""; n >=
// len(s) returns s unchanged. Saves the `Slice(s, 0, n)` ceremony
// at call sites (common shortcut for "take prefix"). Byte-counted,
// not rune-counted — for rune-aware truncation use RuneSlice.
fun Left(s string, n int) string {
    if n <= 0 { ret "" }
    var sn int = len(s)
    if n >= sn { ret "" + s }
    ret Slice(s, 0, n)
}

// Right returns the last n bytes of s. n <= 0 returns ""; n >=
// len(s) returns s unchanged. Saves `Slice(s, len(s)-n, len(s))`.
// Byte-counted; use RuneSlice for rune-aware tails.
fun Right(s string, n int) string {
    if n <= 0 { ret "" }
    var sn int = len(s)
    if n >= sn { ret "" + s }
    ret Slice(s, sn - n, sn)
}

// returns "". UTF-8 boundary-safe — single rune-walking pass, so
// O(byteLen) regardless of rune width.
fun RuneSlice(s string, lo int, hi int) string {
    var n int = len(s)
    if n == 0 { ret "" }
    var loFix int = lo
    if loFix < 0 { loFix = 0 }
    if hi <= loFix { ret "" }
    var runeCount int = 0
    var bytePos int = 0
    var startByte int = -1
    var endByte int = -1
    for bytePos < n {
        if runeCount == loFix {
            if startByte < 0 { startByte = bytePos }
        }
        if runeCount == hi {
            endByte = bytePos
            break
        }
        var c int = s[bytePos] & 255
        var step int = 1
        if c >= 192 {
            step = 2
            if c >= 224 { step = 3 }
            if c >= 240 { step = 4 }
        }
        bytePos = bytePos + step
        runeCount = runeCount + 1
    }
    if startByte < 0 { ret "" }
    if endByte < 0 { endByte = n }
    var b *bytes.Builder = bytes.NewBuilder()
    for i := startByte; i < endByte; i++ {
        b.WriteByte(s[i])
    }
    ret b.String()
}

// TruncateRunes is the UTF-8-boundary-respecting counterpart to
// Truncate. Clamps s to at most maxRunes UTF-8 code points and
// appends `ellipsis` if truncation occurred. The ellipsis is not
// counted in maxRunes (matches common UI semantics where the
// content budget is the "real" text). maxRunes <= 0 → "".
fun TruncateRunes(s string, maxRunes int, ellipsis string) string {
    if maxRunes <= 0 { ret "" }
    var n int = len(s)
    var runeCount int = 0
    var bytePos int = 0
    for bytePos < n {
        if runeCount == maxRunes { break }
        var c int = s[bytePos] & 255
        var step int = 1
        if c >= 192 {
            step = 2
            if c >= 224 { step = 3 }
            if c >= 240 { step = 4 }
        }
        bytePos = bytePos + step
        runeCount = runeCount + 1
    }
    if bytePos >= n { ret "" + s }
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < bytePos; i++ {
        b.WriteByte(s[i])
    }
    b.WriteString(ellipsis)
    ret b.String()
}

// RuneAt returns the rune at 0-based index idx as a fresh string.
// Out-of-range idx (negative or >= rune count) returns "". Useful
// for: nth-character extraction in tokenizers, indexed access
// without materializing the full rune slice.
fun RuneAt(s string, idx int) string {
    if idx < 0 { ret "" }
    var n int = len(s)
    var runeCount int = 0
    var i int = 0
    for i < n {
        var c int = s[i] & 255
        var step int = 1
        if c >= 192 {
            step = 2
            if c >= 224 { step = 3 }
            if c >= 240 { step = 4 }
        }
        if runeCount == idx {
            var lim int = i + step
            if lim > n { lim = n }
            var b *bytes.Builder = bytes.NewBuilder()
            for j := i; j < lim; j++ {
                b.WriteByte(s[j])
            }
            ret b.String()
        }
        i = i + step
        runeCount = runeCount + 1
    }
    ret ""
}

// FirstRune returns the first UTF-8 rune of s as a fresh string,
// or "" for empty input. If the leading byte advertises a length
// that extends past end-of-s, returns whatever is available.
fun FirstRune(s string) string {
    var n int = len(s)
    if n == 0 { ret "" }
    var c int = s[0] & 255
    var step int = 1
    if c >= 192 {
        step = 2
        if c >= 224 { step = 3 }
        if c >= 240 { step = 4 }
    }
    if step > n { step = n }
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < step; i++ {
        b.WriteByte(s[i])
    }
    ret b.String()
}

// LastRune returns the last UTF-8 rune of s as a fresh string.
// Walks backward past continuation bytes (10xxxxxx) to find a
// lead byte. Useful for trailing-character checks in tokenizers.
fun LastRune(s string) string {
    var n int = len(s)
    if n == 0 { ret "" }
    var i int = n - 1
    for i > 0 {
        var c int = s[i] & 255
        if c < 128 { break }
        if c >= 192 { break }
        i = i - 1
    }
    var b *bytes.Builder = bytes.NewBuilder()
    for j := i; j < n; j++ {
        b.WriteByte(s[j])
    }
    ret b.String()
}

// IsValidUtf8 reports whether s is a well-formed UTF-8 byte
// sequence. Empty returns true. Verifies leading-byte / trailing-
// byte structure but does NOT reject over-long encodings or
// surrogate-range code points (the simple-byte check most callers
// actually want for "decode-safe?"). Useful as a precondition
// before passing strings to APIs that assume valid UTF-8.
fun IsValidUtf8(s string) bool {
    var n int = len(s)
    var i int = 0
    for i < n {
        var c int = s[i] & 255           // widen unsigned
        if c < 128 {
            i = i + 1
            continue
        }
        if c >= 248 { ret false }
        var need int = 0
        if c >= 240 { need = 3 }
        if c >= 224 {
            if c < 240 { need = 2 }
        }
        if c >= 192 {
            if c < 224 { need = 1 }
        }
        if need == 0 { ret false }
        if (i + need) >= n { ret false }
        var k int = 1
        for k <= need {
            var nc int = s[i + k] & 255
            if nc < 128 { ret false }
            if nc >= 192 { ret false }
            k = k + 1
        }
        i = i + 1 + need
    }
    ret true
}

// RuneCount returns the number of UTF-8 code points (runes) in s.
// For ASCII this equals len(s); for multi-byte sequences each
// leading byte starts one rune (continuation bytes are skipped
// via the step jump). Does NOT validate well-formedness — call
// IsValidUtf8 first if you need that guarantee.
fun RuneCount(s string) int {
    var n int = len(s)
    var count int = 0
    var i int = 0
    for i < n {
        var c int = s[i] & 255           // widen unsigned to avoid sign-extension
        var step int = 1
        if c >= 192 {
            step = 2
            if c >= 224 { step = 3 }
            if c >= 240 { step = 4 }
        }
        i = i + step
        count = count + 1
    }
    ret count
}

// IsAscii reports whether every byte of s is in the 7-bit ASCII
// range [0, 127]. Empty string returns true (no non-ASCII bytes).
// Useful for input validation before passing strings to APIs that
// only accept ASCII (legacy file formats, some network protocols).
fun IsAscii(s string) bool {
    var n int = len(s)
    for i := 0; i < n; i++ {
        if (s[i] & 255) > 127 { ret false }
    }
    ret true
}

// IsBlank reports whether s contains only whitespace bytes
// (' ' / '\t' / '\n' / '\r' / '\v' / '\f'). Empty string returns
// true (no non-whitespace bytes). Uses the same `isWhitespace`
// classifier as Fields/TrimFunc.
fun IsBlank(s string) bool {
    var n int = len(s)
    for i := 0; i < n; i++ {
        if !isWhitespace(s[i]) { ret false }
    }
    ret true
}

// IsAsciiPrintable reports whether every byte of s is in the
// printable-ASCII range 0x20..0x7E (space through `~`). Empty
// string returns true (vacuous). Control characters (incl. `\n`,
// `\t`) and DEL (0x7F) FAIL the check — distinct from `IsAscii`
// which accepts the full 0x00..0x7F range. Useful for "can this be
// displayed in a terminal / log line without escapes?" checks.
fun IsAsciiPrintable(s string) bool {
    var n int = len(s)
    for i := 0; i < n; i++ {
        var c int = s[i] & 255
        if c < 32 { ret false }
        if c > 126 { ret false }
    }
    ret true
}

// CountByte returns the number of times byte c appears in s.
// Equivalent to `Count(s, string(c))` but avoids the substring-build
// path and runs in a single linear pass.
fun CountByte(s string, c byte) int {
    var n int = len(s)
    var k int = 0
    for i := 0; i < n; i++ {
        if s[i] == c { k = k + 1 }
    }
    ret k
}

// CountFunc returns the number of bytes in s for which pred returns
// true. Predicate-driven counterpart to CountByte / CountAny — same
// linear scan, but the membership test is supplied by the caller.
// Pairs naturally with IndexFunc / LastIndexFunc / TrimFunc, all of
// which already exist. Empty s returns 0. Useful for ad-hoc tallies
// (digits, uppercase letters, vowels, custom-class bytes) where
// pre-building a chars-set string is overkill.
fun CountFunc(s string, pred fun(byte) bool) int {
    var n int = len(s)
    var k int = 0
    for i := 0; i < n; i++ {
        if pred(s[i]) { k = k + 1 }
    }
    ret k
}

// HasOnly reports whether every byte of s appears in the chars set
// (i.e. s is drawn only from the alphabet defined by chars). Empty
// s returns true (vacuous truth). Empty chars + non-empty s
// returns false (no allowed bytes). O(len(s) + len(chars)) via a
// 256-byte membership lookup. Useful for whitelist validation —
// "is this string drawn only from my allowed alphabet?" guards.
fun HasOnly(s string, chars string) bool {
    var n int = len(s)
    if n == 0 { ret true }
    if len(chars) == 0 { ret false }
    var member []bool = new(256) []bool {}
    var cn int = len(chars)
    for i := 0; i < cn; i++ {
        var c int = chars[i] & 255
        member[c] = true
    }
    for i := 0; i < n; i++ {
        var c int = s[i] & 255
        if !member[c] { ret false }
    }
    ret true
}

// HasNone reports whether no byte of s appears in the chars set
// (i.e. s is free of every byte in the blacklist). Blacklist
// counterpart to HasOnly: empty s returns true (vacuous); empty
// chars returns true (nothing forbidden). O(len(s) + len(chars))
// via a 256-byte membership lookup. Useful for "this string
// contains no forbidden bytes" guards — control-char sanitizers,
// log-injection screens, etc.
fun HasNone(s string, chars string) bool {
    var n int = len(s)
    if n == 0 { ret true }
    var cn int = len(chars)
    if cn == 0 { ret true }
    var member []bool = new(256) []bool {}
    for i := 0; i < cn; i++ {
        var c int = chars[i] & 255
        member[c] = true
    }
    for i := 0; i < n; i++ {
        var c int = s[i] & 255
        if member[c] { ret false }
    }
    ret true
}

// CountAny returns the total number of bytes in s that match ANY
// byte in chars. Single pass with a 256-byte membership lookup —
// O(len(s) + len(chars)) rather than the O(len(s) * len(chars))
// of a naive inner-loop scan. Empty chars returns 0. Useful for
// tallying multiple characters at once (e.g. vowel count, total
// punctuation count, total whitespace count).
fun CountAny(s string, chars string) int {
    if len(chars) == 0 { ret 0 }
    var member []bool = new(256) []bool {}
    var cn int = len(chars)
    for i := 0; i < cn; i++ {
        var c int = chars[i] & 255
        member[c] = true
    }
    var n int = len(s)
    var k int = 0
    for i := 0; i < n; i++ {
        var c int = s[i] & 255
        if member[c] { k = k + 1 }
    }
    ret k
}

// Center returns s symmetrically padded with byte c so the total
// byte length is at least n. If len(s) >= n, returns s unchanged.
// When the padding is odd, the EXTRA byte goes on the right (matches
// Python's str.center). Useful for fixed-width column headers.
fun Center(s string, n int, c byte) string {
    var sn int = len(s)
    if sn >= n { ret s }
    var total int = n - sn
    var left int = total / 2
    var right int = total - left
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < left; i++ {
        b.WriteByte(c)
    }
    b.WriteString(s)
    for i := 0; i < right; i++ {
        b.WriteByte(c)
    }
    ret b.String()
}

// RepeatRune returns a string built by repeating UTF-8 rune `r`
// `n` times. Returns "" for n <= 0 or empty r. Useful for: ASCII/
// Unicode-aware padding ("⋆⋆⋆"), divider lines with custom
// chars, spinner frames.
fun RepeatRune(r string, n int) string {
    if n <= 0 { ret "" }
    if len(r) == 0 { ret "" }
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < n; i++ {
        b.WriteString("" + r)
    }
    ret b.String()
}

// Repeat returns a string built by repeating s n times. Returns ""
// for n <= 0.
fun Repeat(s string, n int) string {
    if n <= 0 { ret "" }
    var b *bytes.Builder = bytes.NewBuilder()
    for i:=0; i < n; i++ {
        b.WriteString("" + s)
    }
    ret b.String()
}

// RepeatTo returns the prefix of `Repeat(s, ⌈totalLen/len(s)⌉)`
// truncated to exactly `totalLen` bytes. Useful for "fill to N
// characters with this pattern" — e.g. progress bars (`RepeatTo("█",
// 10)` yields a 10-byte bar; `RepeatTo("abc", 7)` yields "abcabca"),
// banner separators, hatching patterns. Empty s or totalLen <= 0
// returns "". For exact n-copies use Repeat.
fun RepeatTo(s string, totalLen int) string {
    if totalLen <= 0 { ret "" }
    var ls int = len(s)
    if ls == 0 { ret "" }
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < totalLen; i++ {
        b.WriteByte(s[i % ls])
    }
    ret b.String()
}

// ReplaceFirst returns s with only the FIRST occurrence of old
// replaced by repl. If old is empty or doesn't appear, returns s
// unchanged. Useful when the caller wants surgical edits without
// the all-occurrences semantics of `Replace`. Equivalent to
// `ReplaceN(s, old, repl, 1)` but slightly faster on early-match.
fun ReplaceFirst(s string, old string, repl string) string {
    var lold int = len(old)
    if lold == 0 { ret s }
    var idx int = Index(s, old)
    if idx < 0 { ret s }
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < idx; i++ {
        b.WriteByte(s[i])
    }
    b.WriteString("" + repl)
    var n int = len(s)
    for i := idx + lold; i < n; i++ {
        b.WriteByte(s[i])
    }
    ret b.String()
}

// ReplaceN returns s with up to the first n occurrences of old
// replaced by repl. n < 0 replaces all (matches Go's strings.Replace
// with n = -1). n == 0 returns s unchanged. Empty old returns s.
fun ReplaceN(s string, old string, repl string, n int) string {
    var lold int = len(old)
    if lold == 0 { ret s }
    if n == 0 { ret s }
    var nMax int = n
    if n < 0 { nMax = -1 }   // sentinel: unlimited
    var ls int = len(s)
    var b *bytes.Builder = bytes.NewBuilder()
    var i int = 0
    var replaced int = 0
    var last int = ls - lold
    for i <= last {
        var match bool = true
        for j := 0; j < lold; j++ {
            if s[i + j] != old[j] { match = false; break }
        }
        var canReplace bool = false
        if nMax < 0 { canReplace = true }
        if nMax > 0 {
            if replaced < nMax { canReplace = true }
        }
        if match {
            if canReplace {
                b.WriteString("" + repl)
                i = i + lold
                replaced = replaced + 1
                continue
            }
        }
        b.WriteByte(s[i])
        i = i + 1
    }
    for i < ls {
        b.WriteByte(s[i])
        i = i + 1
    }
    ret b.String()
}

// TrimPrefix returns s with prefix removed from its start, or s
// unchanged if it doesn't start with prefix.
fun TrimPrefix(s string, prefix string) string {
    if !HasPrefix(s, prefix) { ret s }
    var lp int = len(prefix)
    var ls int = len(s)
    var b *bytes.Builder = bytes.NewBuilder()
    for i:=lp; i < ls; i++ {
        b.WriteByte(s[i])
    }
    ret b.String()
}

// TrimSuffix returns s with suffix removed from its end, or s
// unchanged if it doesn't end with suffix.
fun TrimSuffix(s string, suffix string) string {
    if !HasSuffix(s, suffix) { ret s }
    var lend int = len(s) - len(suffix)
    var b *bytes.Builder = bytes.NewBuilder()
    for i:=0; i < lend; i++ {
        b.WriteByte(s[i])
    }
    ret b.String()
}

// TrimNewline returns s with a single trailing newline removed —
// strips `\r\n`, `\n`, or `\r` (in that priority order), or s
// unchanged otherwise. Idempotent: trailing-double-newline becomes
// trailing-single-newline (only ONE line ending is removed). Useful
// for normalizing line input from file / network reads where the
// terminator is sometimes present and sometimes not. Perl's `chomp`
// in spirit.
fun TrimNewline(s string) string {
    var n int = len(s)
    if n == 0 { ret s }
    if n >= 2 {
        if s[n-2] == 13 {
            if s[n-1] == 10 {
                var b *bytes.Builder = bytes.NewBuilder()
                for i := 0; i < n - 2; i++ { b.WriteByte(s[i]) }
                ret b.String()
            }
        }
    }
    if s[n-1] == 10 {
        var b *bytes.Builder = bytes.NewBuilder()
        for i := 0; i < n - 1; i++ { b.WriteByte(s[i]) }
        ret b.String()
    }
    if s[n-1] == 13 {
        var b *bytes.Builder = bytes.NewBuilder()
        for i := 0; i < n - 1; i++ { b.WriteByte(s[i]) }
        ret b.String()
    }
    ret s
}

// EnsurePrefix returns s unchanged if it already starts with
// prefix; otherwise returns prefix + s. Idempotent counterpart to
// TrimPrefix — combining the two yields the original. Useful for
// normalizing URLs (`EnsurePrefix(url, "https://")`), making sure
// a path starts with `/`, or any "add header iff missing" need.
fun EnsurePrefix(s string, prefix string) string {
    if HasPrefix(s, prefix) { ret "" + s }
    var b *bytes.Builder = bytes.NewBuilder()
    b.WriteString(prefix)
    b.WriteString(s)
    ret b.String()
}

// EnsureSuffix returns s unchanged if it already ends with suffix;
// otherwise returns s + suffix. Counterpart to TrimSuffix. Useful
// for "always end paths with `/`", "make sure filename ends in
// `.txt`", or trailing-newline-on-output style normalizations.
fun EnsureSuffix(s string, suffix string) string {
    if HasSuffix(s, suffix) { ret "" + s }
    var b *bytes.Builder = bytes.NewBuilder()
    b.WriteString(s)
    b.WriteString(suffix)
    ret b.String()
}

// Bracket returns `open + s + close` — wraps s in matching brackets
// without any quoting / escaping. Useful for display formatting like
// `[item]`, `(arg)`, `{ obj }`, `<tag>`, and CLI-style optional-arg
// notation. For string-literal-quoting, use strconv.Quote.
fun Bracket(s string, open string, close string) string {
    var b *bytes.Builder = bytes.NewBuilder()
    b.WriteString(open)
    b.WriteString(s)
    b.WriteString(close)
    ret b.String()
}

// Surround returns `wrap + s + wrap` — uses the same string on both
// sides. Convenience for symmetric wrapping like backticks, quotes,
// or asterisks. `Surround(s, "*")` for emphasis, `Surround(s, "\"")`
// for inline quoting (without escape processing — use strconv.Quote
// for Go-syntax escaped quoting).
fun Surround(s string, wrap string) string {
    ret Bracket(s, wrap, wrap)
}

// LastIndex returns the largest position at which sub starts in s,
// or -1 if absent. Empty sub returns len(s) per Go's convention.
fun LastIndex(s string, sub string) int {
    var ls int = len(s)
    var lsub int = len(sub)
    if lsub == 0 { ret ls }
    if lsub > ls { ret -1 }
    var i int = ls - lsub
    for i >= 0 {
        var match bool = true
        for j:=0; j < lsub; j++ {
            if s[i + j] != sub[j] {
                match = false
                break
            }
        }
        if match { ret i }
        i = i - 1
    }
    ret -1
}

// IndexAny returns the first position in s where any byte from
// chars appears, or -1 if none do. Empty chars returns -1.
fun IndexAny(s string, chars string) int {
    if len(chars) == 0 { ret -1 }
    var n int = len(s)
    for i:=0; i < n; i++ {
        if containsByte(chars, s[i]) { ret i }
    }
    ret -1
}

// LastIndexAny returns the last position in s where any byte from
// chars appears, or -1 if none do. Empty chars or empty s returns -1.
// Useful for "find rightmost punctuation / separator / control byte".
fun LastIndexAny(s string, chars string) int {
    if len(chars) == 0 { ret -1 }
    var n int = len(s)
    for i := n - 1; i >= 0; i-- {
        if containsByte(chars, s[i]) { ret i }
    }
    ret -1
}

// SplitN behaves like Split but caps the result at n parts:
//   n < 0  → no cap (same as Split)
//   n == 0 → empty slice
//   n > 0  → at most n parts; the last part contains the unsplit
//            remainder of s (including any further sep occurrences).
fun SplitN(s string, sep string, n int) []string {
    if n == 0 {
        var empty []string = new(0) []string{}
        ret empty
    }
    if n < 0 { ret Split(s, sep) }
    if len(sep) == 0 {
        var single []string = new(1) []string{}
        single[0] = "" + s
        ret single
    }
    var out []string = new(n) []string{}
    var idx int = 0
    var lsep int = len(sep)
    var ls int = len(s)
    var startPos int = 0
    var i int = 0
    var last int = ls - lsep
    for i <= last {
        if idx == n - 1 { break }
        var match bool = true
        for j:=0; j < lsep; j++ {
            if s[i + j] != sep[j] {
                match = false
                break
            }
        }
        if match {
            var pb *bytes.Builder = bytes.NewBuilder()
            for k:=startPos; k < i; k++ {
                pb.WriteByte(s[k])
            }
            out[idx] = pb.String()
            idx = idx + 1
            i = i + lsep
            startPos = i
        } else {
            i = i + 1
        }
    }
    // Remainder from startPos to end of s.
    var tb *bytes.Builder = bytes.NewBuilder()
    for k:=startPos; k < ls; k++ {
        tb.WriteByte(s[k])
    }
    out[idx] = tb.String()
    idx = idx + 1
    // Trim to actual length used.
    if idx == n { ret out }
    var fitted []string = new(idx) []string{}
    for i2:=0; i2 < idx; i2++ {
        fitted[i2] = out[i2]
    }
    ret fitted
}

// EqualFold reports whether s and t are equal under ASCII case-
// folding (case-insensitive compare). Non-ASCII bytes compare
// literally.
fun EqualFold(s string, t string) bool {
    var n int = len(s)
    if len(t) != n { ret false }
    for i:=0; i < n; i++ {
        var a int = s[i] & 255
        var b int = t[i] & 255
        if a >= 65 { if a <= 90 { a = a + 32 } }
        if b >= 65 { if b <= 90 { b = b + 32 } }
        if a != b { ret false }
    }
    ret true
}

// containsByte reports whether s contains the byte b.
fun containsByte(s string, b byte) bool {
    var n int = len(s)
    for i:=0; i < n; i++ {
        if s[i] == b { ret true }
    }
    ret false
}

// TrimLeft returns s with all leading bytes that appear in cutset
// removed. An empty cutset returns s unchanged.
fun TrimLeft(s string, cutset string) string {
    if len(cutset) == 0 { ret s }
    var n int = len(s)
    var lo int = 0
    for lo < n {
        if !containsByte(cutset, s[lo]) { break }
        lo = lo + 1
    }
    var b *bytes.Builder = bytes.NewBuilder()
    for i := lo; i < n; i++ {
        b.WriteByte(s[i])
    }
    ret b.String()
}

// TrimRight returns s with all trailing bytes that appear in
// cutset removed. An empty cutset returns s unchanged.
fun TrimRight(s string, cutset string) string {
    if len(cutset) == 0 { ret s }
    var n int = len(s)
    var hi int = n
    for hi > 0 {
        if !containsByte(cutset, s[hi - 1]) { break }
        hi = hi - 1
    }
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < hi; i++ {
        b.WriteByte(s[i])
    }
    ret b.String()
}

// Translate returns s with every byte that appears in `from`
// replaced by the byte at the corresponding position in `to`. If
// `from` is longer than `to`, the extra bytes are deleted instead
// (analogous to unix `tr -d`). If `from` and `to` are both empty,
// returns s unchanged. Useful for charset remapping (rot13-like
// substitutions, encoding-table reapplication, character-class
// canonicalization).
fun Translate(s string, from string, to string) string {
    if len(from) == 0 { ret "" + s }
    var nt int = len(to)
    var n int = len(s)
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < n; i++ {
        var c byte = s[i]
        var idx int = IndexByte(from, c)
        if idx < 0 {
            b.WriteByte(c)
            continue
        }
        if idx >= nt { continue }   // delete (no corresponding target byte)
        b.WriteByte(to[idx])
    }
    ret b.String()
}

// RemoveChars returns s with every byte that appears in `chars`
// removed (interior bytes too, not just edges — distinct from
// `Trim` which only strips ends). Empty `chars` returns s unchanged.
// Useful for filtering disallowed bytes (e.g. stripping every
// non-alphanumeric byte by pre-building the cutset).
fun RemoveChars(s string, chars string) string {
    if len(chars) == 0 { ret "" + s }
    var n int = len(s)
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < n; i++ {
        if containsByte(chars, s[i]) { continue }
        b.WriteByte(s[i])
    }
    ret b.String()
}

// KeepOnly returns s with every byte that does NOT appear in
// `chars` removed (i.e. the whitelist counterpart to RemoveChars).
// Empty chars returns "" (nothing is allowed). O(len(s) +
// len(chars)) via a 256-byte membership lookup. Useful for
// whitelist filtering — "drop everything except my allowed
// alphabet" passes (digits-only, alpha-only, hex-only, etc.).
fun KeepOnly(s string, chars string) string {
    if len(chars) == 0 { ret "" }
    var n int = len(s)
    if n == 0 { ret "" }
    var member []bool = new(256) []bool {}
    var cn int = len(chars)
    for i := 0; i < cn; i++ {
        var c int = chars[i] & 255
        member[c] = true
    }
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < n; i++ {
        var c int = s[i] & 255
        if member[c] { b.WriteByte(s[i]) }
    }
    ret b.String()
}

// Trim returns s with all leading and trailing bytes that appear in
// cutset removed. An empty cutset returns s unchanged.
fun Trim(s string, cutset string) string {
    if len(cutset) == 0 { ret s }
    var n int = len(s)
    var lo int = 0
    for lo < n {
        if !containsByte(cutset, s[lo]) { break }
        lo = lo + 1
    }
    var hi int = n
    for hi > lo {
        if !containsByte(cutset, s[hi - 1]) { break }
        hi = hi - 1
    }
    var b *bytes.Builder = bytes.NewBuilder()
    for i:=lo; i < hi; i++ {
        b.WriteByte(s[i])
    }
    ret b.String()
}

// isWhitespace reports whether b is a Go-style whitespace byte
// (space, tab, newline, carriage return, vertical tab, form feed).
fun isWhitespace(b byte) bool {
    if b == 32 { ret true }   // ' '
    if b == 9 { ret true }    // '\t'
    if b == 10 { ret true }   // '\n'
    if b == 13 { ret true }   // '\r'
    if b == 11 { ret true }   // '\v'
    if b == 12 { ret true }   // '\f'
    ret false
}

// Fields splits s around each instance of one or more consecutive
// whitespace bytes (Go-style: space, tab, newline, CR, VT, FF). Empty
// or all-whitespace input returns an empty slice. Adjacent whitespace
// runs collapse — Fields never returns empty pieces.
// WordCount returns the number of whitespace-separated tokens in s.
// Same semantics as `len(Fields(s))` but without allocating the
// slice — walks bytes once counting transitions from whitespace
// into non-whitespace. Empty / all-whitespace input returns 0.
// Useful for log/UI counters where the parsed pieces aren't needed.
fun WordCount(s string) int {
    var n int = len(s)
    var count int = 0
    var inWord bool = false
    for i := 0; i < n; i++ {
        if isWhitespace(s[i]) {
            inWord = false
        } else {
            if !inWord {
                count = count + 1
                inWord = true
            }
        }
    }
    ret count
}

// LineCol returns the 1-based (line, column) position of a byte
// index in s. Newlines (`\n`) advance the line and reset col to 1;
// the byte AT the newline reports as belonging to the line that
// ends with it. Out-of-range `byteIdx` clamps: negative → (1, 1);
// past `len(s)` → position of the implicit end-of-input. Useful
// for lexer / parser error messages that say
// "syntax error at line 7, col 23". O(byteIdx) — for repeated
// queries on the same string consider building a line-start index.
fun LineCol(s string, byteIdx int) (int, int) {
    var line int = 1
    var col int = 1
    var n int = len(s)
    if byteIdx < 0 { byteIdx = 0 }
    if byteIdx > n { byteIdx = n }
    for i := 0; i < byteIdx; i++ {
        if s[i] == 10 {
            line = line + 1
            col = 1
        } else {
            col = col + 1
        }
    }
    ret line, col
}

// LineSpan returns the byte-range `[lo, hi)` of the line containing
// `byteIdx` in s. `lo` points at the first byte of the line (right
// after the previous `\n`, or 0); `hi` points one past the last byte
// (at the next `\n`, or len(s)). The trailing `\n` itself is NOT
// included in the range. Useful for excerpting the offending line
// in lexer / parser error messages: `Slice(s, lo, hi)` gives you
// "    bad := x + ?" context to display under the caret.
// Out-of-range `byteIdx` clamps to [0, len(s)]. Empty s → (0, 0).
fun LineSpan(s string, byteIdx int) (int, int) {
    var n int = len(s)
    if byteIdx < 0 { byteIdx = 0 }
    if byteIdx > n { byteIdx = n }
    var lo int = byteIdx
    for lo > 0 {
        if s[lo - 1] == 10 { break }
        lo = lo - 1
    }
    var hi int = byteIdx
    for hi < n {
        if s[hi] == 10 { break }
        hi = hi + 1
    }
    ret lo, hi
}

// NumLines returns the number of lines in s. A line is any run of
// non-`\n` bytes ending with `\n` or at end-of-input. Empty string
// returns 0. Trailing newline doesn't add a phantom empty line:
// `"abc\n"` → 1, `"abc\ndef"` → 2, `"abc\ndef\n"` → 2, `"\n"` → 1,
// `"\n\n"` → 2. CR-only line endings are not split. Useful for
// log/script line-count stats without allocating the per-line slice.
fun NumLines(s string) int {
    var n int = len(s)
    if n == 0 { ret 0 }
    var count int = 0
    var inLine bool = false
    for i := 0; i < n; i++ {
        if s[i] == 10 {
            count = count + 1
            inLine = false
        } else {
            inLine = true
        }
    }
    if inLine { count = count + 1 }
    ret count
}

fun Fields(s string) []string {
    var n int = len(s)
    // First pass: count fields.
    var count int = 0
    var inField bool = false
    for i := 0; i < n; i++ {
        if isWhitespace(s[i]) {
            inField = false
        } else {
            if !inField {
                count = count + 1
                inField = true
            }
        }
    }
    if count == 0 {
        var empty []string = new(0) []string{}
        ret empty
    }
    // Second pass: collect.
    var out []string = new(count) []string{}
    var idx int = 0
    var start int = 0
    inField = false
    for i := 0; i < n; i++ {
        if isWhitespace(s[i]) {
            if inField {
                var b *bytes.Builder = bytes.NewBuilder()
                for j := start; j < i; j++ {
                    b.WriteByte(s[j])
                }
                out[idx] = b.String()
                idx = idx + 1
                inField = false
            }
        } else {
            if !inField {
                start = i
                inField = true
            }
        }
    }
    if inField {
        var b *bytes.Builder = bytes.NewBuilder()
        for j := start; j < n; j++ {
            b.WriteByte(s[j])
        }
        out[idx] = b.String()
    }
    ret out
}

// FieldsFunc splits s into substrings at every byte where fn returns
// true. Runs of separator bytes are collapsed (no empty pieces in
// the result), matching the semantics of Fields() generalized to an
// arbitrary predicate. Empty input or all-separator input returns
// an empty slice. The complement to TrimFunc / IndexFunc — useful
// NthField returns the n-th whitespace-separated field of s
// (0-indexed; awk `$1` is `NthField(s, 0)`). Out-of-range n
// returns "". Mirrors awk-style field access without materializing
// the full Fields slice (saves one alloc when only one field is
// needed). Same whitespace definition as Fields: runs of
// space/tab/newline/CR/VT/FF collapse.
fun NthField(s string, n int) string {
    if n < 0 { ret "" }
    var ns int = len(s)
    var start int = -1
    var idx int = 0
    for i := 0; i < ns; i++ {
        var c byte = s[i]
        var ws bool = false
        if c == 32 { ws = true }
        if c == 9 { ws = true }
        if c == 10 { ws = true }
        if c == 13 { ws = true }
        if c == 11 { ws = true }
        if c == 12 { ws = true }
        if !ws {
            if start < 0 { start = i }
        } else {
            if start >= 0 {
                if idx == n {
                    var b *bytes.Builder = bytes.NewBuilder()
                    for k := start; k < i; k++ { b.WriteByte(s[k]) }
                    ret b.String()
                }
                idx = idx + 1
                start = -1
            }
        }
    }
    if start >= 0 {
        if idx == n {
            var b *bytes.Builder = bytes.NewBuilder()
            for k := start; k < ns; k++ { b.WriteByte(s[k]) }
            ret b.String()
        }
    }
    ret ""
}

// NthFieldSep returns the n-th field of s after splitting on the
// literal byte sep (0-indexed). Adjacent separators yield empty
// fields ("a,,b" with sep=',' → ["a", "", "b"]). Use this when you
// need awk-style field access on a custom delimiter (CSV, log fields).
// Out-of-range n returns "". Empty s returns "" (or "" for n==0
// because the single field is "").
fun NthFieldSep(s string, sep byte, n int) string {
    if n < 0 { ret "" }
    var ns int = len(s)
    var start int = 0
    var idx int = 0
    for i := 0; i < ns; i++ {
        if s[i] == sep {
            if idx == n {
                var b *bytes.Builder = bytes.NewBuilder()
                for k := start; k < i; k++ { b.WriteByte(s[k]) }
                ret b.String()
            }
            idx = idx + 1
            start = i + 1
        }
    }
    if idx == n {
        var b *bytes.Builder = bytes.NewBuilder()
        for k := start; k < ns; k++ { b.WriteByte(s[k]) }
        ret b.String()
    }
    ret ""
}

// for splitting on multi-set separators (any-of-`,;:|`), splitting
// at digit / non-digit boundaries, or any predicate composed at the
// call site.
// FieldsAny splits s into non-empty fields separated by any byte in
// `separators`. Multiple consecutive separators are treated as a
// single boundary; empty fields are skipped. Ergonomic alternative
// to FieldsFunc when the separator set is a known string. Examples:
//
//   FieldsAny("a,b;c", ",;")        →  ["a", "b", "c"]
//   FieldsAny("  one\ttwo three", " \t") → ["one", "two", "three"]
//
// Empty s or empty separators yields special behavior — empty s → []
// (no fields), empty separators → s as a single field if non-empty.
fun FieldsAny(s string, separators string) []string {
    var n int = len(s)
    if n == 0 { ret new(0) []string {} }
    if len(separators) == 0 {
        var out []string = new(1) []string {}
        out[0] = "" + s
        ret out
    }
    // Build a 256-byte member table for O(1) separator check.
    var member []byte = new(256) []byte {}
    var sl int = len(separators)
    for i := 0; i < sl; i++ {
        var c int = separators[i] & 255
        member[c] = 1
    }
    // First pass: count fields.
    var count int = 0
    var inField bool = false
    for i := 0; i < n; i++ {
        var c int = s[i] & 255
        if member[c] != 0 {
            inField = false
        } else {
            if !inField {
                count = count + 1
                inField = true
            }
        }
    }
    if count == 0 { ret new(0) []string {} }
    var out []string = new(count) []string {}
    var idx int = 0
    var start int = -1
    for i := 0; i < n; i++ {
        var c int = s[i] & 255
        if member[c] != 0 {
            if start >= 0 {
                out[idx] = Slice(s, start, i)
                idx = idx + 1
                start = -1
            }
        } else {
            if start < 0 { start = i }
        }
    }
    if start >= 0 {
        out[idx] = Slice(s, start, n)
    }
    ret out
}

fun FieldsFunc(s string, fn fun(byte) bool) []string {
    var n int = len(s)
    // First pass: count fields.
    var count int = 0
    var inField bool = false
    for i := 0; i < n; i++ {
        if fn(s[i]) {
            inField = false
        } else {
            if !inField {
                count = count + 1
                inField = true
            }
        }
    }
    if count == 0 {
        var empty []string = new(0) []string{}
        ret empty
    }
    // Second pass: collect.
    var out []string = new(count) []string{}
    var idx int = 0
    var start int = 0
    inField = false
    for i := 0; i < n; i++ {
        if fn(s[i]) {
            if inField {
                var b *bytes.Builder = bytes.NewBuilder()
                for j := start; j < i; j++ {
                    b.WriteByte(s[j])
                }
                out[idx] = b.String()
                idx = idx + 1
                inField = false
            }
        } else {
            if !inField {
                start = i
                inField = true
            }
        }
    }
    if inField {
        var b *bytes.Builder = bytes.NewBuilder()
        for j := start; j < n; j++ {
            b.WriteByte(s[j])
        }
        out[idx] = b.String()
    }
    ret out
}

// Cut slices s around the first occurrence of sep, returning the
// portion before sep, the portion after, and whether sep was present.
// If sep is not found in s, returns (s, "", false). If sep is empty,
// matches at position 0: returns ("", s, true) (matches Go).
fun Cut(s string, sep string) (string, string, bool) {
    var n int = len(s)
    var nsep int = len(sep)
    if nsep == 0 {
        var before *bytes.Builder = bytes.NewBuilder()
        var after *bytes.Builder = bytes.NewBuilder()
        for i := 0; i < n; i++ {
            after.WriteByte(s[i])
        }
        ret before.String(), after.String(), true
    }
    var idx int = Index(s, sep)
    if idx < 0 {
        var bld *bytes.Builder = bytes.NewBuilder()
        for i := 0; i < n; i++ {
            bld.WriteByte(s[i])
        }
        ret bld.String(), "", false
    }
    var before *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < idx; i++ {
        before.WriteByte(s[i])
    }
    var after *bytes.Builder = bytes.NewBuilder()
    var off int = idx + nsep
    for i := off; i < n; i++ {
        after.WriteByte(s[i])
    }
    ret before.String(), after.String(), true
}

// CutLast slices s around the LAST occurrence of sep, returning
// the portion before sep, the portion after, and whether sep was
// present. Right-anchored mirror of Cut. Useful for filename /
// path splitting where the rightmost separator matters (basename
// vs extension via the last `.`). Empty sep returns (s, "", true).
fun CutLast(s string, sep string) (string, string, bool) {
    var n int = len(s)
    var nsep int = len(sep)
    if nsep == 0 {
        var before *bytes.Builder = bytes.NewBuilder()
        for i := 0; i < n; i++ { before.WriteByte(s[i]) }
        ret before.String(), "", true
    }
    var idx int = LastIndex(s, sep)
    if idx < 0 {
        var bld *bytes.Builder = bytes.NewBuilder()
        for i := 0; i < n; i++ { bld.WriteByte(s[i]) }
        ret bld.String(), "", false
    }
    var before *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < idx; i++ { before.WriteByte(s[i]) }
    var after *bytes.Builder = bytes.NewBuilder()
    var off int = idx + nsep
    for i := off; i < n; i++ { after.WriteByte(s[i]) }
    ret before.String(), after.String(), true
}

// CutPrefix returns s without the leading prefix and reports whether
// the prefix was present. If s doesn't start with prefix, returns (s,
// false). Mirrors Go 1.20's strings.CutPrefix.
fun CutPrefix(s string, prefix string) (string, bool) {
    if !HasPrefix(s, prefix) {
        var bld *bytes.Builder = bytes.NewBuilder()
        var n int = len(s)
        for i := 0; i < n; i++ {
            bld.WriteByte(s[i])
        }
        ret bld.String(), false
    }
    var off int = len(prefix)
    var n int = len(s)
    var bld *bytes.Builder = bytes.NewBuilder()
    for i := off; i < n; i++ {
        bld.WriteByte(s[i])
    }
    ret bld.String(), true
}

// CutSuffix returns s without the trailing suffix and reports whether
// the suffix was present. If s doesn't end with suffix, returns (s,
// false). Mirrors Go 1.20's strings.CutSuffix.
fun CutSuffix(s string, suffix string) (string, bool) {
    if !HasSuffix(s, suffix) {
        var bld *bytes.Builder = bytes.NewBuilder()
        var n int = len(s)
        for i := 0; i < n; i++ {
            bld.WriteByte(s[i])
        }
        ret bld.String(), false
    }
    var n int = len(s) - len(suffix)
    var bld *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < n; i++ {
        bld.WriteByte(s[i])
    }
    ret bld.String(), true
}

// ContainsAny reports whether any byte in chars occurs in s. Empty
// chars returns false (no candidate bytes to match). Matches Go's
// byte-level semantics (volt has no rune type).
fun ContainsAny(s string, chars string) bool {
    ret IndexAny(s, chars) >= 0
}

// Map returns a string with each byte of s transformed by fn. The
// result has the same length as s — Go's drop-on-negative-return
// behavior is not modeled (volt has no rune type). Useful for ASCII
// case transforms, ROT-13, byte-level character substitution.
fun Map(fn fun(byte) byte, s string) string {
    var n int = len(s)
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < n; i++ {
        b.WriteByte(fn(s[i]))
    }
    ret b.String()
}

// IndexFunc returns the byte index of the first byte in s that
// satisfies fn(b), or -1 if no byte does. Useful for finding the
// next whitespace / first digit / etc. with a custom predicate.
fun IndexFunc(s string, fn fun(byte) bool) int {
    var n int = len(s)
    for i := 0; i < n; i++ {
        if fn(s[i]) { ret i }
    }
    ret -1
}

// LastIndexFunc returns the byte index of the last byte in s that
// satisfies fn(b), or -1 if no byte does.
fun LastIndexFunc(s string, fn fun(byte) bool) int {
    for i := len(s) - 1; i >= 0; i = i - 1 {
        if fn(s[i]) { ret i }
    }
    ret -1
}

// TrimFunc returns s with leading and trailing bytes for which fn
// returns true removed.
fun TrimFunc(s string, fn fun(byte) bool) string {
    var n int = len(s)
    var lo int = 0
    for lo < n {
        if !fn(s[lo]) { break }
        lo = lo + 1
    }
    var hi int = n
    for hi > lo {
        if !fn(s[hi - 1]) { break }
        hi = hi - 1
    }
    var b *bytes.Builder = bytes.NewBuilder()
    for i := lo; i < hi; i++ {
        b.WriteByte(s[i])
    }
    ret b.String()
}

// NOTE: strings.Builder was attempted as a Go-style alias for
// bytes.Builder but reverted — volt's type/method namespace is
// global, so both `bytes.Builder` and `strings.Builder` collided
// on method dispatch (`*bytes.Builder` calls were rewired to
// `strings_Builder_WriteByte` and crashed at runtime). Use
// bytes.Builder directly until the type namespace becomes
// per-package.

// SplitAfter slices s into substrings after each occurrence of sep
// and returns a slice of those substrings. The sep itself is
// retained at the end of each piece (vs Split, which discards sep).
// If sep is empty, returns a single-element slice containing s.
fun SplitAfter(s string, sep string) []string {
    var n int = len(s)
    var nsep int = len(sep)
    var out []string = new(0) []string{}
    if nsep == 0 {
        var b *bytes.Builder = bytes.NewBuilder()
        for i := 0; i < n; i++ { b.WriteByte(s[i]) }
        out = append(out, b.String())
        ret out
    }
    var start int = 0
    var i int = 0
    var limit int = n - nsep
    for i <= limit {
        var match bool = true
        for j := 0; j < nsep; j++ {
            if s[i + j] != sep[j] { match = false; break }
        }
        if match {
            var end int = i + nsep
            var b *bytes.Builder = bytes.NewBuilder()
            for k := start; k < end; k++ {
                b.WriteByte(s[k])
            }
            out = append(out, b.String())
            start = end
            i = end
        } else {
            i = i + 1
        }
    }
    // Tail: any unmatched remainder.
    if start < n {
        var b *bytes.Builder = bytes.NewBuilder()
        for k := start; k < n; k++ {
            b.WriteByte(s[k])
        }
        out = append(out, b.String())
    }
    ret out
}

// Compare returns -1 if a < b, 0 if a == b, +1 if a > b (byte-wise
// lex compare). Useful as a comparator for sort.StringsBy-style
// helpers when you need three-way ordering rather than the boolean
// less-than predicate.
fun Compare(a string, b string) int {
    var na int = len(a)
    var nb int = len(b)
    var m int = na
    if nb < m { m = nb }
    for i := 0; i < m; i++ {
        var ai int = a[i] & 255
        var bi int = b[i] & 255
        if ai < bi { ret -1 }
        if ai > bi { ret 1 }
    }
    if na < nb { ret -1 }
    if na > nb { ret 1 }
    ret 0
}

// NGrams returns every contiguous n-byte substring of s as a slice,
// stepping by 1 (sliding window). For s="hello", n=2 the result is
// ["he", "el", "ll", "lo"]. Returns an empty slice if n <= 0 or
// n > len(s). Useful for fuzzy matching, language modeling, fixed-
// width text indexing.
fun NGrams(s string, n int) []string {
    var ls int = len(s)
    if n <= 0 { ret new(0) []string {} }
    if n > ls { ret new(0) []string {} }
    var cnt int = ls - n + 1
    var out []string = new(cnt) []string {}
    for i := 0; i < cnt; i++ {
        var bld *bytes.Builder = bytes.NewBuilder()
        for k := 0; k < n; k++ {
            bld.WriteByte(s[i + k])
        }
        out[i] = bld.String()
    }
    ret out
}

// IsAnagram reports whether a and b are byte-frequency permutations
// of each other. Returns false on length mismatch. Empty strings
// are anagrams of each other. Operates on bytes — for ASCII this
// matches the standard definition; UTF-8 multi-byte chars are
// counted byte-by-byte.
fun IsAnagram(a string, b string) bool {
    var na int = len(a)
    var nb int = len(b)
    if na != nb { ret false }
    var hist []int = new(256) []int {}
    for i := 0; i < na; i++ {
        var ai int = a[i] & 255
        var bi int = b[i] & 255
        hist[ai] = hist[ai] + 1
        hist[bi] = hist[bi] - 1
    }
    for k := 0; k < 256; k++ {
        if hist[k] != 0 { ret false }
    }
    ret true
}

// SortChars returns s with its bytes rearranged in ascending order.
// Counting-sort over the 256-bucket histogram (O(n + 256)) — faster
// than a comparison sort and stable trivially. Useful for: anagram-
// key generation (`SortChars(a) == SortChars(b)` iff `IsAnagram(a,b)`
// for ASCII), character-frequency normalization, hash-bucket keying.
fun SortChars(s string) string {
    var n int = len(s)
    if n == 0 { ret "" }
    var hist []int = new(256) []int {}
    for i := 0; i < n; i++ {
        var c int = s[i] & 255
        hist[c] = hist[c] + 1
    }
    var b *bytes.Builder = bytes.NewBuilder()
    for k := 0; k < 256; k++ {
        var c int = hist[k]
        var kb byte = k
        for j := 0; j < c; j++ {
            b.WriteByte(kb)
        }
    }
    ret b.String()
}

// Frequencies returns a 256-bucket byte-frequency histogram of s.
// `out[b]` is the count of byte value `b` in s. Empty input returns
// a 256-element slice of zeros. Useful for: byte-distribution
// analysis (entropy estimation, charset detection), seeding the
// IsAnagram check, building cryptanalytic frequency tables.
fun Frequencies(s string) []int {
    var hist []int = new(256) []int {}
    var n int = len(s)
    for i := 0; i < n; i++ {
        var idx int = s[i] & 255
        hist[idx] = hist[idx] + 1
    }
    ret hist
}

// MostCommonByte returns the byte value with the highest frequency
// in s. On ties, returns the smallest byte value with that count
// (deterministic). Empty input returns 0. Useful for charset-
// majority decisions, dominant-symbol detection.
fun MostCommonByte(s string) byte {
    var hist []int = Frequencies(s)
    var bestByte int = 0
    var bestCount int = -1
    for i := 0; i < 256; i++ {
        if hist[i] > bestCount {
            bestCount = hist[i]
            bestByte = i
        }
    }
    var b byte = bestByte
    ret b
}

// OnlyLetters returns s with every non-ASCII-letter byte removed.
// Letters keep their case. Useful for: tokenizer-style "give me
// just the alphabetic content" filtering before search / NLP
// preprocessing.
fun OnlyLetters(s string) string {
    var n int = len(s)
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < n; i++ {
        var c byte = s[i]
        if c >= 65 {
            if c <= 90 { b.WriteByte(c); continue }
        }
        if c >= 97 {
            if c <= 122 { b.WriteByte(c) }
        }
    }
    ret b.String()
}

// MaskMiddle returns s with middle bytes replaced by `mask` byte
// while preserving the first `keepStart` and last `keepEnd` bytes.
// If `keepStart + keepEnd >= len(s)`, returns s unchanged (no
// middle to mask). Negative keep counts are clamped to 0. Useful
// for: PII / credential / phone-number redaction in UI / logs
// ("MaskMiddle('5551234567', 3, 4, '*')" → "555***4567").
fun MaskMiddle(s string, keepStart int, keepEnd int, mask byte) string {
    var n int = len(s)
    var ks int = keepStart
    var ke int = keepEnd
    if ks < 0 { ks = 0 }
    if ke < 0 { ke = 0 }
    if (ks + ke) >= n { ret "" + s }
    var midLen int = n - ks - ke
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < ks; i++ { b.WriteByte(s[i]) }
    for i := 0; i < midLen; i++ { b.WriteByte(mask) }
    for i := n - ke; i < n; i++ { b.WriteByte(s[i]) }
    ret b.String()
}

// OnlyHex returns s with every byte that isn't an ASCII hex digit
// (0-9, a-f, A-F) removed. Mixed case is preserved (no normalization).
// Useful for: extracting hex content from formatted dumps,
// sanitizing hash strings that mix in separators.
fun OnlyHex(s string) string {
    var n int = len(s)
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < n; i++ {
        var c byte = s[i]
        if c >= 48 {
            if c <= 57 { b.WriteByte(c); continue }
        }
        if c >= 65 {
            if c <= 70 { b.WriteByte(c); continue }
        }
        if c >= 97 {
            if c <= 102 { b.WriteByte(c); continue }
        }
    }
    ret b.String()
}

// OnlyDigits returns s with every non-ASCII-digit byte removed.
// Empty input returns "". Useful for: phone-number / postal-code
// normalization, extracting numeric IDs from formatted strings,
// stripping decoration from "$1,234.50" → "123450".
fun OnlyDigits(s string) string {
    var n int = len(s)
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < n; i++ {
        var c byte = s[i]
        if c >= 48 {
            if c <= 57 { b.WriteByte(c) }
        }
    }
    ret b.String()
}

// OnlyAlphanumeric returns s with every non-ASCII-letter / non-digit
// byte removed. Letters keep their case. Useful for: slug-prep,
// search-token normalization, ID sanitization.
fun OnlyAlphanumeric(s string) string {
    var n int = len(s)
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < n; i++ {
        var c byte = s[i]
        if c >= 48 {
            if c <= 57 { b.WriteByte(c); continue }
        }
        if c >= 65 {
            if c <= 90 { b.WriteByte(c); continue }
        }
        if c >= 97 {
            if c <= 122 { b.WriteByte(c); continue }
        }
    }
    ret b.String()
}

// OnlyAscii returns s with every non-ASCII byte (bytes >= 128)
// removed. Keeps the control range 0x00..0x1F + DEL untouched (use
// strings.NormalizeWhitespace / TrimSpace / IsControl-style filters
// to strip those separately). Useful for: locale-tolerant rendering
// pipelines, fail-soft text display when output is ASCII-only,
// UTF-8 stripping before passing to legacy APIs. Byte's high bit
// (signed-byte negative range) is the distinguishing condition —
// uses `& 255` to widen to int before the bound check.
fun OnlyAscii(s string) string {
    var n int = len(s)
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < n; i++ {
        var c int = s[i] & 255
        if c < 128 {
            var cb byte = c
            b.WriteByte(cb)
        }
    }
    ret b.String()
}

// IndicesOfByte returns every position in s where the byte equals
// c. Single-byte specialization of IndicesOf — useful when scanning
// for a delimiter / control byte (e.g. every newline position).
fun IndicesOfByte(s string, c byte) []int {
    var n int = len(s)
    var out []int = new(0) []int {}
    for i := 0; i < n; i++ {
        if s[i] == c { out = append(out, i) }
    }
    ret out
}

// IndexNthByte returns the index of the n-th occurrence (0-indexed)
// of byte c in s, or -1 if there are fewer than n+1 matches. n<0
// returns -1. Useful for "find the second tab", "third comma" type
// lookups without materializing the full IndicesOfByte slice.
fun IndexNthByte(s string, c byte, n int) int {
    if n < 0 { ret -1 }
    var ls int = len(s)
    var k int = 0
    for i := 0; i < ls; i++ {
        if s[i] == c {
            if k == n { ret i }
            k = k + 1
        }
    }
    ret -1
}

// IndexNth returns the starting position of the n-th non-overlapping
// occurrence (0-indexed) of substring sub in s, or -1 if there are
// fewer than n+1 matches. n<0 returns -1. Empty sub returns -1
// (matches the empty-sub convention of IndicesOf, not Go's Index).
// After a hit at position i the search advances by len(sub) so
// matches are non-overlapping.
fun IndexNth(s string, sub string, n int) int {
    if n < 0 { ret -1 }
    var ls int = len(s)
    var lsub int = len(sub)
    if lsub == 0 { ret -1 }
    if ls < lsub { ret -1 }
    var i int = 0
    var limit int = ls - lsub
    var k int = 0
    for i <= limit {
        var match bool = true
        for j := 0; j < lsub; j++ {
            if s[i + j] != sub[j] {
                match = false
                break
            }
        }
        if match {
            if k == n { ret i }
            k = k + 1
            i = i + lsub
        } else {
            i = i + 1
        }
    }
    ret -1
}

// IndicesOf returns every starting position in s where sub appears.
// Matches are non-overlapping: after a match at i, the search
// continues at i + len(sub). Empty sub returns an empty slice
// (avoid the degenerate "match every position" path Go's Count
// takes for empty sub). Empty s returns empty. Companion to
// strings.Count + strings.Index — useful when you need every
// match's location, not just the count or first.
fun IndicesOf(s string, sub string) []int {
    var out []int = new(0) []int {}
    var ls int = len(s)
    var lsub int = len(sub)
    if lsub == 0 { ret out }
    if ls < lsub { ret out }
    var i int = 0
    var limit int = ls - lsub
    for i <= limit {
        var match bool = true
        for j := 0; j < lsub; j++ {
            if s[i + j] != sub[j] {
                match = false
                break
            }
        }
        if match {
            out = append(out, i)
            i = i + lsub
        } else {
            i = i + 1
        }
    }
    ret out
}

// HammingDistance returns the number of byte positions at which a
// and b differ. Both inputs must have the same length; returns -1
// if lengths differ. Operates on bytes, not runes — for ASCII this
// matches the standard definition.
fun HammingDistance(a string, b string) int {
    var na int = len(a)
    var nb int = len(b)
    if na != nb { ret -1 }
    var d int = 0
    for i := 0; i < na; i++ {
        if a[i] != b[i] { d = d + 1 }
    }
    ret d
}

// Levenshtein returns the minimum number of single-byte edits
// (insert, delete, substitute) required to transform a into b.
// Standard DP using two rolling rows, O(na*nb) time, O(min) space.
// Operates on bytes — for ASCII this matches the standard
// definition; for UTF-8 multi-byte chars the metric is byte-level
// rather than rune-level. Useful for spell-check / typo suggestion
// / fuzzy matching.
fun Levenshtein(a string, b string) int {
    var na int = len(a)
    var nb int = len(b)
    if na == 0 { ret nb }
    if nb == 0 { ret na }
    var prev []int = new(nb + 1) []int {}
    var curr []int = new(nb + 1) []int {}
    for j := 0; j <= nb; j++ { prev[j] = j }
    for i := 1; i <= na; i++ {
        curr[0] = i
        for j := 1; j <= nb; j++ {
            var cost int = 1
            if a[i - 1] == b[j - 1] { cost = 0 }
            var del int = prev[j] + 1
            var ins int = curr[j - 1] + 1
            var sub int = prev[j - 1] + cost
            var m int = del
            if ins < m { m = ins }
            if sub < m { m = sub }
            curr[j] = m
        }
        for j := 0; j <= nb; j++ { prev[j] = curr[j] }
    }
    ret prev[nb]
}

// Capitalize returns s with its first byte mapped to ASCII upper
// (if it's a lowercase letter), preserving the rest. Returns empty
// for empty input. Doesn't span Unicode rune boundaries — v1 is
// byte-level.
fun Capitalize(s string) string {
    var n int = len(s)
    if n == 0 { ret "" }
    var b *bytes.Builder = bytes.NewBuilder()
    var c byte = s[0]
    if c >= 97 {
        if c <= 122 { c = c - 32 }
    }
    b.WriteByte(c)
    for i := 1; i < n; i++ {
        b.WriteByte(s[i])
    }
    ret b.String()
}

// LongestRun returns the length of the longest run of consecutive
// `c` bytes in s. 0 if c never appears. Useful for indent-depth
// estimation, repeated-character detection (e.g. longest run of `-`
// in a separator), simple compression-style stats. Single linear
// pass.
fun LongestRun(s string, c byte) int {
    var n int = len(s)
    var best int = 0
    var cur int = 0
    for i := 0; i < n; i++ {
        if s[i] == c {
            cur = cur + 1
            if cur > best { best = cur }
        } else {
            cur = 0
        }
    }
    ret best
}

// LongestRunFunc returns the length of the longest run of consecutive
// bytes for which `pred(b)` returns true. 0 if no byte matches.
// More flexible than LongestRun (which takes a fixed byte) — useful
// for "longest whitespace run", "longest digit run", "longest
// non-letter run" estimations.
fun LongestRunFunc(s string, pred fun(byte) bool) int {
    var n int = len(s)
    var best int = 0
    var cur int = 0
    for i := 0; i < n; i++ {
        if pred(s[i]) {
            cur = cur + 1
            if cur > best { best = cur }
        } else {
            cur = 0
        }
    }
    ret best
}

// Title returns s with the first byte of each whitespace-separated
// word mapped to ASCII upper. Whitespace bytes (' ', '\t', '\n',
// '\r') are preserved unchanged. Non-letter bytes pass through.
// Byte-level only — no Unicode rune awareness.
fun Title(s string) string {
    var n int = len(s)
    if n == 0 { ret "" }
    var b *bytes.Builder = bytes.NewBuilder()
    var atWordStart bool = true
    for i := 0; i < n; i++ {
        var c byte = s[i]
        if c == 32 {            // ' '
            atWordStart = true
            b.WriteByte(c)
            continue
        }
        if c == 9 {             // '\t'
            atWordStart = true
            b.WriteByte(c)
            continue
        }
        if c == 10 {            // '\n'
            atWordStart = true
            b.WriteByte(c)
            continue
        }
        if c == 13 {            // '\r'
            atWordStart = true
            b.WriteByte(c)
            continue
        }
        if atWordStart {
            if c >= 97 {        // 'a'
                if c <= 122 {   // 'z'
                    c = c - 32
                }
            }
            atWordStart = false
        }
        b.WriteByte(c)
    }
    ret b.String()
}

// PascalCase converts a string from snake_case / kebab-case /
// space-separated to PascalCase. Separators ('_', '-', ' ') drop
// out and each following letter gets uppercased. The very first
// letter of the input is also uppercased. Non-letter / non-sep
// characters pass through. Useful for: language-to-language
// identifier conversion (Python snake → Go Pascal exports).
// TitleCase capitalizes the first letter of each space-separated
// word in s, lowercasing the rest. "hello world" → "Hello World".
// ASCII-only: bytes outside [A-Za-z] are passed through unchanged.
// Use case: book titles, header rendering, name normalization.
fun TitleCase(s string) string {
    var n int = len(s)
    if n == 0 { ret "" }
    var b *bytes.Builder = bytes.NewBuilder()
    var atWordStart bool = true
    for i := 0; i < n; i++ {
        var c byte = s[i]
        if c == 32 || c == 9 || c == 10 || c == 13 {
            b.WriteByte(c)
            atWordStart = true
            continue
        }
        if atWordStart {
            if c >= 97 {
                if c <= 122 { c = c - 32 }
            }
            atWordStart = false
        } else {
            if c >= 65 {
                if c <= 90 { c = c + 32 }
            }
        }
        b.WriteByte(c)
    }
    ret b.String()
}

fun PascalCase(s string) string {
    var n int = len(s)
    var b *bytes.Builder = bytes.NewBuilder()
    var nextUpper bool = true
    for i := 0; i < n; i++ {
        var c byte = s[i]
        if c == 95 { nextUpper = true; continue }    // '_'
        if c == 45 { nextUpper = true; continue }    // '-'
        if c == 32 { nextUpper = true; continue }    // ' '
        if nextUpper {
            if c >= 97 {
                if c <= 122 {
                    var upper byte = c - 32
                    b.WriteByte(upper)
                    nextUpper = false
                    continue
                }
            }
            b.WriteByte(c)
            nextUpper = false
        } else {
            b.WriteByte(c)
        }
    }
    ret b.String()
}

// CamelCase: same as PascalCase but with the first letter
// lowercased — produces conventional camelCase identifiers.
fun CamelCase(s string) string {
    ret Decapitalize(PascalCase(s))
}

// SnakeCase converts a string to snake_case. Inserts an underscore
// before each uppercase letter that's preceded by a lowercase
// letter OR by an uppercase that's itself followed by a lowercase
// (so "HTTPRequest" → "http_request", not "httprequest"). Letters
// are lowercased; non-letters pass through. Useful for converting
// CamelCase identifiers to snake_case (column names, env vars).
fun SnakeCase(s string) string {
    ret caseConvert(s, 95)   // '_'
}

// KebabCase converts a string to kebab-case using the same rules
// as SnakeCase but with '-' instead of '_'. Useful for URL slugs,
// CSS class names.
fun KebabCase(s string) string {
    ret caseConvert(s, 45)   // '-'
}

// caseConvert is the shared implementation for SnakeCase /
// KebabCase. `sep` is the byte to insert at word boundaries.
fun caseConvert(s string, sep byte) string {
    var n int = len(s)
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < n; i++ {
        var c byte = s[i]
        var isUpper bool = false
        if c >= 65 {
            if c <= 90 { isUpper = true }
        }
        if isUpper {
            if i > 0 {
                var prev byte = s[i - 1]
                var prevLower bool = false
                if prev >= 97 {
                    if prev <= 122 { prevLower = true }
                }
                var prevUpper bool = false
                if prev >= 65 {
                    if prev <= 90 { prevUpper = true }
                }
                var nextLower bool = false
                if (i + 1) < n {
                    var nxt byte = s[i + 1]
                    if nxt >= 97 {
                        if nxt <= 122 { nextLower = true }
                    }
                }
                if prevLower {
                    b.WriteByte(sep)
                } else {
                    if prevUpper {
                        if nextLower { b.WriteByte(sep) }
                    }
                }
            }
            var lower byte = c + 32
            b.WriteByte(lower)
        } else {
            b.WriteByte(c)
        }
    }
    ret b.String()
}

// Decapitalize returns s with its first byte mapped to ASCII lower
// (if it's an uppercase letter), preserving the rest. Counterpart
// to Capitalize. Useful for camelCase generation: take a CapWord
// and lowercase the first letter for camelCase.
fun Decapitalize(s string) string {
    var n int = len(s)
    if n == 0 { ret "" }
    var b *bytes.Builder = bytes.NewBuilder()
    var c byte = s[0]
    if c >= 65 {
        if c <= 90 { c = c + 32 }
    }
    b.WriteByte(c)
    for i := 1; i < n; i++ {
        b.WriteByte(s[i])
    }
    ret b.String()
}

// SwapCase returns s with every ASCII letter's case flipped:
// upper → lower, lower → upper. Non-letters pass through. Useful
// for novelty / puzzle effects, accessibility test data.
fun SwapCase(s string) string {
    var n int = len(s)
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < n; i++ {
        var c byte = s[i]
        if c >= 65 {
            if c <= 90 {
                var lower byte = c + 32
                b.WriteByte(lower)
                continue
            }
        }
        if c >= 97 {
            if c <= 122 {
                var upper byte = c - 32
                b.WriteByte(upper)
                continue
            }
        }
        b.WriteByte(c)
    }
    ret b.String()
}

// CommonPrefix returns the longest byte sequence shared by a and b
// at their starts. Returns "" if the strings disagree on byte 0 or
// either is empty. Useful for collapsing shared directory prefixes,
// shrinking diff context, and bucketing strings by common stem.
fun CommonPrefix(a string, b string) string {
    var na int = len(a)
    var nb int = len(b)
    var lim int = na
    if nb < lim { lim = nb }
    var k int = 0
    for k < lim {
        if a[k] != b[k] { break }
        k = k + 1
    }
    if k == 0 { ret "" }
    var bld *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < k; i++ {
        bld.WriteByte(a[i])
    }
    ret bld.String()
}

// CommonSuffix returns the longest byte sequence shared by a and b
// at their ends. Counterpart to CommonPrefix. Useful for stripping
// shared file-extensions, finding common URL tails.
fun CommonSuffix(a string, b string) string {
    var na int = len(a)
    var nb int = len(b)
    var lim int = na
    if nb < lim { lim = nb }
    var k int = 0
    for k < lim {
        if a[na - 1 - k] != b[nb - 1 - k] { break }
        k = k + 1
    }
    if k == 0 { ret "" }
    var bld *bytes.Builder = bytes.NewBuilder()
    for i := na - k; i < na; i++ {
        bld.WriteByte(a[i])
    }
    ret bld.String()
}

// RemoveAll returns s with every occurrence of every substring in
// `subs` removed (Replace-with-empty for each, in order). Order
// matters when substrings overlap — earlier subs are removed first.
// Empty subs slice or empty individual sub strings → s unchanged.
// Useful for: noise-token stripping, header-junk removal,
// sanitization pipelines.
fun RemoveAll(s string, subs []string) string {
    var out string = "" + s
    var n int = len(subs)
    for i := 0; i < n; i++ {
        if len(subs[i]) == 0 { continue }
        out = Replace(out, subs[i], "")
    }
    ret out
}

// ReplaceMany returns s with each (old, new) pair applied in order.
// `pairs` is a flat slice of even length where pairs[2k] is the old
// substring and pairs[2k+1] is the replacement. Useful for: charset
// substitution batches, multi-token rename passes. Odd-length input
// silently ignores the trailing unmatched element.
fun ReplaceMany(s string, pairs []string) string {
    var out string = "" + s
    var n int = len(pairs)
    var pairsCount int = n / 2
    for i := 0; i < pairsCount; i++ {
        out = Replace(out, pairs[2 * i], pairs[2 * i + 1])
    }
    ret out
}

// CommonPrefixAll returns the longest byte sequence that prefixes
// every string in `strs`. Empty input slice returns "". Single-
// element slice returns that element verbatim. Useful for finding
// the deepest shared directory prefix across many paths, or the
// shared stem of a related-strings group.
fun CommonPrefixAll(strs []string) string {
    var n int = len(strs)
    if n == 0 { ret "" }
    var acc string = "" + strs[0]
    for i := 1; i < n; i++ {
        acc = CommonPrefix(acc, strs[i])
        if len(acc) == 0 { ret "" }
    }
    ret acc
}

// CommonSuffixAll returns the longest byte sequence that suffixes
// every string in `strs`. Counterpart to CommonPrefixAll.
fun CommonSuffixAll(strs []string) string {
    var n int = len(strs)
    if n == 0 { ret "" }
    var acc string = "" + strs[0]
    for i := 1; i < n; i++ {
        acc = CommonSuffix(acc, strs[i])
        if len(acc) == 0 { ret "" }
    }
    ret acc
}

// Reverse returns s with byte order reversed. Empty input returns "".
fun Reverse(s string) string {
    var n int = len(s)
    if n == 0 { ret "" }
    var b *bytes.Builder = bytes.NewBuilder()
    for i := n - 1; i >= 0; i = i - 1 {
        b.WriteByte(s[i])
    }
    ret b.String()
}

// ToBytes returns a fresh []byte containing the bytes of s. Inverse
// of bytes.String — useful when passing string data into APIs that
// take []byte (network writes, byte-mutation pipelines). Volt
// strings are immutable so this is always a defensive copy.
fun ToBytes(s string) []byte {
    var n int = len(s)
    var out []byte = new(n) []byte {}
    for i := 0; i < n; i++ {
        out[i] = s[i]
    }
    ret out
}

// ReverseWords returns s with the order of its whitespace-separated
// tokens reversed, single-space-joined. Splits on `Fields` semantics
// (any whitespace run is a separator), so input whitespace shape is
// not preserved — `"  hello   world  "` becomes `"world hello"`.
// Empty / all-whitespace input returns "". Useful for "last name
// first name" reorderings, simple text-reversal tricks.
fun ReverseWords(s string) string {
    var parts []string = Fields(s)
    var n int = len(parts)
    if n == 0 { ret "" }
    var b *bytes.Builder = bytes.NewBuilder()
    for i := n - 1; i >= 0; i = i - 1 {
        if i < n - 1 { b.WriteByte(32) }
        b.WriteString(parts[i])
    }
    ret b.String()
}

// Lines splits s into lines on `\n` boundaries with `\r` stripped
// from each line (handles both LF and CRLF). Mirrors bufio.SplitLines
// but lives in `strings` for ergonomic discoverability — users
// reaching for line-splitting usually look in strings first.
// Empty input returns an empty slice.
fun Lines(s string) []string {
    var n int = len(s)
    var out []string = new(0) []string {}
    if n == 0 { ret out }
    var start int = 0
    for i := 0; i < n; i++ {
        if s[i] == 10 {                       // '\n'
            var end int = i
            if end > start {
                if s[end - 1] == 13 { end = end - 1 }   // strip '\r'
            }
            var b *bytes.Builder = bytes.NewBuilder()
            for k := start; k < end; k++ {
                b.WriteByte(s[k])
            }
            out = append(out, b.String())
            start = i + 1
        }
    }
    if start < n {
        var end int = n
        if s[end - 1] == 13 { end = end - 1 }
        var b *bytes.Builder = bytes.NewBuilder()
        for k := start; k < end; k++ {
            b.WriteByte(s[k])
        }
        out = append(out, b.String())
    }
    ret out
}


// intDecimalStr is the inlined "positive int → decimal string"
// helper used by NumberLines so the strings package doesn't pull
// in strconv as a dependency.
fun intDecimalStr(n int) string {
    if n == 0 { ret "0" }
    var buf []byte = new(20) []byte {}
    var x int = n
    var neg bool = false
    if x < 0 { neg = true; x = -x }
    var k int = 0
    for x > 0 {
        buf[k] = ((x % 10) + 48) & 255
        x = x / 10
        k = k + 1
    }
    var b *bytes.Builder = bytes.NewBuilder()
    if neg { b.WriteByte(45) }
    for i := k - 1; i >= 0; i-- { b.WriteByte(buf[i]) }
    ret b.String()
}

// NumberLines prefixes each line of s with its 1-indexed line
// number followed by a tab. CRLF normalized via Lines. Blank lines
// get a number too. Useful for error-message context, code-listing
// output, debug pretty-print. Empty input returns "".
fun NumberLines(s string) string {
    if len(s) == 0 { ret "" }
    var ls []string = Lines(s)
    var n int = len(ls)
    if n == 0 { ret "" }
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < n; i++ {
        b.WriteString(intDecimalStr(i + 1))
        b.WriteByte(9)   // tab
        b.WriteString(ls[i])
        if i < n - 1 { b.WriteByte(10) }
    }
    ret b.String()
}

// ReverseLines returns s with line order reversed (last line first,
// rejoined with '\n'). CRLF normalized via Lines. Useful for log
// tail-first inspection and undo-style display.
fun ReverseLines(s string) string {
    if len(s) == 0 { ret "" }
    var ls []string = Lines(s)
    var n int = len(ls)
    if n == 0 { ret "" }
    var b *bytes.Builder = bytes.NewBuilder()
    for i := n - 1; i >= 0; i-- {
        b.WriteString(ls[i])
        if i > 0 { b.WriteByte(10) }
    }
    ret b.String()
}

// MapLines returns a fresh string where every line of s has been
// passed through fn and the result rejoined with '\n'. CRLF
// normalized via Lines (so the input "\r\n" is treated the same
// as "\n"). Empty input returns "". Useful for per-line
// transformations: case-folding logs, prepending arbitrary
// per-line context, regex-substitution-style line edits.
fun MapLines(s string, fn fun(string) string) string {
    if len(s) == 0 { ret "" }
    var ls []string = Lines(s)
    var n int = len(ls)
    if n == 0 { ret "" }
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < n; i++ {
        b.WriteString(fn(ls[i]))
        if i < n - 1 { b.WriteByte(10) }
    }
    ret b.String()
}

// FilterLines returns a fresh string containing only the lines of
// s for which keep(line) returns true; survivors rejoined with
// '\n'. CRLF normalized. Empty input returns "". Useful for
// log-level filtering, blank-line stripping, error-line extraction.
fun FilterLines(s string, keep fun(string) bool) string {
    if len(s) == 0 { ret "" }
    var ls []string = Lines(s)
    var n int = len(ls)
    if n == 0 { ret "" }
    var b *bytes.Builder = bytes.NewBuilder()
    var first bool = true
    for i := 0; i < n; i++ {
        if keep(ls[i]) {
            if !first { b.WriteByte(10) }
            b.WriteString(ls[i])
            first = false
        }
    }
    ret b.String()
}

// GrepLines returns s with only the lines that contain the literal
// substring `pat` kept (UNIX `grep pat`), rejoined with '\n'.
// CRLF normalized via Lines. Empty pat matches every line (Go's
// strings.Contains convention). Empty input returns "". Useful for
// log filtering, server-tail search, drop-in `grep` over a
// composed string.
fun GrepLines(s string, pat string) string {
    if len(s) == 0 { ret "" }
    var ls []string = Lines(s)
    var n int = len(ls)
    if n == 0 { ret "" }
    var b *bytes.Builder = bytes.NewBuilder()
    var first bool = true
    for i := 0; i < n; i++ {
        if Contains(ls[i], pat) {
            if !first { b.WriteByte(10) }
            b.WriteString(ls[i])
            first = false
        }
    }
    ret b.String()
}

// GrepLinesNot is `grep -v pat` — keeps lines that do NOT contain
// the literal substring `pat`. Empty pat matches everything (so
// the result is "" — matches Unix grep -v "" semantics, which
// drops every line).
fun GrepLinesNot(s string, pat string) string {
    if len(s) == 0 { ret "" }
    var ls []string = Lines(s)
    var n int = len(ls)
    if n == 0 { ret "" }
    var b *bytes.Builder = bytes.NewBuilder()
    var first bool = true
    for i := 0; i < n; i++ {
        if !Contains(ls[i], pat) {
            if !first { b.WriteByte(10) }
            b.WriteString(ls[i])
            first = false
        }
    }
    ret b.String()
}

// UniqueLines returns s with duplicate lines removed, preserving
// the order of first occurrence (Unix `awk '!seen[$0]++'`
// semantics). Rejoined with '\n'. CRLF normalized via Lines.
// Empty input returns "". O(n²) — fine for typical log sizes.
// Useful for log deduplication, deduplicated allow-list files,
// stable-order set-of-lines.
fun UniqueLines(s string) string {
    if len(s) == 0 { ret "" }
    var ls []string = Lines(s)
    var n int = len(ls)
    if n == 0 { ret "" }
    var seen []string = new(0) []string {}
    var b *bytes.Builder = bytes.NewBuilder()
    var first bool = true
    for i := 0; i < n; i++ {
        var dup bool = false
        var sn int = len(seen)
        for j := 0; j < sn; j++ {
            if seen[j] == ls[i] { dup = true; break }
        }
        if !dup {
            seen = append(seen, "" + ls[i])
            if !first { b.WriteByte(10) }
            b.WriteString(ls[i])
            first = false
        }
    }
    ret b.String()
}

// SortLines returns s with its lines sorted ascending in byte-wise
// lex order, rejoined with '\n'. CRLF normalized. Empty input
// returns "". O(n²) inlined insertion sort (kept inline so the
// strings package doesn't take a sort dep). Useful for sorted-log
// output, canonical-form file diffs.
fun SortLines(s string) string {
    if len(s) == 0 { ret "" }
    var ls []string = Lines(s)
    var n int = len(ls)
    if n == 0 { ret "" }
    // Insertion sort in-place over ls (byte-wise lex compare).
    for i := 1; i < n; i++ {
        var key string = "" + ls[i]
        var j int = i - 1
        for j >= 0 {
            if Compare(ls[j], key) <= 0 { break }
            ls[j + 1] = "" + ls[j]
            j = j - 1
        }
        ls[j + 1] = key
    }
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < n; i++ {
        b.WriteString(ls[i])
        if i < n - 1 { b.WriteByte(10) }
    }
    ret b.String()
}

// HeadLines returns the first n lines of s (split on '\n', \r-aware)
// rejoined with '\n'. n <= 0 returns ""; n >= number-of-lines
// returns all of s (with newlines normalized to '\n'). Useful for
// `head`-style log previews. Trailing newline is NOT preserved if
// the requested prefix didn't end at a real line break — the
// output is a clean concatenation of n lines joined by '\n'.
fun HeadLines(s string, n int) string {
    if n <= 0 { ret "" }
    var ls []string = Lines(s)
    var nl int = len(ls)
    if n > nl { n = nl }
    if n == 0 { ret "" }
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < n; i++ {
        b.WriteString(ls[i])
        if i < n - 1 { b.WriteByte(10) }
    }
    ret b.String()
}

// TailLines returns the last n lines of s. n <= 0 returns "";
// n >= number-of-lines returns all of s (newlines normalized to
// '\n'). Useful for `tail`-style log inspection.
fun TailLines(s string, n int) string {
    if n <= 0 { ret "" }
    var ls []string = Lines(s)
    var nl int = len(ls)
    if n > nl { n = nl }
    if n == 0 { ret "" }
    var b *bytes.Builder = bytes.NewBuilder()
    var off int = nl - n
    for i := 0; i < n; i++ {
        b.WriteString(ls[off + i])
        if i < n - 1 { b.WriteByte(10) }
    }
    ret b.String()
}

// TrimSpaceEachLine returns s with every line (split on '\n', \r-aware)
// having its leading and trailing whitespace stripped via TrimSpace,
// then rejoined with '\n'. Convenient for cleaning up multi-line
// input (heredocs, user-pasted blocks, log captures) where each
// line has inconsistent trailing/leading whitespace. Empty input
// returns "". Preserves blank lines (they become "" — not
// dropped). Trailing newline preserved iff input had one.
fun TrimSpaceEachLine(s string) string {
    var n int = len(s)
    if n == 0 { ret "" }
    var hadTrailingNL bool = false
    if s[n - 1] == 10 { hadTrailingNL = true }
    var ls []string = Lines(s)
    var b *bytes.Builder = bytes.NewBuilder()
    var nl int = len(ls)
    for i := 0; i < nl; i++ {
        var t string = TrimSpace(ls[i])
        b.WriteString(t)
        if i < nl - 1 { b.WriteByte(10) }
    }
    if hadTrailingNL { b.WriteByte(10) }
    ret b.String()
}

// ---- Builder ---------------------------------------------------------

// Builder is the strings-package counterpart to bytes.Builder. It
// accumulates bytes (or strings, via WriteString) into an internal
// buffer and finalizes to an immutable %string in O(n). Method
// signatures mirror bytes.Builder so the two types are
// interchangeable when only WriteByte/WriteString/String are used,
// but they are DISTINCT types — method dispatch must respect the
// receiver's declared package qualifier (BUG.4).
type Builder struct {
    buf []byte
    n   int
}

fun NewBuilder() *Builder {
    var b *Builder = new Builder { buf: new(16) []byte {}, n: 0 }
    ret b
}

fun (b *Builder) Len() int { ret b.n }

fun (b *Builder) growTo(need int) {
    if need <= len(b.buf) { ret }
    var newCap int = len(b.buf) * 2
    if newCap < 16 { newCap = 16 }
    for newCap < need { newCap = newCap * 2 }
    var nb []byte = new(newCap) []byte {}
    for i := 0; i < b.n; i++ {
        nb[i] = b.buf[i]
    }
    b.buf = nb
}

fun (b *Builder) WriteByte(c byte) {
    b.growTo(b.n + 1)
    b.buf[b.n] = c
    b.n = b.n + 1
}

fun (b *Builder) WriteString(s string) {
    var sn int = len(s)
    b.growTo(b.n + sn)
    for i := 0; i < sn; i++ {
        b.buf[b.n + i] = s[i]
    }
    b.n = b.n + sn
}

// WriteRepeat appends c repeated count times. count <= 0 is a no-op.
// Single up-front grow, no per-iter overhead. Mirror of
// bytes.Builder.WriteRepeat — useful for padding / alignment fills /
// framing characters on the strings-side Builder.
fun (b *Builder) WriteRepeat(c byte, count int) {
    if count <= 0 { ret }
    b.growTo(b.n + count)
    for i := 0; i < count; i++ {
        b.buf[b.n + i] = c
    }
    b.n = b.n + count
}

// WriteInt appends the base-10 decimal representation of n. Mirror
// of bytes.Builder.WriteInt — delegates to strconv.Itoa then
// WriteString. Useful for building log lines / formatted output
// without pre-computing the full string.
fun (b *Builder) WriteInt(n int) {
    b.WriteString(strconv.Itoa(n))
}

// WriteBool appends `"true"` or `"false"` depending on v. Mirror of
// bytes.Builder.WriteBool.
fun (b *Builder) WriteBool(v bool) {
    if v {
        b.WriteString("true")
        ret
    }
    b.WriteString("false")
}

fun (b *Builder) Reset() { b.n = 0 }

fun (b *Builder) String() string {
    var out string = ""
    for i := 0; i < b.n; i++ {
        out = out + chr(b.buf[i])
    }
    ret out
}

// WrapAt soft-wraps `s` so no line exceeds `width` columns. Word-aware:
// breaks happen at whitespace; words longer than `width` get their own
// line (no mid-word breaks). Returns the wrapped result with `\n`
// separators between lines. Width <= 0 returns s unchanged.
// Useful for CLI help text, log message formatting, fixed-width
// output.
//
// Implementation note: builds the result via bytes.Builder rather
// than `+`-concatenated strings. The string + flavor would force a
// fresh heap-alloc per word join AND need careful aliasing dance
// around the per-iteration `word`. Single Builder = one buffer.
fun WrapAt(s string, width int) string {
    if width <= 0 { ret s }
    var n int = len(s)
    if n == 0 { ret "" }
    var out *bytes.Builder = bytes.NewBuilder()
    var lineStart int = -1                  // -1 = no current line
    var lineLen int = 0
    var firstLine bool = true
    var i int = 0
    for i < n {
        // Skip leading whitespace at the start of a fresh line.
        if lineStart == -1 && (s[i] == 32 || s[i] == 9 || s[i] == 10) {
            i = i + 1
            continue
        }
        // Find next word (non-space run).
        var j int = i
        for j < n && s[j] != 32 && s[j] != 9 && s[j] != 10 { j = j + 1 }
        var wordLen int = j - i
        var wordStart int = i

        if lineStart == -1 {
            // First word on this line — emit it as the line.
            if !firstLine { out.WriteByte(10) }
            for k := 0; k < wordLen; k++ { out.WriteByte(s[wordStart + k]) }
            lineStart = wordStart
            lineLen = wordLen
            firstLine = false
        } else if lineLen + 1 + wordLen > width {
            // Break: start a new line with this word.
            out.WriteByte(10)
            for k := 0; k < wordLen; k++ { out.WriteByte(s[wordStart + k]) }
            lineStart = wordStart
            lineLen = wordLen
        } else {
            // Fits on current line — append.
            out.WriteByte(32)
            for k := 0; k < wordLen; k++ { out.WriteByte(s[wordStart + k]) }
            lineLen = lineLen + 1 + wordLen
        }

        i = j
        // Consume one whitespace if present.
        if i < n && (s[i] == 32 || s[i] == 9) { i = i + 1 }
    }
    ret out.String()
}

// JustifyLeft pads `s` on the right with spaces to reach `width`.
// Returns s unchanged when already at/over width. Mirror of
// PadLeftSpace which left-pads.
fun JustifyLeft(s string, width int) string {
    var n int = len(s)
    if n >= width { ret "" + s }
    var b *bytes.Builder = bytes.NewBuilder()
    b.WriteString(s)
    for i := 0; i < width - n; i++ { b.WriteByte(32) }
    ret b.String()
}

// JustifyRight pads `s` on the left with spaces to reach `width`.
fun JustifyRight(s string, width int) string {
    var n int = len(s)
    if n >= width { ret "" + s }
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < width - n; i++ { b.WriteByte(32) }
    b.WriteString(s)
    ret b.String()
}

// JustifyCenter pads `s` symmetrically with spaces to reach `width`.
// When the deficit is odd, the extra space goes on the right.
fun JustifyCenter(s string, width int) string {
    var n int = len(s)
    if n >= width { ret "" + s }
    var deficit int = width - n
    var left int = deficit / 2
    var right int = deficit - left
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < left; i++ { b.WriteByte(32) }
    b.WriteString(s)
    for i := 0; i < right; i++ { b.WriteByte(32) }
    ret b.String()
}

// NewReader wraps s as an io.Reader (one-shot: the first Read returns the
// whole string, then "" = EOF). It returns the io.Reader interface rather
// than a concrete `strings.Reader` because volt's type namespace is global
// and `Reader` is io's interface — the concrete impl is io.StringReader.
// Feed it anywhere an io.Reader is wanted (io.Copy, exec stdin, ...).
fun NewReader(s string) io.Reader {
    ret io.NewStringReader(s)
}
