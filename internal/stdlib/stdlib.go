// Package stdlib embeds the volt standard-library source files so the
// compiler binary is self-contained. The driver compiles these alongside
// user code when their packages are imported.
//
// Note: the syscall package is a placeholder for `import "syscall"`. Its
// `Write`/`Exit` functions are compiler intrinsics — the codegen lowers
// them directly to calls into the runtime. So syscall.volt contains no
// function bodies.
package stdlib

import (
	"embed"
	"io/fs"
	"strings"
)

//go:embed bufio/bufio.volt bytes/bytes.volt crypto/hmac/hmac.volt crypto/md5/md5.volt crypto/rand/rand.volt crypto/sha1/sha1.volt crypto/sha256/sha256.volt encoding/base64/base64.volt encoding/hex/hex.volt errors/errors.volt fmt/fmt.volt hash/adler32/adler32.volt hash/crc32/crc32.volt hash/fnv/fnv.volt io/io.volt json/json.volt log/log.volt maps/maps.volt math/math.volt net/net.volt os/os.volt path/filepath/filepath.volt runtime/runtime.volt slices/slices.volt sort/sort.volt strconv/strconv.volt strings/strings.volt syscall/syscall.volt testing/testing.volt time/time.volt unicode/unicode.volt
var files embed.FS

// Source returns the source bytes for the named package's main file,
// or (nil, false) if the package is unknown to the embedded stdlib.
// Multi-segment paths (`hash/fnv`) look up `hash/fnv/fnv.volt` —
// the last path segment is the file basename.
func Source(pkg string) ([]byte, bool) {
	last := pkg
	if i := strings.LastIndex(pkg, "/"); i >= 0 {
		last = pkg[i+1:]
	}
	b, err := fs.ReadFile(files, pkg+"/"+last+".volt")
	if err != nil {
		return nil, false
	}
	return b, true
}

// List returns the import paths of every embedded stdlib package,
// sorted alphabetically. Derived from a single walk of the embedded
// FS so it stays automatically in sync with the go:embed line.
//
// Each entry is the import path (`crypto/sha256`, `hash/fnv`,
// `strings`, etc.) — the same string a user code would pass to
// `import "..."`.
func List() []string {
	var out []string
	_ = fs.WalkDir(files, ".", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		if !d.IsDir() && strings.HasSuffix(path, ".volt") {
			// Strip the `<basename>/<basename>.volt` suffix.
			dir := path
			if i := strings.LastIndex(dir, "/"); i >= 0 {
				dir = dir[:i]
			}
			out = append(out, dir)
		}
		return nil
	})
	return out
}

// ShortNameToPath maps a stdlib package's short (basename) name to
// its full import path. `strings` → `strings`, `sha256` → `crypto/sha256`,
// `filepath` → `path/filepath`. Built once from List() so adding a
// new stdlib package (extend the go:embed line + drop a .volt) shows
// up automatically wherever the map is consumed.
func ShortNameToPath() map[string]string {
	m := make(map[string]string)
	for _, p := range List() {
		short := p
		if i := strings.LastIndex(p, "/"); i >= 0 {
			short = p[i+1:]
		}
		m[short] = p
	}
	return m
}
