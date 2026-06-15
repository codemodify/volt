// syscall.ReadLine / os.ReadLine (added for interactive prompts). On EOF
// (no stdin, as in the smoke runner) it returns "" without blocking or
// crashing. Interactive line reading is exercised manually.
package main
import "log"
import "os"
fun main() int {
	var line string = os.ReadLine()   // EOF here → ""
	if len(line) == 0 {
		log.Println("readline eof ok")
		ret 42
	}
	ret 0
}
