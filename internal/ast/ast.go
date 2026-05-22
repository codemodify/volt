// Package ast defines the volt abstract syntax tree.
//
// Mirrors the productions in grammar.ebnf. Every node carries a
// source position from lex.Pos for diagnostics.
//
// v0.1a/b scope: covers package, import, fun, block, expression
// statement, call, selector, identifier, string literal. More node
// types will be added as parser/typechecker grow.
package ast

import "github.com/codemodify/volt/internal/lex"

// Node is the root interface satisfied by every AST node.
type Node interface {
	Pos() lex.Pos
}

// ---------------------------------------------------------------------
// File and top-level
// ---------------------------------------------------------------------

// File represents a complete .volt source file.
type File struct {
	P       lex.Pos
	Package string
	Imports []*Import
	Decls   []Decl
}

func (f *File) Pos() lex.Pos { return f.P }

// Import represents an `import "path"` directive.
type Import struct {
	P    lex.Pos
	Path string
}

func (i *Import) Pos() lex.Pos { return i.P }

// Decl is the interface for top-level declarations.
type Decl interface {
	Node
	declNode()
}

// FuncDecl is `fun Name(params) result { body }`.
// For methods, Receiver is non-nil and Name is the method name; the
// receiver's Type is one of: NamedType (value receiver), BorrowType
// (`&T` shared), or PointerType (`*T` unique). The bare type name is
// always wrapped — there's no `(r T) M()` with T being raw struct.
type FuncDecl struct {
	P        lex.Pos
	Receiver *Param // nil for free functions, set for methods
	Name     string
	Params   []*Param
	Results  []Type // empty = no return
	Body     *Block
}

func (d *FuncDecl) Pos() lex.Pos { return d.P }
func (d *FuncDecl) declNode()    {}

// ReceiverTypeName returns the bare struct type the method is on
// (e.g., "File" for `fun (f *File) Read()`). Empty if not a method.
func (d *FuncDecl) ReceiverTypeName() string {
	if d.Receiver == nil {
		return ""
	}
	switch t := d.Receiver.Type.(type) {
	case *NamedType:
		return t.Name
	case *BorrowType:
		if nt, ok := t.Elem.(*NamedType); ok {
			return nt.Name
		}
	case *PointerType:
		if nt, ok := t.Elem.(*NamedType); ok {
			return nt.Name
		}
	}
	return ""
}

// Param is a function parameter.
type Param struct {
	P    lex.Pos
	Name string
	Type Type
}

func (p *Param) Pos() lex.Pos { return p.P }

// ---------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------

// Type is the interface for type expressions in source.
type Type interface {
	Node
	typeNode()
}

// NamedType is a bare or qualified type name: `int`, `string`, `pkg.T`.
type NamedType struct {
	P       lex.Pos
	Package string // empty if unqualified
	Name    string
}

func (t *NamedType) Pos() lex.Pos { return t.P }
func (t *NamedType) typeNode()    {}

// BorrowType is `&T` — shared, read-only borrow.
type BorrowType struct {
	P    lex.Pos
	Elem Type
}

func (t *BorrowType) Pos() lex.Pos { return t.P }
func (t *BorrowType) typeNode()    {}

// PointerType is `*T` — unique, read/write borrow.
type PointerType struct {
	P    lex.Pos
	Elem Type
}

func (t *PointerType) Pos() lex.Pos { return t.P }
func (t *PointerType) typeNode()    {}

// StructType is `struct { fields }` (typically used inside a TypeDecl).
type StructType struct {
	P      lex.Pos
	Fields []*Field
}

func (t *StructType) Pos() lex.Pos { return t.P }
func (t *StructType) typeNode()    {}

// SliceType is `[]T`.
type SliceType struct {
	P    lex.Pos
	Elem Type
}

func (t *SliceType) Pos() lex.Pos { return t.P }
func (t *SliceType) typeNode()    {}

// Field is one declaration inside a struct.
type Field struct {
	P    lex.Pos
	Name string
	Type Type
}

func (f *Field) Pos() lex.Pos { return f.P }

// TypeDecl is a top-level `type Name Type` declaration.
type TypeDecl struct {
	P    lex.Pos
	Name string
	Type Type
}

func (d *TypeDecl) Pos() lex.Pos { return d.P }
func (d *TypeDecl) declNode()    {}

// ---------------------------------------------------------------------
// Statements
// ---------------------------------------------------------------------

// Stmt is the interface for statements.
type Stmt interface {
	Node
	stmtNode()
}

// Block is `{ stmts }`.
type Block struct {
	P     lex.Pos
	Stmts []Stmt
}

