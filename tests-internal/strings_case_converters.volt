package main
import "log"
import "strings"

// Positive test: strings.SnakeCase + strings.KebabCase.

fun main() int {
	var pass int = 0

	// SnakeCase from CamelCase.
	if strings.SnakeCase("MyClassName") == "my_class_name" { pass = pass + 1 }
	// camelCase variant.
	if strings.SnakeCase("myClassName") == "my_class_name" { pass = pass + 1 }
	// Already snake.
	if strings.SnakeCase("already_snake") == "already_snake" { pass = pass + 1 }
	// All lowercase.
	if strings.SnakeCase("foo") == "foo" { pass = pass + 1 }
	// Acronym preserved.
	if strings.SnakeCase("HTTPRequest") == "http_request" { pass = pass + 1 }
	if strings.SnakeCase("HTTP") == "http" { pass = pass + 1 }
	// Mixed acronym + word.
	if strings.SnakeCase("OAuthClient") == "o_auth_client" { pass = pass + 1 }
	// Single char.
	if strings.SnakeCase("X") == "x" { pass = pass + 1 }
	if strings.SnakeCase("a") == "a" { pass = pass + 1 }
	// Numbers preserved.
	if strings.SnakeCase("Item42") == "item42" { pass = pass + 1 }
	// Empty.
	if strings.SnakeCase("") == "" { pass = pass + 1 }
	// Underscores already there preserved.
	if strings.SnakeCase("foo_BarBaz") == "foo_bar_baz" { pass = pass + 1 }

	// KebabCase — same rules with '-'.
	if strings.KebabCase("MyClassName") == "my-class-name" { pass = pass + 1 }
	if strings.KebabCase("HTTPRequest") == "http-request" { pass = pass + 1 }
	if strings.KebabCase("alreadyKebab") == "already-kebab" { pass = pass + 1 }
	if strings.KebabCase("") == "" { pass = pass + 1 }
	if strings.KebabCase("foo") == "foo" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 17 { ret 42 }
	ret 0
}
