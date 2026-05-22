// volt test discovery: has TestX functions, no main.
// Two tests pass, one fails.

package main

fun TestAddition() int {
    if 2 + 2 != 4 { ret 1 }
    ret 0
}

fun TestMultiplication() int {
    if 3 * 7 != 21 { ret 1 }
    ret 0
}

fun TestBuggyMath() int {
    if 2 + 2 == 5 { ret 0 }
    ret 1  // FAIL
}
