// Package lex implements the volt lexer (tokenizer).
//
// The lexer reads a .volt source file as bytes and produces a stream
// of tokens for the parser. It handles whitespace, comments, identifiers,
// keywords, literals, operators, and Go-style statement-terminator
// insertion at line ends.
//
// See grammar.ebnf for the full token set.
package lex

import (
	"fmt"
	"unicode/utf8"
)

// Kind enumerates token kinds.
type Kind int

const (
	Illegal Kind = iota
	EOF
	Semi // ';' — explicit or auto-inserted at end of line

	// literals
	Ident
	Int
	Float
	String
	Rune

	// keywords (prefixed Kw to avoid collisions with Go identifiers like New)
	KwAtomic
	KwBreak
	KwCase
	KwChan
	KwChan11
	KwChan1N
	KwChanN1
	KwChanNN
	KwCondvar
	KwConst
	KwContinue
	KwDef
	KwDefault
	KwElse
	KwFalse
	KwFor
	KwFun
	KwIf
	KwImport
	KwInterface
	KwMap
	KwMut
	KwMutex
	KwNew
	KwNil
	KwOnce
	KwPackage
	KwRange
	KwRet
	KwRun
	KwRwMutex
	KwSelect
	KwStruct
	KwSwitch
	KwTrue
	KwType
	KwVar
	KwWaitgroup

	// punctuation
	LBrace   // {
	RBrace   // }
	LParen   // (
	RParen   // )
	LBrack   // [
	RBrack   // ]
	Comma    // ,
	Dot      // .
	Colon    // :
	Ellipsis // ...

	// operators / assignment
	Assign        // =
	ColonAssign   // :=
	Plus          // +
	Minus         // -
	Star          // *
	Slash         // /
	Percent       // %
	Eq            // ==
	Neq           // !=
	Lt            // <
	Leq           // <=
	Gt            // >
	Geq           // >=
	LAnd          // &&
	LOr           // ||
	LNot          // !
	Amp           // &
	Pipe          // |
	Caret         // ^
	Shl           // <<
	Shr           // >>
	Arrow         // <-
	Inc           // ++
	Dec           // --
	PlusAssign    // +=
	MinusAssign   // -=
	StarAssign    // *=
	SlashAssign   // /=
	PercentAssign // %=
	AmpAssign     // &=
	PipeAssign    // |=
	CaretAssign   // ^=
	ShlAssign     // <<=
	ShrAssign     // >>=
)

var kindNames = [...]string{
	Illegal:       "ILLEGAL",
	EOF:           "EOF",
	Semi:          ";",
	Ident:         "IDENT",
	Int:           "INT",
	Float:         "FLOAT",
	String:        "STRING",
	Rune:          "RUNE",
	KwAtomic:      "atomic",
	KwBreak:       "break",
	KwCase:        "case",
	KwChan:        "chan",
	KwChan11:      "chan11",
	KwChan1N:      "chan1N",
	KwChanN1:      "chanN1",
	KwChanNN:      "chanNN",
	KwCondvar:     "condvar",
	KwConst:       "const",
	KwContinue:    "continue",
	KwDef:         "def",
	KwDefault:     "default",
	KwElse:        "else",
	KwFalse:       "false",
	KwFor:         "for",
	KwFun:         "fun",
	KwIf:          "if",
	KwImport:      "import",
	KwInterface:   "interface",
	KwMap:         "map",
	KwMut:         "mut",
	KwMutex:       "mutex",
	KwNew:         "new",
	KwNil:         "nil",
	KwOnce:        "once",
	KwPackage:     "package",
	KwRange:       "range",
	KwRet:         "ret",
	KwRun:         "run",
	KwRwMutex:     "rwmutex",
	KwSelect:      "select",
	KwStruct:      "struct",
	KwSwitch:      "switch",
	KwTrue:        "true",
	KwType:        "type",
	KwVar:         "var",
	KwWaitgroup:   "waitgroup",
	LBrace:        "{",
	RBrace:        "}",
	LParen:        "(",
	RParen:        ")",
	LBrack:        "[",
	RBrack:        "]",
	Comma:         ",",
	Dot:           ".",
	Colon:         ":",
	Ellipsis:      "...",
	Assign:        "=",
	ColonAssign:   ":=",
	Plus:          "+",
	Minus:         "-",
	Star:          "*",
	Slash:         "/",
	Percent:       "%",
	Eq:            "==",
	Neq:           "!=",
	Lt:            "<",
	Leq:           "<=",
	Gt:            ">",
	Geq:           ">=",
	LAnd:          "&&",
	LOr:           "||",
	LNot:          "!",
	Amp:           "&",
	Pipe:          "|",
	Caret:         "^",
	Shl:           "<<",
	Shr:           ">>",
	Arrow:         "<-",
	Inc:           "++",
	Dec:           "--",
	PlusAssign:    "+=",
	MinusAssign:   "-=",
	StarAssign:    "*=",
	SlashAssign:   "/=",
	PercentAssign: "%=",
	AmpAssign:     "&=",
	PipeAssign:    "|=",
	CaretAssign:   "^=",
	ShlAssign:     "<<=",
	ShrAssign:     ">>=",
}

