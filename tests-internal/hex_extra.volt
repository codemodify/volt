package main
import "log"
import "encoding/hex"

fun main() int {
	var pass int = 0

	// EncodeToStringUpper — basic uppercase output.
	if hex.EncodeToStringUpper("hello") == "68656C6C6F" { pass = pass + 1 }
	if hex.EncodeToStringUpper("") == "" { pass = pass + 1 }

	// EncodeToStringUpper — every nibble's uppercase form.
	// 0xDE 0xAD 0xBE 0xEF → "DEADBEEF"
	if hex.EncodeToStringUpper("\xde\xad\xbe\xef") == "DEADBEEF" { pass = pass + 1 }

	// EncodeToStringUpper — all digits.
	if hex.EncodeToStringUpper("\x01\x23\x45\x67\x89\xab\xcd\xef") == "0123456789ABCDEF" { pass = pass + 1 }

	// EncodeToString (existing) — lowercase, same input.
	if hex.EncodeToString("\xde\xad\xbe\xef") == "deadbeef" { pass = pass + 1 }

	// DecodeString round-trips with both forms.
	var dec1 string = ""
	var err1 error = nil
	dec1, err1 = hex.DecodeString("DEADBEEF")
	if err1 == nil { pass = pass + 1 }
	if dec1 == "\xde\xad\xbe\xef" { pass = pass + 1 }

	var dec2 string = ""
	var err2 error = nil
	dec2, err2 = hex.DecodeString("deadbeef")
	if err2 == nil { pass = pass + 1 }
	if dec2 == "\xde\xad\xbe\xef" { pass = pass + 1 }

	// Mixed-case decode works.
	var dec3 string = ""
	var err3 error = nil
	dec3, err3 = hex.DecodeString("DeAdBeEf")
	if err3 == nil { pass = pass + 1 }
	if dec3 == "\xde\xad\xbe\xef" { pass = pass + 1 }

	// EncodedLen / DecodedLen.
	if hex.EncodedLen(0) == 0 { pass = pass + 1 }
	if hex.EncodedLen(1) == 2 { pass = pass + 1 }
	if hex.EncodedLen(8) == 16 { pass = pass + 1 }
	if hex.EncodedLen(32) == 64 { pass = pass + 1 }

	if hex.DecodedLen(0) == 0 { pass = pass + 1 }
	if hex.DecodedLen(2) == 1 { pass = pass + 1 }
	if hex.DecodedLen(64) == 32 { pass = pass + 1 }
	if hex.DecodedLen(5) == 2 { pass = pass + 1 }   // odd truncates

	log.Println("pass=%d", pass)
	if pass == 19 { ret 42 }
	ret 0
}
