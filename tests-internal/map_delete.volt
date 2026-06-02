// delete(m, key) builtin smoke — exercises both map[string]int and
// map[string]string via the Pass-98 box-via-heap-ptr path.

package main

import "maps"
import "log"

fun main() int {
    var pass int = 0

    // ---- map[string]int -------------------------------------------
    var m map[string]int = new {"a": 1, "b": 2, "c": 3}
    if maps.ContainsKeyStringInt(m, "b") { pass = pass + 1 }
    delete(m, "b")
    if !maps.ContainsKeyStringInt(m, "b") { pass = pass + 1 }
    if maps.ContainsKeyStringInt(m, "a") { pass = pass + 1 }   // others survive
    if maps.ContainsKeyStringInt(m, "c") { pass = pass + 1 }
    if len(m) == 2 { pass = pass + 1 }

    // Delete on missing key is a no-op.
    delete(m, "nope")
    if len(m) == 2 { pass = pass + 1 }

    // Delete then re-insert.
    delete(m, "a")
    m["a"] = 99
    if m["a"] == 99 { pass = pass + 1 }

    // Delete every entry → empty map.
    delete(m, "a")
    delete(m, "c")
    if len(m) == 0 { pass = pass + 1 }
    if !maps.ContainsKeyStringInt(m, "a") { pass = pass + 1 }

    // ---- map[string]string ----------------------------------------
    var sm map[string]string = new {"name": "alice", "city": "wonderland"}
    if sm["name"] == "alice" { pass = pass + 1 }
    delete(sm, "name")
    if sm["name"] == "" { pass = pass + 1 }   // gone → zero value
    if sm["city"] == "wonderland" { pass = pass + 1 }   // other survives
    if len(sm) == 1 { pass = pass + 1 }

    log.Println("pass=%d/13", pass)
    if pass == 13 { ret 42 }
    ret 0
}