func (k Kind) String() string {
	if int(k) < len(kindNames) && kindNames[k] != "" {
		return kindNames[k]
	}
	return fmt.Sprintf("Kind(%d)", int(k))
}

var keywords = map[string]Kind{
	"atomic":    KwAtomic,
	"break":     KwBreak,
	"case":      KwCase,
	"chan":      KwChan,
	"chan11":    KwChan11,
	"chan1N":    KwChan1N,
	"chanN1":    KwChanN1,
	"chanNN":    KwChanNN,
	"condvar":   KwCondvar,
	"const":     KwConst,
	"continue":  KwContinue,
	"def":       KwDef,
	"default":   KwDefault,
	"else":      KwElse,
	"false":     KwFalse,
	"for":       KwFor,
	"fun":       KwFun,
	"if":        KwIf,
	"import":    KwImport,
	"interface": KwInterface,
	"map":       KwMap,
	"mut":       KwMut,
	"mutex":     KwMutex,
	"new":       KwNew,
	"nil":       KwNil,
	"once":      KwOnce,
	"package":   KwPackage,
	"range":     KwRange,
	"ret":       KwRet,
	"run":       KwRun,
	"rwmutex":   KwRwMutex,
	"select":    KwSelect,
	"struct":    KwStruct,
	"switch":    KwSwitch,
	"true":      KwTrue,
	"type":      KwType,
	"var":       KwVar,
	"waitgroup": KwWaitgroup,
}

// Pos is a source position for diagnostics.
type Pos struct {
	File   string
	Line   int
	Column int
}

func (p Pos) String() string { return fmt.Sprintf("%s:%d:%d", p.File, p.Line, p.Column) }

// Token is a lexed token with kind, text, and source position.
type Token struct {
	Kind Kind
	Text string
	Pos  Pos
}

func (t Token) String() string {
	if t.Text != "" && t.Text != t.Kind.String() {
		return fmt.Sprintf("%s(%q) @ %s", t.Kind, t.Text, t.Pos)
	}
	return fmt.Sprintf("%s @ %s", t.Kind, t.Pos)
}

// Comment is a captured comment with its source position. Position
// refers to the start of the comment (the leading `/`).
type Comment struct {
	Pos  Pos
	Text string // includes the leading `//` or `/* */` delimiters
}

// Lexer tokenizes a single source file.
type Lexer struct {
	file string
	src  []byte
	pos  int // byte offset of next char to read
	line int // 1-based
	col  int // 1-based, column of next char

	// for Go-style semicolon insertion
	prev    Kind // kind of last non-Semi token emitted (Illegal if none)
	pending *Token

	// captured comments in source order
	comments []Comment
}

// Comments returns all comments encountered so far, in source order.
// Safe to call after EOF.
func (l *Lexer) Comments() []Comment { return l.comments }

// New returns a Lexer for the given source.
func New(file string, src []byte) *Lexer {
	return &Lexer{file: file, src: src, line: 1, col: 1, prev: Illegal}
}

