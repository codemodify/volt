// crypto/md5 smoke — RFC 1321 §A.5 test vectors.

package main

import "crypto/md5"
import "log"

fun main() int {
    var pass int = 0

    // RFC 1321 §A.5 test suite — canonical MD5 vectors.
    if md5.SumHex("") ==
        "d41d8cd98f00b204e9800998ecf8427e" {
        pass = pass + 1
    }
    if md5.SumHex("a") ==
        "0cc175b9c0f1b6a831c399e269772661" {
        pass = pass + 1
    }
    if md5.SumHex("abc") ==
        "900150983cd24fb0d6963f7d28e17f72" {
        pass = pass + 1
    }
    if md5.SumHex("message digest") ==
        "f96b697d7cb7938d525a2f31aaf161d0" {
        pass = pass + 1
    }
    if md5.SumHex("abcdefghijklmnopqrstuvwxyz") ==
        "c3fcd3d76192e4007dfb496cca67e13b" {
        pass = pass + 1
    }
    if md5.SumHex("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789") ==
        "d174ab98d277d9f5a5611c2c9f419d9f" {
        pass = pass + 1
    }
    if md5.SumHex("12345678901234567890123456789012345678901234567890123456789012345678901234567890") ==
        "57edf4a22be3c955ac49da2e2107b67a" {
        pass = pass + 1
    }
    // Block boundary stress: 64-byte exact block. Python-cross-checked.
    if md5.SumHex("1234567890123456789012345678901234567890123456789012345678901234") ==
        "eb6c4179c0a7c82cc2828c1e6338e165" {
        pass = pass + 1
    }

    log.Println("pass=%d/8", pass)
    if pass == 8 { ret 42 }
    ret 0
}
