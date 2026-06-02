// hash/fnv smoke test against published FNV-1a vectors.

package main

import "hash/fnv"
import "log"

fun main() int {
    var pass int = 0

    // Empty string: hash == offset.
    if fnv.HashStr32("") == 2166136261 { pass = pass + 1 }
    if fnv.HashStr64("") == -3750763034362895579 { pass = pass + 1 }

    // Single byte "a".
    if fnv.HashStr32("a") == 3826002220 { pass = pass + 1 }
    if fnv.HashStr64("a") == -5808556873153909620 { pass = pass + 1 }

    // "foobar".
    if fnv.HashStr32("foobar") == 3214735720 { pass = pass + 1 }
    if fnv.HashStr64("foobar") == -8821353812377114648 { pass = pass + 1 }

    // Determinism: same input twice → same output.
    if fnv.HashStr32("repeat") == fnv.HashStr32("repeat") { pass = pass + 1 }
    if fnv.HashStr64("repeat") == fnv.HashStr64("repeat") { pass = pass + 1 }

    // Avalanche-ish: one bit difference yields very different output.
    if fnv.HashStr32("a") != fnv.HashStr32("b") { pass = pass + 1 }

    log.Println("pass=%d/9", pass)
    if pass == 9 { ret 42 }
    ret 0
}
