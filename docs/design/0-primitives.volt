// volt:noformat — spec file; hand-aligned.
// =====================================================================
// 0-primitives.volt — every built-in primitive type, declared and used
// =====================================================================
// Demonstrates the full set of primitive types.
//
// Aliases worth knowing:
//   int   == int64   (one machine word)
//   uint  == uint64
//   byte  == uint8
//   float == float64
//
// `error` and `any` are interface-shaped (opaque pointer); see interfaces.volt.
//
//   volt run docs/design/0-primitives.volt

package main

import "log"

fun main() {
    // ---- signed integers --------------------------------------------------
    var a int8  = 127                  // 1 byte,  -128..127
    var b int16 = 32000                // 2 bytes, -32768..32767
    var c int32 = 2000000000           // 4 bytes
    var d int64 = 9000000000           // 8 bytes
    var e int   = 42                   // alias for int64

    // ---- unsigned integers ------------------------------------------------
    var f uint8  = 255                 // alias: byte
    var g uint16 = 65000
    var h uint32 = 4000000000
    var i uint64 = 18000000000
    var j uint   = 99                  // alias for uint64

    // ---- bool / byte / string ---------------------------------------------
    var n byte   = 7                   // alias for uint8
    var o bool   = false
    var p string = "hello, volt"

    // ---- heap-allocated containers (more in allocation.volt) --------------
    var q []byte         = new {0, 0, 0, 0, 0, 0, 0, 0}
    var r map[string]int = new {"one": 1, "two": 2, "three": 3}

    // mixed-width integer arithmetic auto-widens to the largest operand.
    var sum int = a + b + c + d + e + f + g + h + i + j + n

    // print
    log.Println(p)
    if !o          { log.Println("bool = false") }
    if len(q) == 8 { log.Println("slice len = 8") }
    if len(r) == 3 { log.Println("map len = 3") }
    if sum > 0     { log.Println("mixed-width sum > 0") }

    log.Println("primitives ok")
}
