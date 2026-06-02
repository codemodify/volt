package main
import "log"
import "maps"

fun main() int {
	var pass int = 0

	// SumValuesStringInt — empty map.
	var empty map[string]int = new map[string]int
	if maps.SumValuesStringInt(empty) == 0 { pass = pass + 1 }
	if maps.MaxValueStringInt(empty) == 0 { pass = pass + 1 }
	if maps.MinValueStringInt(empty) == 0 { pass = pass + 1 }

	// Single-entry.
	var one map[string]int = new map[string]int
	one["solo"] = 42
	if maps.SumValuesStringInt(one) == 42 { pass = pass + 1 }
	if maps.MaxValueStringInt(one) == 42 { pass = pass + 1 }
	if maps.MinValueStringInt(one) == 42 { pass = pass + 1 }

	// Multi-entry — typical word-count map.
	var freq map[string]int = new map[string]int
	freq["a"] = 5
	freq["b"] = 10
	freq["c"] = 3
	freq["d"] = 7
	if maps.SumValuesStringInt(freq) == 25 { pass = pass + 1 }
	if maps.MaxValueStringInt(freq) == 10 { pass = pass + 1 }
	if maps.MinValueStringInt(freq) == 3 { pass = pass + 1 }

	// Negative values.
	var neg map[string]int = new map[string]int
	neg["a"] = -3
	neg["b"] = -1
	neg["c"] = -10
	if maps.SumValuesStringInt(neg) == -14 { pass = pass + 1 }
	if maps.MaxValueStringInt(neg) == -1 { pass = pass + 1 }
	if maps.MinValueStringInt(neg) == -10 { pass = pass + 1 }

	// All-zero values.
	var zero map[string]int = new map[string]int
	zero["a"] = 0
	zero["b"] = 0
	if maps.SumValuesStringInt(zero) == 0 { pass = pass + 1 }
	if maps.MaxValueStringInt(zero) == 0 { pass = pass + 1 }
	if maps.MinValueStringInt(zero) == 0 { pass = pass + 1 }

	// Mixed positive/negative.
	var mixed map[string]int = new map[string]int
	mixed["x"] = 100
	mixed["y"] = -50
	mixed["z"] = 25
	if maps.SumValuesStringInt(mixed) == 75 { pass = pass + 1 }
	if maps.MaxValueStringInt(mixed) == 100 { pass = pass + 1 }
	if maps.MinValueStringInt(mixed) == -50 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
