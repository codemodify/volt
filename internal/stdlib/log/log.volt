// Package log: minimal logger.
//
// Surface:
//   Print  (fmt string, args...)   — write formatted args to stderr (no newline)
//   Println(fmt string, args...)   — write formatted args to stderr + "\n"
//
// Both also accept a single-string form: `log.Print("hello")`.
//
// Both are COMPILER INTRINSICS — see emitLogFormatCall in codegen. The
// bodies below are stand-ins that never run; they only exist so that
// `import "log"` resolves and method signatures are visible to the
// type-checker.
//
// There is no `Fatal` / `Fatalf` — volt avoids hiding control-flow exits
// behind logging functions. Use `syscall.Exit(code)` explicitly when you
// need to terminate the process.
//
// Supported format verbs:
//   %d   integer (any width — widened to i64 for printing)
//   %s   string
//   %t   bool (prints "true" / "false")
//   %v   auto-dispatch by argument type
//   %%   literal '%'

package log

import "syscall"

fun Print(s string) {
    syscall.Write(2, s)
}

fun Println(s string) {
    syscall.Write(2, s)
    syscall.Write(2, "\n")
}
