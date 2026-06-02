package main
import "log"
import "os"

fun main() int {
	var pass int = 0

	// GetenvOr — unset variable returns default.
	if os.GetenvOr("VOLT_NEVER_SET_12345_xyz", "fallback") == "fallback" { pass = pass + 1 }
	if os.GetenvOr("VOLT_NEVER_SET_12345_xyz", "") == "" { pass = pass + 1 }
	if os.GetenvOr("VOLT_NEVER_SET_12345_xyz", "8080") == "8080" { pass = pass + 1 }

	// GetenvOr — set variable returns actual value, NOT the default.
	// PATH is virtually always set on Linux. We don't know the exact
	// content, but it should not equal "fallback".
	if os.GetenvOr("PATH", "fallback") != "fallback" { pass = pass + 1 }
	if os.GetenvOr("PATH", "") != "" { pass = pass + 1 }   // assuming PATH non-empty

	// GetenvOr — preserves the exact value of the set variable.
	if os.GetenvOr("PATH", "ignored") == os.Getenv("PATH") { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 6 { ret 42 }
	ret 0
}
