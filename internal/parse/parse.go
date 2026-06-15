// Package parse implements the volt parser.
//
// Hand-written recursive descent. Consumes tokens from a lex.Lexer,
// produces an ast.File. No parser generator.
//
// v0.2 scope: package, imports, `fun` decls with params + optional
// single return type + body. Statements: var, ret, expression-statement.
// Expressions: identifier, selector, call, string literal, integer
// literal, binary (+, -, *, /, %, comparisons, &&, ||), parens.
package parse

import (
	"fmt"
	"strconv"
	"strings"

	"github.com/codemodify/volt/internal/ast"
	"github.com/codemodify/volt/internal/lex"
)

// Parser produces an AST from a token stream.
type Parser struct {
	lexer *lex.Lexer
	tok   lex.Token   // current
	peek  []lex.Token // arbitrary-length lookahead buffer (lazily populated)
	errs  []string
}

// New returns a Parser for the given lexer.
func New(l *lex.Lexer) *Parser {
	p := &Parser{lexer: l}
	p.advance()
	return p
}

// ParseFile parses a complete source file.
func (p *Parser) ParseFile() (*ast.File, error) {
	f := &ast.File{P: p.tok.Pos}
	p.skipSemis()

	// PackageClause
	if !p.expect(lex.KwPackage) {
		return nil, p.error()
	}
	if p.tok.Kind != lex.Ident {
		p.errorf("expected package name, got %s", p.tok.Kind)
		return nil, p.error()
	}
	f.Package = p.tok.Text
	p.advance()
	p.expect(lex.Semi)
	p.skipSemis()

	// ImportDecls
	for p.tok.Kind == lex.KwImport {
		f.Imports = append(f.Imports, p.parseImports()...)
		p.skipSemis()
	}

	// TopLevelDecls
	for p.tok.Kind != lex.EOF {
		// `const` may be a single decl or a `const ( ... )` group; the
		// latter flattens to several decls, so handle it here rather than
		// through parseTopLevelDecl (which returns a single Decl).
		if p.tok.Kind == lex.KwConst {
			f.Decls = append(f.Decls, p.parseConstDecls()...)
			p.skipSemis()
			continue
		}
		d := p.parseTopLevelDecl()
		if d != nil {
			f.Decls = append(f.Decls, d)
		}
		p.skipSemis()
	}

	f.Comments = p.lexer.Comments()
	return f, p.error()
}

// ---------- imports ----------

func (p *Parser) parseImports() []*ast.Import {
	startTok := p.tok
	p.advance() // consume `import`
	var out []*ast.Import

	switch p.tok.Kind {
	case lex.LParen:
		p.advance()
		p.skipSemis()
		for p.tok.Kind != lex.RParen && p.tok.Kind != lex.EOF {
			if p.tok.Kind != lex.String {
				p.errorf("expected string literal in import group, got %s", p.tok.Kind)
				p.advance()
				continue
			}
			out = append(out, &ast.Import{P: p.tok.Pos, Path: p.tok.Text})
			p.advance()
			p.skipSemis()
		}
		p.expect(lex.RParen)
	case lex.String:
		out = append(out, &ast.Import{P: p.tok.Pos, Path: p.tok.Text})
		p.advance()
	default:
		p.errorf("expected string or '(' after import, got %s at %s", p.tok.Kind, startTok.Pos)
	}
	p.expect(lex.Semi)
	return out
}

// ---------- top-level decls ----------

func (p *Parser) parseTopLevelDecl() ast.Decl {
	switch p.tok.Kind {
	case lex.KwFun:
		return p.parseFuncDecl()
	case lex.KwType:
		return p.parseTypeDecl()
	case lex.KwConst:
		return p.parseConstDecl()
	}
	p.errorf("unexpected token %s at top level", p.tok.Kind)
	p.advance()
	return nil
}

func (p *Parser) parseConstDecl() *ast.ConstDecl {
	p.advance() // consume `const`
	return p.parseConstSpec()
}

// parseConstSpec parses a single `Name [Type] = Value` const specification
// (the body of a const decl, with the `const` keyword already consumed).
// Used for both the single form and each line of a `const ( ... )` group.
func (p *Parser) parseConstSpec() *ast.ConstDecl {
	start := p.tok.Pos
	if p.tok.Kind != lex.Ident {
		p.errorf("expected const name, got %s", p.tok.Kind)
		return nil
	}
	name := p.tok.Text
	p.advance()
	// Optional type annotation: preserved on the AST so `volt fmt` can
	// round-trip it; codegen substitutes the value and ignores the type.
	var typ ast.Type
	if p.tok.Kind != lex.Assign {
		typ = p.parseType()
	}
	if !p.expect(lex.Assign) {
		return nil
	}
	val := p.parseExpr()
	return &ast.ConstDecl{P: start, Name: name, Type: typ, Value: val}
}

// parseConstDecls handles a top-level const declaration in either form:
//
//	const Name [Type] = Value          // single
//	const ( Name [Type] = Value; ... )  // grouped (flattened to N decls)
//
// A group is flattened into individual *ast.ConstDecl nodes so the rest of
// the pipeline (checker, codegen) is unaffected; the printer re-groups
// adjacent consts on output.
func (p *Parser) parseConstDecls() []ast.Decl {
	p.advance() // consume `const`
	if p.tok.Kind == lex.LParen {
		p.advance()
		p.skipSemis()
		var out []ast.Decl
		for p.tok.Kind != lex.RParen && p.tok.Kind != lex.EOF {
			cd := p.parseConstSpec()
			if cd != nil {
				out = append(out, cd)
			} else if p.tok.Kind != lex.RParen && p.tok.Kind != lex.Semi {
				// A malformed spec may leave the cursor parked; advance to
				// guarantee forward progress and avoid spinning on errors.
				p.advance()
			}
			p.skipSemis()
		}
		p.expect(lex.RParen)
		return out
	}
	if cd := p.parseConstSpec(); cd != nil {
		return []ast.Decl{cd}
	}
	return nil
}

func (p *Parser) parseTypeDecl() *ast.TypeDecl {
	start := p.tok.Pos
	p.advance() // consume `type`
	if p.tok.Kind != lex.Ident {
		p.errorf("expected type name, got %s", p.tok.Kind)
		return nil
	}
	name := p.tok.Text
	p.advance()
	t := p.parseType()
	if t == nil {
		return nil
	}
	return &ast.TypeDecl{P: start, Name: name, Type: t}
}

