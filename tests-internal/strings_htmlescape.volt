package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// HtmlEscape — each metachar.
	if strings.HtmlEscape("&") == "&amp;" { pass = pass + 1 }
	if strings.HtmlEscape("<") == "&lt;" { pass = pass + 1 }
	if strings.HtmlEscape(">") == "&gt;" { pass = pass + 1 }
	if strings.HtmlEscape("\"") == "&quot;" { pass = pass + 1 }
	if strings.HtmlEscape("'") == "&#39;" { pass = pass + 1 }

	// HtmlEscape — mixed.
	if strings.HtmlEscape("a < b && c") == "a &lt; b &amp;&amp; c" { pass = pass + 1 }
	if strings.HtmlEscape("<p>Hi</p>") == "&lt;p&gt;Hi&lt;/p&gt;" { pass = pass + 1 }

	// HtmlEscape — empty / no special.
	if strings.HtmlEscape("") == "" { pass = pass + 1 }
	if strings.HtmlEscape("plain text") == "plain text" { pass = pass + 1 }

	// HtmlUnescape — each entity.
	if strings.HtmlUnescape("&amp;") == "&" { pass = pass + 1 }
	if strings.HtmlUnescape("&lt;") == "<" { pass = pass + 1 }
	if strings.HtmlUnescape("&gt;") == ">" { pass = pass + 1 }
	if strings.HtmlUnescape("&quot;") == "\"" { pass = pass + 1 }
	if strings.HtmlUnescape("&#39;") == "'" { pass = pass + 1 }
	if strings.HtmlUnescape("&apos;") == "'" { pass = pass + 1 }
	if strings.HtmlUnescape("&#34;") == "\"" { pass = pass + 1 }

	// HtmlUnescape — mixed.
	if strings.HtmlUnescape("a &lt; b &amp;&amp; c") == "a < b && c" { pass = pass + 1 }
	if strings.HtmlUnescape("&lt;p&gt;Hi&lt;/p&gt;") == "<p>Hi</p>" { pass = pass + 1 }

	// HtmlUnescape — unknown entity passes through.
	if strings.HtmlUnescape("&nbsp;") == "&nbsp;" { pass = pass + 1 }

	// HtmlUnescape — empty / no entities.
	if strings.HtmlUnescape("") == "" { pass = pass + 1 }
	if strings.HtmlUnescape("plain text") == "plain text" { pass = pass + 1 }

	// HtmlUnescape(HtmlEscape(s)) is identity (when s lacks entity-like fragments).
	if strings.HtmlUnescape(strings.HtmlEscape("a<b&c>d")) == "a<b&c>d" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 22 { ret 42 }
	ret 0
}
