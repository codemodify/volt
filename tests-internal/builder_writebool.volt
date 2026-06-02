package main
import "log"
import "bytes"
import "strings"

fun main() int {
	var pass int = 0

	// bytes.Builder.WriteBool.
	var b1 *bytes.Builder = bytes.NewBuilder()
	b1.WriteBool(true)
	if b1.String() == "true" { pass = pass + 1 }
	if b1.Len() == 4 { pass = pass + 1 }

	var b2 *bytes.Builder = bytes.NewBuilder()
	b2.WriteBool(false)
	if b2.String() == "false" { pass = pass + 1 }
	if b2.Len() == 5 { pass = pass + 1 }

	// Mixed with WriteString.
	var b3 *bytes.Builder = bytes.NewBuilder()
	b3.WriteString("enabled=")
	b3.WriteBool(true)
	if b3.String() == "enabled=true" { pass = pass + 1 }

	// Sequence of bools.
	var b4 *bytes.Builder = bytes.NewBuilder()
	b4.WriteBool(true)
	b4.WriteByte(44)    // ','
	b4.WriteBool(false)
	b4.WriteByte(44)
	b4.WriteBool(true)
	if b4.String() == "true,false,true" { pass = pass + 1 }

	// After Reset.
	var b5 *bytes.Builder = bytes.NewBuilder()
	b5.WriteString("garbage")
	b5.Reset()
	b5.WriteBool(true)
	if b5.String() == "true" { pass = pass + 1 }

	// strings.Builder.WriteBool — parallel.
	var sb1 *strings.Builder = strings.NewBuilder()
	sb1.WriteBool(true)
	if sb1.String() == "true" { pass = pass + 1 }

	var sb2 *strings.Builder = strings.NewBuilder()
	sb2.WriteBool(false)
	if sb2.String() == "false" { pass = pass + 1 }

	var sb3 *strings.Builder = strings.NewBuilder()
	sb3.WriteString("flag=")
	sb3.WriteBool(false)
	sb3.WriteString(", count=")
	sb3.WriteInt(7)
	if sb3.String() == "flag=false, count=7" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 10 { ret 42 }
	ret 0
}
