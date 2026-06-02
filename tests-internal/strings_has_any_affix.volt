package main
import "log"
import "strings"

// Positive test: strings.HasAnyPrefix + strings.HasAnySuffix.

fun main() int {
	var pass int = 0

	// HasAnyPrefix — matches first option.
	var p1 []string = new(3) []string{"http://", "https://", "ftp://"}
	if strings.HasAnyPrefix("http://example.com", p1) { pass = pass + 1 }

	// Matches middle option.
	if strings.HasAnyPrefix("https://example.com", p1) { pass = pass + 1 }

	// Matches last option.
	if strings.HasAnyPrefix("ftp://example.com", p1) { pass = pass + 1 }

	// No match.
	if !strings.HasAnyPrefix("mailto:test@example.com", p1) { pass = pass + 1 }

	// Empty list → false.
	var pe []string = new(0) []string{}
	if !strings.HasAnyPrefix("anything", pe) { pass = pass + 1 }

	// Empty s.
	if !strings.HasAnyPrefix("", p1) { pass = pass + 1 }

	// Empty prefix in list always matches.
	var pwe []string = new(2) []string{"xyz", ""}
	if strings.HasAnyPrefix("anything", pwe) { pass = pass + 1 }

	// Single-element list.
	var p2 []string = new(1) []string{"foo"}
	if strings.HasAnyPrefix("foobar", p2) { pass = pass + 1 }
	if !strings.HasAnyPrefix("barfoo", p2) { pass = pass + 1 }

	// HasAnySuffix — matches first option.
	var s1 []string = new(3) []string{".jpg", ".png", ".gif"}
	if strings.HasAnySuffix("photo.jpg", s1) { pass = pass + 1 }

	// Matches middle option.
	if strings.HasAnySuffix("logo.png", s1) { pass = pass + 1 }

	// Matches last option.
	if strings.HasAnySuffix("anim.gif", s1) { pass = pass + 1 }

	// No match.
	if !strings.HasAnySuffix("doc.pdf", s1) { pass = pass + 1 }

	// Empty list.
	var se []string = new(0) []string{}
	if !strings.HasAnySuffix("anything", se) { pass = pass + 1 }

	// Empty suffix always matches.
	var swe []string = new(2) []string{".xyz", ""}
	if strings.HasAnySuffix("anything", swe) { pass = pass + 1 }

	// Empty s, non-empty list — bare-prefix "" still matches but
	// .jpg suffix doesn't.
	if !strings.HasAnySuffix("", s1) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
