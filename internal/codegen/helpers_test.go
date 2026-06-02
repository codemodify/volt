package codegen

import (
	"testing"

	"github.com/codemodify/volt/internal/ast"
)

// Levenshtein is the workhorse for every did-you-mean suggestion;
// regressions here would silently degrade dozens of error messages.
func TestLevenshteinDistance(t *testing.T) {
	cases := []struct {
		a, b string
		want int
	}{
		{"", "", 0},
		{"a", "", 1},
		{"", "abc", 3},
		{"abc", "abc", 0},
		{"counter", "cuonter", 2}, // transposition counts as 2 edits
		{"hello", "hellp", 1},
		{"strings", "strngs", 1},
		{"x", "y", 1},
	}
	for _, tc := range cases {
		got := levenshteinDistance(tc.a, tc.b)
		if got != tc.want {
			t.Errorf("levenshteinDistance(%q, %q) = %d, want %d", tc.a, tc.b, got, tc.want)
		}
	}
}

func TestClosestName(t *testing.T) {
	cands := []string{"counter", "hello", "Point", "strings"}
	cases := []struct {
		name string
		want string
	}{
		{"cuonter", "counter"},
		{"hellp", "hello"},
		{"Pont", "Point"},
		{"strngs", "strings"},
		// Too distant — no suggestion.
		{"wxyzabc", ""},
		// Identical name with no close non-identical alternative —
		// must not suggest itself, and no other candidate fits the
		// threshold.
		{"counter", ""},
	}
	for _, tc := range cases {
		got := closestName(tc.name, cands)
		if got != tc.want {
			t.Errorf("closestName(%q, %v) = %q, want %q", tc.name, cands, got, tc.want)
		}
	}
}

func TestIsBuiltinTypeName(t *testing.T) {
	for _, name := range []string{"int", "string", "bool", "error", "any", "byte", "uint64", "float32"} {
		if !isBuiltinTypeName(name) {
			t.Errorf("isBuiltinTypeName(%q) = false, want true", name)
		}
	}
	for _, name := range []string{"Point", "MyType", "Foo", "", "INT"} {
		if isBuiltinTypeName(name) {
			t.Errorf("isBuiltinTypeName(%q) = true, want false", name)
		}
	}
}

func TestTypeMismatchMessage(t *testing.T) {
	intT := &ast.NamedType{Name: "int"}
	strT := &ast.NamedType{Name: "string"}

	// Compatible: same type → ""
	if got := typeMismatchMessage(intT, "i64", "i64"); got != "" {
		t.Errorf("same-type should return empty, got %q", got)
	}
	// Compatible: both numeric → "" (convertInt handles widening)
	if got := typeMismatchMessage(intT, "i32", "i64"); got != "" {
		t.Errorf("numeric widen should return empty, got %q", got)
	}
	// Compatible: target ptr (boxing handles upstream) → ""
	if got := typeMismatchMessage(strT, "%string", "ptr"); got != "" {
		t.Errorf("target=ptr should defer, got %q", got)
	}
	// Mismatch: string into int
	got := typeMismatchMessage(intT, "%string", "i64")
	if got == "" {
		t.Errorf("string→int should mismatch, got empty")
	}
	if !contains(got, "string") || !contains(got, "int") {
		t.Errorf("expected message to name 'string' and 'int', got %q", got)
	}
}

func TestTypesStructurallyEqual(t *testing.T) {
	a := &ast.NamedType{Name: "int"}
	b := &ast.NamedType{Name: "int"}
	if !typesStructurallyEqual(a, b) {
		t.Errorf("same-name NamedTypes should be equal")
	}
	c := &ast.NamedType{Name: "string"}
	if typesStructurallyEqual(a, c) {
		t.Errorf("int vs string should not be equal")
	}
	// Slice of int == slice of int
	si := &ast.SliceType{Elem: &ast.NamedType{Name: "int"}}
	sj := &ast.SliceType{Elem: &ast.NamedType{Name: "int"}}
	if !typesStructurallyEqual(si, sj) {
		t.Errorf("[]int == []int should be true")
	}
	// Slice of int != slice of string
	ss := &ast.SliceType{Elem: &ast.NamedType{Name: "string"}}
	if typesStructurallyEqual(si, ss) {
		t.Errorf("[]int == []string should be false")
	}
	// Nil safety
	if !typesStructurallyEqual(nil, nil) {
		t.Errorf("nil == nil should be true")
	}
	if typesStructurallyEqual(a, nil) {
		t.Errorf("int == nil should be false")
	}
}

func TestLLvmTypeFriendlyName(t *testing.T) {
	cases := map[string]string{
		"i1":        "bool",
		"i8":        "byte",
		"i64":       "int",
		"double":    "float",
		"float":     "float32",
		"%string":   "string",
		"%slice":    "slice",
		"%MyStruct": "MyStruct",
	}
	for in, want := range cases {
		if got := llvmTypeFriendlyName(in); got != want {
			t.Errorf("llvmTypeFriendlyName(%q) = %q, want %q", in, got, want)
		}
	}
}

func contains(s, substr string) bool {
	for i := 0; i+len(substr) <= len(s); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
