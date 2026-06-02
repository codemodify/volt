// strings package: Equal, HasPrefix, HasSuffix, Index, Contains,
// IndexByte, Count. All operate on byte sequences (UTF-8 safe at the
// byte level; rune-aware operations are deferred).

package main

import "log"
import "strings"

fun main() int {
    var pass int = 0
    if strings.Equal("hello", "hello") { pass = pass + 1 }
    if !strings.Equal("hello", "world") { pass = pass + 1 }
    if strings.HasPrefix("hello, world", "hello") { pass = pass + 1 }
    if !strings.HasPrefix("hi", "hello") { pass = pass + 1 }
    if strings.HasSuffix("hello.txt", ".txt") { pass = pass + 1 }
    if !strings.HasSuffix("file", ".txt") { pass = pass + 1 }
    if strings.Index("hello, world", "world") == 7 { pass = pass + 1 }
    if strings.Index("abc", "xyz") == -1 { pass = pass + 1 }
    if strings.Contains("hello, world", "world") { pass = pass + 1 }
    if !strings.Contains("hello", "xyz") { pass = pass + 1 }
    if strings.IndexByte("hello", 108) == 2 { pass = pass + 1 }
    if strings.Count("ababab", "ab") == 3 { pass = pass + 1 }
    log.Println("pass=%d/12", pass)
    if pass == 12 { ret 42 }
    ret 0
}
