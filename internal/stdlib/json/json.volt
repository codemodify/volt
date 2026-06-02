// Package json: minimal JSON value tree + encode/decode.
//
// v1 scope:
//   - Value struct with a `kind` tag (no sum types, no type assertions
//     in volt yet) and slots for each variant.
//   - Constructors: Null / Bool / Int / String / Array / Object.
//   - Encode(v *Value) string                — full recursive encoder
//   - Decode(s string) (*Value, error)       — full recursive parser
//   - QuoteString / UnquoteString helpers
//
// Numbers are int (i64) — float numbers deferred until volt has
// explicit int↔float casts.
// No \uXXXX escape decoding yet (rejects them with an error).

package json

import "strings"
import "strconv"
import "errors"
import "bytes"

// Kind tags.
//   0 Null   1 Bool   2 Number (int)   3 String   4 Array   5 Object
type Value struct {
    kind  int
    boolV bool
    numV  int
    strV  string
    arr   []*Value
    keys  []string
    vals  []*Value
}

// ---- Constructors ---------------------------------------------------

fun Null() *Value {
    var v *Value = new Value {kind: 0}
    ret v
}

fun Bool(b bool) *Value {
    var v *Value = new Value {kind: 1, boolV: b}
    ret v
}

fun Int(n int) *Value {
    var v *Value = new Value {kind: 2, numV: n}
    ret v
}

fun String(s string) *Value {
    var v *Value = new Value {kind: 3, strV: s}
    ret v
}

fun Array(items []*Value) *Value {
    var v *Value = new Value {kind: 4, arr: items}
    ret v
}

fun Object(keys []string, vals []*Value) *Value {
    var v *Value = new Value {kind: 5, keys: keys, vals: vals}
    ret v
}

// ---- Accessors ------------------------------------------------------

fun (v *Value) Kind() int     { ret v.kind }
fun (v *Value) AsBool() bool  { ret v.boolV }
fun (v *Value) AsInt() int    { ret v.numV }
fun (v *Value) AsString() string { ret v.strV }
fun (v *Value) ArrayLen() int { ret len(v.arr) }
fun (v *Value) ArrayAt(i int) *Value {
    var arr []*Value = v.arr
    ret arr[i]
}
fun (v *Value) ObjectLen() int { ret len(v.keys) }
fun (v *Value) KeyAt(i int) string {
    var keys []string = v.keys
    ret keys[i]
}
fun (v *Value) ValAt(i int) *Value {
    var vals []*Value = v.vals
    ret vals[i]
}

// ---- QuoteString: escape + wrap with double quotes -----------------
fun QuoteString(s string) string {
    var b *bytes.Builder = bytes.NewBuilder()
    b.WriteByte(34)  // '"'
    var n int = len(s)
    for i:=0; i < n; i++ {
        var c byte = s[i]
        if c == 34       { b.WriteString("\\\"") } else
        if c == 92       { b.WriteString("\\\\") } else
        if c == 8        { b.WriteString("\\b")  } else
        if c == 9        { b.WriteString("\\t")  } else
        if c == 10       { b.WriteString("\\n")  } else
        if c == 12       { b.WriteString("\\f")  } else
        if c == 13       { b.WriteString("\\r")  } else
                         { b.WriteByte(c) }
    }
    b.WriteByte(34)
    ret b.String()
}

// ---- UnquoteString: parses "\"...\"" into the unescaped string -----
fun UnquoteString(s string) (string, error) {
    var n int = len(s)
    if n < 2 { ret "", errors.New("json: too short") }
    if s[0] != 34 { ret "", errors.New("json: missing opening quote") }
    if s[n-1] != 34 { ret "", errors.New("json: missing closing quote") }
    var b *bytes.Builder = bytes.NewBuilder()
    var i int = 1
    for i < n-1 {
        var c byte = s[i]
        if c == 92 {                       // '\\'
            if i + 1 >= n - 1 {
                ret "", errors.New("json: dangling escape")
            }
            var esc byte = s[i+1]
            var matched bool = true
            if esc == 34       { b.WriteByte(34)  } else
            if esc == 92       { b.WriteByte(92)  } else
            if esc == 47       { b.WriteByte(47)  } else
            if esc == 98       { b.WriteByte(8)   } else
            if esc == 102      { b.WriteByte(12)  } else
            if esc == 110      { b.WriteByte(10)  } else
            if esc == 114      { b.WriteByte(13)  } else
            if esc == 116      { b.WriteByte(9)   } else
            if esc == 117      { ret "", errors.New("json: \\u escapes not supported in v1") } else
                               { matched = false }
            if !matched { ret "", errors.New("json: bad escape") }
            i = i + 2
        } else {
            b.WriteByte(c)
            i = i + 1
        }
    }
    ret b.String(), nil
}

