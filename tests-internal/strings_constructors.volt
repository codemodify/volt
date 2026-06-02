// strings constructor operations — ToLower, ToUpper, TrimSpace,
// Replace, Split, Join. All build fresh strings via chr() + concat.

package main

import "strings"
import "log"

fun main() int {
    var pass int = 0

    if strings.ToLower("HELLO") == "hello" { pass = pass + 1 }
    if strings.ToLower("MiXeD") == "mixed" { pass = pass + 1 }
    if strings.ToUpper("hi") == "HI" { pass = pass + 1 }
    if strings.ToUpper("MiXeD") == "MIXED" { pass = pass + 1 }

    if strings.TrimSpace("  abc  ") == "abc" { pass = pass + 1 }
    if strings.TrimSpace("\t\nfoo\r\n") == "foo" { pass = pass + 1 }
    if strings.TrimSpace("nopad") == "nopad" { pass = pass + 1 }
    if strings.TrimSpace("   ") == "" { pass = pass + 1 }

    if strings.Replace("a.b.c", ".", "-") == "a-b-c" { pass = pass + 1 }
    if strings.Replace("aaa", "a", "bb") == "bbbbbb" { pass = pass + 1 }
    if strings.Replace("hello", "x", "y") == "hello" { pass = pass + 1 }

    var parts []string = strings.Split("a,b,c", ",")
    if len(parts) == 3 {
        if parts[0] == "a" {
            if parts[1] == "b" {
                if parts[2] == "c" { pass = pass + 1 }
            }
        }
    }

    var single []string = strings.Split("nosep", ",")
    if len(single) == 1 {
        if single[0] == "nosep" { pass = pass + 1 }
    }

    var joined string = strings.Join(parts, "-")
    if joined == "a-b-c" { pass = pass + 1 }

    var two []string = new(2) []string{}
    two[0] = "x"
    two[1] = "y"
    if strings.Join(two, "") == "xy" { pass = pass + 1 }

    log.Println("pass=%d/15", pass)
    if pass == 15 { ret 42 }
    ret 0
}
