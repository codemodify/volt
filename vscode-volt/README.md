# vscode-volt

Syntax highlighting for the [volt](../) programming language.

## What it highlights

- Comments (`//`, `/* */`)
- Strings (`"..."`, raw `` `...` ``), runes (`'...'`), escape sequences
- Numeric literals — decimal, hex (`0x`), binary (`0b`), octal (`0o`), float, with `_` digit separators
- Keywords
  - 3-letter set: `var`, `fun`, `ret`, `def`, `run`, `new`, `int`, `for`, `nil`, `map`
  - Longer set: `package`, `import`, `type`, `struct`, `interface`, `if`, `else`, `switch`, `case`, `default`, `chan`, `range`, `break`, `continue`, `const`, `select`, `true`, `false`
- Built-in types: `int8..int64`, `uint..uint64`, `float..float64`, `byte`, `rune`, `bool`, `string`, `error`, `any`, `void`
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
cp -r . ~/.vscode/extensions/codemodify.vscode-volt-0.1.0
```

Then restart VS Code and open a `.volt` file (e.g. [../testdata/tour.volt](../testdata/tour.volt)).

## Install (packaged)

```bash
npm i -g @vscode/vsce
vsce package
code --install-extension vscode-volt-0.1.0.vsix
```

## Layout

- [package.json](package.json) — extension manifest, registers the `volt` language and `.volt` extension
- [language-configuration.json](language-configuration.json) — brackets, comments, indent rules
- [syntaxes/volt.tmLanguage.json](syntaxes/volt.tmLanguage.json) — TextMate grammar driving the colorizer
