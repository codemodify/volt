// json_clone_immutable — ValAt/ArrayAt return independent deep clones, so a
// json.Value is immutable from the outside (like a string): pulling a child
// out hands back its own owned subtree. Exercises cloneValue recursively
// through object -> array -> object -> bool and checks content survives.

package main

import "json"
import "log"

fun main() int {
    var doc *json.Value = nil
    var err error = nil
    doc, err = json.Decode("{\"a\":[1,2,{\"b\":true}],\"c\":\"hi\"}")
    if err != nil {
        log.Println("decode failed: %s", err.Error())
        ret 1
    }

    // doc.ValAt(0) is the value for key "a" — an array — returned as a CLONE.
    var a *json.Value = doc.ValAt(0)
    if a.Kind() != json.KindArray { ret 2 }
    if a.ArrayLen() != 3 { ret 3 }

    // ArrayAt(2) is the nested object {"b":true} — another CLONE.
    var third *json.Value = a.ArrayAt(2)
    if third.Kind() != json.KindObject { ret 4 }

    // ValAt(0) on that object is the bool true — a CLONE of a scalar leaf.
    var b *json.Value = third.ValAt(0)
    if b.Kind() != json.KindBool { ret 5 }
    if b.AsBool() != true { ret 6 }

    // The clones re-encode to the same JSON as their source subtree.
    if json.Encode(a) != "[1,2,{\"b\":true}]" {
        log.Println("clone re-encode mismatch: %s", json.Encode(a))
        ret 7
    }

    log.Println("clone chain ok")
    ret 42
}
