package main
import "log"
import "crypto/rand"
import "strings"

fun main() int {
	var pass int = 0

	// String — n <= 0 returns "".
	if rand.String(0, "ABC") == "" { pass = pass + 1 }
	if rand.String(-1, "ABC") == "" { pass = pass + 1 }

	// String — empty alphabet returns "".
	if rand.String(5, "") == "" { pass = pass + 1 }

	// String — length matches n.
	if len(rand.String(8, "ABC")) == 8 { pass = pass + 1 }
	if len(rand.String(32, "abcdefgh")) == 32 { pass = pass + 1 }
	if len(rand.String(100, "01")) == 100 { pass = pass + 1 }

	// String — every output byte is from the supplied alphabet.
	var alpha string = "XYZ"
	var s string = rand.String(20, alpha)
	var allFromAlpha bool = true
	for i := 0; i < len(s); i++ {
		if strings.IndexByte(alpha, s[i]) < 0 { allFromAlpha = false }
	}
	if allFromAlpha { pass = pass + 1 }

	// String — single-char alphabet produces all-same output.
	var solo string = rand.String(10, "Q")
	if solo == "QQQQQQQQQQ" { pass = pass + 1 }

	// AlphanumString — n <= 0 returns "".
	if rand.AlphanumString(0) == "" { pass = pass + 1 }
	if rand.AlphanumString(-3) == "" { pass = pass + 1 }

	// AlphanumString — length matches.
	if len(rand.AlphanumString(16)) == 16 { pass = pass + 1 }
	if len(rand.AlphanumString(64)) == 64 { pass = pass + 1 }

	// AlphanumString — output is all alphanumeric.
	var token string = rand.AlphanumString(50)
	var allAlnum bool = true
	for i := 0; i < len(token); i++ {
		var c byte = token[i]
		var ok bool = false
		if c >= 48 { if c <= 57 { ok = true } }    // 0..9
		if c >= 65 { if c <= 90 { ok = true } }    // A..Z
		if c >= 97 { if c <= 122 { ok = true } }   // a..z
		if !ok { allAlnum = false }
	}
	if allAlnum { pass = pass + 1 }

	// AlphanumString — two calls produce different tokens (high entropy).
	var t1 string = rand.AlphanumString(32)
	var t2 string = rand.AlphanumString(32)
	if t1 != t2 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 14 { ret 42 }
	ret 0
}
