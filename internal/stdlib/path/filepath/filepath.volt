// Package filepath: minimal Unix path-manipulation utilities.
//
// Surface (v1):
//   Base(path) string  — last element of the path (or "." / "/")
//   Dir(path) string   — everything before the last element (or ".")
//   Ext(path) string   — file extension including the leading "."
//   Join(a, b) string  — two-arg join with single-slash normalization
//
// Unix-style only; assumes `/` separator. Doesn't currently fold
// `.`/`..` components — Clean is a future widening.

package filepath

import "bytes"
import "errors"

const slash byte = 47    // '/'
const dot   byte = 46    // '.'

// Base returns the last element of path. Trailing slashes are
// stripped before extracting. Returns "." for an empty path and
// "/" if the path is all slashes.
fun Base(path string) string {
    var n int = len(path)
    if n == 0 { ret "." }
    // Strip trailing slashes.
    for n > 1 {
        if path[n-1] != slash { break }
        n = n - 1
    }
    if n == 1 {
        if path[0] == slash { ret "/" }
    }
    // Walk back to the slash before the basename (or off the front).
    var i int = n - 1
    for i >= 0 {
        if path[i] == slash { break }
        i = i - 1
    }
    var bld *bytes.Builder = bytes.NewBuilder()
    for j:=i+1; j < n; j++ {
        bld.WriteByte(path[j])
    }
    var out string = bld.String()
    if out == "" { ret "." }
    ret out
}

// Dir returns all but the last element of path. Trailing slashes
// are stripped first. If path has no slash, Dir returns ".".
fun Dir(path string) string {
    var n int = len(path)
    if n == 0 { ret "." }
    for n > 1 {
        if path[n-1] != slash { break }
        n = n - 1
    }
    var i int = n - 1
    for i >= 0 {
        if path[i] == slash { break }
        i = i - 1
    }
    if i < 0 { ret "." }
    if i == 0 { ret "/" }
    var bld *bytes.Builder = bytes.NewBuilder()
    for j:=0; j < i; j++ {
        bld.WriteByte(path[j])
    }
    ret bld.String()
}

// Ext returns the file extension — the substring from the final
// `.` to the end of the path, OR "" if no dot is present in the
// final segment.
fun Ext(path string) string {
    var n int = len(path)
    var i int = n - 1
    for i >= 0 {
        if path[i] == slash { ret "" }
        if path[i] == dot { break }
        i = i - 1
    }
    if i < 0 { ret "" }
    var bld *bytes.Builder = bytes.NewBuilder()
    for j:=i; j < n; j++ {
        bld.WriteByte(path[j])
    }
    ret bld.String()
}

// SplitExt splits the final path element into base + extension,
// returning (base, ext) where ext starts with the final dot in the
// basename (matching Ext's semantics). If there's no extension,
// ext is "" and base is the original path. A leading-dot basename
// like ".bashrc" is treated as having no extension (the whole
// basename IS the name, not an extension). Useful for: filename
// rewrites ("foo.txt" → "foo.md"), grouping files by extension.
fun SplitExt(path string) (string, string) {
    var n int = len(path)
    var dotIdx int = -1
    var slashIdx int = -1
    var i int = n - 1
    for i >= 0 {
        var c byte = path[i]
        if c == slash {
            slashIdx = i
            break
        }
        if c == dot {
            if dotIdx < 0 { dotIdx = i }
        }
        i = i - 1
    }
    // No dot found → no extension.
    if dotIdx < 0 { ret "" + path, "" }
    // Hidden-file basename (".bashrc", "/etc/.cfg") — leading dot in basename.
    if dotIdx == slashIdx + 1 { ret "" + path, "" }
    var baseB *bytes.Builder = bytes.NewBuilder()
    for j := 0; j < dotIdx; j++ { baseB.WriteByte(path[j]) }
    var extB *bytes.Builder = bytes.NewBuilder()
    for j := dotIdx; j < n; j++ { extB.WriteByte(path[j]) }
    ret baseB.String(), extB.String()
}

// WithoutExt returns path with its trailing extension stripped (the
// part beginning at the final dot in the basename). Files with no
// extension or leading-dot basenames (".bashrc") are returned
// unchanged. Multi-extension paths only strip the final segment:
// `"a.tar.gz"` → `"a.tar"`. Useful for renaming or stem-extraction.
fun WithoutExt(path string) string {
    var base string = ""
    var ext string = ""
    base, ext = SplitExt(path)
    if len(ext) < 0 { ret "" }                          // dead use to satisfy checker
    ret base
}