func (p *Parser) parseFuncDecl() *ast.FuncDecl {
	start := p.tok.Pos
	p.advance() // consume `fun`

	// Optional receiver: `fun (r Type) Name(...)`. If next is `(`, parse receiver.
	var receiver *ast.Param
	if p.tok.Kind == lex.LParen {
		p.advance() // consume `(`
		if p.tok.Kind != lex.Ident {
			p.errorf("expected receiver name, got %s", p.tok.Kind)
			return nil
		}
		rName := p.tok.Text
		rPos := p.tok.Pos
		p.advance()
		rType := p.parseType()
		if rType == nil {
			return nil
		}
		if !p.expect(lex.RParen) {
			return nil
		}
		receiver = &ast.Param{P: rPos, Name: rName, Type: rType}
	}

	if p.tok.Kind != lex.Ident {
		p.errorf("expected function name, got %s", p.tok.Kind)
		return nil
	}
	name := p.tok.Text
	p.advance()

	params, results, ok := p.parseFuncSignature()
	if !ok {
		return nil
	}
	body := p.parseBlock()
	return &ast.FuncDecl{P: start, Receiver: receiver, Name: name, Params: params, Results: results, Body: body}
}

// ---------- types ----------

func (p *Parser) parseType() ast.Type {
	switch p.tok.Kind {
	case lex.Amp:
		pos := p.tok.Pos
		p.advance()
		inner := p.parseType()
		return &ast.BorrowType{P: pos, Elem: inner}
	case lex.Star:
		pos := p.tok.Pos
		p.advance()
		inner := p.parseType()
		return &ast.PointerType{P: pos, Elem: inner}
	case lex.LBrack:
		// `[]T` slice type
		pos := p.tok.Pos
		p.advance()
		if !p.expect(lex.RBrack) {
			return nil
		}
		inner := p.parseType()
		if inner == nil {
			return nil
		}
		return &ast.SliceType{P: pos, Elem: inner}
	case lex.KwChan, lex.KwChan11, lex.KwChan1N, lex.KwChanN1, lex.KwChanNN:
		pos := p.tok.Pos
		multi := ast.ChanMultiNone
		switch p.tok.Kind {
		case lex.KwChan11:
			multi = ast.ChanMulti11
		case lex.KwChan1N:
			multi = ast.ChanMulti1N
		case lex.KwChanN1:
			multi = ast.ChanMultiN1
		case lex.KwChanNN:
			multi = ast.ChanMultiNN
		}
		p.advance()
		// Optional direction modifier: `chan read T` / `chan write T`.
		// `read` and `write` aren't reserved keywords (they're builtin
		// function names matched at codegen), so we peek the identifier
		// text. Plain `chan T` is bidirectional. Multiplicity-contracted
		// forms accept the same direction modifier (the contract is on
		// the channel value; direction narrows a handle of it).
		dir := ast.ChanBoth
		if p.tok.Kind == lex.Ident && (p.tok.Text == "read" || p.tok.Text == "write") {
			if p.tok.Text == "read" {
				dir = ast.ChanRead
			} else {
				dir = ast.ChanWrite
			}
			p.advance()
		}
		elem := p.parseType()
		if elem == nil {
			return nil
		}
		return &ast.ChanType{P: pos, Elem: elem, Dir: dir, Multi: multi}
	case lex.KwAtomic:
		pos := p.tok.Pos
		p.advance()
		elem := p.parseType()
		if elem == nil {
			return nil
		}
		return &ast.AtomicType{P: pos, Elem: elem}
	case lex.KwMutex:
		pos := p.tok.Pos
		p.advance()
		elem := p.parseType()
		if elem == nil {
			return nil
		}
		return &ast.MutexType{P: pos, Elem: elem}
	case lex.KwRwMutex:
		pos := p.tok.Pos
		p.advance()
		elem := p.parseType()
		if elem == nil {
			return nil
		}
		return &ast.RwMutexType{P: pos, Elem: elem}
	case lex.KwWaitgroup:
		pos := p.tok.Pos
		p.advance()
		return &ast.WaitgroupType{P: pos}
	case lex.KwOnce:
		pos := p.tok.Pos
		p.advance()
		return &ast.OnceType{P: pos}
	case lex.KwCondvar:
		pos := p.tok.Pos
		p.advance()
		return &ast.CondvarType{P: pos}
	case lex.KwMap:
		pos := p.tok.Pos
		p.advance()
		if !p.expect(lex.LBrack) {
			return nil
		}
		k := p.parseType()
		if k == nil {
			return nil
		}
		if !p.expect(lex.RBrack) {
			return nil
		}
		v := p.parseType()
		if v == nil {
			return nil
		}
		return &ast.MapType{P: pos, Key: k, Value: v}
	case lex.KwStruct:
		return p.parseStructType()
	case lex.KwInterface:
		return p.parseInterfaceType()
	case lex.Ident:
		pos := p.tok.Pos
		name := p.tok.Text
		p.advance()
		// Accept the qualified form `pkg.Type`. The qualifier is
		// preserved on NamedType.Package so codegen can disambiguate
		// types with the same bare name across packages.
		var pkg string
		if p.tok.Kind == lex.Dot && p.peekKind() == lex.Ident {
			pkg = name
			p.advance() // consume '.'
			name = p.tok.Text
			p.advance() // consume the type ident
		}
		return &ast.NamedType{P: pos, Package: pkg, Name: name}
	case lex.KwFun:
		return p.parseFuncType()
	}
	p.errorf("expected type, got %s", p.tok.Kind)
	return nil
}

// parseFuncType parses `fun(T, ...) R` (unnamed-param form, allowed
// only in type position) or `fun(name T, ...) R` (named-param form) as
// a TYPE expression. One-token lookahead disambiguates: if the first
// param token is an Ident followed by `,` or `)`, it's a bare type;
// otherwise it's `name type`. Distinguished from FuncLit by the
// absence of a trailing `{` body.
func (p *Parser) parseFuncType() ast.Type {
	start := p.tok.Pos
	p.advance() // consume `fun`
	if !p.expect(lex.LParen) {
		return nil
	}
	var params []*ast.Param
	for p.tok.Kind != lex.RParen && p.tok.Kind != lex.EOF {
		pPos := p.tok.Pos
		var pName string
		// "name type" if Ident followed by something that can start a
		// type AND isn't `,` or `)`. Otherwise treat as bare type.
		if p.tok.Kind == lex.Ident {
			pk := p.peekKind()
			if pk != lex.Comma && pk != lex.RParen && canStartType(pk) {
				pName = p.tok.Text
				p.advance()
			}
		}
		t := p.parseType()
		if t == nil {
			return nil
		}
		params = append(params, &ast.Param{P: pPos, Name: pName, Type: t})
		if p.tok.Kind == lex.Comma {
			p.advance()
			continue
		}
		break
	}
	if !p.expect(lex.RParen) {
		return nil
	}
	var results []ast.Type
	switch {
	case p.tok.Kind == lex.LBrace, p.tok.Kind == lex.Semi:
		// no return type
	case p.tok.Kind == lex.LParen:
		p.advance()
		for p.tok.Kind != lex.RParen && p.tok.Kind != lex.EOF {
			t := p.parseType()
			if t != nil {
				results = append(results, t)
			}
			if p.tok.Kind == lex.Comma {
				p.advance()
			}
		}
		p.expect(lex.RParen)
	default:
		if canStartType(p.tok.Kind) {
			t := p.parseType()
			if t != nil {
				results = append(results, t)
			}
		}
	}
	return &ast.FuncType{P: start, Params: params, Results: results}
}

