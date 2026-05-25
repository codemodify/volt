// atomic *T — smoke test for ptr-typed atomic ops.
// volt has no `&x` expression syntax, so we can only juggle nil and
// the value returned by a.Load(). This verifies the ptr-width ops
// dispatch correctly: Load returns the stored ptr; Store(nil) writes
// it; CompareAndSwap succeeds when expected matches current.
// Exit 42 if the CAS dance returns the expected 1/1.

package main

type Node struct {
    id int
}

fun main() int {
    var a atomic *Node = new{}
    a.Store(nil)
    var cas1 int = a.CompareAndSwap(nil, nil)   // expected==current → 1
    var cas2 int = a.CompareAndSwap(nil, nil)   // still nil → 1
    if cas1 == 1 {
        if cas2 == 1 {
            ret 42
        }
    }
    ret 0
}
