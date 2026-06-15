package multifilepkg

// part_a.volt — one half of a multi-file package. Defines a package-level
// const and a function. The const is referenced from part_b.volt, proving
// the files are genuinely merged into one package (not loaded in isolation).

const Factor int = 10

fun Sum(a int, b int) int {
	ret a + b
}
