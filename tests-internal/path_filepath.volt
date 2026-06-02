// path/filepath smoke — Base, Dir, Ext, Join.

package main

import "path/filepath"
import "log"

fun main() int {
    var pass int = 0

    // Base
    if filepath.Base("/usr/bin/volt") == "volt"  { pass = pass + 1 }
    if filepath.Base("volt")          == "volt"  { pass = pass + 1 }
    if filepath.Base("/")             == "/"     { pass = pass + 1 }
    if filepath.Base("")              == "."     { pass = pass + 1 }
    if filepath.Base("/usr/")         == "usr"   { pass = pass + 1 }
    if filepath.Base("./x/y")         == "y"     { pass = pass + 1 }

    // Dir
    if filepath.Dir("/usr/bin/volt") == "/usr/bin" { pass = pass + 1 }
    if filepath.Dir("volt")          == "."        { pass = pass + 1 }
    if filepath.Dir("/x")            == "/"        { pass = pass + 1 }
    if filepath.Dir("")              == "."        { pass = pass + 1 }
    if filepath.Dir("/usr/")         == "/"        { pass = pass + 1 }
    if filepath.Dir("a/b/c.txt")     == "a/b"      { pass = pass + 1 }

    // Ext
    if filepath.Ext("main.volt")     == ".volt"    { pass = pass + 1 }
    if filepath.Ext("README")        == ""         { pass = pass + 1 }
    if filepath.Ext("a.tar.gz")      == ".gz"      { pass = pass + 1 }
    if filepath.Ext("dir.foo/x")     == ""         { pass = pass + 1 }   // dot in dir, not basename
    if filepath.Ext(".hidden")       == ".hidden"  { pass = pass + 1 }   // leading-dot file: whole thing is ext per Go semantics

    // Join
    if filepath.Join("a", "b")       == "a/b"      { pass = pass + 1 }
    if filepath.Join("a/", "b")      == "a/b"      { pass = pass + 1 }
    if filepath.Join("a", "/b")      == "a/b"      { pass = pass + 1 }
    if filepath.Join("a//", "//b")   == "a/b"      { pass = pass + 1 }
    if filepath.Join("", "b")        == "b"        { pass = pass + 1 }
    if filepath.Join("a", "")        == "a"        { pass = pass + 1 }
    if filepath.Join("/usr/bin", "volt") == "/usr/bin/volt" { pass = pass + 1 }

    log.Println("pass=%d/24", pass)
    if pass == 24 { ret 42 }
    ret 0
}
