package modfile

import (
	"strconv"
	"strings"
)

// Semver is a parsed semantic-version string of the form
// `vMAJOR.MINOR.PATCH[-PRERELEASE][+BUILD]`. The leading `v` is
// required; trailing pre-release / build metadata is optional. We
// implement just enough of semver 2.0.0 to compare versions that
// `volt mod get` produces.
type Semver struct {
	Major, Minor, Patch int
	Pre                 string // empty when no -pre suffix
	Build               string // empty when no +build suffix
	Raw                 string // original input, for error messages
}

// ParseSemver parses a `vX.Y.Z[-pre][+build]` string. Returns
// (Semver{}, false) on malformed input. Missing minor/patch is
// rejected — semver requires all three numeric segments.
func ParseSemver(v string) (Semver, bool) {
	out := Semver{Raw: v}
	if !strings.HasPrefix(v, "v") {
		return out, false
	}
	body := v[1:]
	// Split off +build first; build doesn't affect ordering.
	if i := strings.Index(body, "+"); i >= 0 {
		out.Build = body[i+1:]
		body = body[:i]
	}
	// Then split off -pre.
	if i := strings.Index(body, "-"); i >= 0 {
		out.Pre = body[i+1:]
		body = body[:i]
	}
	parts := strings.Split(body, ".")
	if len(parts) != 3 {
		return out, false
	}
	var err error
	if out.Major, err = strconv.Atoi(parts[0]); err != nil || out.Major < 0 {
		return out, false
	}
	if out.Minor, err = strconv.Atoi(parts[1]); err != nil || out.Minor < 0 {
		return out, false
	}
	if out.Patch, err = strconv.Atoi(parts[2]); err != nil || out.Patch < 0 {
		return out, false
	}
	return out, true
}

// CmpSemver returns -1 if a < b, 0 if equal, +1 if a > b.
// Pre-release versions are ordered BEFORE the corresponding release
// (semver 2.0.0 §11): v1.0.0-alpha < v1.0.0. Pre-release identifiers
// themselves are compared lexicographically segment-by-segment with
// numeric segments compared numerically.
func CmpSemver(a, b Semver) int {
	switch {
	case a.Major != b.Major:
		return cmpInt(a.Major, b.Major)
	case a.Minor != b.Minor:
		return cmpInt(a.Minor, b.Minor)
	case a.Patch != b.Patch:
		return cmpInt(a.Patch, b.Patch)
	}
	// A version WITH pre-release < same version WITHOUT pre-release.
	switch {
	case a.Pre == "" && b.Pre == "":
		return 0
	case a.Pre == "":
		return 1
	case b.Pre == "":
		return -1
	}
	return cmpPre(a.Pre, b.Pre)
}

func cmpInt(a, b int) int {
	switch {
	case a < b:
		return -1
	case a > b:
		return 1
	}
	return 0
}

// cmpPre compares two pre-release strings dot-segment-by-dot-segment.
// Numeric segments compared numerically; identifier segments compared
// lexicographically; numeric segments are LOWER precedence than
// alphanumeric (semver §11.4.3).
func cmpPre(a, b string) int {
	as, bs := strings.Split(a, "."), strings.Split(b, ".")
	for i := 0; i < len(as) && i < len(bs); i++ {
		ai, aOk := strconv.Atoi(as[i])
		bi, bOk := strconv.Atoi(bs[i])
		switch {
		case aOk == nil && bOk == nil:
			if c := cmpInt(ai, bi); c != 0 {
				return c
			}
		case aOk == nil:
			return -1 // numeric < alphanumeric
		case bOk == nil:
			return 1
		default:
			if c := strings.Compare(as[i], bs[i]); c != 0 {
				return c
			}
		}
	}
	return cmpInt(len(as), len(bs))
}

// MaxSemver returns whichever of a or b is greater under CmpSemver.
// Falls back to lexicographic comparison if either string fails to
// parse — keeps the call site simple for callers that mix tagged
// versions with random branch names.
func MaxSemver(a, b string) string {
	av, aok := ParseSemver(a)
	bv, bok := ParseSemver(b)
	if aok && bok {
		if CmpSemver(av, bv) >= 0 {
			return a
		}
		return b
	}
	if strings.Compare(a, b) >= 0 {
		return a
	}
	return b
}

// SelectVersion implements minimum-version selection (MVS) for a
// list of version strings required for the same module path: pick
// the highest tagged version. Empty input → "".
func SelectVersion(versions []string) string {
	if len(versions) == 0 {
		return ""
	}
	best := versions[0]
	for _, v := range versions[1:] {
		best = MaxSemver(best, v)
	}
	return best
}
