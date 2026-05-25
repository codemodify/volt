package main
import "log"

type Stringer interface {
    String() string
}

type Greeter struct {
    name string
}

fun (g *Greeter) String() string {
    ret g.name
}

type Counter struct {
    n int
}

fun (c *Counter) String() string {
    ret "counter"
}

fun show(s Stringer) {
    log.Println(s.String())
}

fun main() int {
    var g Greeter = new Greeter{name: "hello"}
    var c Counter = new Counter{n: 42}

    var s1 Stringer = g
    var s2 Stringer = c

    show(s1)              // hello
    show(s2)              // counter
    ret 42
}
