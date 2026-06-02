// strconv.ParseBool / FormatBool smoke.

package main

import "strconv"
import "log"

fun main() int {
    var pass int = 0

    // FormatBool
    if strconv.FormatBool(true)  == "true"  { pass = pass + 1 }
    if strconv.FormatBool(false) == "false" { pass = pass + 1 }

    // ParseBool: accepted true-forms
    var b bool = false
    var e error = nil
    b, e = strconv.ParseBool("true")
    if e == nil { if b { pass = pass + 1 } }
    b, e = strconv.ParseBool("True")
    if e == nil { if b { pass = pass + 1 } }
    b, e = strconv.ParseBool("TRUE")
    if e == nil { if b { pass = pass + 1 } }
    b, e = strconv.ParseBool("t")
    if e == nil { if b { pass = pass + 1 } }
    b, e = strconv.ParseBool("T")
    if e == nil { if b { pass = pass + 1 } }
    b, e = strconv.ParseBool("1")
    if e == nil { if b { pass = pass + 1 } }

    // ParseBool: accepted false-forms
    b, e = strconv.ParseBool("false")
    if e == nil { if !b { pass = pass + 1 } }
    b, e = strconv.ParseBool("False")
    if e == nil { if !b { pass = pass + 1 } }
    b, e = strconv.ParseBool("FALSE")
    if e == nil { if !b { pass = pass + 1 } }
    b, e = strconv.ParseBool("f")
    if e == nil { if !b { pass = pass + 1 } }
    b, e = strconv.ParseBool("F")
    if e == nil { if !b { pass = pass + 1 } }
    b, e = strconv.ParseBool("0")
    if e == nil { if !b { pass = pass + 1 } }

    // ParseBool: rejected forms
    b, e = strconv.ParseBool("yes")
    if e != nil { if !b { pass = pass + 1 } }   // err returns false bool
    b, e = strconv.ParseBool("")
    if e != nil { pass = pass + 1 }
    b, e = strconv.ParseBool("TrUe")             // mixed case beyond the accepted set
    if e != nil { pass = pass + 1 }

    // Round-trip
    var rt bool = false
    var rte error = nil
    rt, rte = strconv.ParseBool(strconv.FormatBool(true))
    if rte == nil { if rt { pass = pass + 1 } }
    rt, rte = strconv.ParseBool(strconv.FormatBool(false))
    if rte == nil { if !rt { pass = pass + 1 } }

    log.Println("pass=%d/19", pass)
    if pass == 19 { ret 42 }
    ret 0
}
