// fmt.Sprintf / fmt.Errorf — format strings into fresh heap strings,
// or wrap a formatted message into an error. Built on string concat
// + volt_int_to_string / volt_bool_to_string runtime helpers.

package main

import "fmt"
import "log"

fun main() int {
    var pass int = 0

    var s1 string = fmt.Sprintf("hello, %s", "world")
    if s1 == "hello, world" { pass = pass + 1 }

    var s2 string = fmt.Sprintf("n=%d, b=%t, name=%s", 42, true, "alice")
    if s2 == "n=42, b=true, name=alice" { pass = pass + 1 }

    var s3 string = fmt.Sprintf("no verbs here")
    if s3 == "no verbs here" { pass = pass + 1 }

    var s4 string = fmt.Sprintf("%d", -123)
    if s4 == "-123" { pass = pass + 1 }

    var err error = fmt.Errorf("bad input: %d", 7)
    if err != nil {
        if err.Error() == "bad input: 7" { pass = pass + 1 }
    }

    // Roundtrip: Sprintf -> Atoi-like via string content
    var s5 string = fmt.Sprintf("answer=%d", 42)
    if s5 == "answer=42" { pass = pass + 1 }

    log.Println("pass=%d/6", pass)
    if pass == 6 { ret 42 }
    ret 0
}
