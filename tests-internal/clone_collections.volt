package main
fun main() int {
    var s []int = new []int{10, 20, 30, 40, 50}
    var t []int = clone(s)
    var m map[string]int = new {"a": 1, "b": 2, "c": 3}
    var n map[string]int = clone(m)
    if len(s) == 5 {
        if len(t) == 5 {
            if len(m) == 3 {
                if len(n) == 3 {
                    if n["b"] == 2 { ret 42 }
                }
            }
        }
    }
    ret 0
}
