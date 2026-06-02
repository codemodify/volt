package main
import "log"
import "os"
import "crypto/rand"

fun main() int {
	var pass int = 0

	var suffix string = rand.AlphanumString(12)
	var path string = "/tmp/volt_appendfile_" + suffix

	// AppendFile to a non-existent file creates it.
	if !os.Exists(path) { pass = pass + 1 }
	var e1 error = os.AppendFile(path, "first ", 420)   // 0644
	if e1 == nil { pass = pass + 1 }
	if os.Exists(path) { pass = pass + 1 }

	var data string = ""
	var er error = nil
	data, er = os.ReadFile(path)
	if er == nil { pass = pass + 1 }
	if data == "first " { pass = pass + 1 }

	// AppendFile preserves existing content and adds at the end.
	var e2 error = os.AppendFile(path, "second ", 420)
	if e2 == nil { pass = pass + 1 }
	data, er = os.ReadFile(path)
	if er == nil { pass = pass + 1 }
	if data == "first second " { pass = pass + 1 }

	// Append again.
	var e3 error = os.AppendFile(path, "third", 420)
	if e3 == nil { pass = pass + 1 }
	data, er = os.ReadFile(path)
	if er == nil { pass = pass + 1 }
	if data == "first second third" { pass = pass + 1 }

	// Empty append is a no-op write but still succeeds.
	var e4 error = os.AppendFile(path, "", 420)
	if e4 == nil { pass = pass + 1 }
	data, er = os.ReadFile(path)
	if data == "first second third" { pass = pass + 1 }

	// WriteFile vs AppendFile contrast: WriteFile truncates.
	var e5 error = os.WriteFile(path, "fresh", 420)
	if e5 == nil { pass = pass + 1 }
	data, er = os.ReadFile(path)
	if data == "fresh" { pass = pass + 1 }

	// AppendFile after WriteFile-truncate preserves the new content.
	var e6 error = os.AppendFile(path, "-tail", 420)
	if e6 == nil { pass = pass + 1 }
	data, er = os.ReadFile(path)
	if data == "fresh-tail" { pass = pass + 1 }

	// Cleanup.
	os.Remove(path)

	log.Println("pass=%d", pass)
	if pass == 17 { ret 42 }
	ret 0
}
