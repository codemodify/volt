// =====================================================================
// interfaces.volt — structural interfaces
// =====================================================================
// volt interfaces are nominal-by-name but structural-by-shape: any type
// whose methods match the interface's signatures satisfies it. There is
// no `impl` keyword and no nominal subtyping.
//
// An `interface` declares a set of method signatures. Any type whose
// methods cover that set satisfies the interface — no explicit
// declaration of conformance required.
//
//   volt run docs/design/interfaces.volt

package main

import "log"

// Method-receiver forms mirror the three forms of a value:
//   fun (c Cat)  m()   — method MOVES c (consumes; rare; for terminal ops)
//   fun (c &Cat) m()   — method takes READ ACCESS (many readers OK)
//   fun (c *Cat) m()   — method takes WRITE ACCESS (exclusive)

type Greeter interface {
    Greet()
}

type Cat struct {
    name string
}

fun (c &Cat) Greet() {
    log.Println("meow")
}

fun main() {
    var c Cat = new Cat{name: "tabby"}
    c.Greet()
    log.Println("interfaces design ok")
}
