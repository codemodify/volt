// Package check implements volt's borrow/ownership analysis.
//
// v0.3 scope (intentionally minimal):
//   - Tracks per-function the move state of locals and parameters.
//   - Movable types: `string`. Primitives (int, bool, byte, ...) are Copy.
//   - A bare identifier used as an argument to a function that takes
//     the same type by value (not &T or *T) is treated as a MOVE.
//   - Reassigning a moved variable revives it.
//   - Reports use-after-move with the source position of the move.
//
// Limitations (deferred to a later pass):
//   - No branch joining: state divergence across if/else/for arms is
//     handled by descending into branches but not merging — this is
//     unsound but catches the obvious straight-line errors.
//   - Cross-package call signatures are unknown to the checker, so
//     calls to imported functions are NOT considered moves. This means
//     foreign calls effectively "borrow" the argument for now.
//   - No lifetime inference (out of scope for v0.3).
//   - No aliasing-XOR-mutation enforcement on &T / *T borrows.
//
// What works:
//   var s string = "hi"
//   consumes(s)
//   consumes(s)    // error: use of moved value "s"
package check

import (
	"fmt"
	"strings"

	"github.com/codemodify/volt/internal/ast"
)

type Checker struct {
	errs    []string
	funcs   map[string]*ast.FuncDecl
	extPkgs map[string]map[string]*ast.FuncDecl // pkg → func name → decl
}

func New() *Checker {
	return &Checker{
		funcs:   make(map[string]*ast.FuncDecl),
		extPkgs: make(map[string]map[string]*ast.FuncDecl),
	}
}

// AddExternal registers the function signatures of another package so the
// checker can reason about cross-package calls.
func (c *Checker) AddExternal(pkgName string, file *ast.File) {
	if c.extPkgs[pkgName] == nil {
		c.extPkgs[pkgName] = make(map[string]*ast.FuncDecl)
	}
	for _, d := range file.Decls {
		fd, ok := d.(*ast.FuncDecl)
		if !ok || fd.Receiver != nil {
			continue
		}
		c.extPkgs[pkgName][fd.Name] = fd
	}
}

// Check runs ownership analysis on the file. Returns a non-nil error
// listing all violations, if any.
func (c *Checker) Check(file *ast.File) error {
	for _, d := range file.Decls {
		if fd, ok := d.(*ast.FuncDecl); ok {
			c.funcs[fd.Name] = fd
		}
	}
	for _, d := range file.Decls {
		if fd, ok := d.(*ast.FuncDecl); ok {
			c.checkFunc(fd)
		}
	}
	if len(c.errs) > 0 {
		return fmt.Errorf("borrow check failed:\n  %s", strings.Join(c.errs, "\n  "))
	}
	return nil
}

// ---------------------------------------------------------------------
// Per-function analysis
// ---------------------------------------------------------------------

type state struct {
	movable bool
	moved   ast.Node // nil if alive; otherwise the statement that moved it
}

func (c *Checker) checkFunc(fd *ast.FuncDecl) {
	syms := make(map[string]*state)
	for _, p := range fd.Params {
		syms[p.Name] = &state{movable: isMovableType(p.Type)}
	}
	if fd.Body == nil {
		return
	}
	c.checkBlock(fd.Body, syms)
}

func (c *Checker) checkBlock(b *ast.Block, syms map[string]*state) {
	for _, s := range b.Stmts {
		c.checkStmt(s, syms)
	}
}

func (c *Checker) checkStmt(s ast.Stmt, syms map[string]*state) {
	switch s := s.(type) {
	case *ast.VarStmt:
		c.checkExprUse(s.Value, syms)
		c.maybeMoveBareIdent(s.Value, s, syms)
		syms[s.Name] = &state{movable: isMovableType(s.Type)}
	case *ast.AssignStmt:
		c.checkExprUse(s.RHS, syms)
		c.maybeMoveBareIdent(s.RHS, s, syms)
		if id, ok := s.LHS.(*ast.IdentExpr); ok {
			if st, ok := syms[id.Name]; ok {
				st.moved = nil // reassigned, revived
			}
		}
	case *ast.RetStmt:
		for _, v := range s.Values {
			c.checkExprUse(v, syms)
		}
		// Returning a value can be a move; but our return values are i64
		// for now (no string returns), so not actionable yet.
	case *ast.ExprStmt:
		c.checkExprUse(s.Expr, syms)
		if call, ok := s.Expr.(*ast.CallExpr); ok {
			c.checkCallMoves(call, syms)
		}
	case *ast.IfStmt:
		c.checkExprUse(s.Cond, syms)
		if s.Then != nil {
			c.checkBlock(s.Then, syms)
		}
		if s.Else != nil {
			c.checkStmt(s.Else, syms)
		}
	case *ast.ForStmt:
		if s.Init != nil {
			c.checkStmt(s.Init, syms)
		}
		c.checkExprUse(s.Cond, syms)
		if s.Body != nil {
			c.checkBlock(s.Body, syms)
		}
		if s.Post != nil {
			c.checkStmt(s.Post, syms)
		}
	case *ast.Block:
		c.checkBlock(s, syms)
	}
}