// Stem returns the basename of path with its extension stripped —
// `Base(path)` followed by `WithoutExt`. Useful for "what's the name
// of this file without directory and without ext?" — common pattern
// in build systems (`foo.c` → `foo` → input for `foo.o`), test-name
// extraction, derivation of related-file names.
// `Stem("/usr/local/lib/libfoo.so")` → `"libfoo"`.
// `Stem("readme")` → `"readme"`.
// `Stem("/")` → `"/"` (matches Base behavior on root).
fun Stem(path string) string {
    var b string = Base(path)
    var st string = ""
    var ext string = ""
    st, ext = SplitExt(b)
    if len(ext) < 0 { ret "" }                          // dead use
    ret st
}

// WithExt returns path with its trailing extension replaced by ext.
// If path has no extension, ext is appended. If ext is empty, the
// extension is stripped (same as WithoutExt). A leading dot in ext
// is optional: WithExt("foo.txt", "md") and WithExt("foo.txt", ".md")
// both yield "foo.md". Multi-extension paths only replace the final
// segment: `"a.tar.gz"` + `"bz2"` → `"a.tar.bz2"`. Useful for
// filename transforms in build pipelines (.c → .o, .md → .html).
fun WithExt(path string, ext string) string {
    var base string = ""
    var oldExt string = ""
    base, oldExt = SplitExt(path)
    if len(oldExt) < 0 { ret "" }                       // dead use to satisfy checker
    if len(ext) == 0 { ret base }
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < len(base); i++ { b.WriteByte(base[i]) }
    if ext[0] != dot { b.WriteByte(dot) }
    for i := 0; i < len(ext); i++ { b.WriteByte(ext[i]) }
    ret b.String()
}

// HasExt reports whether path's extension equals `ext`. Comparison
// is byte-exact (case-sensitive). A leading dot in `ext` is optional
// — `HasExt("foo.txt", "txt")` and `HasExt("foo.txt", ".txt")` both
// return true. Empty `ext` matches paths with no extension (mirrors
// `Ext(path) == ""`). Useful for filtering directory listings,
// dispatching by file type in build pipelines, accept-this-input
// guards.
fun HasExt(path string, ext string) bool {
    var pExt string = Ext(path)
    if len(ext) == 0 {
        if len(pExt) == 0 { ret true }
        ret false
    }
    if ext[0] == dot {
        if pExt == ext { ret true }
        ret false
    }
    // ext has no leading dot; pExt always does (when non-empty).
    if len(pExt) != len(ext) + 1 { ret false }
    if pExt[0] != dot { ret false }
    for i := 0; i < len(ext); i++ {
        if pExt[i + 1] != ext[i] { ret false }
    }
    ret true
}

// Join concatenates two path elements with exactly one slash
// between them. Empty elements pass through (Join("", "x") == "x";
// Join("x", "") == "x"). Multiple trailing slashes on a or leading
// slashes on b collapse to a single separator.
fun Join(a string, b string) string {
    if a == "" { ret b }
    if b == "" { ret a }
    var aEnd int = len(a)
    for aEnd > 1 {
        if a[aEnd-1] != slash { break }
        aEnd = aEnd - 1
    }
    var bStart int = 0
    var bLen int = len(b)
    for bStart < bLen {
        if b[bStart] != slash { break }
        bStart = bStart + 1
    }
    var bld *bytes.Builder = bytes.NewBuilder()
    for i:=0; i < aEnd; i++ {
        bld.WriteByte(a[i])
    }
    bld.WriteByte(47)   // '/'
    for j:=bStart; j < bLen; j++ {
        bld.WriteByte(b[j])
    }
    ret bld.String()
}

