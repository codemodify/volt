package main
import "log"
import "math"

// Positive test: math.IcbrtFloor + math.IsPerfectCube.

fun main() int {
	var pass int = 0

	// IcbrtFloor — exact cubes.
	if math.IcbrtFloor(0) == 0 { pass = pass + 1 }
	if math.IcbrtFloor(1) == 1 { pass = pass + 1 }
	if math.IcbrtFloor(8) == 2 { pass = pass + 1 }
	if math.IcbrtFloor(27) == 3 { pass = pass + 1 }
	if math.IcbrtFloor(64) == 4 { pass = pass + 1 }
	if math.IcbrtFloor(125) == 5 { pass = pass + 1 }
	if math.IcbrtFloor(1000) == 10 { pass = pass + 1 }
	if math.IcbrtFloor(1000000) == 100 { pass = pass + 1 }

	// IcbrtFloor — between cubes.
	if math.IcbrtFloor(2) == 1 { pass = pass + 1 }       // cbrt 2 ~ 1.26
	if math.IcbrtFloor(7) == 1 { pass = pass + 1 }
	if math.IcbrtFloor(9) == 2 { pass = pass + 1 }
	if math.IcbrtFloor(26) == 2 { pass = pass + 1 }
	if math.IcbrtFloor(28) == 3 { pass = pass + 1 }
	if math.IcbrtFloor(999) == 9 { pass = pass + 1 }

	// IcbrtFloor — negative / zero.
	if math.IcbrtFloor(-1) == 0 { pass = pass + 1 }
	if math.IcbrtFloor(-1000) == 0 { pass = pass + 1 }

	// IsPerfectCube — exact cubes.
	if math.IsPerfectCube(0) { pass = pass + 1 }
	if math.IsPerfectCube(1) { pass = pass + 1 }
	if math.IsPerfectCube(8) { pass = pass + 1 }
	if math.IsPerfectCube(27) { pass = pass + 1 }
	if math.IsPerfectCube(64) { pass = pass + 1 }
	if math.IsPerfectCube(125) { pass = pass + 1 }
	if math.IsPerfectCube(1000) { pass = pass + 1 }
	if math.IsPerfectCube(1000000) { pass = pass + 1 }

	// Non-cubes.
	if !math.IsPerfectCube(2) { pass = pass + 1 }
	if !math.IsPerfectCube(7) { pass = pass + 1 }
	if !math.IsPerfectCube(9) { pass = pass + 1 }
	if !math.IsPerfectCube(26) { pass = pass + 1 }
	if !math.IsPerfectCube(100) { pass = pass + 1 }   // perfect SQUARE not cube
	if !math.IsPerfectCube(999) { pass = pass + 1 }

	// Negatives.
	if !math.IsPerfectCube(-1) { pass = pass + 1 }
	if !math.IsPerfectCube(-27) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 32 { ret 42 }
	ret 0
}
