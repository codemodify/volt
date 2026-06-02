// crypto/sha256 smoke — verifies against NIST test vectors.

package main

import "crypto/sha256"
import "log"

fun main() int {
    var pass int = 0

    // FIPS 180-2 Appendix C / NIST short-message vectors.
    if sha256.SumHex("") ==
        "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" {
        pass = pass + 1
    }
    if sha256.SumHex("abc") ==
        "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad" {
        pass = pass + 1
    }
    if sha256.SumHex("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq") ==
        "248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1" {
        pass = pass + 1
    }
    if sha256.SumHex("hello world") ==
        "b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9" {
        pass = pass + 1
    }
    // Block boundary: exactly 64 bytes.
    if sha256.SumHex("1234567890123456789012345678901234567890123456789012345678901234") ==
        "676491965ed3ec50cb7a63ee96315480a95c54426b0b72bca8a0d4ad1285ad55" {
        pass = pass + 1
    }
    // Block boundary: 56 bytes (one byte before length encoding triggers
    // a second block from the padding).
    if sha256.SumHex("12345678901234567890123456789012345678901234567890123456") ==
        "0be66ce72c2467e793202906000672306661791622e0ca9adf4a8955b2ed189c" {
        pass = pass + 1
    }

    log.Println("pass=%d/6", pass)
    if pass == 6 { ret 42 }
    ret 0
}
