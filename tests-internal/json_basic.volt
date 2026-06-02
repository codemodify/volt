// encoding/json: Value tree, Encode, Decode, QuoteString roundtrips.

package main

import "json"
import "log"

fun main() int {
    var pass int = 0

    // QuoteString
    if json.QuoteString("hi") == "\"hi\"" { pass = pass + 1 }
    if json.QuoteString("a\"b") == "\"a\\\"b\"" { pass = pass + 1 }
    if json.QuoteString("a\nb") == "\"a\\nb\"" { pass = pass + 1 }

    // Encode primitives
    if json.Encode(json.Null()) == "null" { pass = pass + 1 }
    if json.Encode(json.Bool(true)) == "true" { pass = pass + 1 }
    if json.Encode(json.Bool(false)) == "false" { pass = pass + 1 }
    if json.Encode(json.Int(42)) == "42" { pass = pass + 1 }
    if json.Encode(json.Int(-7)) == "-7" { pass = pass + 1 }
    if json.Encode(json.String("hello")) == "\"hello\"" { pass = pass + 1 }

    // Encode array
    var items []*Value = new(3) []*Value{}
    items[0] = json.Int(1)
    items[1] = json.Int(2)
    items[2] = json.Int(3)
    if json.Encode(json.Array(items)) == "[1,2,3]" { pass = pass + 1 }

    // Encode object
    var keys []string = new(2) []string{}
    keys[0] = "name"
    keys[1] = "age"
    var vals []*Value = new(2) []*Value{}
    vals[0] = json.String("alice")
    vals[1] = json.Int(30)
    var obj *Value = json.Object(keys, vals)
    if json.Encode(obj) == "{\"name\":\"alice\",\"age\":30}" { pass = pass + 1 }

    // Decode primitives
    var v1 *Value = nil
    var e1 error = nil
    v1, e1 = json.Decode("null")
    if e1 == nil {
        if v1.Kind() == 0 { pass = pass + 1 }
    }
    var v2 *Value = nil
    var e2 error = nil
    v2, e2 = json.Decode("true")
    if e2 == nil {
        if v2.Kind() == 1 {
            if v2.AsBool() { pass = pass + 1 }
        }
    }
    var v3 *Value = nil
    var e3 error = nil
    v3, e3 = json.Decode("123")
    if e3 == nil {
        if v3.Kind() == 2 {
            if v3.AsInt() == 123 { pass = pass + 1 }
        }
    }
    var v4 *Value = nil
    var e4 error = nil
    v4, e4 = json.Decode("\"hello\\nworld\"")
    if e4 == nil {
        if v4.Kind() == 3 {
            if v4.AsString() == "hello\nworld" { pass = pass + 1 }
        }
    }

    // Decode array
    var v5 *Value = nil
    var e5 error = nil
    v5, e5 = json.Decode("[10, 20, 30]")
    if e5 == nil {
        if v5.Kind() == 4 {
            if v5.ArrayLen() == 3 {
                var a0 *Value = v5.ArrayAt(0)
                var a2 *Value = v5.ArrayAt(2)
                if a0.AsInt() == 10 {
                    if a2.AsInt() == 30 { pass = pass + 1 }
                }
            }
        }
    }

    // Decode object
    var v6 *Value = nil
    var e6 error = nil
    v6, e6 = json.Decode("{\"a\":1, \"b\":\"two\"}")
    if e6 == nil {
        if v6.Kind() == 5 {
            if v6.ObjectLen() == 2 {
                if v6.KeyAt(0) == "a" {
                    var ov0 *Value = v6.ValAt(0)
                    if ov0.AsInt() == 1 {
                        if v6.KeyAt(1) == "b" {
                            var ov1 *Value = v6.ValAt(1)
                            if ov1.AsString() == "two" { pass = pass + 1 }
                        }
                    }
                }
            }
        }
    }

    // Roundtrip: nested object with mixed types.
    var ikeys []string = new(2) []string{}
    ikeys[0] = "x"
    ikeys[1] = "tags"
    var ivals []*Value = new(2) []*Value{}
    ivals[0] = json.Int(7)
    var tagItems []*Value = new(2) []*Value{}
    tagItems[0] = json.String("a")
    tagItems[1] = json.String("b")
    ivals[1] = json.Array(tagItems)
    var nested *Value = json.Object(ikeys, ivals)
    var encoded string = json.Encode(nested)

    var decoded *Value = nil
    var derr error = nil
    decoded, derr = json.Decode(encoded)
    if derr == nil {
        if decoded.Kind() == 5 {
            if decoded.ObjectLen() == 2 {
                var dv0 *Value = decoded.ValAt(0)
                var dv1 *Value = decoded.ValAt(1)
                if dv0.AsInt() == 7 {
                    if dv1.ArrayLen() == 2 { pass = pass + 1 }
                }
            }
        }
    }

    // Error path: malformed input
    var verr *Value = nil
    var eerr error = nil
    verr, eerr = json.Decode("{bad}")
    if eerr != nil {
        if verr == nil { pass = pass + 1 }
    }

    log.Println("pass=%d/19", pass)
    if pass == 19 { ret 42 }
    ret 0
}
