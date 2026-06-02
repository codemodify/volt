// strings.LastIndex / IndexAny / SplitN / EqualFold smoke.

package main

import "strings"
import "log"

fun main() int {
    var pass int = 0

    // LastIndex
    if strings.LastIndex("abcabc", "b")    == 4 { pass = pass + 1 }
    if strings.LastIndex("abcabc", "abc")  == 3 { pass = pass + 1 }
    if strings.LastIndex("abc", "x")       == -1 { pass = pass + 1 }
    if strings.LastIndex("abc", "")        == 3 { pass = pass + 1 }   // empty → len(s)
    if strings.LastIndex("", "abc")        == -1 { pass = pass + 1 }
    if strings.LastIndex("abc", "abc")     == 0 { pass = pass + 1 }   // start

    // IndexAny
    if strings.IndexAny("hello", "aeiou")  == 1 { pass = pass + 1 }   // 'e'
    if strings.IndexAny("rhythm", "aeiou") == -1 { pass = pass + 1 }
    if strings.IndexAny("", "abc")         == -1 { pass = pass + 1 }
    if strings.IndexAny("abc", "")         == -1 { pass = pass + 1 }
    if strings.IndexAny("abc", "ca")       == 0 { pass = pass + 1 }   // first matched byte in s

    // SplitN
    var p []string = strings.SplitN("a,b,c,d", ",", 2)
    if len(p) == 2 { if p[0] == "a" { if p[1] == "b,c,d" { pass = pass + 1 } } }

    var p2 []string = strings.SplitN("a,b,c", ",", 5)   // n > parts → all parts
    if len(p2) == 3 { if p2[2] == "c" { pass = pass + 1 } }

    var p3 []string = strings.SplitN("a,b,c", ",", 0)   // n == 0 → empty
    if len(p3) == 0 { pass = pass + 1 }

    var p4 []string = strings.SplitN("a,b,c", ",", -1)  // n < 0 → all
    if len(p4) == 3 { pass = pass + 1 }

    var p5 []string = strings.SplitN("a,b,c", ",", 1)   // n == 1 → whole string
    if len(p5) == 1 { if p5[0] == "a,b,c" { pass = pass + 1 } }

    // EqualFold
    if strings.EqualFold("Hello", "hello")       { pass = pass + 1 }
    if strings.EqualFold("ABCxyz", "abcXYZ")     { pass = pass + 1 }
    if !strings.EqualFold("hello", "helo")       { pass = pass + 1 }   // different length
    if !strings.EqualFold("abc", "abd")          { pass = pass + 1 }
    if strings.EqualFold("", "")                 { pass = pass + 1 }
    if strings.EqualFold("123!@#", "123!@#")     { pass = pass + 1 }   // non-letters unchanged

    log.Println("pass=%d/22", pass)
    if pass == 22 { ret 42 }
    ret 0
}