// Next returns the next token. Returns EOF when exhausted.
func (l *Lexer) Next() Token {
	if l.pending != nil {
		t := *l.pending
		l.pending = nil
		l.prev = t.Kind
		return t
	}

	// Skip whitespace; track whether we crossed a newline (for semi-insertion).
	sawNewline := l.skipWhitespaceAndComments()
	if sawNewline && needsSemiAfter(l.prev) {
		// Buffer the actual next token; emit a Semi now.
		realTok := l.scanOne()
		semi := Token{Kind: Semi, Text: ";", Pos: realTok.Pos}
		l.pending = &realTok
		l.prev = Semi
		return semi
	}

	tok := l.scanOne()
	if tok.Kind == EOF && needsSemiAfter(l.prev) {
		// Final implicit semi at EOF.
		semi := Token{Kind: Semi, Text: ";", Pos: tok.Pos}
		l.pending = &tok
		l.prev = Semi
		return semi
	}
	l.prev = tok.Kind
	return tok
}

// scanOne reads exactly one token (no semi-insertion logic; caller handles).
func (l *Lexer) scanOne() Token {
	if l.pos >= len(l.src) {
		return Token{Kind: EOF, Pos: l.posHere()}
	}

	start := l.posHere()
	c := l.src[l.pos]

	switch {
	case isLetter(c):
		return l.scanIdentOrKeyword(start)
	case isDigit(c):
		return l.scanNumber(start)
	case c == '"':
		return l.scanString(start)
	case c == '\'':
		return l.scanRune(start)
	case c == '`':
		return l.scanRawString(start)
	}

	// Multi-char and single-char operators.
	return l.scanOp(start)
}

// ---------- scanners ----------

func (l *Lexer) scanIdentOrKeyword(start Pos) Token {
	begin := l.pos
	for l.pos < len(l.src) && (isLetter(l.src[l.pos]) || isDigit(l.src[l.pos])) {
		l.advance()
	}
	text := string(l.src[begin:l.pos])
	if k, ok := keywords[text]; ok {
		return Token{Kind: k, Text: text, Pos: start}
	}
	return Token{Kind: Ident, Text: text, Pos: start}
}

func (l *Lexer) scanNumber(start Pos) Token {
	begin := l.pos
	kind := Int

	// Detect prefix (0x, 0b, 0o)
	if l.src[l.pos] == '0' && l.pos+1 < len(l.src) {
		p := l.src[l.pos+1]
		if p == 'x' || p == 'X' || p == 'b' || p == 'B' || p == 'o' || p == 'O' {
			l.advance()
			l.advance()
			for l.pos < len(l.src) && (isHexDigit(l.src[l.pos]) || l.src[l.pos] == '_') {
				l.advance()
			}
			return Token{Kind: Int, Text: string(l.src[begin:l.pos]), Pos: start}
		}
	}

	// Decimal int or float.
	for l.pos < len(l.src) && (isDigit(l.src[l.pos]) || l.src[l.pos] == '_') {
		l.advance()
	}
	if l.pos < len(l.src) && l.src[l.pos] == '.' {
		// Could be a float or a range/operator — but '.' followed by digit means float.
		// Look ahead one char.
		if l.pos+1 < len(l.src) && isDigit(l.src[l.pos+1]) {
			kind = Float
			l.advance()
			for l.pos < len(l.src) && (isDigit(l.src[l.pos]) || l.src[l.pos] == '_') {
				l.advance()
			}
		}
	}
	// Exponent
	if l.pos < len(l.src) && (l.src[l.pos] == 'e' || l.src[l.pos] == 'E') {
		kind = Float
		l.advance()
		if l.pos < len(l.src) && (l.src[l.pos] == '+' || l.src[l.pos] == '-') {
			l.advance()
		}
		for l.pos < len(l.src) && (isDigit(l.src[l.pos]) || l.src[l.pos] == '_') {
			l.advance()
		}
	}
	return Token{Kind: kind, Text: string(l.src[begin:l.pos]), Pos: start}
}

