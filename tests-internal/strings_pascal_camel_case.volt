package main
import "log"
import "strings"

// Positive test: strings.PascalCase + strings.CamelCase.

fun main() int {
	var pass int = 0

	// PascalCase from snake.
	if strings.PascalCase("my_class_name") == "MyClassName" { pass = pass + 1 }
	if strings.PascalCase("hello_world") == "HelloWorld" { pass = pass + 1 }

	// From kebab.
	if strings.PascalCase("css-class-name") == "CssClassName" { pass = pass + 1 }

	// From space-separated.
	if strings.PascalCase("hello world") == "HelloWorld" { pass = pass + 1 }

	// Single word lowercased.
	if strings.PascalCase("foo") == "Foo" { pass = pass + 1 }

	// Already PascalCase preserved (no separators to act on).
	if strings.PascalCase("MyClassName") == "MyClassName" { pass = pass + 1 }

	// Mixed separators.
	if strings.PascalCase("a_b-c d") == "ABCD" { pass = pass + 1 }

	// Empty.
	if strings.PascalCase("") == "" { pass = pass + 1 }

	// Numbers in middle preserved.
	if strings.PascalCase("item_42_value") == "Item42Value" { pass = pass + 1 }

	// Leading separator handled (next-upper resets, no leading sep emitted).
	if strings.PascalCase("_foo_bar") == "FooBar" { pass = pass + 1 }

	// CamelCase — same but first letter lower.
	if strings.CamelCase("my_class_name") == "myClassName" { pass = pass + 1 }
	if strings.CamelCase("hello_world") == "helloWorld" { pass = pass + 1 }
	if strings.CamelCase("css-class-name") == "cssClassName" { pass = pass + 1 }
	if strings.CamelCase("hello world") == "helloWorld" { pass = pass + 1 }
	if strings.CamelCase("foo") == "foo" { pass = pass + 1 }
	if strings.CamelCase("") == "" { pass = pass + 1 }

	// Roundtrip: PascalCase ↔ SnakeCase.
	var snake string = strings.SnakeCase("MyClassName")
	if snake == "my_class_name" { pass = pass + 1 }
	if strings.PascalCase(snake) == "MyClassName" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
