// Package crc32: CRC-32 checksum using the IEEE 802.3 polynomial
// (Go's default crc32 variant). Reflected polynomial 0xEDB88320.
//
// Surface:
//   ChecksumIEEE(s string) int   — CRC-32 of the byte sequence
//
// The output is 32 bits, returned as a non-negative int (the high
// 32 bits are always zero).

package crc32

// IEEE is the reflected CRC-32 polynomial used by IEEE 802.3 /
// Ethernet, PNG, gzip, and most "default" CRC-32 implementations.
const IEEE int = 3988292384   // 0xEDB88320

// tableValue computes the CRC-32 table entry for byte b. Doing it
// on demand avoids the need for a 256-element top-level array (volt
// doesn't yet support package-level array literals).
fun tableValue(b int) int {
    var crc int = b
    for k := 0; k < 8; k++ {
        if (crc & 1) == 1 {
            crc = (crc >> 1) ^ IEEE
        } else {
            crc = crc >> 1
        }
    }
    ret crc & 4294967295   // mask to 32 bits
}

// ChecksumIEEE returns the CRC-32 checksum of s using the IEEE
// polynomial. Standard initialization: crc = 0xFFFFFFFF; standard
// finalization: XOR with 0xFFFFFFFF.
fun ChecksumIEEE(s string) int {
    var crc int = 4294967295   // 0xFFFFFFFF
    var n int = len(s)
    for i := 0; i < n; i++ {
        var b int = s[i] & 255
        var idx int = (crc ^ b) & 255
        crc = (crc >> 8) ^ tableValue(idx)
        crc = crc & 4294967295
    }
    ret (crc ^ 4294967295) & 4294967295
}
