package main
import "log"
import "bytes"

fun main() int {
	var pass int = 0

	// WriteRepeat — basic count.
	var b1 *bytes.Builder = bytes.NewBuilder()
	b1.WriteRepeat(32, 5)        // 5 spaces
	if b1.Len() == 5 { pass = pass + 1 }
	if b1.String() == "     " { pass = pass + 1 }

	// WriteRepeat — count <= 0 is no-op.
	var b2 *bytes.Builder = bytes.NewBuilder()
	b2.WriteRepeat(32, 0)
	if b2.Len() == 0 { pass = pass + 1 }
	b2.WriteRepeat(32, -3)
	if b2.Len() == 0 { pass = pass + 1 }
	if b2.String() == "" { pass = pass + 1 }

	// WriteRepeat — mixed with other writes.
	var b3 *bytes.Builder = bytes.NewBuilder()
	b3.WriteString("name:")
	b3.WriteRepeat(32, 3)         // 3-space padding
	b3.WriteString("alice")
	if b3.String() == "name:   alice" { pass = pass + 1 }
	if b3.Len() == 13 { pass = pass + 1 }

	// WriteRepeat — typical use: separator framing.
	var b4 *bytes.Builder = bytes.NewBuilder()
	b4.WriteRepeat(45, 10)        // ten dashes
	b4.WriteString("\n")
	b4.WriteString("title")
	b4.WriteString("\n")
	b4.WriteRepeat(45, 10)
	if b4.String() == "----------\ntitle\n----------" { pass = pass + 1 }

	// WriteRepeat — large count.
	var b5 *bytes.Builder = bytes.NewBuilder()
	b5.WriteRepeat(120, 1000)     // 1000 'x'
	if b5.Len() == 1000 { pass = pass + 1 }
	var s string = b5.String()
	if len(s) == 1000 { pass = pass + 1 }
	if s[0] == 120 { pass = pass + 1 }
	if s[999] == 120 { pass = pass + 1 }
	if s[500] == 120 { pass = pass + 1 }

	// WriteRepeat — count of 1 equals WriteByte.
	var b6 *bytes.Builder = bytes.NewBuilder()
	b6.WriteRepeat(65, 1)
	if b6.String() == "A" { pass = pass + 1 }

	// WriteRepeat — works after Reset.
	var b7 *bytes.Builder = bytes.NewBuilder()
	b7.WriteString("garbage")
	b7.Reset()
	b7.WriteRepeat(46, 4)        // four dots
	if b7.String() == "...." { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 15 { ret 42 }
	ret 0
}
