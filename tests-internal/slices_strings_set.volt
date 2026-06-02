package main
import "log"
import "slices"

// Positive test: slices.StringsToSet / SetContainsString —
// fast-membership-test helpers using map[string]bool as a set.

fun main() int {
	var pass int = 0

	// Basic set from a slice.
	var src []string = new(4) []string{"apple", "banana", "cherry", "date"}
	var set map[string]bool = slices.StringsToSet(src)
	if len(set) == 4 { pass = pass + 1 }

	// SetContainsString — present and absent.
	if slices.SetContainsString(set, "apple") { pass = pass + 1 }
	if slices.SetContainsString(set, "banana") { pass = pass + 1 }
	if !slices.SetContainsString(set, "grape") { pass = pass + 1 }

	// Duplicates collapse.
	var src2 []string = new(5) []string{"x", "y", "x", "y", "z"}
	var set2 map[string]bool = slices.StringsToSet(src2)
	if len(set2) == 3 { pass = pass + 1 }
	if slices.SetContainsString(set2, "x") { pass = pass + 1 }
	if slices.SetContainsString(set2, "z") { pass = pass + 1 }
	if !slices.SetContainsString(set2, "w") { pass = pass + 1 }

	// Empty input → empty set.
	var src3 []string = new(0) []string{}
	var set3 map[string]bool = slices.StringsToSet(src3)
	if len(set3) == 0 { pass = pass + 1 }
	if !slices.SetContainsString(set3, "anything") { pass = pass + 1 }

	// Practical: filter a slice keeping only allowed values.
	var allowed []string = new(2) []string{"GET", "POST"}
	var allowedSet map[string]bool = slices.StringsToSet(allowed)
	var methods []string = new(5) []string{"GET", "DELETE", "POST", "PATCH", "GET"}
	var filtered []string = new(0) []string{}
	var mn int = len(methods)
	for i := 0; i < mn; i++ {
		if slices.SetContainsString(allowedSet, methods[i]) {
			filtered = append(filtered, "" + methods[i])
		}
	}
	if len(filtered) == 3 { pass = pass + 1 }
	if filtered[0] == "GET" { pass = pass + 1 }
	if filtered[2] == "GET" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 13 { ret 42 }
	ret 0
}