func (b *Block) Pos() lex.Pos { return b.P }
func (b *Block) stmtNode()    {}

// ExprStmt wraps a bare expression used as a statement (typically a call).
type ExprStmt struct {
	P    lex.Pos
	Expr Expr
}

func (s *ExprStmt) Pos() lex.Pos { return s.P }
func (s *ExprStmt) stmtNode()    {}

// VarStmt is `var name [Type] = expr` inside a function body.
type VarStmt struct {
	P     lex.Pos
	Name  string
	Type  Type // may be nil (inferred)
	Value Expr
}

func (s *VarStmt) Pos() lex.Pos { return s.P }
func (s *VarStmt) stmtNode()    {}

// RetStmt is `ret [expr, expr, ...]`. Empty = bare `ret`. 1 = single-value
// return. 2+ = multi-value (emitted as an LLVM aggregate return).
type RetStmt struct {
	P      lex.Pos
	Values []Expr
}

func (s *RetStmt) Pos() lex.Pos { return s.P }
func (s *RetStmt) stmtNode()    {}

// BreakStmt is `break`.
type BreakStmt struct {
	P lex.Pos
}

func (s *BreakStmt) Pos() lex.Pos { return s.P }
func (s *BreakStmt) stmtNode()    {}

// ContinueStmt is `continue`.
type ContinueStmt struct {
	P lex.Pos
}

func (s *ContinueStmt) Pos() lex.Pos { return s.P }
func (s *ContinueStmt) stmtNode()    {}

// IfStmt is `if cond { Then } [else { Else } | else IfStmt]`.
type IfStmt struct {
	P    lex.Pos
	Cond Expr
	Then *Block
	Else Stmt // nil, *Block, or *IfStmt (for "else if")
}

func (s *IfStmt) Pos() lex.Pos { return s.P }
func (s *IfStmt) stmtNode()    {}

// ForStmt is `for [Init;] [Cond] [;Post] { Body }`.
// All three of Init/Cond/Post may be nil (giving `for { ... }`, infinite).
type ForStmt struct {
	P    lex.Pos
	Init Stmt // typically *VarStmt or *AssignStmt; may be nil
	Cond Expr // may be nil
	Post Stmt // typically *AssignStmt; may be nil
	Body *Block
}

func (s *ForStmt) Pos() lex.Pos { return s.P }
func (s *ForStmt) stmtNode()    {}

// AssignStmt is `LHS = RHS`. For v0.2 LHS is restricted to an IdentExpr.
type AssignStmt struct {
	P   lex.Pos
	LHS Expr
	RHS Expr
}

func (s *AssignStmt) Pos() lex.Pos { return s.P }
func (s *AssignStmt) stmtNode()    {}

// MultiAssignStmt is `a, b, ... = call(...)`. RHS must yield multiple
// values (typically a call to a multi-return function).
type MultiAssignStmt struct {
	P   lex.Pos
	LHS []Expr // each entry is the target lvalue (Ident or Selector)
	RHS Expr
}

func (s *MultiAssignStmt) Pos() lex.Pos { return s.P }
func (s *MultiAssignStmt) stmtNode()    {}

// MultiVarStmt is `a, b, ... := call(...)` — short decl of multiple vars
// from a multi-return call.
type MultiVarStmt struct {
	P     lex.Pos
	Names []string
	RHS   Expr
}

func (s *MultiVarStmt) Pos() lex.Pos { return s.P }
func (s *MultiVarStmt) stmtNode()    {}

// DeferStmt is `def expr` — registers expr (typically a call) to run
// at function scope exit in LIFO order.
type DeferStmt struct {
	P    lex.Pos
	Call *CallExpr
}

func (s *DeferStmt) Pos() lex.Pos { return s.P }
func (s *DeferStmt) stmtNode()    {}

// RunStmt is `run expr` — launches a goroutine. In v0.4 (no scheduler)
// this lowers to a synchronous call. Real goroutine semantics require
// the runtime work in Phase 3 proper.
type RunStmt struct {
	P    lex.Pos
	Call *CallExpr
}

func (s *RunStmt) Pos() lex.Pos { return s.P }
func (s *RunStmt) stmtNode()    {}

// SendStmt is `ch <- value` — channel send.
type SendStmt struct {
	P       lex.Pos
	Channel Expr
	Value   Expr
}

func (s *SendStmt) Pos() lex.Pos { return s.P }
func (s *SendStmt) stmtNode()    {}

// ChanType is `chan T` — a channel carrying values of T.
type ChanType struct {
	P    lex.Pos
	Elem Type
}

