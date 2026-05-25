package main
fun worker(p *int) {
    p = 5
}
fun main() int {
    var x int = 10
    run worker(x)         // expected: error — borrow can't cross threads
    ret 0
}