// checkExprUse: walks an expression, flagging use of moved variables.
func (c *Checker) checkExprUse(e ast.Expr, syms map[string]*state) {
	if e == nil {
		return
	}
	switch ex := e.(type) {
	case *ast.IdentExpr:
		if st, ok := syms[ex.Name]; ok && st.moved != nil {
			c.errs = append(c.errs, fmt.Sprintf(
				"%s: use of moved value %q (moved at %s)",
				ex.Pos(), ex.Name, st.moved.Pos()))
		}
	case *ast.CallExpr:
		c.checkExprUse(ex.Fun, syms)
		for _, a := range ex.Args {
			c.checkExprUse(a, syms)
		}
	case *ast.BinaryExpr:
		c.checkExprUse(ex.X, syms)
		c.checkExprUse(ex.Y, syms)
	case *ast.UnaryExpr:
		c.checkExprUse(ex.X, syms)
	case *ast.SelectorExpr:
		c.checkExprUse(ex.X, syms)
	}
}

// checkCallMoves does two checks on a call's arguments:
//  1. Move tracking: if a movable-typed arg is passed by value (not borrow),
//     the source variable is marked moved.
//  2. Aliasing-XOR-mutation: within a single call's args, if the same source
//     variable is borrowed multiple times AND at least one borrow is mutable
//     (`*T`), it's a borrow-check error.
func (c *Checker) checkCallMoves(call *ast.CallExpr, syms map[string]*state) {
	var sig *ast.FuncDecl
	switch fn := call.Fun.(type) {
	case *ast.IdentExpr:
		sig = c.funcs[fn.Name]
	case *ast.SelectorExpr:
		if pkgId, ok := fn.X.(*ast.IdentExpr); ok {
			if pkg, ok := c.extPkgs[pkgId.Name]; ok {
				sig = pkg[fn.Sel]
			}
		}
	}
	if sig == nil {
		return
	}

	type borrowInfo struct {
		mutable bool
		node    ast.Node
	}
	borrows := make(map[string][]borrowInfo)

	for i, arg := range call.Args {
		if i >= len(sig.Params) {
			break
		}
		paramType := sig.Params[i].Type
		argId, isIdent := arg.(*ast.IdentExpr)

		switch {
		case isBorrowType(paramType):
			if isIdent {
				borrows[argId.Name] = append(borrows[argId.Name], borrowInfo{mutable: false, node: arg})
			}
		case isPointerType(paramType):
			if isIdent {
				borrows[argId.Name] = append(borrows[argId.Name], borrowInfo{mutable: true, node: arg})
			}
		case isMovableType(paramType) && isIdent:
			if st, ok := syms[argId.Name]; ok && st.movable && st.moved == nil {
				st.moved = call
			}
		}
	}

	for name, bs := range borrows {
		if len(bs) <= 1 {
			continue
		}
		hasMut := false
		for _, b := range bs {
			if b.mutable {
				hasMut = true
				break
			}
		}
		if hasMut {
			c.errs = append(c.errs, fmt.Sprintf(
				"%s: variable %q borrowed multiple times in same call; at least one is mutable (*T) — aliasing-XOR-mutation violation",
				bs[0].node.Pos(), name))
		}
	}
}

// maybeMoveBareIdent: for `var x = y` and `x = y` patterns, mark y moved
// if y is itself movable.
func (c *Checker) maybeMoveBareIdent(rhs ast.Expr, at ast.Node, syms map[string]*state) {
	id, ok := rhs.(*ast.IdentExpr)
	if !ok {
		return
	}
	if st, ok := syms[id.Name]; ok && st.movable && st.moved == nil {
		st.moved = at
	}
}

// ---------------------------------------------------------------------
// Type predicates
// ---------------------------------------------------------------------

func isMovableType(t ast.Type) bool {
	if t == nil {
		return false
	}
	if nt, ok := t.(*ast.NamedType); ok {
		switch nt.Name {
		case "string":
			return true
		}
	}
	return false
}

func isBorrowOrPointer(t ast.Type) bool {
	if t == nil {
		return false
	}
	switch t.(type) {
	case *ast.BorrowType, *ast.PointerType:
		return true
	}
	return false
}

func isBorrowType(t ast.Type) bool {
	_, ok := t.(*ast.BorrowType)
	return ok
}

func isPointerType(t ast.Type) bool {
	_, ok := t.(*ast.PointerType)
	return ok
}
