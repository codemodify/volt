// json_kind_consts.volt — the json package exposes its kind tags as
// named, cross-package constants (json.KindNull .. json.KindObject)
// instead of forcing callers to compare Kind() against magic ints.

package main

import "json"
import "log"

fun main() int {
    var pass int = 0

    // The constants have the documented integer values.
    if json.KindNull == 0   { pass = pass + 1 }
    if json.KindBool == 1   { pass = pass + 1 }
    if json.KindNumber == 2 { pass = pass + 1 }
    if json.KindString == 3 { pass = pass + 1 }
    if json.KindArray == 4  { pass = pass + 1 }
    if json.KindObject == 5 { pass = pass + 1 }

    // And they match what Decode actually tags a value with.
    var root *json.Value = nil
    var err error = nil
    root, err = json.Decode("{\"n\": 7, \"s\": \"hi\", \"a\": [true, null]}")
    if err != nil { log.Println("decode failed"); ret 0 }

    if root.Kind() == json.KindObject { pass = pass + 1 }

    var n int = root.ObjectLen()
    for i := 0; i < n; i++ {
        var k string = root.KeyAt(i)
        var v *json.Value = root.ValAt(i)
        if k == "n" && v.Kind() == json.KindNumber { pass = pass + 1 }
        if k == "s" && v.Kind() == json.KindString { pass = pass + 1 }
        if k == "a" && v.Kind() == json.KindArray  { pass = pass + 1 }
    }

    // Reach inside the array: a Bool then a Null.
    var arr *json.Value = root.ValAt(2)
    if arr.ArrayAt(0).Kind() == json.KindBool { pass = pass + 1 }
    if arr.ArrayAt(1).Kind() == json.KindNull { pass = pass + 1 }

    log.Println("pass=%d/12", pass)
    if pass == 12 { ret 42 }
    ret 0
}