func (t *ChanType) Pos() lex.Pos { return t.P }
func (t *ChanType) typeNode()    {}

// SwitchStmt is `switch [tag] { case ... default ... }`.
// When Tag is nil, the cases are boolean expressions (Go-style "switch
// {}").
type SwitchStmt struct {
	P     lex.Pos
	Tag   Expr
	Cases []*CaseClause
}

func (s *SwitchStmt) Pos() lex.Pos { return s.P }
func (s *SwitchStmt) stmtNode()    {}

// CaseClause is `case v1, v2: stmts` or `default: stmts`.
type CaseClause struct {
	P     lex.Pos
	Vals  []Expr // nil for default
	Stmts []Stmt
}

func (c *CaseClause) Pos() lex.Pos { return c.P }

// ---------------------------------------------------------------------
// Expressions
// ---------------------------------------------------------------------

// Expr is the interface for expressions.
type Expr interface {
	Node
	exprNode()
}

// IdentExpr is a bare identifier.
type IdentExpr struct {
	P    lex.Pos
	Name string
}

func (e *IdentExpr) Pos() lex.Pos { return e.P }
func (e *IdentExpr) exprNode()    {}

// SelectorExpr is `X.Sel` (e.g. log.Println).
type SelectorExpr struct {
	P   lex.Pos
	X   Expr
	Sel string
}

func (e *SelectorExpr) Pos() lex.Pos { return e.P }
func (e *SelectorExpr) exprNode()    {}

// CallExpr is `Fun(Args...)`.
type CallExpr struct {
	P    lex.Pos
	Fun  Expr
	Args []Expr
}

func (e *CallExpr) Pos() lex.Pos { return e.P }
func (e *CallExpr) exprNode()    {}

// StringLit is a string literal. Text is the un-escaped content.
type StringLit struct {
	P    lex.Pos
	Text string
}

func (e *StringLit) Pos() lex.Pos { return e.P }
func (e *StringLit) exprNode()    {}

// IntLit is an integer literal. Value is the parsed value.
type IntLit struct {
	P     lex.Pos
	Value int64
	Text  string // original source text
}

func (e *IntLit) Pos() lex.Pos { return e.P }
func (e *IntLit) exprNode()    {}

// BoolLit is `true` or `false`.
type BoolLit struct {
	P     lex.Pos
	Value bool
}

func (e *BoolLit) Pos() lex.Pos { return e.P }
func (e *BoolLit) exprNode()    {}

// NilLit is the `nil` literal (currently only valid for interface types).
type NilLit struct {
	P lex.Pos
}

func (e *NilLit) Pos() lex.Pos { return e.P }
func (e *NilLit) exprNode()    {}

// BinaryExpr is `X op Y` for binary operators (+, -, *, /, etc.).
type BinaryExpr struct {
	P  lex.Pos
	Op string // "+", "-", "*", "/", "%", ...
	X  Expr
	Y  Expr
}

func (e *BinaryExpr) Pos() lex.Pos { return e.P }
func (e *BinaryExpr) exprNode()    {}

// UnaryExpr is `op X` for unary operators (!, -).
type UnaryExpr struct {
	P  lex.Pos
	Op string // "!", "-"
	X  Expr
}

func (e *UnaryExpr) Pos() lex.Pos { return e.P }
func (e *UnaryExpr) exprNode()    {}

// NewExpr is `new T{...}` or `new T()` — heap-allocates an owned T.
type NewExpr struct {
	P     lex.Pos
	Type  Type           // the type to allocate
	Pairs []*KeyValuePair // for `new T{a: 1, b: 2}`; nil otherwise
	Args  []Expr          // for `new T(args)`; nil otherwise
}

func (e *NewExpr) Pos() lex.Pos { return e.P }
func (e *NewExpr) exprNode()    {}

// KeyValuePair is one `name: value` in a composite literal.
type KeyValuePair struct {
	P     lex.Pos
	Key   string
	Value Expr
}

func (k *KeyValuePair) Pos() lex.Pos { return k.P }

// SliceLit is `[]T{e1, e2, e3}`.
type SliceLit struct {
	P     lex.Pos
	Elem  Type
	Elems []Expr
}

func (e *SliceLit) Pos() lex.Pos { return e.P }
func (e *SliceLit) exprNode()    {}

// IndexExpr is `X[Index]`.
type IndexExpr struct {
	P     lex.Pos
	X     Expr
	Index Expr
}

func (e *IndexExpr) Pos() lex.Pos { return e.P }
func (e *IndexExpr) exprNode()    {}
