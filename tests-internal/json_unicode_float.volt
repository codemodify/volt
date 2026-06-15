// json \uXXXX decoding + float tolerance (added for the AUR RPC, whose
// responses contain > escapes and Popularity floats).
package main
import "log"
import "json"
import "strconv"

fun main() int {
	var pass int = 0

	// \uXXXX (BMP) -> UTF-8: >='>', &='&'
	var a *json.Value = nil
	var ea error = nil
	a, ea = json.Decode("{\"d\":\"x\\u003ey \\u0026 z\"}")
	if ea == nil && a.ValAt(0).AsString() == "x>y & z" { pass = pass + 1 }

	// surrogate pair -> astral codepoint (U+1F600 grin); just confirm it
	// decodes without error and yields 4 UTF-8 bytes.
	var s *json.Value = nil
	var es error = nil
	s, es = json.Decode("{\"e\":\"\\uD83D\\uDE00\"}")
	if es == nil && len(s.ValAt(0).AsString()) == 4 { pass = pass + 1 }

	// float tolerance: parser consumes the whole token, value = int part.
	var f *json.Value = nil
	var ef error = nil
	f, ef = json.Decode("{\"pop\":1.2345,\"big\":2.0e3,\"ood\":null,\"v\":42}")
	if ef == nil { pass = pass + 1 }
	if f.ValAt(0).AsInt() == 1 { pass = pass + 1 }       // 1.2345 -> 1
	if f.ValAt(3).AsInt() == 42 { pass = pass + 1 }      // plain int intact

	// negative float
	var g *json.Value = nil
	var eg error = nil
	g, eg = json.Decode("[-3.5, -7]")
	if eg == nil && g.ArrayAt(0).AsInt() == -3 && g.ArrayAt(1).AsInt() == -7 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 6 { ret 42 }
	ret 0
}
