package multifilepkg

// part_b.volt — the other half. Scaled() multiplies by Factor, which is
// declared over in part_a.volt; resolving it requires the two files to be
// merged into a single package before checking.

fun Scaled(n int) int {
	ret n * Factor
}
