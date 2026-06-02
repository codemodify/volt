package main

import "log"

// Negative test: when a concrete type doesn't satisfy an interface,
// the error must name the missing methods so the user can fix it.
// Previously the message read "missing one of its methods" with no
// indication of which.
//
// Expected error: type Cat does not implement interface Animal (missing method(s): Speak, Name)

type Animal interface {
	Speak() string
	Name() string
}

type Cat struct {
	nameField string
}

fun main() int {
	var c Cat = new Cat{nameField: "Tom"}
	var a Animal = c
	log.Println(a)
	ret 0
}