// parseFuncSignature parses `(name T, ...) R | (R1, R2)` — the param
// list followed by an optional return-type list. Used by FuncDecl,
// FuncType, and FuncLit. All three follow the same grammar; the
// caller adds the body / name / etc. around it.
func (p *Parser) parseFuncSignature() (params []*ast.Param, results []ast.Type, ok bool) {
	if !p.expect(lex.LParen) {
		return nil, nil, false
	}
	for p.tok.Kind != lex.RParen && p.tok.Kind != lex.EOF {
		if p.tok.Kind != lex.Ident {
			p.errorf("expected parameter name, got %s", p.tok.Kind)
			return nil, nil, false
		}
		pName := p.tok.Text
		pPos := p.tok.Pos
		p.advance()
		t := p.parseType()
		if t == nil {
			return nil, nil, false
		}
		params = append(params, &ast.Param{P: pPos, Name: pName, Type: t})
		if p.tok.Kind == lex.Comma {
			p.advance()
			continue
		}
		break
	}
	if !p.expect(lex.RParen) {
		return nil, nil, false
	}
	switch {
	case p.tok.Kind == lex.LBrace, p.tok.Kind == lex.Semi:
		// no return type
	case p.tok.Kind == lex.LParen:
		p.advance()
		for p.tok.Kind != lex.RParen && p.tok.Kind != lex.EOF {
			t := p.parseType()
			if t != nil {
				results = append(results, t)
			}
			if p.tok.Kind == lex.Comma {
				p.advance()
			}
		}
		p.expect(lex.RParen)
	default:
		if canStartType(p.tok.Kind) {
			t := p.parseType()
			if t != nil {
				results = append(results, t)
			}
		}
	}
	return params, results, true
}

// parseNewExpr parses the full `new` expression grammar:
//
//	new T              new(s) T         new T{i}         new(s) T{i}    // long form
//	                   new(s)           new{i}           new(s){i}      // short form
//
// Size always comes immediately after `new` (between the `new` keyword
// and the type). In the short form, the type is omitted and the LHS
// of the same `=` must supply it (see emitVar in codegen).
func (p *Parser) parseNewExpr() ast.Expr {
	start := p.tok.Pos
	p.advance() // consume `new`

	expr := &ast.NewExpr{P: start}

	// Optional `(sizeArgs)` — always comes immediately after `new`.
	if p.tok.Kind == lex.LParen {
		expr.HasParens = true
		p.advance()
		for p.tok.Kind != lex.RParen && p.tok.Kind != lex.EOF {
			expr.SizeArgs = append(expr.SizeArgs, p.parseExpr())
			if p.tok.Kind == lex.Comma {
				p.advance()
			}
		}
		p.expect(lex.RParen)
	}

	// Optional type — present when the next token can start a type.
	// `{` cannot start a type; that's the start of the init block.
	if canStartType(p.tok.Kind) {
		t := p.parseType()
		if t == nil {
			return nil
		}
		expr.Type = t
	}

	// Optional `{init}` part.
	if p.tok.Kind == lex.LBrace {
		expr.HasBraces = true
		p.advance()
		p.skipSemis()
		p.parseNewBraceItems(expr)
		p.expect(lex.RBrace)
	}

	return expr
}

// canStartType reports whether tok could begin a volt type — Ident,
// `&T`, `*T`, `[]T`, `chan T` (or contract-typed `chan11 T`,
// `chan1N T`, `chanN1 T`, `chanNN T`), `map[K]V`, `interface{...}`,
// `atomic T`, `mutex T`, `rwmutex T`, `waitgroup`, `once`.
func canStartType(k lex.Kind) bool {
	switch k {
	case lex.Ident, lex.Amp, lex.Star, lex.LBrack,
		lex.KwChan, lex.KwChan11, lex.KwChan1N,
		lex.KwChanN1, lex.KwChanNN,
		lex.KwMap, lex.KwInterface,
		lex.KwAtomic, lex.KwMutex, lex.KwRwMutex,
		lex.KwWaitgroup, lex.KwOnce, lex.KwCondvar,
		lex.KwFun:
		return true
	}
	return false
}

// parseNewBraceItems classifies each `{...}` item by its leading token:
//
//	IDENT ':' expr   → struct field (Pairs)
//	<expr> ':' expr  → map entry    (MapEntries)
//	<expr>           → slice elem   (SliceElems)
//
// Mixing kinds within one literal is an error, but we capture them
// separately rather than failing here — the checker can produce a
// better message with the LHS type in hand.
func (p *Parser) parseNewBraceItems(expr *ast.NewExpr) {
	for p.tok.Kind != lex.RBrace && p.tok.Kind != lex.EOF {
		itemPos := p.tok.Pos

		// Struct field shortcut: IDENT directly followed by `:`.
		if p.tok.Kind == lex.Ident {
			name := p.tok.Text
			save := p.tok
			p.advance()
			if p.tok.Kind == lex.Colon {
				p.advance()
				val := p.parseExpr()
				expr.Pairs = append(expr.Pairs, &ast.KeyValuePair{P: itemPos, Key: name, Value: val})
				if p.tok.Kind == lex.Comma {
					p.advance()
				}
				p.skipSemis()
				continue
			}
			// IDENT but no `:` — re-interpret as the start of an expression.
			// Re-wind: emit an IdentExpr from the saved token and continue
			// parsing the rest of the expression around it.
			ident := &ast.IdentExpr{P: save.Pos, Name: name}
			e := p.continueExprFrom(ident)
			if p.tok.Kind == lex.Colon {
				p.advance()
				val := p.parseExpr()
				expr.MapEntries = append(expr.MapEntries, &ast.MapEntry{P: itemPos, Key: e, Value: val})
			} else {
				expr.SliceElems = append(expr.SliceElems, e)
			}
			if p.tok.Kind == lex.Comma {
				p.advance()
			}
			p.skipSemis()
			continue
		}

		// Anything else: parse a full expression, then check for `:`.
		e := p.parseExpr()
		if p.tok.Kind == lex.Colon {
			p.advance()
			val := p.parseExpr()
			expr.MapEntries = append(expr.MapEntries, &ast.MapEntry{P: itemPos, Key: e, Value: val})
		} else {
			expr.SliceElems = append(expr.SliceElems, e)
		}
		if p.tok.Kind == lex.Comma {
			p.advance()
		}
		p.skipSemis()
	}
}

