package main
import "log"
import "path/filepath"

// Positive test: filepath.Depth + filepath.IsParent.

fun main() int {
	var pass int = 0

	// Depth — root.
	if filepath.Depth("/") == 0 { pass = pass + 1 }

	// Depth — single component.
	if filepath.Depth("/a") == 1 { pass = pass + 1 }
	if filepath.Depth("a") == 1 { pass = pass + 1 }
	if filepath.Depth("foo") == 1 { pass = pass + 1 }

	// Depth — multiple components.
	if filepath.Depth("/a/b/c") == 3 { pass = pass + 1 }
	if filepath.Depth("a/b") == 2 { pass = pass + 1 }
	if filepath.Depth("/usr/local/bin") == 3 { pass = pass + 1 }
	if filepath.Depth("/usr/local/share/man/man1") == 5 { pass = pass + 1 }

	// Depth — empty.
	if filepath.Depth("") == 0 { pass = pass + 1 }

	// Depth — runs of slashes don't inflate (Components consumes them).
	if filepath.Depth("//a///b//") == 2 { pass = pass + 1 }

	// IsParent — basic ancestor.
	if filepath.IsParent("/a", "/a/b") { pass = pass + 1 }
	if filepath.IsParent("/a/b", "/a/b/c") { pass = pass + 1 }
	if filepath.IsParent("/usr", "/usr/local/bin") { pass = pass + 1 }

	// IsParent — root is parent of everything.
	if filepath.IsParent("/", "/a") { pass = pass + 1 }
	if filepath.IsParent("/", "/usr/local") { pass = pass + 1 }

	// IsParent — trailing slash on parent OK.
	if filepath.IsParent("/a/", "/a/b") { pass = pass + 1 }
	if filepath.IsParent("/a//", "/a/b") { pass = pass + 1 }

	// IsParent — equal paths NOT parent.
	if !filepath.IsParent("/a", "/a") { pass = pass + 1 }
	if !filepath.IsParent("/", "/") { pass = pass + 1 }

	// IsParent — sibling NOT parent.
	if !filepath.IsParent("/a", "/b") { pass = pass + 1 }
	if !filepath.IsParent("/foo", "/foobar") { pass = pass + 1 }   // not a path boundary

	// IsParent — child shorter than parent.
	if !filepath.IsParent("/a/b/c", "/a") { pass = pass + 1 }

	// IsParent — empty parent.
	if !filepath.IsParent("", "/a") { pass = pass + 1 }

	// Relative path containment.
	if filepath.IsParent("a", "a/b") { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 24 { ret 42 }
	ret 0
}
