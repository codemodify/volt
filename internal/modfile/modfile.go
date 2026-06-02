// Package modfile parses + writes volt.mod and volt.sum files.
//
// volt.mod surface (v1):
//
//	module example.com/myapp
//
//	volt 0.5
//
//	require example.com/greeter v1.0.0
//	require github.com/foo/bar v2.3.4
//
// Block-form `require ( ... )` is not yet supported — keep it simple.
//
// volt.sum surface:
//
//	example.com/greeter v1.0.0 h1:<base64-sha256>
//	github.com/foo/bar v2.3.4 h1:<base64-sha256>
//
// The hash is sha256 over the sorted contents of every `.volt` file in
// the package's cache directory. Matches Go's `go.sum h1:` style.
package modfile

import (
	"bufio"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// File is a parsed volt.mod.
type File struct {
	Module      string
	VoltVersion string
	Require     []Require
	Replace     []Replace
}

// Require pins a dependency to a version.
type Require struct {
	Path    string
	Version string
}

// Replace redirects an import path to a different target. Two forms:
//
//	replace <from-path> => <to-path>                       (path-only)
//	replace <from-path> <from-ver> => <to-path> [<to-ver>] (version-pinned)
//
// FromVersion=="" means the redirect applies to *every* required
// version of From. ToVersion is empty for local-path replacements
// (the target is a directory, not a tagged module).
type Replace struct {
	From        string
	FromVersion string
	To          string
	ToVersion   string
}

// Parse reads volt.mod content into a File. Lines starting with `//`
// are comments and ignored. Supports both single-line `require <p> <v>`
// and block-form `require ( <p> <v> ... )`.
func Parse(data []byte) (*File, error) {
	f := &File{}
	sc := bufio.NewScanner(strings.NewReader(string(data)))
	lineNo := 0
	inRequireBlock := false
	inReplaceBlock := false
	for sc.Scan() {
		lineNo++
		raw := sc.Text()
		line := strings.TrimSpace(raw)
		if line == "" || strings.HasPrefix(line, "//") {
			continue
		}
		// Inside `require ( … )`: lines are bare `<path> <version>`,
		// terminated by a `)`.
		if inRequireBlock {
			if line == ")" {
				inRequireBlock = false
				continue
			}
			fields := strings.Fields(line)
			if len(fields) < 2 {
				return nil, fmt.Errorf("volt.mod:%d: require block entry needs path + version", lineNo)
			}
			f.Require = append(f.Require, Require{Path: fields[0], Version: fields[1]})
			continue
		}
		// Inside `replace ( … )`: lines are `<from> => <to>`.
		if inReplaceBlock {
			if line == ")" {
				inReplaceBlock = false
				continue
			}
			rep, err := parseReplaceArrow(line, lineNo)
			if err != nil {
				return nil, err
			}
			f.Replace = append(f.Replace, rep)
			continue
		}
		fields := strings.Fields(line)
		switch fields[0] {
		case "module":
			if len(fields) < 2 {
				return nil, fmt.Errorf("volt.mod:%d: module needs a path", lineNo)
			}
			f.Module = fields[1]
		case "volt":
			if len(fields) < 2 {
				return nil, fmt.Errorf("volt.mod:%d: volt directive needs a version", lineNo)
			}
			f.VoltVersion = fields[1]
		case "require":
			if len(fields) == 2 && fields[1] == "(" {
				inRequireBlock = true
				continue
			}
			if len(fields) < 3 {
				return nil, fmt.Errorf("volt.mod:%d: require needs path + version (or `require (`)", lineNo)
			}
			f.Require = append(f.Require, Require{Path: fields[1], Version: fields[2]})
		case "replace":
			if len(fields) == 2 && fields[1] == "(" {
				inReplaceBlock = true
				continue
			}
			// Strip the leading "replace " before parsing the arrow.
			rep, err := parseReplaceArrow(strings.TrimSpace(strings.TrimPrefix(line, "replace")), lineNo)
			if err != nil {
				return nil, err
			}
			f.Replace = append(f.Replace, rep)
		default:
			return nil, fmt.Errorf("volt.mod:%d: unknown directive %q", lineNo, fields[0])
		}
	}
	if err := sc.Err(); err != nil {
		return nil, err
	}
	if inRequireBlock {
		return nil, fmt.Errorf("volt.mod: unterminated `require (` block")
	}
	if inReplaceBlock {
		return nil, fmt.Errorf("volt.mod: unterminated `replace (` block")
	}
	if f.Module == "" {
		return nil, fmt.Errorf("volt.mod: missing `module` directive")
	}
	return f, nil
}

// parseReplaceArrow splits `<from> [<from-ver>] => <to> [<to-ver>]`
// into a Replace. Both sides accept an optional trailing version.
// Pre-stripped of any leading `replace ` keyword.
func parseReplaceArrow(s string, lineNo int) (Replace, error) {
	parts := strings.SplitN(s, "=>", 2)
	if len(parts) != 2 {
		return Replace{}, fmt.Errorf("volt.mod:%d: replace needs `<from> => <to>`", lineNo)
	}
	lhsFields := strings.Fields(parts[0])
	rhsFields := strings.Fields(parts[1])
	if len(lhsFields) == 0 || len(rhsFields) == 0 {
		return Replace{}, fmt.Errorf("volt.mod:%d: replace has empty from/to", lineNo)
	}
	if len(lhsFields) > 2 {
		return Replace{}, fmt.Errorf("volt.mod:%d: replace LHS takes path [version], got %d tokens", lineNo, len(lhsFields))
	}
	if len(rhsFields) > 2 {
		return Replace{}, fmt.Errorf("volt.mod:%d: replace RHS takes path [version], got %d tokens", lineNo, len(rhsFields))
	}
	rep := Replace{From: lhsFields[0], To: rhsFields[0]}
	if len(lhsFields) == 2 {
		rep.FromVersion = lhsFields[1]
	}
	if len(rhsFields) == 2 {
		rep.ToVersion = rhsFields[1]
	}
	return rep, nil
}

// MatchReplace finds the best-matching Replace for (path, version),
// preferring version-specific entries over catch-all ones. Returns
// the matching Replace and true; (Replace{}, false) if none matches.
func MatchReplace(replaces []Replace, path, version string) (Replace, bool) {
	var catchAll *Replace
	for i := range replaces {
		r := &replaces[i]
		if r.From != path {
			continue
		}
		if r.FromVersion == "" {
			catchAll = r
			continue
		}
		if r.FromVersion == version {
			return *r, true
		}
	}
	if catchAll != nil {
		return *catchAll, true
	}
	return Replace{}, false
}

// Format serializes a File back to volt.mod text. Single require gets
// the one-line form; multiple requires use the block form.
func (f *File) Format() []byte {
	var sb strings.Builder
	fmt.Fprintf(&sb, "module %s\n\n", f.Module)
	if f.VoltVersion != "" {
		fmt.Fprintf(&sb, "volt %s\n\n", f.VoltVersion)
	}
	switch len(f.Require) {
	case 0:
		// nothing
	case 1:
		r := f.Require[0]
		fmt.Fprintf(&sb, "require %s %s\n", r.Path, r.Version)
	default:
		sb.WriteString("require (\n")
		for _, r := range f.Require {
			fmt.Fprintf(&sb, "\t%s %s\n", r.Path, r.Version)
		}
		sb.WriteString(")\n")
	}
	switch len(f.Replace) {
	case 0:
		// nothing
	case 1:
		r := f.Replace[0]
		if len(f.Require) > 0 {
			sb.WriteByte('\n')
		}
		fmt.Fprintf(&sb, "replace %s\n", formatReplaceBody(r))
	default:
		if len(f.Require) > 0 {
			sb.WriteByte('\n')
		}
		sb.WriteString("replace (\n")
		for _, r := range f.Replace {
			fmt.Fprintf(&sb, "\t%s\n", formatReplaceBody(r))
		}
		sb.WriteString(")\n")
	}
	return []byte(sb.String())
}

func formatReplaceBody(r Replace) string {
	lhs := r.From
	if r.FromVersion != "" {
		lhs = r.From + " " + r.FromVersion
	}
	rhs := r.To
	if r.ToVersion != "" {
		rhs = r.To + " " + r.ToVersion
	}
	return lhs + " => " + rhs
}

// AddRequire upserts a require entry. Existing entries with the same
// path get their version updated; new paths are appended.
func (f *File) AddRequire(path, version string) {
	for i := range f.Require {
		if f.Require[i].Path == path {
			f.Require[i].Version = version
			return
		}
	}
	f.Require = append(f.Require, Require{Path: path, Version: version})
}

// ---- volt.sum ------------------------------------------------------

// SumEntry is a single line in volt.sum.
type SumEntry struct {
	Path    string
	Version string
	Hash    string // base64-encoded sha256 (no "h1:" prefix)
}

// ParseSum reads volt.sum into a slice of entries.
func ParseSum(data []byte) ([]SumEntry, error) {
	var out []SumEntry
	sc := bufio.NewScanner(strings.NewReader(string(data)))
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" || strings.HasPrefix(line, "//") {
			continue
		}
		fields := strings.Fields(line)
		if len(fields) != 3 {
			return nil, fmt.Errorf("volt.sum: bad line %q", line)
		}
		hash := fields[2]
		if !strings.HasPrefix(hash, "h1:") {
			return nil, fmt.Errorf("volt.sum: hash must start with h1: prefix")
		}
		out = append(out, SumEntry{
			Path:    fields[0],
			Version: fields[1],
			Hash:    strings.TrimPrefix(hash, "h1:"),
		})
	}
	return out, sc.Err()
}

