// crypto/sha1 smoke — FIPS / Python-cross-checked vectors.

package main

import "crypto/sha1"
import "log"

fun main() int {
    var pass int = 0

    // Empty
    if sha1.SumHex("") ==
        "da39a3ee5e6b4b0d3255bfef95601890afd80709" {
        pass = pass + 1
    }
    // FIPS 180-2 §A.1: "abc"
    if sha1.SumHex("abc") ==
        "a9993e364706816aba3e25717850c26c9cd0d89d" {
        pass = pass + 1
    }
    // FIPS 180-2 §A.2: long
    if sha1.SumHex("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq") ==
        "84983e441c3bd26ebaae4aa1f95129e5e54670f1" {
        pass = pass + 1
    }
    // "hello world"
    if sha1.SumHex("hello world") ==
        "2aae6c35c94fcfb415dbe95f408b9ce91ee846ed" {
        pass = pass + 1
    }
    // 64-byte block boundary
    if sha1.SumHex("1234567890123456789012345678901234567890123456789012345678901234") ==
        "c71490fc24aa3d19e11282da77032dd9cdb33103" {
        pass = pass + 1
    }
    // 56-byte (padding spills into a 2nd block). Python-cross-checked.
    if sha1.SumHex("12345678901234567890123456789012345678901234567890123456") ==
        "0a84666b66e843a4146088fb46aabaa998b4c2b1" {
        pass = pass + 1
    }

    log.Println("pass=%d/6", pass)
    if pass == 6 { ret 42 }
    ret 0
}
