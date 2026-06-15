package main

import (
	"io"
	"bytes"
	"strings"
	"fmt"
)

// bytes.Builder satisfies io.Writer even though strings.Builder shares the
// bare type name "Builder" (volt's type namespace is global). The Pass-786
// fix package-qualifies interface vtable symbols (@bytes_Builder_Writer_vtable
// vs @strings_Builder_Writer_vtable) and tracks each value's owning package,
// so the two same-named types coexist without clobbering. Returns 42 on pass.
fun main() int {
	var (
		pass int = 0
		want int = 4
	)
	// io.Copy into a *bytes.Builder used as an io.Writer.
	var (
		b  *bytes.Builder = bytes.NewBuilder()
		_n int            = 0
		_e error          = nil
	)
	_n, _e = io.Copy(b, strings.NewReader("copied"))
	if b.String() == "copied" {
		pass = pass + 1
	}
	// Writing through the io.Writer interface shares the same buffer.
	var (
		w   io.Writer = b
		_n2 int       = 0
		_e2 error     = nil
	)
	_n2, _e2 = w.Write("-more")
	if b.String() == "copied-more" {
		pass = pass + 1
	}
	// strings.Builder (same bare name "Builder", different package) coexists
	// and keeps working for its own purpose — no vtable/type collision.
	var sb *strings.Builder = strings.NewBuilder()
	sb.WriteString("strings-side")
	if sb.String() == "strings-side" {
		pass = pass + 1
	}
	// The bytes.Builder is unaffected by the strings.Builder above.
	if b.String() == "copied-more" {
		pass = pass + 1
	}
	fmt.Printf("bytes-builder-writer pass=%d/%d b=[%s] sb=[%s]\n", pass, want, b.String(), sb.String())
	if pass == want {
		ret 42
	}
	ret 1
}
