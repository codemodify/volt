package main
import "log"
import "encoding/base64"

fun main() int {
	var pass int = 0

	// EncodeToStringURL — empty.
	if base64.EncodeToStringURL("") == "" { pass = pass + 1 }

	// EncodeToStringURL — basic ASCII (no `+` or `/` produced).
	if base64.EncodeToStringURL("hello") == "aGVsbG8=" { pass = pass + 1 }

	// EncodeToStringURL — input that triggers `+` and `/` in standard
	// form should produce `-` and `_` in URL form.
	// 0xFB = 11111011 binary; 0xFF = 11111111; encoded "FB FF" needs `+` and `/`.
	// Pick bytes that exercise the substitution.
	// "\xff\xff\xff" → "////" in standard, "____" in URL.
	if base64.EncodeToString("\xff\xff\xff") == "////" { pass = pass + 1 }
	if base64.EncodeToStringURL("\xff\xff\xff") == "____" { pass = pass + 1 }

	// "\xfb\xff\xbf" produces a `+`. Let me pick a known one.
	// 0xFB 0xEF 0xBE → binary 11111011 11101111 10111110
	//   chunks of 6: 111110 111110 111110 111110 = 62 62 62 62 = + + + +
	if base64.EncodeToString("\xfb\xef\xbe") == "++++" { pass = pass + 1 }
	if base64.EncodeToStringURL("\xfb\xef\xbe") == "----" { pass = pass + 1 }

	// Round-trip.
	var enc string = base64.EncodeToStringURL("\xff\xff\xff\xfb\xef\xbe")
	var dec string = ""
	var err error = nil
	dec, err = base64.DecodeStringURL(enc)
	if err == nil { pass = pass + 1 }
	if dec == "\xff\xff\xff\xfb\xef\xbe" { pass = pass + 1 }

	// Round-trip plain ASCII.
	var enc2 string = base64.EncodeToStringURL("user@example.com:secret")
	var dec2 string = ""
	var err2 error = nil
	dec2, err2 = base64.DecodeStringURL(enc2)
	if err2 == nil { pass = pass + 1 }
	if dec2 == "user@example.com:secret" { pass = pass + 1 }

	// Round-trip empty.
	var dec3 string = ""
	var err3 error = nil
	dec3, err3 = base64.DecodeStringURL("")
	if err3 == nil { pass = pass + 1 }
	if dec3 == "" { pass = pass + 1 }

	// DecodeStringURL accepts unpadded input (typical JWT-style).
	// "aGVsbG8" (no padding) → "hello"
	var dec4 string = ""
	var err4 error = nil
	dec4, err4 = base64.DecodeStringURL("aGVsbG8")
	if err4 == nil { pass = pass + 1 }
	if dec4 == "hello" { pass = pass + 1 }

	// DecodeStringURL accepts padded input too.
	var dec5 string = ""
	var err5 error = nil
	dec5, err5 = base64.DecodeStringURL("aGVsbG8=")
	if err5 == nil { pass = pass + 1 }
	if dec5 == "hello" { pass = pass + 1 }

	// DecodeStringURL rejects length-1-mod-4 inputs (forwards to
	// DecodeString which errors on n % 4 != 0).
	var dec6 string = ""
	var err6 error = nil
	dec6, err6 = base64.DecodeStringURL("a")
	if err6 != nil { pass = pass + 1 }
	if dec6 == "" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
