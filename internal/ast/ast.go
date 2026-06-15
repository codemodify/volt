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
	P        lex.Pos
	Package  string
	Imports  []*Import
	Decls    []Decl
	Comments []lex.Comment // all comments in source order; populated by parser
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

// BorrowType is `&T` — a shared, read-only borrow. Many `&T` of the
// same source may coexist. The exclusive write borrow is `*T`
// (PointerType): one at a time, mutually exclusive with any `&T`.
// The checker enforces:
//   - many `&T` of the same source OK at once
//   - one `*T` write borrow of the source OK; blocks all other borrows
//   - `*p = v` requires p to be `*T`
type BorrowType struct {
	P    lex.Pos
	Elem Type
}

func (t *BorrowType) Pos() lex.Pos { return t.P }
func (t *BorrowType) typeNode()    {}

// PointerType is `*T` — the exclusive write borrow (one at a time, XOR
// with any `&T`) when taken as `&x` of a named var; also the owning
// heap pointer returned by `new T{}`.
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

// InterfaceType is `interface { method... }`. v0.7: parsed for source
// fidelity but treated as opaque `ptr` in codegen — no dynamic
// dispatch / vtable. A type satisfies an interface by name only.
type InterfaceType struct {
	P       lex.Pos
	Methods []*Field // each Field's Type is a FunctionType-ish shape
}

func (t *InterfaceType) Pos() lex.Pos { return t.P }
func (t *InterfaceType) typeNode()    {}

// FuncType is `fun(P1, P2) R` — a first-class function type. Used in
// variable declarations, parameters, struct fields, etc. At LLVM
// level a FuncType lowers to %fn_value = {ptr fn, ptr env} — a closure
// fat pointer. Bare function names get a trampoline + null env when
// used in a fn-typed context.
type FuncType struct {
	P       lex.Pos
	Params  []*Param // unnamed positional params allowed (Name == "")
	Results []Type   // empty = no return
}

func (t *FuncType) Pos() lex.Pos { return t.P }
func (t *FuncType) typeNode()    {}

// SliceType is `[]T`.
type SliceType struct {
	P    lex.Pos
	Elem Type
}

func (t *SliceType) Pos() lex.Pos { return t.P }
func (t *SliceType) typeNode()    {}

// MapType is `map[K]V`. v0.5 only supports map[string]int — codegen
// will reject other forms.
type MapType struct {
	P     lex.Pos
	Key   Type
	Value Type
}

func (t *MapType) Pos() lex.Pos { return t.P }
func (t *MapType) typeNode()    {}

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

// ConstDecl is a top-level `const Name [Type] = Value` declaration. v0.5
// limits Value to a literal-constant expression; codegen substitutes the
// value at each use site. Type is optional (nil when omitted) and is kept
// only so the formatter can round-trip it; codegen ignores it.
type ConstDecl struct {
	P     lex.Pos
	Name  string
	Type  Type // may be nil
	Value Expr
}

func (d *ConstDecl) Pos() lex.Pos { return d.P }
func (d *ConstDecl) declNode()    {}

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
	P     lex.Pos // the opening `{`
	End   lex.Pos // the closing `}` (used by the formatter to bound in-body comment flushing)
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
	// MovedAtEnd is set by the checker at the declaring block's close when
	// this local's value has been moved out (and not revived) by then. The
	// checker's move-state is type-aware (it knows movable-vs-Copy field
	// extracts), so codegen unions this into movedNames to suppress the
	// scope-end free precisely — the foundation for safe recursive reclaim.
	MovedAtEnd bool
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

// IfStmt is `if [Init;] cond { Then } [else { Else } | else IfStmt]`.
// Init, when present, is a SimpleStmt (typically VarStmt / MultiVarStmt /
// AssignStmt) scoped to the entire if/else chain — its bindings are
// visible in Cond, Then, and Else (including else-if Cond's).
type IfStmt struct {
	P    lex.Pos
	Init Stmt // nil if no init clause
	Cond Expr
	Then *Block
	Else Stmt // nil, *Block, or *IfStmt (for "else if")
}

func (s *IfStmt) Pos() lex.Pos { return s.P }
func (s *IfStmt) stmtNode()    {}

