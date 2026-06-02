package main
import "log"
import "hash/crc32"

// Positive test: crc32.ChecksumIEEE — IEEE 802.3 CRC-32 checksum.
// Cross-checked against Python's zlib.crc32 (which uses the same
// polynomial 0xEDB88320).

fun main() int {
	var pass int = 0

	// Empty string → 0
	if crc32.ChecksumIEEE("") == 0 { pass = pass + 1 }

	// "a" → 3904355907 (0xE8B7BE43)
	if crc32.ChecksumIEEE("a") == 3904355907 { pass = pass + 1 }

	// "abc" → 891568578 (0x352441C2)
	if crc32.ChecksumIEEE("abc") == 891568578 { pass = pass + 1 }

	// "hello world" → 222957957
	if crc32.ChecksumIEEE("hello world") == 222957957 { pass = pass + 1 }

	// Pangram → 1095738169
	if crc32.ChecksumIEEE("The quick brown fox jumps over the lazy dog") == 1095738169 { pass = pass + 1 }

	// Determinism: same input twice produces same hash.
	var h1 int = crc32.ChecksumIEEE("repeatable")
	var h2 int = crc32.ChecksumIEEE("repeatable")
	if h1 == h2 { pass = pass + 1 }

	// Avalanche: changing one byte changes the hash significantly.
	var h3 int = crc32.ChecksumIEEE("alpha")
	var h4 int = crc32.ChecksumIEEE("alphz")   // change last byte
	if h3 != h4 { pass = pass + 1 }

	// Constant exposed.
	if crc32.IEEE == 3988292384 { pass = pass + 1 }

	log.Println("pass=%d hello=%d", pass, crc32.ChecksumIEEE("hello world"))
	if pass == 8 { ret 42 }
	ret 0
}
