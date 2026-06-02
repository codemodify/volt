// json.EncodePretty: indented multi-line encoder via bytes.Builder.

package main

import "json"
import "log"

fun main() int {
    var pass int = 0

    // Scalars look like Encode.
    if json.EncodePretty(json.Null(), "  ")        == "null"  { pass = pass + 1 }
    if json.EncodePretty(json.Bool(true), "  ")    == "true"  { pass = pass + 1 }
    if json.EncodePretty(json.Int(42), "  ")       == "42"    { pass = pass + 1 }
    if json.EncodePretty(json.String("hi"), "  ")  == "\"hi\"" { pass = pass + 1 }

    // Empty array / object are flat.
    var emptyArr []*json.Value = new(0) []*json.Value {}
    if json.EncodePretty(json.Array(emptyArr), "  ") == "[]" { pass = pass + 1 }
    var emptyKeys []string = new(0) []string {}
    var emptyVals []*json.Value = new(0) []*json.Value {}
    if json.EncodePretty(json.Object(emptyKeys, emptyVals), "  ") == "{}" { pass = pass + 1 }

    // Non-empty array: 3 elements, 2-space indent.
    var nums []*json.Value = new(3) []*json.Value { nil, nil, nil }
    nums[0] = json.Int(1)
    nums[1] = json.Int(2)
    nums[2] = json.Int(3)
    var arrOut string = json.EncodePretty(json.Array(nums), "  ")
    var arrExp string = "[\n  1,\n  2,\n  3\n]"
    if arrOut == arrExp { pass = pass + 1 }

    // Object with 2 keys.
    var keys []string = new(2) []string { "name", "age" }
    var vals []*json.Value = new(2) []*json.Value { nil, nil }
    vals[0] = json.String("alice")
    vals[1] = json.Int(30)
    var objOut string = json.EncodePretty(json.Object(keys, vals), "  ")
    var objExp string = "{\n  \"name\": \"alice\",\n  \"age\": 30\n}"
    if objOut == objExp { pass = pass + 1 }

    // Nested array inside object.
    var inner []*json.Value = new(2) []*json.Value { nil, nil }
    inner[0] = json.Int(7)
    inner[1] = json.Int(8)
    var nkeys []string = new(1) []string { "vals" }
    var nvals []*json.Value = new(1) []*json.Value { nil }
    nvals[0] = json.Array(inner)
    var nestOut string = json.EncodePretty(json.Object(nkeys, nvals), "  ")
    // {
    //   "vals": [
    //     7,
    //     8
    //   ]
    // }
    var nestExp string = "{\n  \"vals\": [\n    7,\n    8\n  ]\n}"
    if nestOut == nestExp { pass = pass + 1 }

    // Tab indent.
    var t1 []*json.Value = new(2) []*json.Value { nil, nil }
    t1[0] = json.Int(1)
    t1[1] = json.Int(2)
    if json.EncodePretty(json.Array(t1), "\t") == "[\n\t1,\n\t2\n]" { pass = pass + 1 }

    log.Println("pass=%d/10", pass)
    if pass == 10 { ret 42 }
    ret 0
}