// JoinAll concatenates an arbitrary number of path elements with
// single-slash separators (volt has no variadic syntax in v1, so the
// parts arrive as a slice). Empty elements are skipped — so
// `JoinAll(["a", "", "b"])` == `"a/b"`, not `"a//b"`. Multiple
// trailing slashes on any element / leading slashes on the next
// collapse to one separator. If every element is empty, returns "".
// If the first non-empty element is absolute (starts with `/`), the
// result is absolute. Useful when path segments come from `Split`,
// from a list of config dirs, or from accumulated package names.
fun JoinAll(parts []string) string {
    var n int = len(parts)
    var bld *bytes.Builder = bytes.NewBuilder()
    var hasContent bool = false
    var endsWithSlash bool = false
    for i := 0; i < n; i++ {
        var p string = parts[i]
        var pn int = len(p)
        if pn == 0 { continue }

        var ps int = 0
        if hasContent {
            for ps < pn {
                if p[ps] != slash { break }
                ps = ps + 1
            }
        }
        var pe int = pn
        for pe > ps {
            if p[pe-1] != slash { break }
            pe = pe - 1
        }

        if ps >= pe {
            if !hasContent {
                bld.WriteByte(slash)
                hasContent = true
                endsWithSlash = true
            }
            continue
        }

        if hasContent {
            if !endsWithSlash {
                bld.WriteByte(slash)
            }
        }
        for j := ps; j < pe; j++ {
            bld.WriteByte(p[j])
        }
        hasContent = true
        endsWithSlash = false
    }
    ret bld.String()
}

// Depth returns the number of non-empty path components in path.
// `"/"` returns 0, `"/a"` returns 1, `"/a/b/c"` returns 3, `""`
// returns 0, `"foo"` returns 1. Runs of slashes don't inflate the
// count. Useful for: max-nesting-depth checks, sandbox-restriction
// bounds, breadcrumb generation.
fun Depth(path string) int {
    var parts []string = Components(path)
    ret len(parts)
}

// IsParent reports whether `parent` is an ancestor directory of
// `child` — i.e. child starts with parent + `/` (after normalizing
// trailing slashes on parent). Equal paths return false (parent is
// not its own ancestor). Useful for: path-containment checks,
// sandbox enforcement, prefix-strip validation.
fun IsParent(parent string, child string) bool {
    var pn int = len(parent)
    if pn == 0 { ret false }
    // Strip trailing slashes on parent (treat /a/ same as /a) — but
    // keep at least one char so the bare-root case "/" is preserved.
    for pn > 1 {
        if parent[pn - 1] != slash { break }
        pn = pn - 1
    }
    var cn int = len(child)
    if cn <= pn { ret false }
    for i := 0; i < pn; i++ {
        if parent[i] != child[i] { ret false }
    }
    // If parent ends in `/` (only happens when parent is exactly "/"),
    // we're already at the separator boundary — no extra check.
    if parent[pn - 1] != slash {
        if child[pn] != slash { ret false }
    }
    ret true
}

// NormalizeSlashes returns path with runs of `/` collapsed to a
// single `/`. Leading-slash status is preserved (absolute paths
// keep their root). Trailing slashes are kept (except when an empty
// path normalizes to ""). Examples: `"//a///b//"` → `"/a/b/"`,
// `"a//b"` → `"a/b"`, `""` → `""`, `"/"` → `"/"`. Lighter-weight
// than Clean — doesn't fold `.`/`..` segments.
fun NormalizeSlashes(path string) string {
    var n int = len(path)
    if n == 0 { ret "" }
    var b *bytes.Builder = bytes.NewBuilder()
    var prevSlash bool = false
    for i := 0; i < n; i++ {
        var c byte = path[i]
        if c == slash {
            if prevSlash { continue }
            prevSlash = true
            b.WriteByte(slash)
        } else {
            prevSlash = false
            b.WriteByte(c)
        }
    }
    ret b.String()
}

// IsRoot reports whether path is the filesystem root — "/" or any
// string consisting solely of `/` bytes (`//`, `///` — which all
// normalize to `/`). Empty path returns false. Useful for path-
// traversal stopping conditions.
fun IsRoot(path string) bool {
    var n int = len(path)
    if n == 0 { ret false }
    for i := 0; i < n; i++ {
        if path[i] != slash { ret false }
    }
    ret true
}

