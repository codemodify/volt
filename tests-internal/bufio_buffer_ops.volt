package main
import "log"
import "bufio"

fun discard(s string) (int, error) {
	ret len(s), nil
}

fun main() int {
	var pass int = 0

	var b *bufio.Buffer = bufio.New(discard)

	// Len — fresh buffer is empty.
	if b.Len() == 0 { pass = pass + 1 }
	if b.String() == "" { pass = pass + 1 }

	// Len — after WriteString.
	b.WriteString("hello")
	if b.Len() == 5 { pass = pass + 1 }
	if b.String() == "hello" { pass = pass + 1 }

	// Len — accumulates across writes.
	b.WriteString(", world")
	if b.Len() == 12 { pass = pass + 1 }
	if b.String() == "hello, world" { pass = pass + 1 }

	// Flush — emits the buffer and resets Len.
	var n int = 0
	var err error = nil
	n, err = b.Flush()
	if err == nil { pass = pass + 1 }
	if n == 12 { pass = pass + 1 }
	if b.Len() == 0 { pass = pass + 1 }
	if b.String() == "" { pass = pass + 1 }

	// Reset — clears buffer.
	b.WriteString("abandon me")
	if b.Len() == 10 { pass = pass + 1 }
	if b.String() == "abandon me" { pass = pass + 1 }
	b.Reset()
	if b.Len() == 0 { pass = pass + 1 }
	if b.String() == "" { pass = pass + 1 }

	// Reset then Flush — no-op flush.
	var n2 int = 0
	var err2 error = nil
	n2, err2 = b.Flush()
	if err2 == nil { pass = pass + 1 }
	if n2 == 0 { pass = pass + 1 }

	// Writing after reset works normally.
	b.WriteString("fresh start")
	if b.Len() == 11 { pass = pass + 1 }
	if b.String() == "fresh start" { pass = pass + 1 }
	var n3 int = 0
	var err3 error = nil
	n3, err3 = b.Flush()
	if err3 == nil { pass = pass + 1 }
	if n3 == 11 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 20 { ret 42 }
	ret 0
}