// ForStmt is `for [Init;] [Cond] [;Post] { Body }`.
// All three of Init/Cond/Post may be nil (giving `for { ... }`, infinite).
//
// Range form: when RangeOver is non-nil, this is a `for i, v := range
// EXPR { ... }` loop. RangeI is the index/key binding (or "_" / ""
// for the single-variable form `for i := range`); RangeV is the value
// binding (or "" if absent). Codegen lowers range to a normal
// index-based for loop over the underlying slice / string / map.
type ForStmt struct {
	P         lex.Pos
	Init      Stmt // typically *VarStmt or *AssignStmt; may be nil
	Cond      Expr // may be nil
	Post      Stmt // typically *AssignStmt; may be nil
	Body      *Block
	RangeI    string
	RangeV    string
	RangeOver Expr // nil for non-range loops
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

// SelectStmt is `select { case ...: ... }`. Each case is either a
// channel send, a channel receive (with optional v / v,ok bindings),
// or default. Semantics: pick a ready case to execute; if none and no
// default, poll until one is ready.
type SelectStmt struct {
	P     lex.Pos
	Cases []*SelectCase
}

func (s *SelectStmt) Pos() lex.Pos { return s.P }
func (s *SelectStmt) stmtNode()    {}

// SelectCase is one clause of a select.
//
//	Default      → IsDefault, no Channel/Send/Recv*
//	send         → Channel + SendValue set
//	v := <-ch    → Channel set, RecvNames = ["v"]
//	v, ok := <-ch→ Channel set, RecvNames = ["v","ok"]
//	<-ch         → Channel set, RecvNames empty (discard)
type SelectCase struct {
	P         lex.Pos
	IsDefault bool
	Channel   Expr
	SendValue Expr     // non-nil for send cases
	RecvNames []string // for recv cases (0, 1, or 2 names)
	Body      []Stmt
}

func (c *SelectCase) Pos() lex.Pos { return c.P }

// ChanType is `chan T`, `chan read T`, `chan write T`, or one of the
// multiplicity-contracted forms (`chan11 T`, `chan1N T`, `chanN1 T`,
// `chanNN T`) — a channel carrying values of T with an optional
// direction restriction (per-handle) and/or multiplicity contract
// (per-channel-value). Direction is enforced at the read/write/close
// builtin sites; multiplicity is enforced at the declaration site by
// walking the function body and counting endpoints. At the LLVM level
// all forms lower to `ptr`. Construction (`new(N)`) always produces a
// bidirectional handle; narrowing is one-way: bidi → directional.
type ChanType struct {
	P     lex.Pos
	Elem  Type
	Dir   ChanDir
	Multi ChanMulti
}

// ChanDir is the access discipline on a channel handle.
type ChanDir int

const (
	ChanBoth  ChanDir = iota // `chan T` — read + write
	ChanRead                 // `chan read T` — read-only
	ChanWrite                // `chan write T` — write-only
)

// ChanMulti is the endpoint-multiplicity contract on a channel value.
// `1` = exactly one endpoint of that kind; `N` = one or more.
// Notation is <readers><writers> — chan11 = one reader, one writer.
// Verified at compile time at the declaring scope by walking the
// function body and counting reader/writer endpoints.
type ChanMulti int

const (
	ChanMultiNone ChanMulti = iota // `chan T` — no contract
	ChanMulti11                    // `chan11 T` — One Reader, One Writer
	ChanMulti1N                    // `chan1N T` — One Reader, Many Writers
	ChanMultiN1                    // `chanN1 T` — Many Readers, One Writer
	ChanMultiNN                    // `chanNN T` — Many Readers, Many Writers
)

// MultiName returns the surface-syntax keyword for a multiplicity.
func (m ChanMulti) MultiName() string {
	switch m {
	case ChanMulti11:
		return "chan11"
	case ChanMulti1N:
		return "chan1N"
	case ChanMultiN1:
		return "chanN1"
	case ChanMultiNN:
		return "chanNN"
	}
	return "chan"
}

func (t *ChanType) Pos() lex.Pos { return t.P }
func (t *ChanType) typeNode()    {}

// AtomicType is `atomic T` — a hardware-atomic single-word value of T.
// T must be a word-sized primitive (int / int64 / bool / ptr).
type AtomicType struct {
	P    lex.Pos
	Elem Type
}

func (t *AtomicType) Pos() lex.Pos { return t.P }
func (t *AtomicType) typeNode()    {}

// MutexType is `mutex T` — an exclusive-access wrapper around an owned T.
type MutexType struct {
	P    lex.Pos
	Elem Type
}

func (t *MutexType) Pos() lex.Pos { return t.P }
func (t *MutexType) typeNode()    {}

// RwMutexType is `rwmutex T` — a many-readers-or-one-writer wrapper
// around an owned T.
type RwMutexType struct {
	P    lex.Pos
	Elem Type
}

func (t *RwMutexType) Pos() lex.Pos { return t.P }
func (t *RwMutexType) typeNode()    {}

// WaitgroupType is `waitgroup` — a counter that blocks Wait() until it
// hits zero. Unlike mutex/rwmutex/atomic, it has no element type — it
// only manages a count.
type WaitgroupType struct {
	P lex.Pos
}

func (t *WaitgroupType) Pos() lex.Pos { return t.P }
func (t *WaitgroupType) typeNode()    {}

// OnceType is `once` — coordination primitive that runs an
// initialization block exactly once across all threads. Subsequent
// callers block until the first finishes. No element type.
type OnceType struct {
	P lex.Pos
}

func (t *OnceType) Pos() lex.Pos { return t.P }
func (t *OnceType) typeNode()    {}

// CondvarType is `condvar` — wait/signal/broadcast coordination
// primitive on top of the runtime's cond_t. Used with a mutex T so
// Wait(m) atomically releases the lock, blocks, then reacquires
// before returning. No element type — the predicate state lives
// inside the paired mutex's payload.
type CondvarType struct {
	P lex.Pos
}

func (t *CondvarType) Pos() lex.Pos { return t.P }
func (t *CondvarType) typeNode()    {}

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

// FloatLit is a floating-point literal. Text holds the original source
// (digits, `.`, optional exponent, `_` separators stripped) and is
// passed verbatim to LLVM — LLVM parses the actual numeric value.
type FloatLit struct {
	P    lex.Pos
	Text string // canonical form (no `_`s)
}

func (e *FloatLit) Pos() lex.Pos { return e.P }
func (e *FloatLit) exprNode()    {}

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

// FuncLit is an anonymous function expression:
//
//	fun(x int) int { ret x + 1 }
//
// Codegen synthesizes a top-level function for the body. If the body
// references identifiers from the enclosing scope, those are captured
// (by-move for non-Copy types, by-copy for Copy types). The literal
// evaluates to a closure value: %fn_value = {ptr fn, ptr env}.
//
// Captures is populated during the check pass — it lists the free
// identifiers found in Body that resolve to enclosing-scope vars.
type FuncLit struct {
	P        lex.Pos
	Params   []*Param
	Results  []Type
	Body     *Block
	Captures []string // free-variable names; filled in by the check pass
	// C13 escape proof: true when any captured name is a borrow / pointer
	// type. Codegen sets this in emitFuncLit; escape sites (emitRet,
	// emitRun, etc.) consult it to reject closures-with-borrows from
	// crossing scopes they can't be proven to outlive.
	CapturesBorrow bool
}

func (e *FuncLit) Pos() lex.Pos { return e.P }
func (e *FuncLit) exprNode()    {}

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

// NewExpr is a heap allocation. The full grammar is:
//
//	new T          — bare (default-construct, no size/init)
//	new T(s)       — sized: chan cap, slice length, map cap hint
//	new T{i}       — init data: struct fields, map entries, or slice elements
//	new T(s){i}    — sized + initial data (slice with length=s, map with cap=s)
//
// The type may be omitted ("short form") when the LHS of the same `=`
// supplies it via an explicit type annotation:
//
//	var c Counter         = new{value: 10}
//	var ch chan int       = new(4)
//	var m map[string]int  = new{}
//	var s []int           = new(8){1, 2, 3}
//
// Brace content has three sub-shapes, distinguished at parse time:
//
//	Pairs       — `name: expr` (Ident key) → struct fields
//	MapEntries  — `expr: expr` (non-Ident key) → map entries
//	SliceElems  — bare `expr` (no key) → slice positional elements
//
// The type-checker rejects shape/type mismatches (e.g. SliceElems with
// a struct LHS).
type NewExpr struct {
	P          lex.Pos
	Type       Type            // nullable: nil means "short form, infer from LHS"
	SizeArgs   []Expr          // from `(...)`: chan cap, slice length, map cap hint
	Pairs      []*KeyValuePair // from `{name: expr, ...}` (struct fields)
	MapEntries []*MapEntry     // from `{expr: expr, ...}` (map entries)
	SliceElems []Expr          // from `{expr, expr, ...}` (slice positional)
	HasParens  bool            // true if source had `(...)` (even if empty)
	HasBraces  bool            // true if source had `{...}` (even if empty)
}

func (e *NewExpr) Pos() lex.Pos { return e.P }
func (e *NewExpr) exprNode()    {}

// KeyValuePair is one `name: value` in a struct composite literal.
// The key is an identifier (a struct field name).
type KeyValuePair struct {
	P     lex.Pos
	Key   string
	Value Expr
}

func (k *KeyValuePair) Pos() lex.Pos { return k.P }

// MapEntry is one `key: value` in a map composite literal, where the
// key is an arbitrary expression (e.g. a string literal).
type MapEntry struct {
	P     lex.Pos
	Key   Expr
	Value Expr
}

func (m *MapEntry) Pos() lex.Pos { return m.P }

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