// continueExprFrom takes a partially-parsed primary expression and
// continues parsing any suffixes (call, index, selector) plus any
// trailing binary operators at default precedence.
//
// In v0.5 we only need a minimal version: return the primary as-is.
// Future: support `a.b`, `a[i]`, `a + b` here so map keys can be
// arbitrary expressions starting with an Ident.
func (p *Parser) continueExprFrom(prim ast.Expr) ast.Expr {
	return prim
}

// parseSliceLit parses `[]T{e1, e2, ...}` as an expression.
// Called when parsePrimary sees a leading `[`.
func (p *Parser) parseSliceLit() ast.Expr {
	pos := p.tok.Pos
	p.advance() // consume `[`
	if !p.expect(lex.RBrack) {
		return nil
	}
	elemT := p.parseType()
	if elemT == nil {
		return nil
	}
	if !p.expect(lex.LBrace) {
		return nil
	}
	lit := &ast.SliceLit{P: pos, Elem: elemT}
	p.skipSemis()
	for p.tok.Kind != lex.RBrace && p.tok.Kind != lex.EOF {
		lit.Elems = append(lit.Elems, p.parseExpr())
		if p.tok.Kind == lex.Comma {
			p.advance()
		}
		p.skipSemis()
	}
	p.expect(lex.RBrace)
	return lit
}

// parseInterfaceType parses `interface { Name(params) result; ... }`.
// Each method's signature is captured as a `*ast.FuncType` stored in
// the Field's Type, so codegen can dispatch with the right LLVM
// signature at call sites.
func (p *Parser) parseInterfaceType() *ast.InterfaceType {
	start := p.tok.Pos
	p.advance() // consume `interface`
	if !p.expect(lex.LBrace) {
		return nil
	}
	it := &ast.InterfaceType{P: start}
	p.skipSemis()
	for p.tok.Kind != lex.RBrace && p.tok.Kind != lex.EOF {
		if p.tok.Kind != lex.Ident {
			p.errorf("expected method name, got %s", p.tok.Kind)
			break
		}
		mPos := p.tok.Pos
		mName := p.tok.Text
		p.advance()
		params, results, ok := p.parseFuncSignature()
		if !ok {
			return nil
		}
		ft := &ast.FuncType{P: mPos, Params: params, Results: results}
		it.Methods = append(it.Methods, &ast.Field{P: mPos, Name: mName, Type: ft})
		p.expect(lex.Semi)
		p.skipSemis()
	}
	p.expect(lex.RBrace)
	return it
}

func (p *Parser) parseStructType() *ast.StructType {
	start := p.tok.Pos
	p.advance() // consume `struct`
	if !p.expect(lex.LBrace) {
		return nil
	}
	st := &ast.StructType{P: start}
	p.skipSemis()
	for p.tok.Kind != lex.RBrace && p.tok.Kind != lex.EOF {
		if p.tok.Kind != lex.Ident {
			p.errorf("expected field name, got %s", p.tok.Kind)
			break
		}
		fPos := p.tok.Pos
		fName := p.tok.Text
		p.advance()
		fType := p.parseType()
		if fType == nil {
			break
		}
		st.Fields = append(st.Fields, &ast.Field{P: fPos, Name: fName, Type: fType})
		p.expect(lex.Semi)
		p.skipSemis()
	}
	p.expect(lex.RBrace)
	return st
}

// ---------- block / statements ----------

func (p *Parser) parseBlock() *ast.Block {
	startPos := p.tok.Pos
	if !p.expect(lex.LBrace) {
		return nil
	}
	b := &ast.Block{P: startPos}
	p.skipSemis()
	for p.tok.Kind != lex.RBrace && p.tok.Kind != lex.EOF {
		if p.tok.Kind == lex.KwVar {
			for _, v := range p.parseVarDecls() {
				b.Stmts = append(b.Stmts, v)
			}
		} else if s := p.parseStmt(); s != nil {
			b.Stmts = append(b.Stmts, s)
		}
		// A trailing `}` on the same line as the last statement means
		// no auto-semicolon was inserted; tolerate the missing one so
		// single-line forms like `if cond { ret 1 }` parse.
		if p.tok.Kind != lex.RBrace {
			p.expect(lex.Semi)
		}
		p.skipSemis()
	}
	b.End = p.tok.Pos // the `}` (or EOF on a malformed block)
	p.expect(lex.RBrace)
	return b
}

func (p *Parser) parseStmt() ast.Stmt {
	switch p.tok.Kind {
	case lex.KwVar:
		return p.parseVarStmt()
	case lex.KwRet:
		return p.parseRetStmt()
	case lex.KwIf:
		return p.parseIfStmt()
	case lex.KwFor:
		return p.parseForStmt()
	case lex.KwDef:
		return p.parseDeferStmt()
	case lex.KwRun:
		return p.parseRunStmt()
	case lex.KwSwitch:
		return p.parseSwitchStmt()
	case lex.KwSelect:
		return p.parseSelectStmt()
	case lex.KwBreak:
		s := &ast.BreakStmt{P: p.tok.Pos}
		p.advance()
		return s
	case lex.KwContinue:
		s := &ast.ContinueStmt{P: p.tok.Pos}
		p.advance()
		return s
	case lex.LBrace:
		// Bare nested block — creates a new scope. Useful for limiting
		// the lifetime of a guard binding (mutex.Lock()) without the
		// `if 1 < 2 { ... }` workaround the language required before.
		// Body Stmts inherit the same parsing path; emitStmt handles
		// *ast.Block by pushing/popping scope around the inner stmts.
		return p.parseBlock()
	}
	return p.parseSimpleStmt()
}

func (p *Parser) parseSwitchStmt() *ast.SwitchStmt {
	start := p.tok.Pos
	p.advance() // consume `switch`

	var tag ast.Expr
	if p.tok.Kind != lex.LBrace {
		tag = p.parseExpr()
	}
	if !p.expect(lex.LBrace) {
		return nil
	}
	s := &ast.SwitchStmt{P: start, Tag: tag}
	p.skipSemis()
	for p.tok.Kind != lex.RBrace && p.tok.Kind != lex.EOF {
		cc := p.parseCaseClause()
		if cc != nil {
			s.Cases = append(s.Cases, cc)
		}
		p.skipSemis()
	}
	p.expect(lex.RBrace)
	return s
}