// ---- Encode: Value tree → JSON string -------------------------------
// EncodePretty serializes v with newlines + per-level indentation.
// `indent` is the per-level prefix (commonly "  " or "\t"). For
// scalars (null/bool/int/string) the output matches Encode — there's
// nothing to lay out. Arrays and objects expand onto multiple lines.
fun EncodePretty(v *Value, indent string) string {
    var b *bytes.Builder = bytes.NewBuilder()
    encodePrettyInto(v, indent, 0, b)
    ret b.String()
}

// encodePrettyInto uses the `"" + indent` BinaryExpr trick at each
// site where `indent` flows out (recursive calls, helper calls, and
// the inner b.WriteString) so volt's move-tracking sees a fresh
// string at the call site and keeps the parameter's `indent` alive
// across iterations.
fun encodePrettyInto(v *Value, indent string, depth int, b *bytes.Builder) {
    if v.kind == 0 { b.WriteString("null"); ret }
    if v.kind == 1 {
        if v.boolV { b.WriteString("true") } else { b.WriteString("false") }
        ret
    }
    if v.kind == 2 { b.WriteInt(v.numV); ret }
    if v.kind == 3 { b.WriteString(QuoteString(v.strV)); ret }
    if v.kind == 4 {
        var n int = len(v.arr)
        if n == 0 { b.WriteString("[]"); ret }
        b.WriteByte(91)    // '['
        b.WriteByte(10)    // '\n'
        for i:=0; i < n; i++ {
            writeIndentNTimes(b, "" + indent, depth + 1)
            encodePrettyInto(v.arr[i], "" + indent, depth + 1, b)
            if i < n - 1 { b.WriteByte(44) }   // ','
            b.WriteByte(10)
        }
        writeIndentNTimes(b, "" + indent, depth)
        b.WriteByte(93)    // ']'
        ret
    }
    if v.kind == 5 {
        var n int = len(v.keys)
        if n == 0 { b.WriteString("{}"); ret }
        b.WriteByte(123)   // '{'
        b.WriteByte(10)
        for i:=0; i < n; i++ {
            writeIndentNTimes(b, "" + indent, depth + 1)
            b.WriteString(QuoteString(v.keys[i]))
            b.WriteString(": ")
            encodePrettyInto(v.vals[i], "" + indent, depth + 1, b)
            if i < n - 1 { b.WriteByte(44) }
            b.WriteByte(10)
        }
        writeIndentNTimes(b, "" + indent, depth)
        b.WriteByte(125)   // '}'
        ret
    }
}

fun writeIndentNTimes(b *bytes.Builder, indent string, n int) {
    for i:=0; i < n; i++ {
        b.WriteString("" + indent)
    }
}

fun Encode(v *Value) string {
    if v.kind == 0 { ret "null" }
    if v.kind == 1 {
        if v.boolV { ret "true" }
        ret "false"
    }
    if v.kind == 2 { ret strconv.Itoa(v.numV) }
    if v.kind == 3 { ret QuoteString(v.strV) }
    if v.kind == 4 {
        var b *bytes.Builder = bytes.NewBuilder()
        b.WriteByte(91)    // '['
        var n int = len(v.arr)
        for i:=0; i < n; i++ {
            if i > 0 { b.WriteByte(44) }   // ','
            b.WriteString(Encode(v.arr[i]))
        }
        b.WriteByte(93)    // ']'
        ret b.String()
    }
    if v.kind == 5 {
        var b *bytes.Builder = bytes.NewBuilder()
        b.WriteByte(123)   // '{'
        var n int = len(v.keys)
        for i:=0; i < n; i++ {
            if i > 0 { b.WriteByte(44) }
            b.WriteString(QuoteString(v.keys[i]))
            b.WriteByte(58)   // ':'
            b.WriteString(Encode(v.vals[i]))
        }
        b.WriteByte(125)   // '}'
        ret b.String()
    }
    ret "null"
}

// ---- Decode: JSON string → Value tree -------------------------------

// skipWs returns the index of the first non-whitespace byte at or after
// i. Whitespace per RFC 8259 is space, tab, newline, carriage return.
fun skipWs(s string, i int) int {
    var n int = len(s)
    for i < n {
        var c byte = s[i]
        if c == 32 { i = i + 1 } else if c == 9 { i = i + 1 } else if c == 10 { i = i + 1 } else if c == 13 { i = i + 1 } else { break }
    }
    ret i
}

