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

// Kind tags — the `kind` of a Value. Use these instead of raw ints:
//   if v.Kind() == json.KindObject { ... }
// (They can't be named Null/Bool/... because those are the constructor
// function names; the `Kind` prefix keeps them distinct.)
const KindNull   int = 0
const KindBool   int = 1
const KindNumber int = 2
const KindString int = 3
const KindArray  int = 4
const KindObject int = 5

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
    var v *Value = new Value {kind: KindNull}
    ret v
}

fun Bool(b bool) *Value {
    var v *Value = new Value {kind: KindBool, boolV: b}
    ret v
}

fun Int(n int) *Value {
    var v *Value = new Value {kind: KindNumber, numV: n}
    ret v
}

fun String(s string) *Value {
    var v *Value = new Value {kind: KindString, strV: s}
    ret v
}

fun Array(items []*Value) *Value {
    var v *Value = new Value {kind: KindArray, arr: items}
    ret v
}

fun Object(keys []string, vals []*Value) *Value {
    var v *Value = new Value {kind: KindObject, keys: keys, vals: vals}
    ret v
}

// cloneValue deep-copies a Value recursively, so accessors that hand
// back a sub-Value return an independent tree the caller owns. This is
// what makes json.Value immutable-from-the-outside (like a string): you
// can read a child or build a new doc, but you never get a handle that
// mutates the original. Scalar leaves copy their fields; arrays/objects
// rebuild fresh slices and recurse into every child.
fun cloneValue(v *Value) *Value {
    if v == nil { ret nil }
    if v.kind == KindArray {
        var n int = len(v.arr)
        var out []*Value = new(0) []*Value{}
        for i:=0; i < n; i++ {
            out = append(out, cloneValue(v.arr[i]))
        }
        ret new Value {kind: KindArray, arr: out}
    }
    if v.kind == KindObject {
        var n int = len(v.keys)
        var ks []string = new(0) []string{}
        var vs []*Value = new(0) []*Value{}
        for i:=0; i < n; i++ {
            ks = append(ks, "" + v.keys[i])
            vs = append(vs, cloneValue(v.vals[i]))
        }
        ret new Value {kind: KindObject, keys: ks, vals: vs}
    }
    ret new Value {kind: v.kind, boolV: v.boolV, numV: v.numV, strV: "" + v.strV}
}

// ---- Accessors ------------------------------------------------------

