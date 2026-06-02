// strings.Repeat / TrimPrefix / TrimSuffix / Trim smoke.

package main

import "strings"
import "log"

fun main() int {
    var pass int = 0

    // Repeat
    if strings.Repeat("ab", 3)  == "ababab" { pass = pass + 1 }
    if strings.Repeat("x", 0)   == ""       { pass = pass + 1 }
    if strings.Repeat("x", -1)  == ""       { pass = pass + 1 }
    if strings.Repeat("", 5)    == ""       { pass = pass + 1 }
    if strings.Repeat("-", 4)   == "----"   { pass = pass + 1 }
    if strings.Repeat("ab", 1)  == "ab"     { pass = pass + 1 }

    // TrimPrefix
    if strings.TrimPrefix("foobar", "foo")    == "bar"    { pass = pass + 1 }
    if strings.TrimPrefix("foobar", "baz")    == "foobar" { pass = pass + 1 }
    if strings.TrimPrefix("foo", "foo")       == ""       { pass = pass + 1 }
    if strings.TrimPrefix("", "x")            == ""       { pass = pass + 1 }
    if strings.TrimPrefix("abc", "")          == "abc"    { pass = pass + 1 }
    if strings.TrimPrefix("a", "abc")         == "a"      { pass = pass + 1 }   // shorter than prefix

    // TrimSuffix
    if strings.TrimSuffix("foobar", "bar")    == "foo"    { pass = pass + 1 }
    if strings.TrimSuffix("foobar", "baz")    == "foobar" { pass = pass + 1 }
    if strings.TrimSuffix("xyz.txt", ".txt")  == "xyz"    { pass = pass + 1 }
    if strings.TrimSuffix("", "x")            == ""       { pass = pass + 1 }
    if strings.TrimSuffix("a", "abc")         == "a"      { pass = pass + 1 }

    // Trim (cutset)
    if strings.Trim("  hello  ", " ")         == "hello"  { pass = pass + 1 }
    if strings.Trim("###hi###", "#")          == "hi"     { pass = pass + 1 }
    if strings.Trim("xyzabcxzy", "xyz")       == "abc"    { pass = pass + 1 }
    if strings.Trim("nothing", "")            == "nothing"{ pass = pass + 1 }
    if strings.Trim("aaa", "a")               == ""       { pass = pass + 1 }
    if strings.Trim("abc", "xyz")             == "abc"    { pass = pass + 1 }

    log.Println("pass=%d/23", pass)
    if pass == 23 { ret 42 }
    ret 0
}
