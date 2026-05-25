package main
import "log"

type Inner struct {
    id int
}

fun (i *Inner) Drop() {
    log.Println("InnerDrop")
}

type Outer struct {
    inner Inner
}

fun (o *Outer) Drop() {
    log.Println("OuterDrop")
}

// Expected at scope exit: "OuterDrop" then "InnerDrop".

fun main() int {
    var o Outer = new Outer{}
    ret o.inner.id + 42
}
