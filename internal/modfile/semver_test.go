package modfile

import "testing"

func TestParseSemverValid(t *testing.T) {
	cases := []struct {
		in    string
		major int
		minor int
		patch int
		pre   string
		build string
	}{
		{"v0.0.0", 0, 0, 0, "", ""},
		{"v1.2.3", 1, 2, 3, "", ""},
		{"v10.20.30", 10, 20, 30, "", ""},
		{"v1.0.0-alpha", 1, 0, 0, "alpha", ""},
		{"v1.0.0-alpha.1", 1, 0, 0, "alpha.1", ""},
		{"v1.0.0+build.5", 1, 0, 0, "", "build.5"},
		{"v1.0.0-rc.1+exp.sha", 1, 0, 0, "rc.1", "exp.sha"},
	}
	for _, c := range cases {
		got, ok := ParseSemver(c.in)
		if !ok {
			t.Errorf("ParseSemver(%q) ok=false, want true", c.in)
			continue
		}
		if got.Major != c.major || got.Minor != c.minor || got.Patch != c.patch ||
			got.Pre != c.pre || got.Build != c.build {
			t.Errorf("ParseSemver(%q) = %+v, want major=%d minor=%d patch=%d pre=%q build=%q",
				c.in, got, c.major, c.minor, c.patch, c.pre, c.build)
		}
	}
}

func TestParseSemverInvalid(t *testing.T) {
	bad := []string{"", "1.2.3", "v1.2", "v1.2.3.4", "vabc.0.0", "v-1.0.0", "v1.-1.0"}
	for _, in := range bad {
		if _, ok := ParseSemver(in); ok {
			t.Errorf("ParseSemver(%q) ok=true, want false", in)
		}
	}
}

func TestCmpSemverOrder(t *testing.T) {
	// Each adjacent pair: left < right.
	ordered := []string{
		"v1.0.0-alpha",
		"v1.0.0-alpha.1",
		"v1.0.0-alpha.beta",
		"v1.0.0-beta",
		"v1.0.0-beta.2",
		"v1.0.0-beta.11",
		"v1.0.0-rc.1",
		"v1.0.0",
		"v1.0.1",
		"v1.1.0",
		"v2.0.0",
		"v10.0.0",
	}
	for i := 0; i < len(ordered)-1; i++ {
		a, _ := ParseSemver(ordered[i])
		b, _ := ParseSemver(ordered[i+1])
		if c := CmpSemver(a, b); c != -1 {
			t.Errorf("CmpSemver(%s, %s) = %d, want -1", ordered[i], ordered[i+1], c)
		}
		// Reflexivity.
		if c := CmpSemver(a, a); c != 0 {
			t.Errorf("CmpSemver(%s, %s) = %d, want 0", ordered[i], ordered[i], c)
		}
		// Symmetry.
		if c := CmpSemver(b, a); c != 1 {
			t.Errorf("CmpSemver(%s, %s) = %d, want 1", ordered[i+1], ordered[i], c)
		}
	}
}

func TestMaxSemver(t *testing.T) {
	cases := []struct{ a, b, want string }{
		{"v1.0.0", "v2.0.0", "v2.0.0"},
		{"v2.0.0", "v1.0.0", "v2.0.0"},
		{"v1.2.3", "v1.2.3", "v1.2.3"},
		{"v1.0.0-alpha", "v1.0.0", "v1.0.0"},
		// Lexicographic fallback for non-semver strings.
		{"main", "dev", "main"},
	}
	for _, c := range cases {
		if got := MaxSemver(c.a, c.b); got != c.want {
			t.Errorf("MaxSemver(%q, %q) = %q, want %q", c.a, c.b, got, c.want)
		}
	}
}

func TestSelectVersion(t *testing.T) {
	got := SelectVersion([]string{"v1.0.0", "v1.5.0", "v1.3.2", "v0.9.0"})
	if got != "v1.5.0" {
		t.Errorf("SelectVersion = %q, want v1.5.0", got)
	}
	if got := SelectVersion(nil); got != "" {
		t.Errorf("SelectVersion(nil) = %q, want empty", got)
	}
	if got := SelectVersion([]string{"v2.0.0"}); got != "v2.0.0" {
		t.Errorf("SelectVersion single = %q, want v2.0.0", got)
	}
}
