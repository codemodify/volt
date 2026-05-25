// maps. map[string]int — set, get, len.
// Insert 3 entries, look up two, sum them with the count.

package main

fun main() int {
    var m map[string]int = new{}
    m["alpha"] = 10
    m["bravo"] = 17
    m["zulu"]  = 12

    var n int = len(m)              // 3
    var sum int = m["alpha"] + m["bravo"]  // 27
    ret sum + n + 12                // 27 + 3 + 12 = 42
}
