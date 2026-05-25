// =====================================================================
// errors.volt — error handling
// =====================================================================
// The error-handling pattern is multi-return `(T, error)`. `error` is a
// structural interface — and interfaces are the language's only
// nullable type (`*T` and `&T` are non-nullable by construction).
//
// Convention: a function that can fail returns `(value, error)`. The
// caller checks `if err != nil` first, and only uses `value` when
// there's no error.
//
//   volt run docs/design/errors.volt

package main

import "log"

type File struct {
    handle int
}

// openFile returns either (file, nil) on success, or (zero-file, err)
// on failure. The error slot is nilable because `error` is interface-
// shaped; the value slot is always returned (callers check err first
// and only read the value when err == nil).
fun openFile(path string) (File, error) {
    var f File = new File{handle: 3}
    ret f, nil
}

fun main() {
    f, err := openFile("data.txt")
    if err != nil {
        log.Println("would handle error")
        ret
    }

    if f.handle == 3 {
        log.Println("errors design ok")
    }
}
