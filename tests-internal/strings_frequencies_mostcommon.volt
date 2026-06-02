package main
import "log"
import "strings"

// Positive test: strings.Frequencies + strings.MostCommonByte.

fun main() int {
	var pass int = 0

	// Frequencies — empty string.
	var f0 []int = strings.Frequencies("")
	if len(f0) == 256 { pass = pass + 1 }
	if f0[65] == 0 { pass = pass + 1 }

	// Frequencies — single char.
	var f1 []int = strings.Frequencies("A")
	if f1[65] == 1 { pass = pass + 1 }
	if f1[66] == 0 { pass = pass + 1 }

	// Frequencies — "hello".
	var f2 []int = strings.Frequencies("hello")
	if f2[104] == 1 { pass = pass + 1 }   // 'h'
	if f2[101] == 1 { pass = pass + 1 }   // 'e'
	if f2[108] == 2 { pass = pass + 1 }   // 'l' twice
	if f2[111] == 1 { pass = pass + 1 }   // 'o'
	if f2[97] == 0 { pass = pass + 1 }    // 'a' absent

	// Frequencies — repeated content totals.
	var f3 []int = strings.Frequencies("aaa")
	if f3[97] == 3 { pass = pass + 1 }

	// Frequencies — high-bit byte.
	var f4 []int = strings.Frequencies("\xff\xff\xff\xfe")
	if f4[255] == 3 { pass = pass + 1 }
	if f4[254] == 1 { pass = pass + 1 }

	// MostCommonByte — single character.
	if strings.MostCommonByte("A") == 65 { pass = pass + 1 }

	// MostCommonByte — clear majority.
	if strings.MostCommonByte("hello") == 108 { pass = pass + 1 }   // 'l' twice

	// MostCommonByte — ties resolve to smallest byte value.
	if strings.MostCommonByte("ab") == 97 { pass = pass + 1 }       // tied 1 each, smallest is 'a' = 97

	// MostCommonByte — empty returns 0.
	if strings.MostCommonByte("") == 0 { pass = pass + 1 }

	// MostCommonByte — all same character.
	if strings.MostCommonByte("zzzz") == 122 { pass = pass + 1 }

	// MostCommonByte — high-bit byte wins.
	if strings.MostCommonByte("\xff\xff\xff") == 255 { pass = pass + 1 }

	// Frequencies total == len(s).
	var total int = 0
	var f5 []int = strings.Frequencies("abracadabra")
	for i := 0; i < 256; i++ { total = total + f5[i] }
	if total == 11 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
