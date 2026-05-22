
fun main() {
	var a int8       // 1 byte, -128..127
	var b int16      // 2 bytes, -32768..32767
	var c int32      // 4 bytes, −2147483648 to 2147483647, alias==int
	var d int64      // 8 bytes, −9.22 × 10¹⁸ to 9.22 × 10¹⁸

	var e uint8      // 1 byte, 0 to 255, alias==byte
	var f uint16     // 2 bytes, 0 to 65535
	var g uint32     // 4 bytes, 0 to 4294967295, alias==uint
	var h uint64     // 8 bytes, 0 to 1.84 × 10¹⁹

	var i float32    // 4 bytes, IEEE 754 single precision
	var j float64    // 8 bytes, IEEE 754 double precision, alias==float

	var k complex64  // 8 bytes, float32 + float32
	var l complex128 // 16 bytes, float64 + float64

	var m byte   = 0     // alias for uint8
	var n bool   = false // alias for byte

	var p []byte        = "" // array of bytes
	var q map[byte]byte = "" // dictionary of byte -> byte
	var o string = ""    // array of bytes, same as []byte

	var r struct{} // size of field members

	var q *int // 8 bytes
	var s *void // pointer to anything, alias==any
}