func (l *Lexer) scanString(start Pos) Token {
	l.advance() // consume opening "
	var b []byte
	for l.pos < len(l.src) {
		c := l.src[l.pos]
		if c == '"' {
			l.advance()
			return Token{Kind: String, Text: string(b), Pos: start}
		}
		if c == '\n' {
			return Token{Kind: Illegal, Text: "unterminated string", Pos: start}
		}
		if c == '\\' {
			l.advance()
			if l.pos >= len(l.src) {
				return Token{Kind: Illegal, Text: "unterminated escape", Pos: start}
			}
			esc := l.src[l.pos]
			switch esc {
			case 'n':
				b = append(b, '\n')
			case 't':
				b = append(b, '\t')
			case 'r':
				b = append(b, '\r')
			case '0':
				b = append(b, 0)
			case 'a':
				b = append(b, 0x07)
			case 'B':
				b = append(b, 0x08)
			case 'b':
				b = append(b, 0x08)
			case 'f':
				b = append(b, 0x0C)
			case 'v':
				b = append(b, 0x0B)
			case '\\':
				b = append(b, '\\')
			case '"':
				b = append(b, '"')
			case '\'':
				b = append(b, '\'')
			case 'x':
				l.advance()
				if l.pos+1 >= len(l.src) {
					return Token{Kind: Illegal, Text: "unterminated \\x escape", Pos: start}
				}
				h1 := hexNibble(l.src[l.pos])
				h2 := hexNibble(l.src[l.pos+1])
				if h1 < 0 || h2 < 0 {
					return Token{Kind: Illegal, Text: "bad \\x escape", Pos: start}
				}
				b = append(b, byte((h1<<4)|h2))
				l.advance()
				l.advance()
				continue
			default:
				// Unknown escape: emit the char as-is.
				b = append(b, esc)
			}
			l.advance()
			continue
		}
		b = append(b, c)
		l.advance()
	}
	return Token{Kind: Illegal, Text: "unterminated string at EOF", Pos: start}
}

func (l *Lexer) scanRawString(start Pos) Token {
	l.advance() // consume opening `
	begin := l.pos
	for l.pos < len(l.src) {
		if l.src[l.pos] == '`' {
			text := string(l.src[begin:l.pos])
			l.advance()
			return Token{Kind: String, Text: text, Pos: start}
		}
		l.advance()
	}
	return Token{Kind: Illegal, Text: "unterminated raw string", Pos: start}
}

func (l *Lexer) scanRune(start Pos) Token {
	l.advance() // consume opening '
	begin := l.pos
	for l.pos < len(l.src) && l.src[l.pos] != '\'' && l.src[l.pos] != '\n' {
		if l.src[l.pos] == '\\' {
			l.advance()
		}
		l.advance()
	}
	if l.pos >= len(l.src) || l.src[l.pos] != '\'' {
		return Token{Kind: Illegal, Text: "unterminated rune", Pos: start}
	}
	text := string(l.src[begin:l.pos])
	l.advance()
	return Token{Kind: Rune, Text: text, Pos: start}
}

func (l *Lexer) scanOp(start Pos) Token {
	c := l.src[l.pos]
	peek := byte(0)
	if l.pos+1 < len(l.src) {
		peek = l.src[l.pos+1]
	}
	peek2 := byte(0)
	if l.pos+2 < len(l.src) {
		peek2 = l.src[l.pos+2]
	}

	// 3-character: ..., <<=, >>=
	if c == '.' && peek == '.' && peek2 == '.' {
		l.advance()
		l.advance()
		l.advance()
		return Token{Kind: Ellipsis, Text: "...", Pos: start}
	}
	if c == '<' && peek == '<' && peek2 == '=' {
		l.advance()
		l.advance()
		l.advance()
		return Token{Kind: ShlAssign, Text: "<<=", Pos: start}
	}
	if c == '>' && peek == '>' && peek2 == '=' {
		l.advance()
		l.advance()
		l.advance()
		return Token{Kind: ShrAssign, Text: ">>=", Pos: start}
	}

	// 2-character
	type two struct {
		a, b byte
		k    Kind
		t    string
	}
	twos := []two{
		{':', '=', ColonAssign, ":="},
		{'=', '=', Eq, "=="},
		{'!', '=', Neq, "!="},
		{'<', '=', Leq, "<="},
		{'>', '=', Geq, ">="},
		{'&', '&', LAnd, "&&"},
		{'|', '|', LOr, "||"},
		{'<', '<', Shl, "<<"},
		{'>', '>', Shr, ">>"},
		{'<', '-', Arrow, "<-"},
		{'+', '+', Inc, "++"},
		{'-', '-', Dec, "--"},
		{'+', '=', PlusAssign, "+="},
		{'-', '=', MinusAssign, "-="},
		{'*', '=', StarAssign, "*="},
		{'/', '=', SlashAssign, "/="},
		{'%', '=', PercentAssign, "%="},
		{'&', '=', AmpAssign, "&="},
		{'|', '=', PipeAssign, "|="},
		{'^', '=', CaretAssign, "^="},
	}
	for _, t := range twos {
		if c == t.a && peek == t.b {
			l.advance()
			l.advance()
			return Token{Kind: t.k, Text: t.t, Pos: start}
		}
	}

	// 1-character
	var k Kind
	switch c {
	case '{':
		k = LBrace
	case '}':
		k = RBrace
	case '(':
		k = LParen
	case ')':
		k = RParen
	case '[':
		k = LBrack
	case ']':
		k = RBrack
	case ',':
		k = Comma
	case '.':
		k = Dot
	case ':':
		k = Colon
	case ';':
		k = Semi
	case '=':
		k = Assign
	case '+':
		k = Plus
	case '-':
		k = Minus
	case '*':
		k = Star
	case '/':
		k = Slash
	case '%':
		k = Percent
	case '<':
		k = Lt
	case '>':
		k = Gt
	case '!':
		k = LNot
	case '&':
		k = Amp
	case '|':
		k = Pipe
	case '^':
		k = Caret
	default:
		l.advance()
		return Token{Kind: Illegal, Text: fmt.Sprintf("unexpected character %q", c), Pos: start}
	}
	l.advance()
	return Token{Kind: k, Text: string(c), Pos: start}
}

