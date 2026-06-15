// field_containers — POSITIVE.
//
// Map and slice FIELDS support full read/write through the struct (the
// mutable-shared-state / mutex-server pattern): st.m["k"]=v, v:=st.m["k"],
// st.xs = append(st.xs, x), st.xs[i]. Reading a Copy value/element out of a
// container field copies a scalar and does NOT consume the struct.

package main

import "log"

type State struct {
    m  map[string]int
    xs []int
}

fun main() int {
    var st State = new State{}
    st.m = new {}
    st.xs = new {}

    st.m["hits"] = 1
    st.m["hits"] = st.m["hits"] + 1          // field read-modify-write
    if st.m["hits"] != 2 { ret 1 }
    if st.m["absent"] != 0 { ret 2 }         // missing key → zero, no crash

    st.xs = append(st.xs, 10)                 // slice-field self-append
    st.xs = append(st.xs, 20)
    var first int = st.xs[0]                  // slice-field read (no false move)
    if first != 10 { ret 3 }
    if len(st.xs) != 2 { ret 4 }

    st.m["hits"] = st.m["hits"] + len(st.xs)  // st still usable throughout
    if st.m["hits"] != 4 { ret 5 }

    log.Println("field containers: hits=%d xs=%d", st.m["hits"], len(st.xs))
    ret 42
}
