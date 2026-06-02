package main
import "log"
import "path/filepath"

fun main() int {
	var pass int = 0

	// HasExt — both with and without leading dot in `ext`.
	if filepath.HasExt("foo.txt", "txt") { pass = pass + 1 }
	if filepath.HasExt("foo.txt", ".txt") { pass = pass + 1 }

	// HasExt — false on mismatch.
	if !filepath.HasExt("foo.txt", "md") { pass = pass + 1 }
	if !filepath.HasExt("foo.txt", ".md") { pass = pass + 1 }

	// HasExt — multi-extension only matches the final segment.
	if filepath.HasExt("archive.tar.gz", "gz") { pass = pass + 1 }
	if !filepath.HasExt("archive.tar.gz", "tar") { pass = pass + 1 }
	if !filepath.HasExt("archive.tar.gz", "tar.gz") { pass = pass + 1 }

	// HasExt — with a path prefix.
	if filepath.HasExt("/usr/local/file.cfg", "cfg") { pass = pass + 1 }
	if filepath.HasExt("./local/file.html", ".html") { pass = pass + 1 }

	// HasExt — no extension → empty `ext` matches.
	if filepath.HasExt("readme", "") { pass = pass + 1 }
	if filepath.HasExt("./readme", "") { pass = pass + 1 }
	if !filepath.HasExt("foo.txt", "") { pass = pass + 1 }

	// HasExt — empty path.
	if filepath.HasExt("", "") { pass = pass + 1 }
	if !filepath.HasExt("", "txt") { pass = pass + 1 }

	// HasExt — hidden file (leading-dot basename). Volt's Ext treats
	// ".bashrc" as having extension ".bashrc" (consistent with Ext's
	// trailing-dot scan, less so with SplitExt's hidden-file handling),
	// so HasExt with explicit "bashrc" matches.
	if filepath.HasExt(".bashrc", "bashrc") { pass = pass + 1 }
	if !filepath.HasExt(".bashrc", "") { pass = pass + 1 }

	// HasExt — case sensitivity.
	if filepath.HasExt("photo.JPG", "JPG") { pass = pass + 1 }
	if !filepath.HasExt("photo.JPG", "jpg") { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
