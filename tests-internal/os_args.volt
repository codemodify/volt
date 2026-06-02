// os.Argc / os.ArgAt / os.Args / os.Getenv via _start argv/envp capture.
// Also exercises slice index-assignment (s[i] = v) which is needed to
// build the []string from individual ArgAt() calls in os.Args.
//
// We can't pass real args in the smoke runner, but Argc >= 1 (the
// program name is always there) so we exit 42 when basic invariants
// hold.

package main

import "log"
import "os"

fun main() int {
    var pass int = 0

    var n int = os.Argc()
    if n >= 1 { pass = pass + 1 }      // argv[0] always present

    var prog string = os.ArgAt(0)
    if len(prog) > 0 { pass = pass + 1 }

    var oob string = os.ArgAt(9999)
    if len(oob) == 0 { pass = pass + 1 }  // out-of-range → empty

    var args []string = os.Args()
    if len(args) == n { pass = pass + 1 }

    var nope string = os.Getenv("THIS_DOES_NOT_EXIST_VOLT_TEST")
    if len(nope) == 0 { pass = pass + 1 }

    log.Println("argc=%d prog=%s pass=%d/5", n, prog, pass)
    if pass == 5 { ret 42 }
    ret 0
}