func (p *Parser) parseCaseClause() *ast.CaseClause {
	start := p.tok.Pos
	var vals []ast.Expr
	switch p.tok.Kind {
	case lex.KwCase:
		p.advance()
		vals = append(vals, p.parseExpr())
		for p.tok.Kind == lex.Comma {
			p.advance()
			vals = append(vals, p.parseExpr())
		}
	case lex.KwDefault:
		p.advance()
	default:
		p.errorf("expected 'case' or 'default', got %s", p.tok.Kind)
		return nil
	}
	if !p.expect(lex.Colon) {
		return nil
	}
	p.skipSemis()
	cc := &ast.CaseClause{P: start, Vals: vals}
	for p.tok.Kind != lex.KwCase && p.tok.Kind != lex.KwDefault &&
		p.tok.Kind != lex.RBrace && p.tok.Kind != lex.EOF {
		if p.tok.Kind == lex.KwVar {
			for _, v := range p.parseVarDecls() {
				cc.Stmts = append(cc.Stmts, v)
			}
		} else if s := p.parseStmt(); s != nil {
			cc.Stmts = append(cc.Stmts, s)
		}
		p.expect(lex.Semi)
		p.skipSemis()
	}
	return cc
}

// parseSelectStmt parses `select { case ...: ... }`. Each case is one of:
//
//	case read(ch):                   recv-discard
//	case v := read(ch):              recv into v
//	case v, ok := read(ch):          recv with ok
//	case write(ch, value):           send
//	default:
func (p *Parser) parseSelectStmt() *ast.SelectStmt {
	start := p.tok.Pos
	p.advance() // consume `select`
	if !p.expect(lex.LBrace) {
		return nil
	}
	s := &ast.SelectStmt{P: start}
	p.skipSemis()
	for p.tok.Kind != lex.RBrace && p.tok.Kind != lex.EOF {
		c := p.parseSelectCase()
		if c != nil {
			s.Cases = append(s.Cases, c)
		}
		p.skipSemis()
	}
	p.expect(lex.RBrace)
	return s
}

func (p *Parser) parseSelectCase() *ast.SelectCase {
	cs := &ast.SelectCase{P: p.tok.Pos}
	switch p.tok.Kind {
	case lex.KwDefault:
		p.advance()
		cs.IsDefault = true
	case lex.KwCase:
		p.advance()
		// Parse the first expression. Then dispatch on what follows.
		{
			first := p.parseExpr()
			if first == nil {
				return nil
			}
			switch p.tok.Kind {
			case lex.Comma:
				// `case v, ok := read(ch):` or legacy `v, ok := <-ch`
				p.advance()
				second := p.parseExpr()
				id1, ok1 := first.(*ast.IdentExpr)
				id2, ok2 := second.(*ast.IdentExpr)
				if !ok1 || !ok2 {
					p.errorf("%s: select case recv LHS must be identifiers", first.Pos())
					return nil
				}
				if !p.expect(lex.ColonAssign) {
					return nil
				}
				ch := p.parseSelectRecvSource()
				if ch == nil {
					return nil
				}
				cs.Channel = ch
				cs.RecvNames = []string{id1.Name, id2.Name}
			case lex.ColonAssign:
				// `case v := read(ch):` or legacy `v := <-ch`
				id, ok := first.(*ast.IdentExpr)
				if !ok {
					p.errorf("%s: select case recv LHS must be an identifier", first.Pos())
					return nil
				}
				p.advance()
				ch := p.parseSelectRecvSource()
				if ch == nil {
					return nil
				}
				cs.Channel = ch
				cs.RecvNames = []string{id.Name}
			case lex.Colon:
				// Either `case read(ch):` (recv-discard) or
				// `case write(ch, v):` (send).
				if ch := extractReadChannel(first); ch != nil {
					cs.Channel = ch
				} else if ch, v := extractWriteCall(first); ch != nil {
					cs.Channel = ch
					cs.SendValue = v
				} else {
					p.errorf("%s: select case must be `read(ch)`, `v := read(ch)`, `v, ok := read(ch)`, or `write(ch, v)`", first.Pos())
					return nil
				}
			default:
				p.errorf("%s: unexpected token %s in select case", p.tok.Pos, p.tok.Kind)
				return nil
			}
		}
	default:
		p.errorf("expected 'case' or 'default' in select, got %s", p.tok.Kind)
		return nil
	}
	if !p.expect(lex.Colon) {
		return nil
	}
	p.skipSemis()
	for p.tok.Kind != lex.KwCase && p.tok.Kind != lex.KwDefault &&
		p.tok.Kind != lex.RBrace && p.tok.Kind != lex.EOF {
		if p.tok.Kind == lex.KwVar {
			for _, v := range p.parseVarDecls() {
				cs.Body = append(cs.Body, v)
			}
		} else if s := p.parseStmt(); s != nil {
			cs.Body = append(cs.Body, s)
		}
		if p.tok.Kind != lex.RBrace {
			p.expect(lex.Semi)
		}
		p.skipSemis()
	}
	return cs
}

// parseSelectRecvSource parses the channel-source part of a select recv
// case, after `:=`. The only accepted form is `read(ch)`.
func (p *Parser) parseSelectRecvSource() ast.Expr {
	rhs := p.parseExpr()
	if ch := extractReadChannel(rhs); ch != nil {
		return ch
	}
	if rhs != nil {
		p.errorf("%s: select case recv source must be `read(ch)`", rhs.Pos())
	}
	return nil
}

// extractReadChannel returns the channel expression inside a `read(ch)`
// call, or nil if `e` is not a one-arg call to `read`.
func extractReadChannel(e ast.Expr) ast.Expr {
	call, ok := e.(*ast.CallExpr)
	if !ok {
		return nil
	}
	fn, ok := call.Fun.(*ast.IdentExpr)
	if !ok || fn.Name != "read" || len(call.Args) != 1 {
		return nil
	}
	return call.Args[0]
}

// extractWriteCall returns (channel, value) for a `write(ch, v)` call,
// or (nil, nil) if `e` is not a two-arg call to `write`. Used by the
// select-case parser to recognize the canonical send form.
func extractWriteCall(e ast.Expr) (ast.Expr, ast.Expr) {
	call, ok := e.(*ast.CallExpr)
	if !ok {
		return nil, nil
	}
	fn, ok := call.Fun.(*ast.IdentExpr)
	if !ok || fn.Name != "write" || len(call.Args) != 2 {
		return nil, nil
	}
	return call.Args[0], call.Args[1]
}