fun (v *Value) Kind() int     { ret v.kind }
fun (v *Value) AsBool() bool  { ret v.boolV }
fun (v *Value) AsInt() int    { ret v.numV }
fun (v *Value) AsString() string { ret v.strV }
fun (v *Value) ArrayLen() int { ret len(v.arr) }
fun (v *Value) ArrayAt(i int) *Value {
    var arr []*Value = v.arr
    ret cloneValue(arr[i])
}
fun (v *Value) ObjectLen() int { ret len(v.keys) }
fun (v *Value) KeyAt(i int) string {
    var keys []string = v.keys
    ret keys[i]
}
fun (v *Value) ValAt(i int) *Value {
    var vals []*Value = v.vals
    ret cloneValue(vals[i])
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
// jsonHexVal returns the value of a hex digit (0-15), or -1 if `c`
// isn't one.
fun jsonHexVal(c byte) int {
    if c >= 48 && c <= 57  { ret c - 48 }   // '0'-'9'
    if c >= 97 && c <= 102 { ret c - 87 }   // 'a'-'f' -> 10..15
    if c >= 65 && c <= 70  { ret c - 55 }   // 'A'-'F' -> 10..15
    ret -1
}

// jsonWriteCodepoint appends the UTF-8 encoding of Unicode codepoint
// `cp` to b. Uses chr() per byte (volt has no int->byte narrowing).
fun jsonWriteCodepoint(b *bytes.Builder, cp int) {
    if cp < 128 {
        b.WriteString(chr(cp))
    } else if cp < 2048 {
        b.WriteString(chr(192 + cp / 64))
        b.WriteString(chr(128 + cp % 64))
    } else if cp < 65536 {
        b.WriteString(chr(224 + cp / 4096))
        b.WriteString(chr(128 + (cp / 64) % 64))
        b.WriteString(chr(128 + cp % 64))
    } else {
        b.WriteString(chr(240 + cp / 262144))
        b.WriteString(chr(128 + (cp / 4096) % 64))
        b.WriteString(chr(128 + (cp / 64) % 64))
        b.WriteString(chr(128 + cp % 64))
    }
}

// jsonParseU4 reads 4 hex digits of a \uXXXX escape starting at s[at],
// returning the codepoint and true, or 0/false on a malformed escape.
fun jsonParseU4(s string, at int) (int, bool) {
    if at + 4 > len(s) { ret 0, false }
    var cp int = 0
    for k := 0; k < 4; k++ {
        var hv int = jsonHexVal(s[at + k])
        if hv < 0 { ret 0, false }
        cp = cp * 16 + hv
    }
    ret cp, true
}

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
            if esc == 117 {                // '\u' — Unicode escape
                var cp int = 0
                var ok bool = false
                cp, ok = jsonParseU4(s, i + 2)
                if !ok { ret "", errors.New("json: bad \\u escape") }
                i = i + 6
                // Surrogate pair: a high surrogate must be followed by
                // a low surrogate \uDC00-\uDFFF to form one codepoint.
                if cp >= 55296 && cp <= 56319 {   // 0xD800..0xDBFF (high)
                    if i + 1 < n && s[i] == 92 && s[i+1] == 117 {
                        var lo int = 0
                        var ok2 bool = false
                        lo, ok2 = jsonParseU4(s, i + 2)
                        if ok2 && lo >= 56320 && lo <= 57343 {   // 0xDC00..0xDFFF
                            cp = 65536 + (cp - 55296) * 1024 + (lo - 56320)
                            i = i + 6
                        }
                    }
                }
                jsonWriteCodepoint(b, cp)
                continue
            }
            var matched bool = true
            if esc == 34       { b.WriteByte(34)  } else
            if esc == 92       { b.WriteByte(92)  } else
            if esc == 47       { b.WriteByte(47)  } else
            if esc == 98       { b.WriteByte(8)   } else
            if esc == 102      { b.WriteByte(12)  } else
            if esc == 110      { b.WriteByte(10)  } else
            if esc == 114      { b.WriteByte(13)  } else
            if esc == 116      { b.WriteByte(9)   } else
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
    if v.kind == KindNull { b.WriteString("null"); ret }
    if v.kind == KindBool {
        if v.boolV { b.WriteString("true") } else { b.WriteString("false") }
        ret
    }
    if v.kind == KindNumber { b.WriteInt(v.numV); ret }
    if v.kind == KindString { b.WriteString(QuoteString(v.strV)); ret }
    if v.kind == KindArray {
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
    if v.kind == KindObject {
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
    if v.kind == KindNull { ret "null" }
    if v.kind == KindBool {
        if v.boolV { ret "true" }
        ret "false"
    }
    if v.kind == KindNumber { ret strconv.Itoa(v.numV) }
    if v.kind == KindString { ret QuoteString(v.strV) }
    if v.kind == KindArray {
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
    if v.kind == KindObject {
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
    // number. The value model is integer-only (no float kind yet), but
    // the PARSER tolerates real-world floats (`1.5`, `2.0e9`): it
    // consumes the whole numeric token so decoding succeeds, and stores
    // the integer part (truncated toward zero) as the value. This lets
    // json.Decode handle live JSON like the AUR RPC (Popularity floats)
    // without erroring; full float values are a follow-up.
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
        var intEnd int = j                 // integer part is [i, intEnd)
        // Fractional part: '.' digits
        if j < n && s[j] == 46 {           // '.'
            j = j + 1
            for j < n {
                var d byte = s[j]
                if d < 48 { break }
                if d > 57 { break }
                j = j + 1
            }
        }
        // Exponent: ('e'|'E') ('+'|'-')? digits
        if j < n && (s[j] == 101 || s[j] == 69) {   // 'e' / 'E'
            j = j + 1
            if j < n && (s[j] == 43 || s[j] == 45) { j = j + 1 }   // '+' / '-'
            for j < n {
                var d byte = s[j]
                if d < 48 { break }
                if d > 57 { break }
                j = j + 1
            }
        }
        var lit string = ""
        for k:=i; k < intEnd; k++ { lit = lit + chr(s[k]) }
        if lit == "" { lit = "0" }         // e.g. a bare "-" guard / ".5"
        if lit == "-" { lit = "0" }
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
