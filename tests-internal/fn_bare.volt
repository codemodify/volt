package main
import "log"

fun greet() {
    log.Println("hello from fn pointer")
}

fun shout(msg string) {
    log.Println("SHOUT: %s", msg)
}

fun main() int {
    var g fun() = greet
    g()

    var s fun(string) = shout
    s("hi")

    ret 42
}
