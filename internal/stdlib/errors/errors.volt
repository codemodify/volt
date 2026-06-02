// Package errors: lightweight error construction.
//
// Volt's error story is intentionally simple: no wrapping, no chains,
// no Unwrap. An `error` is anything with `Error() string`. Construct
// concrete sentinel errors as package vars; compare with `==`.
//
//   var EOF error = errors.New("EOF")
//
//   if err == io.EOF { ... }                  // sentinel compare
//
// For an error with formatted context, build a fresh value through
// errors.New with the message already composed (typically via
// fmt.Sprintf when fmt lands).
//
// `errors.New` is a COMPILER INTRINSIC — see emitErrorsNew in codegen.
// The signature below is a stand-in so `import "errors"` resolves and
// the call type-checks.

package errors

fun New(msg string) error {
    ret nil
}
