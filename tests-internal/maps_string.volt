// map[string]string round-trip + maps.{Keys,Values,Contains}StringString.
// Exercises the codegen widening that boxes string values behind the
// runtime's i64 value slot.

package main

import "maps"
import "sort"
import "log"

fun main() int {
    var pass int = 0

    // Build a map[string]string by set + read.
    var m map[string]string = new {"alpha": "first", "bravo": "second", "charlie": "third"}

    // Get back via index.
    if m["alpha"]   == "first"  { pass = pass + 1 }
    if m["bravo"]   == "second" { pass = pass + 1 }
    if m["charlie"] == "third"  { pass = pass + 1 }
    // Missing key returns empty string (zero value).
    if m["delta"] == "" { pass = pass + 1 }

    // Overwrite existing key.
    m["alpha"] = "FIRST"
    if m["alpha"] == "FIRST" { pass = pass + 1 }

    // Insert new key.
    m["delta"] = "fourth"
    if m["delta"] == "fourth" { pass = pass + 1 }

    // ContainsKey / ContainsValue.
    if maps.ContainsKeyStringString(m, "alpha")     { pass = pass + 1 }
    if !maps.ContainsKeyStringString(m, "echo")     { pass = pass + 1 }
    if maps.ContainsValueStringString(m, "second")  { pass = pass + 1 }
    if !maps.ContainsValueStringString(m, "nothere"){ pass = pass + 1 }

    // Keys + Values (order undefined → sort before comparing).
    var keys []string = maps.KeysStringString(m)
    keys = sort.StringsAsc(keys)
    if len(keys) == 4 { pass = pass + 1 }
    if keys[0] == "alpha"   { pass = pass + 1 }
    if keys[1] == "bravo"   { pass = pass + 1 }
    if keys[2] == "charlie" { pass = pass + 1 }
    if keys[3] == "delta"   { pass = pass + 1 }

    var vals []string = maps.ValuesStringString(m)
    vals = sort.StringsAsc(vals)
    if len(vals) == 4 { pass = pass + 1 }
    if vals[0] == "FIRST"  { pass = pass + 1 }
    if vals[1] == "fourth" { pass = pass + 1 }
    if vals[2] == "second" { pass = pass + 1 }
    if vals[3] == "third"  { pass = pass + 1 }

    log.Println("pass=%d/20", pass)
    if pass == 20 { ret 42 }
    ret 0
}