// WithName returns path with its basename replaced by `name`.
// The directory portion (everything up to and including the last
// '/') is preserved. If path has no '/', the result is just `name`.
// Useful for filename rewrites that preserve the parent directory:
// `/path/to/old.txt` → `/path/to/new.md`. Empty path returns `name`.
// Companion to WithExt (Pass-239) — WithExt swaps the extension,
// WithName swaps the whole basename.
fun WithName(path string, name string) string {
    var n int = len(path)
    var slashIdx int = -1
    var i int = n - 1
    for i >= 0 {
        if path[i] == slash { slashIdx = i; break }
        i = i - 1
    }
    if slashIdx < 0 { ret "" + name }
    var b *bytes.Builder = bytes.NewBuilder()
    for j := 0; j <= slashIdx; j++ { b.WriteByte(path[j]) }
    for k := 0; k < len(name); k++ { b.WriteByte(name[k]) }
    ret b.String()
}

// IsHidden reports whether path's basename starts with a dot.
// Common Unix convention for hidden files / directories. Empty
// basename returns false. Examples: `.bashrc` (true), `/etc/.cfg`
// (true), `foo.txt` (false), `.` (true), `..` (true), `/dir/.`
// (true — its basename is `.`).
fun IsHidden(path string) bool {
    var b string = Base(path)
    if len(b) == 0 { ret false }
    if b[0] == dot { ret true }
    ret false
}

// IsAbs reports whether path is absolute — Unix-only: starts with
// '/'. Empty path returns false.
fun IsAbs(path string) bool {
    if len(path) == 0 { ret false }
    if path[0] == 47 { ret true }
    ret false
}

// Split splits path into the directory and file components. The
// directory portion includes the trailing slash (so Split("a/b/c.txt")
// returns ("a/b/", "c.txt")). For path with no slash, dir is "" and
// file is path. For "/" or "//" etc., dir keeps the slash and file
// is empty.
fun Split(path string) (string, string) {
    var n int = len(path)
    var lastSlash int = -1
    for i := n - 1; i >= 0; i = i - 1 {
        if path[i] == 47 {
            lastSlash = i
            break
        }
    }
    if lastSlash < 0 {
        var b *bytes.Builder = bytes.NewBuilder()
        for i := 0; i < n; i++ { b.WriteByte(path[i]) }
        ret "", b.String()
    }
    var dirEnd int = lastSlash + 1
    var bd *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < dirEnd; i++ { bd.WriteByte(path[i]) }
    var bf *bytes.Builder = bytes.NewBuilder()
    for i := dirEnd; i < n; i++ { bf.WriteByte(path[i]) }
    ret bd.String(), bf.String()
}

// Clean returns the shortest path-name equivalent to path by purely
// lexical processing — collapses multiple slashes, removes "." and
// trailing "/", and eliminates ".." against the preceding non-".."
// segment. Doesn't touch the filesystem. Matches Go's filepath.Clean
// on Unix (where filepath.Separator == '/'). Empty input returns ".".
fun Clean(path string) string {
    var n int = len(path)
    if n == 0 { ret "." }
    var rooted bool = false
    if path[0] == 47 { rooted = true }
    // Two-pass: collect non-empty, non-"." segments; pop on "..".
    var segs []string = new(0) []string {}
    var i int = 0
    for i < n {
        // Skip slashes.
        for i < n {
            if path[i] != 47 { break }
            i = i + 1
        }
        // Read segment until next slash.
        var start int = i
        for i < n {
            if path[i] == 47 { break }
            i = i + 1
        }
        if start == i { continue }   // run of slashes only — no segment
        var sb *bytes.Builder = bytes.NewBuilder()
        for k := start; k < i; k++ { sb.WriteByte(path[k]) }
        var seg string = sb.String()
        if seg == "." {
            // Drop.
        } else {
            if seg == ".." {
                var sn int = len(segs)
                if sn > 0 {
                    if segs[sn - 1] != ".." {
                        // Pop.
                        var ns []string = new(sn - 1) []string {}
                        for k := 0; k < sn - 1; k++ { ns[k] = segs[k] }
                        segs = ns
                    } else {
                        segs = append(segs, "" + seg)
                    }
                } else {
                    if !rooted {
                        segs = append(segs, "" + seg)
                    }
                    // For rooted path, drop the ".." entirely.
                }
            } else {
                segs = append(segs, "" + seg)
            }
        }
    }
    var out *bytes.Builder = bytes.NewBuilder()
    if rooted { out.WriteByte(47) }
    var ns int = len(segs)
    for k := 0; k < ns; k++ {
        if k > 0 { out.WriteByte(47) }
        out.WriteString("" + segs[k])
    }
    var s string = out.String()
    if len(s) == 0 { ret "." }
    ret s
}

