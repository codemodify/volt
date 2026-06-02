// maps package smoke — Keys / Values / ContainsKey / ContainsValue.

package main

import "maps"
import "sort"
import "log"

fun main() int {
    var pass int = 0

    var m map[string]int = new {"alpha": 1, "bravo": 2, "charlie": 3}

    // ContainsKey
    if maps.ContainsKeyStringInt(m, "alpha")   { pass = pass + 1 }
    if !maps.ContainsKeyStringInt(m, "delta")  { pass = pass + 1 }

    // ContainsValue
    if maps.ContainsValueStringInt(m, 2)       { pass = pass + 1 }
    if !maps.ContainsValueStringInt(m, 99)     { pass = pass + 1 }

    // Keys + Values (order isn't guaranteed → sort before comparing)
    var keys []string = maps.KeysStringInt(m)
    if len(keys) == 3 { pass = pass + 1 }
    keys = sort.StringsAsc(keys)
    if keys[0] == "alpha"   { pass = pass + 1 }
    if keys[1] == "bravo"   { pass = pass + 1 }
    if keys[2] == "charlie" { pass = pass + 1 }

    var vals []int = maps.ValuesStringInt(m)
    if len(vals) == 3 { pass = pass + 1 }
    vals = sort.IntsAsc(vals)
    if vals[0] == 1 { pass = pass + 1 }
    if vals[1] == 2 { pass = pass + 1 }
    if vals[2] == 3 { pass = pass + 1 }

    // Empty map
    var em map[string]int = new {}
    var ek []string = maps.KeysStringInt(em)
    if len(ek) == 0 { pass = pass + 1 }
    if !maps.ContainsKeyStringInt(em, "x") { pass = pass + 1 }

    log.Println("pass=%d/14", pass)
    if pass == 14 { ret 42 }
    ret 0
}
