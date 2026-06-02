package main
import "log"
import "maps"

fun main() int {
	var pass int = 0

	// string→int.
	var mi map[string]int = new map[string]int {}
	mi["a"] = 1
	mi["b"] = 2
	mi["c"] = 3

	// Key present → returns value, ignores default.
	if maps.GetOrStringInt(mi, "a", -1) == 1 { pass = pass + 1 }
	if maps.GetOrStringInt(mi, "b", -1) == 2 { pass = pass + 1 }
	if maps.GetOrStringInt(mi, "c", -1) == 3 { pass = pass + 1 }

	// Key missing → returns default.
	if maps.GetOrStringInt(mi, "z", -1) == -1 { pass = pass + 1 }
	if maps.GetOrStringInt(mi, "missing", 42) == 42 { pass = pass + 1 }
	if maps.GetOrStringInt(mi, "", 99) == 99 { pass = pass + 1 }

	// Empty map → always default.
	var empty map[string]int = new map[string]int {}
	if maps.GetOrStringInt(empty, "a", 7) == 7 { pass = pass + 1 }
	if maps.GetOrStringInt(empty, "", 0) == 0 { pass = pass + 1 }

	// Present key with zero value → returns zero, NOT default.
	var mz map[string]int = new map[string]int {}
	mz["zero"] = 0
	if maps.GetOrStringInt(mz, "zero", 999) == 0 { pass = pass + 1 }

	// Present key with negative value.
	var mn map[string]int = new map[string]int {}
	mn["neg"] = -42
	if maps.GetOrStringInt(mn, "neg", 0) == -42 { pass = pass + 1 }

	// string→string.
	var ms map[string]string = new map[string]string {}
	ms["lang"] = "en"
	ms["region"] = "US"

	if maps.GetOrStringString(ms, "lang", "??") == "en" { pass = pass + 1 }
	if maps.GetOrStringString(ms, "region", "??") == "US" { pass = pass + 1 }
	if maps.GetOrStringString(ms, "tz", "UTC") == "UTC" { pass = pass + 1 }
	if maps.GetOrStringString(ms, "", "fallback") == "fallback" { pass = pass + 1 }

	// Empty string map → default.
	var emptyS map[string]string = new map[string]string {}
	if maps.GetOrStringString(emptyS, "anything", "x") == "x" { pass = pass + 1 }

	// Present key with empty-string value → returns "", NOT default.
	var msz map[string]string = new map[string]string {}
	msz["blank"] = ""
	if maps.GetOrStringString(msz, "blank", "default") == "" { pass = pass + 1 }

	// Config-style use case.
	var cfg map[string]string = new map[string]string {}
	cfg["host"] = "localhost"
	cfg["port"] = "8080"
	var host string = maps.GetOrStringString(cfg, "host", "0.0.0.0")
	var port string = maps.GetOrStringString(cfg, "port", "80")
	var proto string = maps.GetOrStringString(cfg, "proto", "http")
	if host == "localhost" { pass = pass + 1 }
	if port == "8080" { pass = pass + 1 }
	if proto == "http" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 19 { ret 42 }
	ret 0
}
