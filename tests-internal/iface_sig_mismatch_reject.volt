package main

import "log"

// Negative test: a concrete type whose method name matches an
// interface method but whose signature doesn't (different param
// types or return types) used to silently pass the impl check —
// the user only saw a confusing downstream call-site error. Now
// the impl check does structural signature matching and reports
// the mismatched method names.
//
// Expected error: type FakeWriter does not implement interface Writer (signature mismatch on method(s): Write)

type Writer interface {
	Write(s string) int
}

type FakeWriter struct {
	tag int
}

fun (f FakeWriter) Write(s string) string {
	ret s
}

fun main() int {
	var f FakeWriter = new FakeWriter{tag: 1}
	var w Writer = f
	log.Println(w)
	ret 0
}