// Components splits path into a slice of directory components,
// stripping the empty pieces produced by leading / trailing /
// consecutive slashes. Useful for iterating over a path step by
// step, building trees from path strings, or stripping a known
// prefix path tier-by-tier.
fun Components(path string) []string {
    var n int = len(path)
    var out []string = new(0) []string {}
    var start int = 0
    for i := 0; i < n; i++ {
        if path[i] == slash {
            if i > start {
                var b *bytes.Builder = bytes.NewBuilder()
                for j := start; j < i; j++ { b.WriteByte(path[j]) }
                out = append(out, b.String())
            }
            start = i + 1
        }
    }
    if start < n {
        var b *bytes.Builder = bytes.NewBuilder()
        for j := start; j < n; j++ { b.WriteByte(path[j]) }
        out = append(out, b.String())
    }
    ret out
}

// HeadN returns the first n path components joined back with `/`.
// If path was absolute (started with `/`), the leading slash is
// preserved. n <= 0 returns "" (or "/" for absolute). n >= len of
// component count returns the full path. Useful for "show me the
// top three levels of this path" UI presentation.
fun HeadN(path string, n int) string {
    var rooted bool = false
    if len(path) > 0 {
        if path[0] == slash { rooted = true }
    }
    var parts []string = Components(path)
    var np int = len(parts)
    if n < 0 { n = 0 }
    if n > np { n = np }
    var b *bytes.Builder = bytes.NewBuilder()
    if rooted { b.WriteByte(slash) }
    for i := 0; i < n; i++ {
        if i > 0 { b.WriteByte(slash) }
        b.WriteString(parts[i])
    }
    ret b.String()
}

// TailN returns the last n path components joined back with `/`.
// Rooted-ness is NOT preserved (tail of `/a/b/c` is component-only).
// n <= 0 returns "". n >= component count returns all components
// (without the original leading `/`). Useful for "abbreviated path"
// display when the deep tail matters more than the parent dirs.
fun TailN(path string, n int) string {
    var parts []string = Components(path)
    var np int = len(parts)
    if n < 0 { n = 0 }
    if n > np { n = np }
    var start int = np - n
    var b *bytes.Builder = bytes.NewBuilder()
    for i := start; i < np; i++ {
        if i > start { b.WriteByte(slash) }
        b.WriteString(parts[i])
    }
    ret b.String()
}

// CommonPath returns the longest path that is a component-wise
// prefix of every entry in paths. All paths must agree on rooted-
// ness (all leading-`/` or all not); a mixed set returns "". Empty
// input returns ""; a single-entry input returns that entry verbatim.
// If all paths are rooted but share no first component, returns "/".
// Useful for "where do these all live" UX and tree-root inference.
fun CommonPath(paths []string) string {
    var n int = len(paths)
    if n == 0 { ret "" }
    if n == 1 { ret paths[0] }

    var firstRooted bool = false
    if len(paths[0]) > 0 {
        if paths[0][0] == slash { firstRooted = true }
    }

    var firstComps []string = Components(paths[0])
    var maxK int = len(firstComps)

    for i := 1; i < n; i++ {
        var rooted bool = false
        if len(paths[i]) > 0 {
            if paths[i][0] == slash { rooted = true }
        }
        if rooted != firstRooted { ret "" }

        var comps []string = Components(paths[i])
        var cn int = len(comps)
        var k int = 0
        for k < maxK {
            if k >= cn { break }
            if comps[k] != firstComps[k] { break }
            k = k + 1
        }
        maxK = k
        if maxK == 0 { break }
    }

    if maxK == 0 {
        if firstRooted { ret "/" }
        ret ""
    }

    var b *bytes.Builder = bytes.NewBuilder()
    if firstRooted { b.WriteByte(slash) }
    for k := 0; k < maxK; k++ {
        if k > 0 { b.WriteByte(slash) }
        b.WriteString(firstComps[k])
    }
    ret b.String()
}

