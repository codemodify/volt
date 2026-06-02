// json_format — a self-contained sample that parses JSON and emits
// a pretty-printed equivalent. Demonstrates how the volt stdlib's
// json package round-trips through Decode + EncodePretty cleanly.
//
// In a real program you'd accept a filename via os.Args and stream
// from stdin if absent; this sample hardcodes a payload to stay
// fully reproducible across machines (no input dependency).

package main

import "json"
import "log"
import "os"

fun main() int {
    var src string = "{\"name\":\"Alice\",\"age\":30,\"hobbies\":[\"hiking\",\"cooking\"],\"active\":true,\"manager\":null}"

    var doc *json.Value = nil
    var err error = nil
    doc, err = json.Decode(src)
    if err != nil {
        log.Println("decode failed: %s", err.Error())
        ret 1
    }

    // Pretty-print with two-space indent.
    var pretty string = json.EncodePretty(doc, "  ")
    log.Println(pretty)

    // Demonstrate the data is also accessible programmatically.
    // doc.kind 5 = object; ObjectAt(i) returns the i-th *Value.
    var keyCount int = doc.ObjectLen()
    log.Println("(decoded %d top-level keys)", keyCount)

    // Mark success per the project's exit-42 convention.
    if os.Exists("/proc/self") { ret 42 }
    ret 0
}
