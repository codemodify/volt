package main
import "log"
import "strings"

// Positive test: strings.HumanBytes.

fun main() int {
	var pass int = 0

	// Bytes.
	if strings.HumanBytes(0) == "0 B" { pass = pass + 1 }
	if strings.HumanBytes(1) == "1 B" { pass = pass + 1 }
	if strings.HumanBytes(512) == "512 B" { pass = pass + 1 }
	if strings.HumanBytes(1023) == "1023 B" { pass = pass + 1 }

	// KB tier.
	if strings.HumanBytes(1024) == "1 KB" { pass = pass + 1 }
	if strings.HumanBytes(1536) == "1.5 KB" { pass = pass + 1 }   // 1.5 * 1024
	if strings.HumanBytes(2048) == "2 KB" { pass = pass + 1 }
	// 2150 = 2 KB + 102 bytes; 102 * 10 / 1024 = 0, so tenths digit is 0 → no decimal.
	if strings.HumanBytes(2150) == "2 KB" { pass = pass + 1 }

	// MB tier.
	if strings.HumanBytes(1048576) == "1 MB" { pass = pass + 1 }
	if strings.HumanBytes(1572864) == "1.5 MB" { pass = pass + 1 }   // 1.5 * 1048576

	// GB tier.
	if strings.HumanBytes(1073741824) == "1 GB" { pass = pass + 1 }

	// TB tier.
	if strings.HumanBytes(1099511627776) == "1 TB" { pass = pass + 1 }

	// Negatives.
	if strings.HumanBytes(-1024) == "-1 KB" { pass = pass + 1 }
	if strings.HumanBytes(-500) == "-500 B" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 14 { ret 42 }
	ret 0
}