// ---------- helpers ----------

// skipWhitespaceAndComments advances past spaces, tabs, newlines, and comments.
// Returns true if a newline was crossed (used for semi-insertion).
func (l *Lexer) skipWhitespaceAndComments() bool {
	saw := false
	for l.pos < len(l.src) {
		c := l.src[l.pos]
		switch c {
		case ' ', '\t', '\r':
			l.advance()
		case '\n':
			saw = true
			l.advance()
		case '/':
			if l.pos+1 < len(l.src) && l.src[l.pos+1] == '/' {
				// line comment to end of line
				start := l.posHere()
				startByte := l.pos
				for l.pos < len(l.src) && l.src[l.pos] != '\n' {
					l.advance()
				}
				l.comments = append(l.comments, Comment{
					Pos:  start,
					Text: string(l.src[startByte:l.pos]),
				})
			} else if l.pos+1 < len(l.src) && l.src[l.pos+1] == '*' {
				start := l.posHere()
				startByte := l.pos
				l.advance()
				l.advance()
				for l.pos+1 < len(l.src) && !(l.src[l.pos] == '*' && l.src[l.pos+1] == '/') {
					if l.src[l.pos] == '\n' {
						saw = true
					}
					l.advance()
				}
				if l.pos+1 < len(l.src) {
					l.advance()
					l.advance()
				}
				l.comments = append(l.comments, Comment{
					Pos:  start,
					Text: string(l.src[startByte:l.pos]),
				})
			} else {
				return saw
			}
		default:
			return saw
		}
	}
	return saw
}

// advance moves past one byte, updating line/column.
func (l *Lexer) advance() {
	if l.pos >= len(l.src) {
		return
	}
	c := l.src[l.pos]
	if c == '\n' {
		l.line++
		l.col = 1
	} else {
		// Treat UTF-8 multi-byte runes as one column.
		if c < 0x80 || c >= 0xC0 {
			l.col++
		}
		_ = utf8.RuneLen // keep import alive while we wire up multi-byte handling
	}
	l.pos++
}

func (l *Lexer) posHere() Pos {
	return Pos{File: l.file, Line: l.line, Column: l.col}
}

func isLetter(c byte) bool {
	return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'
}

func isDigit(c byte) bool {
	return c >= '0' && c <= '9'
}

func isHexDigit(c byte) bool {
	return isDigit(c) || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
}

// hexNibble returns the 4-bit value of a hex digit, or -1 if not hex.
func hexNibble(c byte) int {
	if c >= '0' && c <= '9' {
		return int(c - '0')
	}
	if c >= 'a' && c <= 'f' {
		return int(c-'a') + 10
	}
	if c >= 'A' && c <= 'F' {
		return int(c-'A') + 10
	}
	return -1
}

// needsSemiAfter reports whether an automatic semicolon should be inserted
// after a token of the given kind when a newline follows.
func needsSemiAfter(prev Kind) bool {
	switch prev {
	case Ident, Int, Float, String, Rune,
		KwTrue, KwFalse, KwNil,
		KwBreak, KwContinue, KwRet,
		Inc, Dec,
		RParen, RBrack, RBrace:
		return true
	}
	return false
}
