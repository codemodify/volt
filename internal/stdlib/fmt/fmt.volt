// Package fmt: formatted output to stdout (fd 1).
//
// Surface today:
//   Print  (s string)               — write s to stdout, no newline
//   Print  (fmt string, args...)    — write formatted to stdout, no newline
//   Println(s string)               — write s + "\n" to stdout
//   Println(fmt string, args...)    — write formatted + "\n" to stdout
//   Printf (fmt string, args...)    — alias for Println form without newline
//                                     handling differs: Printf does NOT add a newline
//
// Wait: Printf doesn't add a newline, Println does. That's Go's convention.
// In volt today, Printf is currently aliased to the same intrinsic as
// Println (both lower through the format walker). The trailing newline
// is controlled by which one you call:
//   - fmt.Print  / fmt.Printf  → no newline
//   - fmt.Println              → trailing "\n"
//
// All three are COMPILER INTRINSICS — stand-in bodies below.
//
// Supported verbs: %d, %s, %t, %v, %% (same as log).
// `fmt.Sprintf` / `fmt.Errorf` (string-returning) are deferred — they
// need an accumulating buffer rather than direct-write.

package fmt

import "io"

fun Print(s string) {}
fun Println(s string) {}
fun Printf(format string) {}
fun Sprintf(format string) string { ret "" }
fun Errorf(format string) error { ret nil }
fun Fprintf(w Writer, format string) (int, error) { ret 0, nil }
