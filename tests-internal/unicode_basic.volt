// unicode smoke — ASCII classification + case folding.

package main

import "unicode"
import "log"

fun main() int {
    var pass int = 0

    // IsDigit
    if unicode.IsDigit(48)  { pass = pass + 1 }   // '0'
    if unicode.IsDigit(57)  { pass = pass + 1 }   // '9'
    if !unicode.IsDigit(47) { pass = pass + 1 }   // '/'
    if !unicode.IsDigit(58) { pass = pass + 1 }   // ':'

    // IsLetter / IsUpper / IsLower
    if unicode.IsUpper(65)  { pass = pass + 1 }   // 'A'
    if unicode.IsUpper(90)  { pass = pass + 1 }   // 'Z'
    if !unicode.IsUpper(91) { pass = pass + 1 }   // '['
    if unicode.IsLower(97)  { pass = pass + 1 }   // 'a'
    if unicode.IsLower(122) { pass = pass + 1 }   // 'z'
    if !unicode.IsLower(96) { pass = pass + 1 }   // '`'
    if unicode.IsLetter(65) { pass = pass + 1 }   // 'A'
    if unicode.IsLetter(97) { pass = pass + 1 }   // 'a'
    if !unicode.IsLetter(48) { pass = pass + 1 }  // '0'

    // IsAlphanumeric
    if unicode.IsAlphanumeric(65) { pass = pass + 1 }    // 'A'
    if unicode.IsAlphanumeric(48) { pass = pass + 1 }    // '0'
    if !unicode.IsAlphanumeric(32) { pass = pass + 1 }   // ' '

    // IsSpace
    if unicode.IsSpace(32)  { pass = pass + 1 }
    if unicode.IsSpace(9)   { pass = pass + 1 }
    if unicode.IsSpace(10)  { pass = pass + 1 }
    if !unicode.IsSpace(65) { pass = pass + 1 }

    // IsPrint
    if unicode.IsPrint(32)  { pass = pass + 1 }   // ' '
    if unicode.IsPrint(126) { pass = pass + 1 }   // '~'
    if !unicode.IsPrint(10) { pass = pass + 1 }   // '\n' not printable
    if !unicode.IsPrint(127) { pass = pass + 1 }  // DEL

    // ToUpper / ToLower
    if unicode.ToUpper(97) == 65 { pass = pass + 1 }    // 'a' → 'A'
    if unicode.ToUpper(65) == 65 { pass = pass + 1 }    // 'A' unchanged
    if unicode.ToUpper(48) == 48 { pass = pass + 1 }    // '0' unchanged
    if unicode.ToLower(65) == 97 { pass = pass + 1 }    // 'A' → 'a'
    if unicode.ToLower(97) == 97 { pass = pass + 1 }    // 'a' unchanged

    log.Println("pass=%d/29", pass)
    if pass == 29 { ret 42 }
    ret 0
}
