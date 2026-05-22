// v0.5 Phase 2: multi-return + multi-LHS short decl and assignment.
// divmod(17, 5) → (3, 2). 3 + 2*20 = 43; subtract 1 = 42.

package main

fun divmod(a int, b int) (int, int) {
    ret a / b, a % b
}

fun main() int {
    q, r := divmod(17, 5)
    ret q + r*20 - 1
}