// decodeAt parses one JSON value starting at s[i] (whitespace-skipped).
// Returns (value, next_index, error). Recursive for arrays/objects.
fun decodeAt(s string, start int) (*Value, int, error) {
    var i int = skipWs(s, start)
    var n int = len(s)
    if i >= n {
        ret nil, i, errors.New("json: unexpected end of input")
    }
    var c byte = s[i]

    // null
    if c == 110 {                          // 'n'
        if i + 4 > n { ret nil, i, errors.New("json: bad null") }
        if s[i+1] != 117 { ret nil, i, errors.New("json: bad null") } // 'u'
        if s[i+2] != 108 { ret nil, i, errors.New("json: bad null") } // 'l'
        if s[i+3] != 108 { ret nil, i, errors.New("json: bad null") } // 'l'
        ret Null(), i + 4, nil
    }
    // true
    if c == 116 {                          // 't'
        if i + 4 > n { ret nil, i, errors.New("json: bad true") }
        if s[i+1] != 114 { ret nil, i, errors.New("json: bad true") } // 'r'
        if s[i+2] != 117 { ret nil, i, errors.New("json: bad true") } // 'u'
        if s[i+3] != 101 { ret nil, i, errors.New("json: bad true") } // 'e'
        ret Bool(true), i + 4, nil
    }
    // false
    if c == 102 {                          // 'f'
        if i + 5 > n { ret nil, i, errors.New("json: bad false") }
        if s[i+1] != 97 { ret nil, i, errors.New("json: bad false") }  // 'a'
        if s[i+2] != 108 { ret nil, i, errors.New("json: bad false") } // 'l'
        if s[i+3] != 115 { ret nil, i, errors.New("json: bad false") } // 's'
        if s[i+4] != 101 { ret nil, i, errors.New("json: bad false") } // 'e'
        ret Bool(false), i + 5, nil
    }
    // string
    if c == 34 {                           // '"'
        var j int = i + 1
        for j < n {
            if s[j] == 92 { j = j + 2 } else if s[j] == 34 { break } else { j = j + 1 }
        }
        if j >= n {
            ret nil, j, errors.New("json: unterminated string")
        }
        // s[i..j+1] is the quoted literal.
        var lit string = ""
        for k:=i; k <= j; k++ { lit = lit + chr(s[k]) }
        var unq string = ""
        var uerr error = nil
        unq, uerr = UnquoteString(lit)
        if uerr != nil {
            ret nil, j, uerr
        }
        ret String(unq), j + 1, nil
    }
    // number (integer only — leading '-' or digit)
    var isNum bool = false
    if c == 45 { isNum = true }            // '-'
    if c >= 48 {
        if c <= 57 { isNum = true }
    }
    if isNum {
        var j int = i
        if s[j] == 45 { j = j + 1 }
        for j < n {
            var d byte = s[j]
            if d < 48 { break }
            if d > 57 { break }
            j = j + 1
        }
        var lit string = ""
        for k:=i; k < j; k++ { lit = lit + chr(s[k]) }
        var num int = 0
        var nerr error = nil
        num, nerr = strconv.Atoi(lit)
        if nerr != nil { ret nil, j, nerr }
        ret Int(num), j, nil
    }
    // array
    if c == 91 {                           // '['
        var items []*Value = new(0) []*Value{}
        i = skipWs(s, i + 1)
        if i < n {
            if s[i] == 93 {                // ']'
                ret Array(items), i + 1, nil
            }
        }
        for i < n {
            var item *Value = nil
            var nx int = 0
            var ierr error = nil
            item, nx, ierr = decodeAt(s, i)
            if ierr != nil { ret nil, nx, ierr }
            items = append(items, item)
            i = skipWs(s, nx)
            if i >= n { ret nil, i, errors.New("json: bad array") }
            if s[i] == 93 { ret Array(items), i + 1, nil }
            if s[i] != 44 { ret nil, i, errors.New("json: expected ',' in array") }
            i = skipWs(s, i + 1)
        }
        ret nil, i, errors.New("json: unterminated array")
    }
    // object
    if c == 123 {                          // '{'
        var keys []string = new(0) []string{}
        var vals []*Value = new(0) []*Value{}
        i = skipWs(s, i + 1)
        if i < n {
            if s[i] == 125 {               // '}'
                ret Object(keys, vals), i + 1, nil
            }
        }
        for i < n {
            // Parse key as a string.
            if s[i] != 34 { ret nil, i, errors.New("json: object key must be string") }
            var keyVal *Value = nil
            var nx int = 0
            var ierr error = nil
            keyVal, nx, ierr = decodeAt(s, i)
            if ierr != nil { ret nil, nx, ierr }
            keys = append(keys, keyVal.strV)
            i = skipWs(s, nx)
            if i >= n { ret nil, i, errors.New("json: bad object") }
            if s[i] != 58 { ret nil, i, errors.New("json: expected ':' in object") }
            i = skipWs(s, i + 1)
            var val *Value = nil
            val, nx, ierr = decodeAt(s, i)
            if ierr != nil { ret nil, nx, ierr }
            vals = append(vals, val)
            i = skipWs(s, nx)
            if i >= n { ret nil, i, errors.New("json: bad object") }
            if s[i] == 125 { ret Object(keys, vals), i + 1, nil }
            if s[i] != 44 { ret nil, i, errors.New("json: expected ',' in object") }
            i = skipWs(s, i + 1)
        }
        ret nil, i, errors.New("json: unterminated object")
    }
    ret nil, i, errors.New("json: unrecognized token")
}

fun Decode(s string) (*Value, error) {
    var v *Value = nil
    var nx int = 0
    var err error = nil
    v, nx, err = decodeAt(s, 0)
    if err != nil { ret nil, err }
    nx = skipWs(s, nx)
    if nx != len(s) {
        ret nil, errors.New("json: trailing garbage")
    }
    ret v, nil
}
