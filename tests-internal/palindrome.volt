package main
import "log"
import "math"
import "strings"

// Positive test: math.IsPalindromeInt + strings.IsPalindrome.

fun main() int {
	var pass int = 0

	// IsPalindromeInt — single digits + 0.
	if math.IsPalindromeInt(0) { pass = pass + 1 }
	if math.IsPalindromeInt(1) { pass = pass + 1 }
	if math.IsPalindromeInt(7) { pass = pass + 1 }

	// 2-digit symmetric.
	if math.IsPalindromeInt(11) { pass = pass + 1 }
	if math.IsPalindromeInt(99) { pass = pass + 1 }
	if !math.IsPalindromeInt(12) { pass = pass + 1 }
	if !math.IsPalindromeInt(10) { pass = pass + 1 }

	// 3-digit.
	if math.IsPalindromeInt(121) { pass = pass + 1 }
	if math.IsPalindromeInt(999) { pass = pass + 1 }
	if !math.IsPalindromeInt(123) { pass = pass + 1 }

	// Longer palindromes.
	if math.IsPalindromeInt(12321) { pass = pass + 1 }
	if math.IsPalindromeInt(1234321) { pass = pass + 1 }
	if !math.IsPalindromeInt(12345) { pass = pass + 1 }

	// Negatives — ignore sign.
	if math.IsPalindromeInt(-121) { pass = pass + 1 }
	if !math.IsPalindromeInt(-123) { pass = pass + 1 }

	// Trailing zero — only palindrome if leading zero (i.e. 0).
	if !math.IsPalindromeInt(120) { pass = pass + 1 }
	if !math.IsPalindromeInt(1000) { pass = pass + 1 }

	// IsPalindrome — basic.
	if strings.IsPalindrome("racecar") { pass = pass + 1 }
	if strings.IsPalindrome("abba") { pass = pass + 1 }
	if strings.IsPalindrome("a") { pass = pass + 1 }
	if strings.IsPalindrome("") { pass = pass + 1 }
	if !strings.IsPalindrome("hello") { pass = pass + 1 }

	// Case-sensitive.
	if !strings.IsPalindrome("Racecar") { pass = pass + 1 }   // R != r

	// Whitespace-sensitive.
	if !strings.IsPalindrome("race car") { pass = pass + 1 }   // space != r

	// Two-character checks.
	if strings.IsPalindrome("aa") { pass = pass + 1 }
	if !strings.IsPalindrome("ab") { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 26 { ret 42 }
	ret 0
}
