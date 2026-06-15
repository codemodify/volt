#!/usr/bin/env volt
# hash_comments.volt — `#` line comments + a `#!` shebang on line 1.
# volt is scriptable: `chmod +x file && ./file` works via the shebang
# (which is just a `#` comment to the lexer), and `volt <file>` /
# `volt run <file>` execute it. `#`, `//`, and `/* */` all comment.

package main

import "log"

# a `#` comment between declarations
const Answer int = 42   # trailing `#` comment

fun main() int {
	# `#` comment inside a function body
	var n int = Answer   // mixed: `//` still works too
	/* and block comments */
	log.Println("n=%d", n)
	if n == 42 {
		ret 42   # success sentinel
	}
	ret 0
}
