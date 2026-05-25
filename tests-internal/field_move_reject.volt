package main
import "log"
type Pair struct {
    a string
    b string
}
fun consume(s string) {}
fun main() int {
    var p Pair = new Pair{a: "x", b: "y"}
    consume(p.a)        // p.a moved; conservative: marks p as moved
    log.Println(p.a)    // expected: error — use of moved value
    ret 0
}
