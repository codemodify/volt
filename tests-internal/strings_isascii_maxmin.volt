package main
import "log"
import "strings"
import "slices"

// Positive test: strings.IsAscii + slices.MaxMinInt.

fun main() int {
	var pass int = 0

	// IsAscii — basic ASCII.
	if strings.IsAscii("hello world") { pass = pass + 1 }
	if strings.IsAscii("ABC 123 !@#") { pass = pass + 1 }

	// Empty.
	if strings.IsAscii("") { pass = pass + 1 }

	// Control bytes are still ASCII (in [0, 127]).
	if strings.IsAscii("\x00\x01\x7f") { pass = pass + 1 }

	// High-bit byte.
	if !strings.IsAscii("a\xffb") { pass = pass + 1 }
	if !strings.IsAscii("\x80") { pass = pass + 1 }

	// UTF-8 multi-byte sequence — has high-bit bytes.
	if !strings.IsAscii("café") { pass = pass + 1 }

	// Mixed: ascii then non-ascii.
	if !strings.IsAscii("hello\xe9") { pass = pass + 1 }

	// 0x7F is borderline ASCII (DEL).
	if strings.IsAscii("\x7f") { pass = pass + 1 }

	// MaxMinInt basic.
	var a []int = new(5) []int{3, 1, 4, 1, 5}
	var mx int = 0
	var mn int = 0
	mx, mn = slices.MaxMinInt(a)
	if mx == 5 { pass = pass + 1 }
	if mn == 1 { pass = pass + 1 }

	// Single element.
	var b []int = new(1) []int{42}
	mx, mn = slices.MaxMinInt(b)
	if mx == 42 { pass = pass + 1 }
	if mn == 42 { pass = pass + 1 }

	// Empty.
	var e []int = new(0) []int{}
	mx, mn = slices.MaxMinInt(e)
	if mx == 0 { pass = pass + 1 }
	if mn == 0 { pass = pass + 1 }

	// Negatives.
	var n []int = new(4) []int{-5, -1, -3, -10}
	mx, mn = slices.MaxMinInt(n)
	if mx == -1 { pass = pass + 1 }
	if mn == -10 { pass = pass + 1 }

	// All same.
	var s []int = new(3) []int{7, 7, 7}
	mx, mn = slices.MaxMinInt(s)
	if mx == 7 { pass = pass + 1 }
	if mn == 7 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 19 { ret 42 }
	ret 0
}
