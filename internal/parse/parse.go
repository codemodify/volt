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
	tok   lex.Token // current
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
		d := p.parseTopLevelDecl()
		if d != nil {
			f.Decls = append(f.Decls, d)
		}
		p.skipSemis()
	}

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
	start := p.tok.Pos
	p.advance() // consume `const`
	if p.tok.Kind != lex.Ident {
		p.errorf("expected const name, got %s", p.tok.Kind)
		return nil
	}
	name := p.tok.Text
	p.advance()
	// Optional type annotation (consume but ignore for now).
	if p.tok.Kind != lex.Assign {
		_ = p.parseType()
	}
	if !p.expect(lex.Assign) {
		return nil
	}
	val := p.parseExpr()
	return &ast.ConstDecl{P: start, Name: name, Value: val}
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

	if !p.expect(lex.LParen) {
		return nil
	}
	var params []*ast.Param
	for p.tok.Kind != lex.RParen && p.tok.Kind != lex.EOF {
		if p.tok.Kind != lex.Ident {
			p.errorf("expected parameter name, got %s", p.tok.Kind)
			break
		}
		pName := p.tok.Text
		pPos := p.tok.Pos
		p.advance()
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

	// Optional return type: single `T` or `(T1, T2, ...)`.
	var results []ast.Type
	switch {
	case p.tok.Kind == lex.LBrace:
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
		t := p.parseType()
		if t != nil {
			results = append(results, t)
		}
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
	case lex.KwChan:
		pos := p.tok.Pos
		p.advance()
		elem := p.parseType()
		if elem == nil {
			return nil
		}
		return &ast.ChanType{P: pos, Elem: elem}
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
	case lex.Ident:
		pos := p.tok.Pos
		name := p.tok.Text
		p.advance()
		return &ast.NamedType{P: pos, Name: name}
	}
	p.errorf("expected type, got %s", p.tok.Kind)
	return nil
}

// parseNewExpr parses `new T{...}` or `new T(args)`. v0.4 scope: only
// the explicit-type forms; LHS-inferred `new(...)` is not yet supported
// (would need expression-context type inference).
func (p *Parser) parseNewExpr() ast.Expr {
	start := p.tok.Pos
	p.advance() // consume `new`

	t := p.parseType()
	if t == nil {
		return nil
	}

	expr := &ast.NewExpr{P: start, Type: t}
	switch p.tok.Kind {
	case lex.LBrace:
		p.advance()
		p.skipSemis()
		for p.tok.Kind != lex.RBrace && p.tok.Kind != lex.EOF {
			if p.tok.Kind != lex.Ident {
				p.errorf("expected field name in composite literal, got %s", p.tok.Kind)
				break
			}
			kvPos := p.tok.Pos
			key := p.tok.Text
			p.advance()
			if !p.expect(lex.Colon) {
				break
			}
			val := p.parseExpr()
			expr.Pairs = append(expr.Pairs, &ast.KeyValuePair{P: kvPos, Key: key, Value: val})
			if p.tok.Kind == lex.Comma {
				p.advance()
			}
			p.skipSemis()
		}
		p.expect(lex.RBrace)
	case lex.LParen:
		p.advance()
		for p.tok.Kind != lex.RParen && p.tok.Kind != lex.EOF {
			expr.Args = append(expr.Args, p.parseExpr())
			if p.tok.Kind == lex.Comma {
				p.advance()
			}
		}
		p.expect(lex.RParen)
	default:
		// Bare `new T` — default-construct (e.g. `new map[K]V`,
		// `new chan T` for unbuffered). Args/Pairs stay nil.
	}
	return expr
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
		s := p.parseStmt()
		if s != nil {
			b.Stmts = append(b.Stmts, s)
		}
		p.expect(lex.Semi)
		p.skipSemis()
	}
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
	case lex.KwBreak:
		s := &ast.BreakStmt{P: p.tok.Pos}
		p.advance()
		return s
	case lex.KwContinue:
		s := &ast.ContinueStmt{P: p.tok.Pos}
		p.advance()
		return s
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
		s := p.parseStmt()
		if s != nil {
			cc.Stmts = append(cc.Stmts, s)
		}
		p.expect(lex.Semi)
		p.skipSemis()
	}
	return cc
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

// parseSimpleStmt: expression, assignment, short var decl, send, or
// multi-LHS variants (`a, b = foo()` / `a, b := foo()`).
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
		case lex.Arrow:
			sendPos := p.tok.Pos
			p.advance()
			rhs := p.parseExpr()
			return &ast.SendStmt{P: sendPos, Channel: first, Value: rhs}
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

	// Otherwise: parse a leading clause. Either:
	//   `for cond { ... }`           (Cond only)
	// or
	//   `for init; cond; post { ... }`  (Init + Cond + Post)
	//
	// Strategy: speculatively parse a simple statement. If the next
	// token is `;`, it was Init; consume the semi and continue.
	// Otherwise, that simple statement IS the condition (and must
	// have been an expression-statement).

	var init ast.Stmt
	var cond ast.Expr
	var post ast.Stmt

	first := p.parseSimpleStmt()
	if p.tok.Kind == lex.Semi {
		// First chunk was Init; need Cond and Post.
		init = first
		p.advance() // consume ';'
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
		// First chunk was the condition. It must be an expression statement.
		if es, ok := first.(*ast.ExprStmt); ok {
			cond = es.Expr
		} else {
			p.errorf("expected condition expression in for loop, got %T", first)
		}
	}

	body := p.parseBlock()
	return &ast.ForStmt{P: start, Init: init, Cond: cond, Post: post, Body: body}
}

func (p *Parser) parseIfStmt() *ast.IfStmt {
	start := p.tok.Pos
	p.advance() // consume `if`
	cond := p.parseExpr()
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
	return &ast.IfStmt{P: start, Cond: cond, Then: then, Else: elseStmt}
}

func (p *Parser) parseVarStmt() *ast.VarStmt {
	start := p.tok.Pos
	p.advance() // consume `var`
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
	case lex.Arrow:
		// `<-ch` — channel receive.
		opPos := p.tok.Pos
		p.advance()
		x := p.parseUnary()
		return &ast.UnaryExpr{P: opPos, Op: "<-", X: x}
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
	case lex.KwTrue:
		x = &ast.BoolLit{P: p.tok.Pos, Value: true}
		p.advance()
	case lex.KwFalse:
		x = &ast.BoolLit{P: p.tok.Pos, Value: false}
		p.advance()
	case lex.KwNil:
		x = &ast.NilLit{P: p.tok.Pos}
		p.advance()
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
	case lex.Star:
		return "*", 5
	case lex.Slash:
		return "/", 5
	case lex.Percent:
		return "%", 5
	}
	return "", 0
}

// ---------- helpers ----------

func (p *Parser) advance() { p.tok = p.lexer.Next() }

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