func (p *Parser) parseDeferStmt() *ast.DeferStmt {
	start := p.tok.Pos
	p.advance() // consume `def`
	expr := p.parseExpr()
	call, ok := expr.(*ast.CallExpr)
	if !ok {
		p.errorf("%s: `def` argument must be a call", start)
		return nil
	}
	return &ast.DeferStmt{P: start, Call: call}
}

func (p *Parser) parseRunStmt() *ast.RunStmt {
	start := p.tok.Pos
	p.advance() // consume `run`
	expr := p.parseExpr()
	call, ok := expr.(*ast.CallExpr)
	if !ok {
		p.errorf("%s: `run` argument must be a call", start)
		return nil
	}
	return &ast.RunStmt{P: start, Call: call}
}

// parseSimpleStmt: expression, assignment, short var decl, or
// multi-LHS variants (`a, b = foo()` / `a, b := foo()`).
// Channel sends use the `write(ch, v)` built-in, not the `<-` operator.
func (p *Parser) parseSimpleStmt() ast.Stmt {
	first := p.parseExpr()
	if first == nil {
		return nil
	}
	// Single-expression cases first.
	if p.tok.Kind != lex.Comma {
		switch p.tok.Kind {
		case lex.Assign:
			assignPos := p.tok.Pos
			p.advance()
			rhs := p.parseExpr()
			return &ast.AssignStmt{P: assignPos, LHS: first, RHS: rhs}
		case lex.ColonAssign:
			id, ok := first.(*ast.IdentExpr)
			if !ok {
				p.errorf("%s: short var decl LHS must be an identifier", first.Pos())
				return nil
			}
			p.advance()
			rhs := p.parseExpr()
			return &ast.VarStmt{P: id.P, Name: id.Name, Type: nil, Value: rhs}
		case lex.Inc, lex.Dec:
			// `x++` / `x--` desugar to `x = x + 1` / `x = x - 1`.
			// Body of for-loop post-statement uses this all the time;
			// also legal as a standalone statement.
			op := "+"
			if p.tok.Kind == lex.Dec {
				op = "-"
			}
			pos := p.tok.Pos
			p.advance()
			one := &ast.IntLit{P: pos, Value: 1, Text: "1"}
			return &ast.AssignStmt{
				P:   pos,
				LHS: first,
				RHS: &ast.BinaryExpr{P: pos, Op: op, X: first, Y: one},
			}
		}
		return &ast.ExprStmt{P: first.Pos(), Expr: first}
	}

	// Multi-LHS: parse the rest of the LHS list.
	lhs := []ast.Expr{first}
	for p.tok.Kind == lex.Comma {
		p.advance()
		lhs = append(lhs, p.parseExpr())
	}
	pos := first.Pos()
	switch p.tok.Kind {
	case lex.Assign:
		p.advance()
		rhs := p.parseExpr()
		return &ast.MultiAssignStmt{P: pos, LHS: lhs, RHS: rhs}
	case lex.ColonAssign:
		// All LHS must be identifiers.
		names := make([]string, 0, len(lhs))
		for _, e := range lhs {
			id, ok := e.(*ast.IdentExpr)
			if !ok {
				p.errorf("%s: short var decl LHS must be identifiers", e.Pos())
				return nil
			}
			names = append(names, id.Name)
		}
		p.advance()
		rhs := p.parseExpr()
		return &ast.MultiVarStmt{P: pos, Names: names, RHS: rhs}
	}
	p.errorf("%s: expected '=' or ':=' after multi-LHS", pos)
	return nil
}

func (p *Parser) parseForStmt() *ast.ForStmt {
	start := p.tok.Pos
	p.advance() // consume `for`

	// `for { ... }` — infinite loop, no clauses.
	if p.tok.Kind == lex.LBrace {
		return &ast.ForStmt{P: start, Body: p.parseBlock()}
	}

	// Range form: `for i := range EXPR { ... }` or
	//             `for i, v := range EXPR { ... }`.
	// Detect by peeking ahead — if the first token is an Ident
	// followed by either ":=" or "," <Ident> ":= range", we're in the
	// range form. Bail out via a dedicated path.
	if p.tok.Kind == lex.Ident && p.isRangeForm() {
		return p.parseRangeFor(start)
	}

	// Otherwise: parse a leading clause. Either:
	//   `for cond { ... }`           (Cond only)
	// or
	//   `for init; cond; post { ... }`  (Init + Cond + Post)
	var init ast.Stmt
	var cond ast.Expr
	var post ast.Stmt

	first := p.parseSimpleStmt()
	if p.tok.Kind == lex.Semi {
		init = first
		p.advance()
		if p.tok.Kind != lex.Semi && p.tok.Kind != lex.LBrace {
			cond = p.parseExpr()
		}
		if p.tok.Kind == lex.Semi {
			p.advance()
			if p.tok.Kind != lex.LBrace {
				post = p.parseSimpleStmt()
			}
		}
	} else {
		if es, ok := first.(*ast.ExprStmt); ok {
			cond = es.Expr
		} else {
			p.errorf("expected condition expression in for loop, got %T", first)
		}
	}

	body := p.parseBlock()
	return &ast.ForStmt{P: start, Init: init, Cond: cond, Post: post, Body: body}
}

// isRangeForm peeks ahead to decide whether what follows `for` is the
// range form. Positioned on the first Ident. Range form looks like:
//   for IDENT := range EXPR              → IDENT `:=` `range`
//   for IDENT , IDENT := range EXPR      → IDENT `,` IDENT `:=` `range`
// The distinguishing token is `range` — the comma alone is enough on
// its own (no other for-statement starts with `IDENT ,`).
func (p *Parser) isRangeForm() bool {
	pk := p.peekKind()
	if pk == lex.Comma {
		return true
	}
	if pk == lex.ColonAssign {
		// `IDENT :=` could be a C-style init (`i := 0`) or a range
		// (`i := range s`). Disambiguate by looking 2 tokens ahead.
		return p.peekKindN(2) == lex.KwRange
	}
	return false
}

// parseRangeFor consumes `IDENT [, IDENT] := range EXPR { BODY }`.
// Called with `p.tok` on the first identifier.
func (p *Parser) parseRangeFor(start lex.Pos) *ast.ForStmt {
	iName := p.tok.Text
	p.advance()
	var vName string
	if p.tok.Kind == lex.Comma {
		p.advance()
		if p.tok.Kind != lex.Ident {
			p.errorf("expected value name after `,` in range, got %s", p.tok.Kind)
			return nil
		}
		vName = p.tok.Text
		p.advance()
	}
	if !p.expect(lex.ColonAssign) {
		return nil
	}
	if p.tok.Kind != lex.KwRange {
		p.errorf("expected `range`, got %s", p.tok.Kind)
		return nil
	}
	p.advance() // consume `range`
	over := p.parseExpr()
	if over == nil {
		return nil
	}
	body := p.parseBlock()
	return &ast.ForStmt{
		P:         start,
		Body:      body,
		RangeI:    iName,
		RangeV:    vName,
		RangeOver: over,
	}
}

