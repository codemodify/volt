package main
import "log"
fun main() int {
    var m map[string]int = new {}
    // Insert 40 distinct keys — past the initial 16 buckets, triggers
    // multiple resizes (16 → 32 → 64).
    m["a"] = 1
    m["b"] = 2
    m["c"] = 3
    m["d"] = 4
    m["e"] = 5
    m["f"] = 6
    m["g"] = 7
    m["h"] = 8
    m["i"] = 9
    m["j"] = 10
    m["k"] = 11
    m["l"] = 12
    m["m"] = 13
    m["n"] = 14
    m["o"] = 15
    m["p"] = 16
    m["q"] = 17
    m["r"] = 18
    m["s"] = 19
    m["t"] = 20
    m["u"] = 21
    m["v"] = 22
    m["w"] = 23
    m["x"] = 24
    m["y"] = 25
    m["z"] = 26
    m["A"] = 27
    m["B"] = 28
    m["C"] = 29
    m["D"] = 30
    m["E"] = 31
    m["F"] = 32
    m["G"] = 33
    m["H"] = 34
    m["I"] = 35
    m["J"] = 36
    m["K"] = 37
    m["L"] = 38
    m["M"] = 39
    m["N"] = 40
    log.Println("inserted: %d", len(m))
    if len(m) == 40 {
        if m["a"] == 1 {
            if m["z"] == 26 {
                if m["N"] == 40 {
                    ret 42
                }
            }
        }
    }
    ret 0
}
