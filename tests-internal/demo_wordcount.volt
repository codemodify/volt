// Integration demo: word-frequency histogram.
// Exercises strings.Split + map[string]int + maps.KeysStringInt +
// sort.StringsAsc + bytes.Builder all in one realistic flow.

package main

import "strings"
import "maps"
import "sort"
import "bytes"
import "log"

fun main() int {
    var pass int = 0

    var text string = "the quick brown fox jumps over the lazy dog and the dog jumps and the fox runs"
    var words []string = strings.Split(text, " ")

    // Count
    var counts map[string]int = new {}
    var wn int = len(words)
    for i:=0; i < wn; i++ {
        var w string = words[i]
        counts[w] = counts[w] + 1
    }

    // Spot-check a few known counts.
    if counts["the"]   == 4 { pass = pass + 1 }
    if counts["dog"]   == 2 { pass = pass + 1 }
    if counts["fox"]   == 2 { pass = pass + 1 }
    if counts["jumps"] == 2 { pass = pass + 1 }
    if counts["and"]   == 2 { pass = pass + 1 }
    if counts["over"]  == 1 { pass = pass + 1 }
    if counts["brown"] == 1 { pass = pass + 1 }

    // Number of distinct words.
    var keys []string = maps.KeysStringInt(counts)
    if len(keys) == 10 { pass = pass + 1 }

    // Sort + build histogram report via Builder (O(n) — no concat blow-up).
    keys = sort.StringsAsc(keys)
    var report *bytes.Builder = bytes.NewBuilder()
    var kn int = len(keys)
    for i:=0; i < kn; i++ {
        report.WriteString(keys[i])
        report.WriteByte(58)  // ':'
        // The count digit fits in one byte for our small text.
        var d byte = 48 + counts[keys[i]]   // '0' + n
        report.WriteByte(d)
        report.WriteByte(10)  // '\n'
    }
    var out string = report.String()

    // Expected histogram = 10 sorted keys, each "word:count\n".
    var expected string = "and:2\nbrown:1\ndog:2\nfox:2\njumps:2\nlazy:1\nover:1\nquick:1\nruns:1\nthe:4\n"
    if out == expected { pass = pass + 1 }

    log.Println("pass=%d/9", pass)
    if pass == 9 { ret 42 }
    ret 0
}
