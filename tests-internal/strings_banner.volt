package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Basic: single-line banner.
	var b1 string = strings.Banner("hello!", 35)
	// Border = "##########" (text=6 + 2 pad + 2 border = 10)
	// Middle = "# hello! #"
	var want1 string = "##########\n# hello! #\n##########"
	if b1 == want1 { pass = pass + 1 }

	// Multi-line: aligns to widest.
	var b2 string = strings.Banner("hi\nworld", 35)
	// Widest = 5 ("world"); inner = 7; border = "#########"
	// Row 1: "# hi    #" (hi padded to 5)
	// Row 2: "# world #"
	var want2 string = "#########\n# hi    #\n# world #\n#########"
	if b2 == want2 { pass = pass + 1 }

	// Different fill byte.
	var b3 string = strings.Banner("X", 42)  // '*'
	var want3 string = "*****\n* X *\n*****"
	if b3 == want3 { pass = pass + 1 }

	// Empty text → border + empty-middle + border.
	var b4 string = strings.Banner("", 35)
	// maxW=0 → inner=2 → border="####", middle="#  #"
	var want4 string = "####\n#  #\n####"
	if b4 == want4 { pass = pass + 1 }

	// Three-line content.
	var b5 string = strings.Banner("a\nbb\nccc", 35)
	// Widest = 3 ("ccc"); inner = 5; border = "#######"
	var want5 string = "#######\n# a   #\n# bb  #\n# ccc #\n#######"
	if b5 == want5 { pass = pass + 1 }

	// RepeatByte basics.
	if strings.RepeatByte(35, 5) == "#####" { pass = pass + 1 }
	if strings.RepeatByte(42, 0) == "" { pass = pass + 1 }
	if strings.RepeatByte(45, -3) == "" { pass = pass + 1 }
	if strings.RepeatByte(65, 3) == "AAA" { pass = pass + 1 }

	// Banner with longer text.
	var b6 string = strings.Banner("Section Header", 61)  // '='
	// inner = 14 + 2 = 16, border = "=================="
	var want6 string = "==================\n= Section Header =\n=================="
	if b6 == want6 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 10 { ret 42 }
	ret 0
}
