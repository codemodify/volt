package main
import "log"
type Box struct {
    n int
}
fun main() int {
    var b Box = new Box{n: 7}
    var y any = b
    log.Println("stored any")
    if y == nil { ret 0 }
    ret 42
}
