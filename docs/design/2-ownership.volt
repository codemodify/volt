// 2-ownership.volt — how volt handles memory: "VALUES OWN, BORROWS VISIT"
//
// THE WHOLE MODEL IN THREE RULES (a 10-year-old can hold these):
//
//   1. You make it, you own it.
//      `new T{...}` gives you a VALUE. When you leave the block it's tidied
//      up for you — automatically. No free(), no garbage collector.
//
//   2. You can lend it, but lends come back.
//      `&T` lets a function LOOK (read-only). `*T` lets it USE-AND-CHANGE in
//      place. Either way the borrow ends when the call ends — it can never be
//      returned, stored in a field/slice/map, or smuggled out in a closure.
//
//   3. Want someone to KEEP one? Give yours away, or give a copy.
//      Giving it away MOVES it (you can't use it afterwards). `.Clone()` makes
//      them their own.
//
// Everything else falls out of those three:
//   - No nil. "Absent" is `(T, bool)` or `(T, error)`. (The one exception:
//     `error` is nilable — but it is only ever COMPARED (`if err != nil`),
//     never read THROUGH, so it can never crash.)
//   - You can't keep a raw pointer, so values can't point in circles: every
//     value is a TREE with exactly ONE owner — which is why the compiler can
//     free it, exactly once, the moment its owner leaves scope.
//   - Recursion goes through a CONTAINER (`[]T`), never a stored pointer.

package main

import "log"

// =====================================================================
// Rule 1 — you make it, you own it. `new` builds a VALUE (no pointer).
// =====================================================================
type Point struct {
    x int
    y int
}

fun makePoint(n int) Point {             // a constructor returns a VALUE Point
    ret new Point{x: n, y: n * 2}        // `new` builds it; nothing points back
}

// =====================================================================
// Rule 2 — you can lend it, but lends come back.
//   &T = peek (read-only)      *T = loan (change in place)
// =====================================================================
fun look(p &Point) int {                 // peek: may read, may not change
    ret p.x + p.y
}

fun shift(p *Point, by int) {            // loan: may change it in place
    p.x = p.x + by
    p.y = p.y + by
}

// REJECTED — a borrow may not OUTLIVE the call that took it:
//     fun escape(p &Point) &Point { ret p }   // give back a copy: p.Clone()
//     type Watcher struct { eye &Point }      // a field can't hold a borrow

fun values() {
    var a Point = makePoint(5)           // a is MINE: (5, 10)
    var sum int = look(&a)               // lend it to read   -> 15
    shift(&a, 1)                         // lend it to change -> (6, 11)
    log.Println("a=(%d,%d) sum=%d", a.x, a.y, sum)
}                                         // a is tidied up here, automatically

// =====================================================================
// Rule 3 — give it away (MOVE), or give a copy. (Note owns a string, so
// it MOVES on pass; an all-number struct like Point would copy instead.)
// =====================================================================
type Note struct {
    text string
}

fun keep(n Note) Note { ret n }           // takes ownership, hands it back

fun handover() {
    var a Note = new Note{text: "hi"}
    var b Note = keep(a)                  // a MOVES into keep — `a` is now gone
    // log.Println("%s", a.text)          // REJECTED: `a` was given away above
    log.Println("b=%s", b.text)
}

// =====================================================================
// Recursion through a CONTAINER, never a stored pointer. No pointers to
// keep ⇒ no cycles ⇒ the whole tree has one owner and frees itself.
// =====================================================================
type Folder struct {
    name    string
    folders []Folder                      // a folder holds folders — just a list
}

fun trees() {
    var root Folder = new Folder{name: "root"}
    var sub  Folder = new Folder{name: "sub"}
    root.folders = append(root.folders, sub)   // sub moves IN — it's root's now
    log.Println("%s holds %s", root.name, root.folders[0].name)
}                                              // root frees its whole tree here

// =====================================================================
// No nil. Absence is a pair you can't deref by accident.
// =====================================================================
fun find(xs []int, want int) (int, bool) {
    var i int = 0
    for i = 0; i < len(xs); i++ {
        if xs[i] == want { ret i, true }
    }
    ret 0, false                          // no nil to return, no nil to crash on
}

fun absence() {
    var xs []int = new []int{1, 2, 3}
    var at int = 0
    var ok bool = false
    at, ok = find(xs, 2)
    if ok { log.Println("found 2 at index %d", at) }
    _, ok = find(xs, 9)
    if !ok { log.Println("9 not found (no crash, no nil)") }
}

fun main() int {
    values()
    handover()
    trees()
    absence()
    ret 42
}
