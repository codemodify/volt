package modfile

import (
	"strings"
	"testing"
)

// TestParseReplacePathOnly is the backward-compat case — bare path on
// both sides.
func TestParseReplacePathOnly(t *testing.T) {
	mod := `module example.com/me
volt 0.5
replace foo => ../foo
`
	f, err := Parse([]byte(mod))
	if err != nil {
		t.Fatal(err)
	}
	if len(f.Replace) != 1 {
		t.Fatalf("got %d replaces, want 1", len(f.Replace))
	}
	r := f.Replace[0]
	if r.From != "foo" || r.To != "../foo" || r.FromVersion != "" || r.ToVersion != "" {
		t.Errorf("got %+v, want From=foo To=../foo (no versions)", r)
	}
}

// TestParseReplaceVersionedSource handles `replace foo v1.0.0 => ../foo`.
func TestParseReplaceVersionedSource(t *testing.T) {
	mod := `module example.com/me
volt 0.5
replace foo v1.0.0 => ../foo
`
	f, err := Parse([]byte(mod))
	if err != nil {
		t.Fatal(err)
	}
	r := f.Replace[0]
	if r.From != "foo" || r.FromVersion != "v1.0.0" || r.To != "../foo" || r.ToVersion != "" {
		t.Errorf("got %+v, want From=foo FromVersion=v1.0.0 To=../foo", r)
	}
}

// TestParseReplaceVersionedBoth handles `replace foo v1 => bar v2`.
func TestParseReplaceVersionedBoth(t *testing.T) {
	mod := `module example.com/me
volt 0.5
replace foo v1.0.0 => bar v2.0.0
`
	f, err := Parse([]byte(mod))
	if err != nil {
		t.Fatal(err)
	}
	r := f.Replace[0]
	if r.From != "foo" || r.FromVersion != "v1.0.0" || r.To != "bar" || r.ToVersion != "v2.0.0" {
		t.Errorf("got %+v, want full version pin", r)
	}
}

// TestMatchReplaceVersionWins verifies a version-specific entry is
// preferred over a catch-all when both match.
func TestMatchReplaceVersionWins(t *testing.T) {
	reps := []Replace{
		{From: "foo", To: "../catchall"},
		{From: "foo", FromVersion: "v1.0.0", To: "../v1path"},
	}
	got, ok := MatchReplace(reps, "foo", "v1.0.0")
	if !ok || got.To != "../v1path" {
		t.Errorf("got %+v ok=%v, want To=../v1path", got, ok)
	}
}

// TestMatchReplaceCatchAllFallback verifies the catch-all is used
// when no version-specific entry matches.
func TestMatchReplaceCatchAllFallback(t *testing.T) {
	reps := []Replace{
		{From: "foo", FromVersion: "v1.0.0", To: "../v1path"},
		{From: "foo", To: "../catchall"},
	}
	got, ok := MatchReplace(reps, "foo", "v2.0.0")
	if !ok || got.To != "../catchall" {
		t.Errorf("got %+v ok=%v, want catchall", got, ok)
	}
}

// TestMatchReplaceMiss verifies an unrelated path returns ok=false.
func TestMatchReplaceMiss(t *testing.T) {
	reps := []Replace{
		{From: "foo", FromVersion: "v1.0.0", To: "../v1path"},
	}
	if _, ok := MatchReplace(reps, "bar", "v1.0.0"); ok {
		t.Errorf("matched unrelated path, want ok=false")
	}
}

// TestFormatReplaceRoundtrip serializes a File with versioned and
// path-only replaces, re-parses it, and confirms equivalence.
func TestFormatReplaceRoundtrip(t *testing.T) {
	src := &File{
		Module:      "example.com/me",
		VoltVersion: "0.5",
		Replace: []Replace{
			{From: "foo", FromVersion: "v1.0.0", To: "../foo"},
			{From: "bar", To: "baz", ToVersion: "v3.2.1"},
		},
	}
	out := src.Format()
	if !strings.Contains(string(out), "foo v1.0.0 => ../foo") {
		t.Errorf("formatted output missing versioned LHS line:\n%s", out)
	}
	if !strings.Contains(string(out), "bar => baz v3.2.1") {
		t.Errorf("formatted output missing versioned RHS line:\n%s", out)
	}
	round, err := Parse(out)
	if err != nil {
		t.Fatalf("re-parse: %v", err)
	}
	if len(round.Replace) != 2 {
		t.Fatalf("round-trip: got %d, want 2", len(round.Replace))
	}
}

// TestParseReplaceRejectsTooManyTokens guards against malformed input.
func TestParseReplaceRejectsTooManyTokens(t *testing.T) {
	bad := `module example.com/me
volt 0.5
replace foo v1.0.0 extra => bar
`
	_, err := Parse([]byte(bad))
	if err == nil || !strings.Contains(err.Error(), "LHS takes") {
		t.Errorf("got err %v, want LHS-takes error", err)
	}
}