// FormatSum serializes sum entries back to volt.sum text. Entries are
// sorted by (path, version) for stable diffs.
func FormatSum(entries []SumEntry) []byte {
	cp := make([]SumEntry, len(entries))
	copy(cp, entries)
	sort.Slice(cp, func(i, j int) bool {
		if cp[i].Path != cp[j].Path {
			return cp[i].Path < cp[j].Path
		}
		return cp[i].Version < cp[j].Version
	})
	var sb strings.Builder
	for _, e := range cp {
		fmt.Fprintf(&sb, "%s %s h1:%s\n", e.Path, e.Version, e.Hash)
	}
	return []byte(sb.String())
}

// UpsertSum updates or inserts a sum entry, returning the new slice.
func UpsertSum(entries []SumEntry, e SumEntry) []SumEntry {
	for i := range entries {
		if entries[i].Path == e.Path && entries[i].Version == e.Version {
			entries[i].Hash = e.Hash
			return entries
		}
	}
	return append(entries, e)
}

// HashPackageDir computes the volt.sum hash for a package: sha256 over
// every .volt file in the directory tree, in sorted relative-path
// order. Returns a base64-encoded digest (RawStdEncoding).
func HashPackageDir(dir string) (string, error) {
	var voltFiles []string
	walkErr := filepath.WalkDir(dir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if d.IsDir() {
			return nil
		}
		if strings.HasSuffix(path, ".volt") {
			voltFiles = append(voltFiles, path)
		}
		return nil
	})
	if walkErr != nil {
		return "", walkErr
	}
	sort.Strings(voltFiles)

	h := sha256.New()
	for _, p := range voltFiles {
		// Include the relative path in the hash so renames are caught.
		rel, _ := filepath.Rel(dir, p)
		fmt.Fprintf(h, "%s\n", rel)
		data, err := os.ReadFile(p)
		if err != nil {
			return "", err
		}
		h.Write(data)
	}
	return base64.RawStdEncoding.EncodeToString(h.Sum(nil)), nil
}
