package main
import "log"
import "strings"

// Positive test: strings.NGrams + strings.IsAnagram.

fun main() int {
	var pass int = 0

	// NGrams — basic bigrams.
	var bi []string = strings.NGrams("hello", 2)
	if len(bi) == 4 { pass = pass + 1 }
	if bi[0] == "he" { pass = pass + 1 }
	if bi[1] == "el" { pass = pass + 1 }
	if bi[2] == "ll" { pass = pass + 1 }
	if bi[3] == "lo" { pass = pass + 1 }

	// NGrams — trigrams.
	var tri []string = strings.NGrams("abcde", 3)
	if len(tri) == 3 { pass = pass + 1 }
	if tri[0] == "abc" { pass = pass + 1 }
	if tri[1] == "bcd" { pass = pass + 1 }
	if tri[2] == "cde" { pass = pass + 1 }

	// NGrams — n == len(s) → single window.
	var full []string = strings.NGrams("abc", 3)
	if len(full) == 1 { pass = pass + 1 }
	if full[0] == "abc" { pass = pass + 1 }

	// NGrams — n=1 (unigrams).
	var uni []string = strings.NGrams("abc", 1)
	if len(uni) == 3 { pass = pass + 1 }
	if uni[0] == "a" { pass = pass + 1 }
	if uni[2] == "c" { pass = pass + 1 }

	// NGrams — n > len(s) → empty.
	var big []string = strings.NGrams("ab", 5)
	if len(big) == 0 { pass = pass + 1 }

	// NGrams — n <= 0 → empty.
	var zero []string = strings.NGrams("hello", 0)
	if len(zero) == 0 { pass = pass + 1 }
	var neg []string = strings.NGrams("hello", -1)
	if len(neg) == 0 { pass = pass + 1 }

	// NGrams — empty input.
	var empty []string = strings.NGrams("", 2)
	if len(empty) == 0 { pass = pass + 1 }

	// IsAnagram — true cases.
	if strings.IsAnagram("listen", "silent") { pass = pass + 1 }
	if strings.IsAnagram("dusty", "study") { pass = pass + 1 }
	if strings.IsAnagram("aabbcc", "ccbbaa") { pass = pass + 1 }

	// IsAnagram — identical is trivially anagram.
	if strings.IsAnagram("same", "same") { pass = pass + 1 }

	// IsAnagram — both empty.
	if strings.IsAnagram("", "") { pass = pass + 1 }

	// IsAnagram — false: length mismatch.
	if !strings.IsAnagram("abc", "abcd") { pass = pass + 1 }

	// IsAnagram — false: same length, different histogram.
	if !strings.IsAnagram("abc", "abd") { pass = pass + 1 }

	// IsAnagram — case-sensitive (byte-level).
	if !strings.IsAnagram("Listen", "silent") { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 26 { ret 42 }
	ret 0
}