func (p *Parser) parseIfStmt() *ast.IfStmt {
	start := p.tok.Pos
	p.advance() // consume `if`

	// Optional init clause: `if STMT; COND { ... }`. The STMT is a
	// SimpleStmt (var decl, multi-var decl, assignment, expression).
	// We detect this by parsing greedily and checking for a `;` before
	// the block-opening `{`. If we hit `{` first, the parsed thing is
	// just the condition.
	var initStmt ast.Stmt
	first := p.parseSimpleStmt()
	var cond ast.Expr
	if p.tok.Kind == lex.Semi {
		// Confirmed init clause — first was the init statement; parse cond next.
		initStmt = first
		p.advance() // consume `;`
		cond = p.parseExpr()
	} else {
		// No semicolon — `first` must have been an ExprStmt; pull its expr out.
		es, ok := first.(*ast.ExprStmt)
		if !ok {
			p.errorf("expected expression as if-condition, got statement")
			return nil
		}
		cond = es.Expr
	}
	if cond == nil {
		return nil
	}

	then := p.parseBlock()
	if then == nil {
		return nil
	}
	var elseStmt ast.Stmt
	// `else` must follow on the same line as the closing `}` (Go convention).
	if p.tok.Kind == lex.KwElse {
		p.advance()
		switch p.tok.Kind {
		case lex.KwIf:
			elseStmt = p.parseIfStmt()
		case lex.LBrace:
			elseStmt = p.parseBlock()
		default:
			p.errorf("expected 'if' or '{' after else, got %s", p.tok.Kind)
		}
	}
	return &ast.IfStmt{P: start, Init: initStmt, Cond: cond, Then: then, Else: elseStmt}
}

func (p *Parser) parseVarStmt() *ast.VarStmt {
	p.advance() // consume `var`
	return p.parseVarSpec()
}

// parseVarSpec parses a single `Name [Type] [= Value]` var specification
// (the `var` keyword already consumed). Used for both the single form and
// each line of a `var ( ... )` group.
func (p *Parser) parseVarSpec() *ast.VarStmt {
	start := p.tok.Pos
	if p.tok.Kind != lex.Ident {
		p.errorf("expected variable name, got %s", p.tok.Kind)
		return nil
	}
	name := p.tok.Text
	p.advance()
	var typ ast.Type
	if p.tok.Kind != lex.Assign {
		typ = p.parseType()
	}
	var value ast.Expr
	if p.tok.Kind == lex.Assign {
		p.advance()
		value = p.parseExpr()
	}
	return &ast.VarStmt{P: start, Name: name, Type: typ, Value: value}
}

// parseVarDecls handles a var statement in either form:
//
//	var Name [Type] [= Value]            // single
//	var ( Name [Type] [= Value]; ... )    // grouped (flattened to N stmts)
//
// Like const groups, a `var ( ... )` block is flattened into individual
// *ast.VarStmt nodes so the checker/codegen see no new node type; the
// printer re-groups adjacent var statements on output.
func (p *Parser) parseVarDecls() []*ast.VarStmt {
	p.advance() // consume `var`
	if p.tok.Kind == lex.LParen {
		p.advance()
		p.skipSemis()
		var out []*ast.VarStmt
		for p.tok.Kind != lex.RParen && p.tok.Kind != lex.EOF {
			v := p.parseVarSpec()
			if v != nil {
				out = append(out, v)
			} else if p.tok.Kind != lex.RParen && p.tok.Kind != lex.Semi {
				// A malformed spec may leave the cursor parked; advance to
				// guarantee forward progress and avoid spinning on errors.
				p.advance()
			}
			p.skipSemis()
		}
		p.expect(lex.RParen)
		return out
	}
	if v := p.parseVarSpec(); v != nil {
		return []*ast.VarStmt{v}
	}
	return nil
}

func (p *Parser) parseRetStmt() *ast.RetStmt {
	start := p.tok.Pos
	p.advance() // consume `ret`
	if p.tok.Kind == lex.Semi || p.tok.Kind == lex.RBrace || p.tok.Kind == lex.EOF {
		return &ast.RetStmt{P: start}
	}
	var values []ast.Expr
	values = append(values, p.parseExpr())
	for p.tok.Kind == lex.Comma {
		p.advance()
		values = append(values, p.parseExpr())
	}
	return &ast.RetStmt{P: start, Values: values}
}

// ---------- expressions ----------

// Precedence levels:
//   1: ||
//   2: &&
//   3: == != < <= > >=
//   4: + -
//   5: * / %
//   (primary is highest)

func (p *Parser) parseExpr() ast.Expr {
	return p.parseBinExpr(1)
}

func (p *Parser) parseBinExpr(minPrec int) ast.Expr {
	lhs := p.parseUnary()
	if lhs == nil {
		return nil
	}
	for {
		op, prec := binaryOp(p.tok.Kind)
		if prec < minPrec {
			return lhs
		}
		opPos := p.tok.Pos
		p.advance()
		rhs := p.parseBinExpr(prec + 1)
		if rhs == nil {
			return lhs
		}
		lhs = &ast.BinaryExpr{P: opPos, Op: op, X: lhs, Y: rhs}
	}
}

func (p *Parser) parseUnary() ast.Expr {
	switch p.tok.Kind {
	case lex.LNot:
		opPos := p.tok.Pos
		p.advance()
		x := p.parseUnary()
		return &ast.UnaryExpr{P: opPos, Op: "!", X: x}
	case lex.Minus:
		opPos := p.tok.Pos
		p.advance()
		x := p.parseUnary()
		return &ast.UnaryExpr{P: opPos, Op: "-", X: x}
	case lex.Amp:
		// C8: `&x` (address-of / borrow) as a value expression. The
		// operator is always `&`; the binding-site TYPE decides read vs
		// write — `&T` is a shared read borrow, `*T` the exclusive write
		// borrow — and the checker applies the right alias rules from it.
		opPos := p.tok.Pos
		p.advance()
		x := p.parseUnary()
		return &ast.UnaryExpr{P: opPos, Op: "&", X: x}
	case lex.Star:
		// C8: `*p` as a value expression — dereference a held borrow.
		// Symmetric to the LHS form `*p = v` which already works.
		opPos := p.tok.Pos
		p.advance()
		x := p.parseUnary()
		return &ast.UnaryExpr{P: opPos, Op: "*", X: x}
	}
	return p.parsePrimary()
}

