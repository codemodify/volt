// fmt package: Print / Println / Printf to stdout (fd 1).
// Same format verbs as log (%d, %s, %t, %v, %%). Sprintf/Errorf are
// deferred — they need an accumulating buffer, not direct-write.

package main

import "fmt"

fun main() int {
    fmt.Print("a")
    fmt.Print("b")
    fmt.Println("c")
    fmt.Println("done")
    fmt.Printf("n=%d s=%s b=%t\n", 7, "ok", true)
    fmt.Println("multi: %d/%d", 3, 5)
    ret 42
}