// pathSegments splits a Cleaned path into its component pieces.
// Leading "/" for rooted paths is dropped — the rooted-ness is
// tracked separately. Empty path returns an empty slice.
fun pathSegments(p string) []string {
    var n int = len(p)
    var out []string = new(0) []string {}
    var start int = 0
    if n > 0 {
        if p[0] == 47 { start = 1 }   // skip leading '/'
    }
    var i int = start
    var segStart int = i
    for i < n {
        if p[i] == 47 {
            if i > segStart {
                var b *bytes.Builder = bytes.NewBuilder()
                for k := segStart; k < i; k++ { b.WriteByte(p[k]) }
                out = append(out, b.String())
            }
            segStart = i + 1
        }
        i = i + 1
    }
    if i > segStart {
        var b *bytes.Builder = bytes.NewBuilder()
        for k := segStart; k < i; k++ { b.WriteByte(p[k]) }
        out = append(out, b.String())
    }
    ret out
}

// Rel returns a relative path that, when joined to basepath, would
// produce the same path as target (modulo lexical normalization).
// Both inputs must be either both rooted (start with `/`) or both
// unrooted; otherwise an empty string + error is returned. Mirrors
// Go's filepath.Rel for Unix.
fun Rel(basepath string, target string) (string, error) {
    var bClean string = Clean(basepath)
    var tClean string = Clean(target)
    var bRooted bool = IsAbs(bClean)
    var tRooted bool = IsAbs(tClean)
    if bRooted != tRooted {
        ret "", errors.New("filepath.Rel: base and target rootedness differ")
    }
    if bClean == tClean { ret ".", nil }
    var bSegs []string = pathSegments(bClean)
    var tSegs []string = pathSegments(tClean)
    // Treat "." (current directory) as zero segments.
    if len(bSegs) == 1 {
        if bSegs[0] == "." {
            bSegs = new(0) []string {}
        }
    }
    if len(tSegs) == 1 {
        if tSegs[0] == "." {
            tSegs = new(0) []string {}
        }
    }
    var commonLen int = 0
    var bN int = len(bSegs)
    var tN int = len(tSegs)
    var lim int = bN
    if tN < lim { lim = tN }
    for i := 0; i < lim; i++ {
        if bSegs[i] != tSegs[i] { break }
        commonLen = commonLen + 1
    }
    var upSteps int = bN - commonLen
    var out *bytes.Builder = bytes.NewBuilder()
    var wroteAny bool = false
    for i := 0; i < upSteps; i++ {
        if wroteAny { out.WriteByte(47) }
        out.WriteString("..")
        wroteAny = true
    }
    for i := commonLen; i < tN; i++ {
        if wroteAny { out.WriteByte(47) }
        out.WriteString("" + tSegs[i])
        wroteAny = true
    }
    if !wroteAny { ret ".", nil }
    ret out.String(), nil
}

// Match reports whether name matches the shell-style glob pattern.
// Supports `*` (matches any sequence of non-slash bytes) and `?`
// (matches any single non-slash byte). Character classes `[abc]`
// and ranges `[a-z]` are NOT yet supported (volt v1) — they fall
// back to literal-byte match. `/` never matches a wildcard.
//
// Matches Go's filepath.Match surface for the wildcard-and-literal
// subset; character-class support is tracked as future work.
fun Match(pattern string, name string) bool {
    ret matchAt(pattern, 0, name, 0)
}

// matchAt walks pattern from index pi and name from index ni.
// Returns true iff the remaining pattern matches the remaining name.
fun matchAt(pattern string, pi int, name string, ni int) bool {
    var np int = len(pattern)
    var nn int = len(name)
    for pi < np {
        var c byte = pattern[pi]
        if c == 42 {           // '*'
            // Skip consecutive '*'s — they're equivalent to one.
            for pi < np {
                if pattern[pi] != 42 { break }
                pi = pi + 1
            }
            if pi == np { ret true }   // trailing '*' matches the rest
            // Try matching '*' against successively longer prefixes
            // of name from current position.
            var j int = ni
            for j <= nn {
                if matchAt(pattern, pi, name, j) { ret true }
                if j == nn { break }
                if name[j] == 47 { ret false }   // '*' never matches '/'
                j = j + 1
            }
            ret false
        }
        if ni == nn { ret false }
        var nc byte = name[ni]
        if c == 63 {           // '?'
            if nc == 47 { ret false }   // '?' never matches '/'
            pi = pi + 1
            ni = ni + 1
            continue
        }
        if c != nc { ret false }
        pi = pi + 1
        ni = ni + 1
    }
    if ni == nn { ret true }
    ret false
}
