package main
import "log"
import "strings"

// Positive test: strings.EscapeHTML + strings.UnescapeHTML.

fun main() int {
	var pass int = 0

	// EscapeHTML — individual chars.
	if strings.EscapeHTML("<") == "&lt;" { pass = pass + 1 }
	if strings.EscapeHTML(">") == "&gt;" { pass = pass + 1 }
	if strings.EscapeHTML("&") == "&amp;" { pass = pass + 1 }
	if strings.EscapeHTML("\"") == "&quot;" { pass = pass + 1 }
	if strings.EscapeHTML("'") == "&#39;" { pass = pass + 1 }

	// EscapeHTML — mixed.
	if strings.EscapeHTML("<p>hello</p>") == "&lt;p&gt;hello&lt;/p&gt;" { pass = pass + 1 }
	if strings.EscapeHTML("Tom & Jerry") == "Tom &amp; Jerry" { pass = pass + 1 }
	if strings.EscapeHTML("\"quoted\"") == "&quot;quoted&quot;" { pass = pass + 1 }
	if strings.EscapeHTML("don't") == "don&#39;t" { pass = pass + 1 }

	// EscapeHTML — no-op (no special chars).
	if strings.EscapeHTML("hello world") == "hello world" { pass = pass + 1 }
	if strings.EscapeHTML("") == "" { pass = pass + 1 }

	// EscapeHTML — combined.
	if strings.EscapeHTML("a < b && c > d") == "a &lt; b &amp;&amp; c &gt; d" { pass = pass + 1 }

	// UnescapeHTML — individual.
	if strings.UnescapeHTML("&lt;") == "<" { pass = pass + 1 }
	if strings.UnescapeHTML("&gt;") == ">" { pass = pass + 1 }
	if strings.UnescapeHTML("&amp;") == "&" { pass = pass + 1 }
	if strings.UnescapeHTML("&quot;") == "\"" { pass = pass + 1 }
	if strings.UnescapeHTML("&#39;") == "'" { pass = pass + 1 }
	if strings.UnescapeHTML("&apos;") == "'" { pass = pass + 1 }

	// UnescapeHTML — combined.
	if strings.UnescapeHTML("&lt;p&gt;hello&lt;/p&gt;") == "<p>hello</p>" { pass = pass + 1 }
	if strings.UnescapeHTML("Tom &amp; Jerry") == "Tom & Jerry" { pass = pass + 1 }
	if strings.UnescapeHTML("&quot;quoted&quot;") == "\"quoted\"" { pass = pass + 1 }

	// UnescapeHTML — pass-through for unknown / partial entities.
	if strings.UnescapeHTML("&zzz;") == "&zzz;" { pass = pass + 1 }
	if strings.UnescapeHTML("a & b") == "a & b" { pass = pass + 1 }   // bare '&' with no entity
	if strings.UnescapeHTML("&am") == "&am" { pass = pass + 1 }        // truncated

	// UnescapeHTML — empty.
	if strings.UnescapeHTML("") == "" { pass = pass + 1 }

	// Roundtrip.
	var s string = "<a href=\"x\">don't & click</a>"
	if strings.UnescapeHTML(strings.EscapeHTML(s)) == s { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 26 { ret 42 }
	ret 0
}
