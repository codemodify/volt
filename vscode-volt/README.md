# vscode-volt

Syntax highlighting for the [volt](../) programming language.

## What it highlights

- Comments (`//`, `/* */`)
- Strings (`"..."`, raw `` `...` ``), runes (`'...'`), escape sequences
- Numeric literals — decimal, hex (`0x`), binary (`0b`), octal (`0o`), float, with `_` digit separators
- Keywords
  - 3-letter set: `var`, `fun`, `ret`, `def`, `run`, `new`, `for`, `nil`, `map`
  - Longer set: `package`, `import`, `type`, `struct`, `interface`, `if`, `else`, `switch`, `case`, `default`, `range`, `break`, `continue`, `const`, `select`, `true`, `false`
- Built-in data types (all share one color):
  - numeric: `int`, `int8`, `int16`, `int32`, `int64`, `uint`, `uint8`, `uint16`, `uint32`, `uint64`, `float`, `float32`, `float64`, `byte`, `rune`
  - other primitives: `bool`, `string`, `error`, `any`, `void`
  - concurrency wrappers: `chan`, `mutex`, `rwmutex`, `atomic`, `waitgroup`, `once`
- Type sigils: `*T` (unique mutable borrow), `&T` (shared read-only borrow)
- Channel send/receive: `<-`
- Operators: arithmetic, bitwise, comparison, logical, assignment, `:=`, variadic `...`
- Function declarations (`fun name(...)`) and method declarations (`fun (r *T) name(...)`)
- Type declarations (`type Name struct {...}`, `type Name interface {...}`)
- Function and method calls, field/selector access

## Install (local dev)

The fastest way to try it without packaging:

```bash
# from this directory
cp -r . ~/.vscode/extensions/codemodify.vscode-volt-0.2.0
```

Then restart VS Code and open a `.volt` file (e.g. [../docs/design/concurrency.volt](../docs/design/concurrency.volt)).

## Install (packaged)

```bash
npm i -g @vscode/vsce
vsce package
code --install-extension vscode-volt-0.2.0.vsix
```

## Layout

- [package.json](package.json) — extension manifest, registers the `volt` language and `.volt` extension
- [language-configuration.json](language-configuration.json) — brackets, comments, indent rules
- [syntaxes/volt.tmLanguage.json](syntaxes/volt.tmLanguage.json) — TextMate grammar driving the colorizer
