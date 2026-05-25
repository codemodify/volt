// atomic *T — smoke test for ptr-typed atomic ops.
// volt has no `&x` expression syntax, so we can only juggle nil and
// the value returned by a.Read(). This verifies the ptr-width ops
// dispatch correctly: Read returns the stored ptr; Write(nil) writes
// it; CompSwap succeeds when expected matches current.
// Exit 42 if both CompSwap calls return true.

package main

type Node struct {
    id int
}

fun main() int {
    var a atomic *Node = new {}
    a.Write(nil)
    var cas1 bool = a.CompSwap(nil, nil)   // expected==current → true
    var cas2 bool = a.CompSwap(nil, nil)   // still nil → true
    if cas1 {
        if cas2 {
            ret 42
        }
    }
    ret 0
}