func (p *Parser) parsePrimary() ast.Expr {
	var x ast.Expr
	switch p.tok.Kind {
	case lex.Ident:
		x = &ast.IdentExpr{P: p.tok.Pos, Name: p.tok.Text}
		p.advance()
	case lex.String:
		x = &ast.StringLit{P: p.tok.Pos, Text: p.tok.Text}
		p.advance()
	case lex.Int:
		n, err := parseIntLit(p.tok.Text)
		if err != nil {
			p.errorf("invalid integer literal %q: %v", p.tok.Text, err)
		}
		x = &ast.IntLit{P: p.tok.Pos, Value: n, Text: p.tok.Text}
		p.advance()
	case lex.Float:
		// Strip `_` digit separators; LLVM's float literal grammar
		// doesn't accept them.
		text := strings.ReplaceAll(p.tok.Text, "_", "")
		x = &ast.FloatLit{P: p.tok.Pos, Text: text}
		p.advance()
	case lex.KwTrue:
		x = &ast.BoolLit{P: p.tok.Pos, Value: true}
		p.advance()
	case lex.KwFalse:
		x = &ast.BoolLit{P: p.tok.Pos, Value: false}
		p.advance()
	case lex.KwNil:
		x = &ast.NilLit{P: p.tok.Pos}
		p.advance()
	case lex.KwFun:
		// Anonymous function literal: `fun(name T, ...) R { body }`.
		// Distinguished from a top-level `fun NAME(...)` declaration by
		// the absence of an Ident after `fun` — here we're in expression
		// position, so the parens come straight after.
		start := p.tok.Pos
		p.advance() // consume `fun`
		params, results, ok := p.parseFuncSignature()
		if !ok {
			return nil
		}
		body := p.parseBlock()
		x = &ast.FuncLit{P: start, Params: params, Results: results, Body: body}
	case lex.KwNew:
		x = p.parseNewExpr()
	case lex.LBrack:
		// `[]T{...}` slice literal (only when `[` is followed by `]`).
		x = p.parseSliceLit()
		if x == nil {
			return nil
		}
	case lex.LParen:
		p.advance()
		x = p.parseExpr()
		p.expect(lex.RParen)
	default:
		p.errorf("unexpected token %s in expression", p.tok.Kind)
		p.advance()
		return nil
	}

	for {
		switch p.tok.Kind {
		case lex.Dot:
			p.advance()
			if p.tok.Kind != lex.Ident {
				p.errorf("expected identifier after '.', got %s", p.tok.Kind)
				return x
			}
			x = &ast.SelectorExpr{P: x.Pos(), X: x, Sel: p.tok.Text}
			p.advance()
		case lex.LParen:
			x = p.parseCall(x)
		case lex.LBrack:
			idxPos := p.tok.Pos
			p.advance()
			idx := p.parseExpr()
			if !p.expect(lex.RBrack) {
				return x
			}
			x = &ast.IndexExpr{P: idxPos, X: x, Index: idx}
		default:
			return x
		}
	}
}

func (p *Parser) parseCall(fun ast.Expr) ast.Expr {
	if fun == nil {
		// Recovery: the caller failed to produce a callee; bail without
		// dereferencing nil. The caller has already recorded an error.
		p.advance() // consume '('
		for p.tok.Kind != lex.RParen && p.tok.Kind != lex.EOF {
			p.parseExpr()
			if p.tok.Kind == lex.Comma {
				p.advance()
				continue
			}
			break
		}
		p.expect(lex.RParen)
		return nil
	}
	p.advance() // '('
	var args []ast.Expr
	for p.tok.Kind != lex.RParen && p.tok.Kind != lex.EOF {
		args = append(args, p.parseExpr())
		if p.tok.Kind == lex.Comma {
			p.advance()
			continue
		}
		break
	}
	p.expect(lex.RParen)
	return &ast.CallExpr{P: fun.Pos(), Fun: fun, Args: args}
}

func binaryOp(k lex.Kind) (string, int) {
	switch k {
	case lex.LOr:
		return "||", 1
	case lex.LAnd:
		return "&&", 2
	case lex.Eq:
		return "==", 3
	case lex.Neq:
		return "!=", 3
	case lex.Lt:
		return "<", 3
	case lex.Leq:
		return "<=", 3
	case lex.Gt:
		return ">", 3
	case lex.Geq:
		return ">=", 3
	case lex.Plus:
		return "+", 4
	case lex.Minus:
		return "-", 4
	case lex.Pipe:
		return "|", 4
	case lex.Caret:
		return "^", 4
	case lex.Star:
		return "*", 5
	case lex.Slash:
		return "/", 5
	case lex.Percent:
		return "%", 5
	case lex.Amp:
		return "&", 5
	case lex.Shl:
		return "<<", 5
	case lex.Shr:
		return ">>", 5
	}
	return "", 0
}

// ---------- helpers ----------

func (p *Parser) advance() {
	if len(p.peek) > 0 {
		p.tok = p.peek[0]
		p.peek = p.peek[1:]
		return
	}
	p.tok = p.lexer.Next()
}

// peekKind returns the kind of the token AFTER the current one. Equivalent
// to peekKindN(1). Used for short-range disambiguation (e.g. fn-type vs
// fn-decl param shape).
func (p *Parser) peekKind() lex.Kind {
	return p.peekKindN(1)
}

// peekKindN returns the kind of the n-th token AFTER the current one
// (1-indexed). Used by the for-loop parser to distinguish range-form
// (`IDENT := range ...`) from C-style (`IDENT := EXPR ; ...`).
func (p *Parser) peekKindN(n int) lex.Kind {
	for len(p.peek) < n {
		p.peek = append(p.peek, p.lexer.Next())
	}
	return p.peek[n-1].Kind
}

func (p *Parser) expect(k lex.Kind) bool {
	if p.tok.Kind == k {
		p.advance()
		return true
	}
	p.errorf("expected %s, got %s", k, p.tok.Kind)
	return false
}

func (p *Parser) skipSemis() {
	for p.tok.Kind == lex.Semi {
		p.advance()
	}
}

func (p *Parser) errorf(format string, args ...any) {
	msg := fmt.Sprintf(format, args...)
	p.errs = append(p.errs, fmt.Sprintf("%s: %s", p.tok.Pos, msg))
}

func (p *Parser) error() error {
	if len(p.errs) == 0 {
		return nil
	}
	return fmt.Errorf("parse errors:\n  %s", strings.Join(p.errs, "\n  "))
}

func parseIntLit(s string) (int64, error) {
	cleaned := strings.ReplaceAll(s, "_", "")
	return strconv.ParseInt(cleaned, 0, 64)
}
