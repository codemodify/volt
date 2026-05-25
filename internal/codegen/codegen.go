// Package codegen emits LLVM IR text from the AST.
//
// v0.3 scope:
//   - Real type tracking per expression (Value with LLVM type tag).
//   - Bool (i1) and nil literals; unary `!` and `-`.
//   - First-class strings: %string = type { ptr, i64 }.
//   - Multi-package compilation: each .volt file is compiled as its
//     own LLVM module; symbols are mangled as `<pkg>_<Name>` and the
//     driver links the modules together.
//   - syscall.Write(fd int, s string) is a compiler intrinsic that
//     lowers to the runtime-provided `volt_write` symbol.
//   - log.Println is now an ordinary stdlib function (see
//     stdlib/log/log.volt), no longer a compiler intrinsic.
//
// Naive alloca/load/store for every variable and parameter. LLVM's
// mem2reg pass cleans this up at -O1+ if you opt in.
package codegen

import (
	"fmt"
	"strings"

	"github.com/codemodify/volt/internal/ast"
	"github.com/codemodify/volt/internal/lex"
)

// ---------------------------------------------------------------------
// Value — an LLVM SSA name with its IR type.
// ---------------------------------------------------------------------

type Value struct {
	Name      string // SSA name ("%t0"), literal ("42"), or global ("@str.0")
	Type      string // LLVM type ("i64", "i1", "%string", "%slice", "ptr", "void")
	SliceElem string // for %slice values: the LLVM element type (e.g. "i64", "i8")
}

// ---------------------------------------------------------------------
// Emitter — one Emitter per module/package.
// ---------------------------------------------------------------------

type Emitter struct {
	pkg        string
	header     strings.Builder
	declares   map[string]bool   // declared external symbols (lines)
	stringDefs strings.Builder   // global string constants
	stringID   int
	funcs      map[string]*ast.FuncDecl // local free functions by name
	methods    map[string]map[string]*ast.FuncDecl // typeName → methodName → decl
	imports    []string                  // import paths used by this file
	imported   map[string]bool           // import-path basename → true
	structs    map[string]*structInfo    // user-defined struct types
	interfaces map[string]bool           // user-declared interface type names (opaque ptr)
	consts     map[string]ast.Expr       // top-level const Name → value expr
	// errorImpls: concrete type names that satisfy the built-in `error`
	// interface (i.e., have a method `fun (r *T) Error() string`).
	// Populated after method registration; consulted when boxing into
	// an `error`-typed variable and when dispatching `.Error()` calls.
	errorImpls map[string]bool
	// interfaceDecls keyed by interface NAME → its AST (method order
	// is preserved so vtable indices match the declared method order).
	interfaceDecls map[string]*ast.InterfaceType
	// ifaceImpls keyed by concrete typeName → set of interface names it implements.
	// Computed once after all types + methods are registered.
	ifaceImpls map[string]map[string]bool
	// fnTrampolines: set of (mangled) function symbols for which we've
	// already emitted a `<sym>_$fn` trampoline that adapts the bare-fn
	// ABI to the closure ABI `(ptr env, args...) -> ret`. Trampolines
	// are emitted lazily on first use as a fn value.
	fnTrampolines map[string]string // function symbol → trampoline symbol
	// trampolineDefs accumulates IR for synthesized trampolines and
	// closure bodies. Written out after the user's functions.
	trampolineDefs strings.Builder
	// closureLitID is a monotonic counter for naming synthesized
	// closure-literal bodies and their env types.
	closureLitID int
	// Optional LLVM target triple. When empty, no `target triple` line
	// is emitted — clang `--target=` then governs.
	targetTriple string
}

// SetTarget sets the LLVM target triple for the emitted module.
func (e *Emitter) SetTarget(triple string) { e.targetTriple = triple }

// structInfo carries field ordering + name→index for a struct type.
type structInfo struct {
	Fields []*ast.Field
	Index  map[string]int
}

func New() *Emitter {
	return &Emitter{
		declares: make(map[string]bool),
		funcs:    make(map[string]*ast.FuncDecl),
		methods:  make(map[string]map[string]*ast.FuncDecl),
		imported: make(map[string]bool),
		structs:        make(map[string]*structInfo),
		interfaces:     make(map[string]bool),
		errorImpls:     make(map[string]bool),
		interfaceDecls: make(map[string]*ast.InterfaceType),
		ifaceImpls:     make(map[string]map[string]bool),
		fnTrampolines:  make(map[string]string),
		consts:         make(map[string]ast.Expr),
	}
}

// methodSymbol mangles a method's LLVM symbol: <pkg>_<TypeName>_<MethodName>.
func methodSymbol(pkg, typeName, method string) string {
	return pkg + "_" + typeName + "_" + method
}

// SymbolName produces the LLVM symbol name for a function `name` in `pkg`.
// Mangling: <pkg>_<name>. `main.main` keeps the bare name `main` so the
// runtime's _start can call it.
func SymbolName(pkg, name string) string {
	if pkg == "main" && name == "main" {
		return "main"
	}
	return pkg + "_" + name
}

// Emit produces LLVM IR for the file.
func (e *Emitter) Emit(file *ast.File) (string, error) {
	e.pkg = file.Package
	for _, im := range file.Imports {
		e.imports = append(e.imports, im.Path)
		e.imported[im.Path] = true
	}
	for _, d := range file.Decls {
		switch d := d.(type) {
		case *ast.FuncDecl:
			if d.Receiver != nil {
				tn := d.ReceiverTypeName()
				if e.methods[tn] == nil {
					e.methods[tn] = make(map[string]*ast.FuncDecl)
				}
				e.methods[tn][d.Name] = d
			} else {
				e.funcs[d.Name] = d
			}
		case *ast.ConstDecl:
			e.consts[d.Name] = d.Value
		case *ast.TypeDecl:
			switch td := d.Type.(type) {
			case *ast.StructType:
				idx := make(map[string]int, len(td.Fields))
				for i, f := range td.Fields {
					idx[f.Name] = i
				}
				e.structs[d.Name] = &structInfo{Fields: td.Fields, Index: idx}
			case *ast.InterfaceType:
				e.interfaces[d.Name] = true
				e.interfaceDecls[d.Name] = td
			}
		}
	}

	// Identify concrete types that satisfy the built-in `error`
	// interface — i.e., declare a method `fun (r *T) Error() string`
	// (no params, single string return). Method registration above is
	// complete by this point.
	for tn, m := range e.methods {
		fd, ok := m["Error"]
		if !ok {
			continue
		}
		if len(fd.Params) != 0 || len(fd.Results) != 1 {
			continue
		}
		if nt, ok := fd.Results[0].(*ast.NamedType); ok && nt.Name == "string" {
			e.errorImpls[tn] = true
		}
	}
	// Identify concrete types that satisfy each user-declared interface.
	// v0.7 match: every method NAME declared on the interface must exist
	// on the concrete type. Signature-strict matching comes later when
	// the parser captures interface method signatures.
	for ifaceName, iface := range e.interfaceDecls {
		for tn, m := range e.methods {
			ok := true
			for _, mDecl := range iface.Methods {
				if _, has := m[mDecl.Name]; !has {
					ok = false
					break
				}
			}
			if !ok {
				continue
			}
			if e.ifaceImpls[tn] == nil {
				e.ifaceImpls[tn] = make(map[string]bool)
			}
			e.ifaceImpls[tn][ifaceName] = true
		}
	}

	fmt.Fprintf(&e.header, "; module: %s\n", file.Package)
	if e.targetTriple != "" {
		fmt.Fprintf(&e.header, "target triple = %q\n\n", e.targetTriple)
	} else {
		e.header.WriteString("\n")
	}
	e.header.WriteString("%string = type { ptr, i64 }\n")
	// %slice = { data ptr, len, cap }. cap is the allocated capacity;
	// new[]T(N) initializes len = N and cap = N. append() can grow cap
	// past len when needed; sub-slicing (when it lands) will reuse the
	// same backing while narrowing len.
	e.header.WriteString("%slice = type { ptr, i64, i64 }\n")
	// %error_box: fat pointer for error-typed values. data is the
	// boxed concrete value, error_fn is the implementing type's
	// Error() method (stored directly instead of via a separate
	// vtable struct — error has exactly one method).
	e.header.WriteString("%error_box = type { ptr, ptr }\n")
	// %fn_value: closure fat pointer { ptr fn, ptr env }. Every
	// function value (named-fn reference, anonymous literal,
	// closure with captures) is this shape. The `fn` slot always
	// has the signature `(env, args...) -> result`; bare-fn
	// references use a synthesized trampoline that ignores env.
	e.header.WriteString("%fn_value = type { ptr, ptr }\n")

	// Emit named struct types. The order from the source file is preserved.
	for _, d := range file.Decls {
		td, ok := d.(*ast.TypeDecl)
		if !ok {
			continue
		}
		st, ok := td.Type.(*ast.StructType)
		if !ok {
			continue
		}
		fmt.Fprintf(&e.header, "%%%s = type { ", td.Name)
		for i, f := range st.Fields {
			if i > 0 {
				e.header.WriteString(", ")
			}
			e.header.WriteString(e.llvmType(f.Type))
		}
		e.header.WriteString(" }\n")
	}
	e.header.WriteString("\n")

	// Emit user-interface vtables: one constant array per (concrete
	// type, interface) pair. Method order matches the interface's
	// declaration order, so dispatch-time indices line up.
	for tn, ifaces := range e.ifaceImpls {
		for ifaceName := range ifaces {
			iface := e.interfaceDecls[ifaceName]
			var entries []string
			for _, m := range iface.Methods {
				entries = append(entries, "ptr @"+methodSymbol(e.pkg, tn, m.Name))
			}
			fmt.Fprintf(&e.header, "@%s_%s_vtable = constant [%d x ptr] [%s]\n",
				tn, ifaceName, len(entries), strings.Join(entries, ", "))
		}
	}
	if len(e.ifaceImpls) > 0 {
		e.header.WriteString("\n")
	}

	var body strings.Builder
	for _, d := range file.Decls {
		fd, ok := d.(*ast.FuncDecl)
		if !ok {
			continue
		}
		if err := e.emitFunc(&body, fd); err != nil {
			return "", err
		}
	}

	var out strings.Builder
	out.WriteString(e.header.String())
	if e.stringDefs.Len() > 0 {
		out.WriteString(e.stringDefs.String())
		out.WriteString("\n")
	}
	for line := range e.declares {
		out.WriteString(line + "\n")
	}
	if len(e.declares) > 0 {
		out.WriteString("\n")
	}
	out.WriteString(body.String())
	if e.trampolineDefs.Len() > 0 {
		out.WriteString("\n; -- synthesized trampolines + closure bodies --\n")
		out.WriteString(e.trampolineDefs.String())
	}
	return out.String(), nil
}

// llvmType maps an AST type to an LLVM type string.
// Borrow (&T) and Pointer (*T) types both become opaque `ptr`.
// User-defined struct types are emitted as `%<Name>`.
func (e *Emitter) llvmType(t ast.Type) string {
	if t == nil {
		return "void"
	}
	switch tt := t.(type) {
	case *ast.NamedType:
		switch tt.Name {
		case "int", "int64", "uint", "uint64":
			return "i64"
		case "int32", "uint32":
			return "i32"
		case "int16", "uint16":
			return "i16"
		case "int8", "uint8", "byte":
			return "i8"
		case "bool":
			return "i1"
		case "float", "float64":
			return "double"
		case "float32":
			return "float"
		case "string":
			return "%string"
		case "error", "any":
			// Interface-shaped types — opaque pointer in this v0.7
			// universe. No vtable / dynamic dispatch yet.
			return "ptr"
		}
		// User-defined struct declared in this file?
		if _, ok := e.structs[tt.Name]; ok {
			return "%" + tt.Name
		}
		// User-declared interface type → opaque ptr.
		if e.interfaces[tt.Name] {
			return "ptr"
		}
	case *ast.BorrowType, *ast.PointerType:
		return "ptr"
	case *ast.SliceType:
		return "%slice"
	case *ast.ChanType:
		// Channels are runtime-allocated; we carry an opaque ptr.
		return "ptr"
	case *ast.MapType:
		return "ptr"
	case *ast.InterfaceType:
		// Interface values are opaque ptrs in v0.7. No vtable layout
		// or dynamic dispatch yet.
		return "ptr"
	case *ast.AtomicType, *ast.MutexType, *ast.RwMutexType,
		*ast.WaitgroupType, *ast.OnceType:
		// Sync primitives are runtime-allocated handles to a struct
		// containing the wrapped value plus any lock state. Reference-
		// typed (copying the value yields another handle).
		return "ptr"
	case *ast.FuncType:
		// First-class function values are %fn_value = {ptr fn, ptr env}.
		// The signature is carried in the AST node; codegen looks at the
		// declared type at the call site to produce the right indirect-
		// call signature.
		return "%fn_value"
	}
	return "void"
}

// isMapType reports whether t is a *ast.MapType.
func isMapType(t ast.Type) bool {
	_, ok := t.(*ast.MapType)
	return ok
}

// chanElemLLVM returns the LLVM element type for a ChanType, or "" otherwise.
// Currently always i64 in v0.5 — channel runtime only supports i64-sized
// elements. Other element types are a later extension.
func (e *Emitter) chanElemLLVM(t ast.Type) string {
	if _, ok := t.(*ast.ChanType); ok {
		return "i64"
	}
	return ""
}

// sliceElemLLVM returns the LLVM element type for a SliceType, or "" otherwise.
func (e *Emitter) sliceElemLLVM(t ast.Type) string {
	if st, ok := t.(*ast.SliceType); ok {
		return e.llvmType(st.Elem)
	}
	return ""
}

// elemType returns the inner LLVM type of a borrow/pointer, or "" otherwise.
func (e *Emitter) elemType(t ast.Type) string {
	switch tt := t.(type) {
	case *ast.BorrowType:
		return e.llvmType(tt.Elem)
	case *ast.PointerType:
		return e.llvmType(tt.Elem)
	}
	return ""
}

func isBorrowOrPointer(t ast.Type) bool {
	switch t.(type) {
	case *ast.BorrowType, *ast.PointerType:
		return true
	}
	return false
}

func (e *Emitter) emitFunc(out *strings.Builder, fd *ast.FuncDecl) error {
	isMain := fd.Name == "main" && e.pkg == "main" && fd.Receiver == nil

	// Symbol name: methods are mangled with their receiver type.
	var symbolName string
	if fd.Receiver != nil {
		symbolName = methodSymbol(e.pkg, fd.ReceiverTypeName(), fd.Name)
	} else {
		symbolName = SymbolName(e.pkg, fd.Name)
	}

	var retType string
	switch {
	case isMain:
		retType = "i64"
	case len(fd.Results) == 0:
		retType = "void"
	case len(fd.Results) == 1:
		retType = e.llvmType(fd.Results[0])
	default:
		// Multi-return: aggregate type "{T1, T2, ...}".
		var sb strings.Builder
		sb.WriteByte('{')
		for i, r := range fd.Results {
			if i > 0 {
				sb.WriteString(", ")
			}
			sb.WriteString(e.llvmType(r))
		}
		sb.WriteByte('}')
		retType = sb.String()
	}

	// All params: receiver prepended if present.
	allParams := fd.Params
	if fd.Receiver != nil {
		allParams = append([]*ast.Param{fd.Receiver}, fd.Params...)
	}

	fmt.Fprintf(out, "define %s @%s(", retType, symbolName)
	for i, p := range allParams {
		if i > 0 {
			out.WriteString(", ")
		}
		fmt.Fprintf(out, "%s %%%s", e.llvmType(p.Type), p.Name)
	}
	out.WriteString(") {\n")
	out.WriteString("entry:\n")

	c := &funcCtx{
		e:         e,
		symbols:   make(map[string]symbol),
		retType:   retType,
		isMain:    isMain,
		usedAddrs: make(map[string]int),
	}

	for _, p := range allParams {
		pt := e.llvmType(p.Type)
		ptr := fmt.Sprintf("%%%s.addr", p.Name)
		c.usedAddrs[p.Name+".addr"] = 1
		fmt.Fprintf(&c.body, "  %s = alloca %s\n", ptr, pt)
		fmt.Fprintf(&c.body, "  store %s %%%s, ptr %s\n", pt, p.Name, ptr)
		c.symbols[p.Name] = symbol{
			Ptr:       ptr,
			Type:      pt,
			Elem:      e.elemType(p.Type),
			SliceElem: e.sliceElemLLVM(p.Type),
			IsMap:     isMapType(p.Type),
			AstType:   p.Type,
		}
	}

	if fd.Body != nil {
		for _, s := range fd.Body.Stmts {
			if err := c.emitStmt(s); err != nil {
				return err
			}
		}
	}

	if !c.terminated {
		// Synthesize fall-through: run defers, then drops, then ret.
		if err := c.emitDefers(); err != nil {
			return err
		}
		c.emitDrops()
		switch {
		case isMain:
			c.body.WriteString("  ret i64 0\n")
		case retType == "void":
			c.body.WriteString("  ret void\n")
		case len(retType) > 0 && retType[0] == '{':
			// Aggregate: use zeroinitializer.
			fmt.Fprintf(&c.body, "  ret %s zeroinitializer\n", retType)
		default:
			fmt.Fprintf(&c.body, "  ret %s 0\n", retType)
		}
	}
	out.WriteString(c.body.String())
	out.WriteString("}\n\n")
	return nil
}

// ---------------------------------------------------------------------
// Per-function context
// ---------------------------------------------------------------------

type symbol struct {
	Ptr        string   // alloca pointer name (e.g., "%x.addr")
	Type       string   // LLVM type stored at alloca (e.g., "i64", "%string", "%slice", "ptr")
	Elem       string   // for borrow/pointer symbols: the pointee LLVM type
	SliceElem  string   // for %slice symbols: the LLVM element type
	IsMap      bool     // true if this symbol is a map[string]int handle (ptr)
	IsGuard    bool     // true if this symbol is a sync guard — must not escape (no passing to fns, no return)
	IsReadOnly bool     // true if this symbol is a reader-only guard — field writes rejected
	AstType    ast.Type // the declared AST type — used to dispatch built-ins like close()/clone()
}

type funcCtx struct {
	e          *Emitter
	body       strings.Builder
	nextTmp    int
	nextLbl    int
	symbols    map[string]symbol
	retType    string
	isMain     bool
	terminated bool
	defers     []*ast.CallExpr
	// Drops registered for owned struct-typed locals whose type has a
	// Drop() method, AND for mutex guard handles. Each entry records the
	// scopeDepth at registration so block-scoped cleanup fires at the
	// correct boundary (loop iteration end, if-body end, etc.).
	drops      []dropEntry
	scopeDepth int         // 0 = function body, +1 per nested block
	loops      []loopFrame // innermost last
	// LLVM-level alloca names already used in this function — keyed by
	// the desired raw name (e.g. "i.addr"). emitVar consults this to
	// uniquify when the same source identifier is declared more than
	// once in the same function (e.g. two sequential `for i := 0` loops).
	usedAddrs map[string]int
}

type loopFrame struct {
	breakLbl    string
	continueLbl string
	scopeDepth  int // scopeDepth at loop entry (before body push)
}

// dropEntry describes one scheduled cleanup. Kind selects the emission
// shape; for struct Drop we look up methods[typeName]["Drop"]; for a
// sync guard we call the recorded unlockFn with the stored handle.
type dropEntry struct {
	kind     dropKind
	depth    int    // scopeDepth at registration; popScope drops entries == depth, break/continue drop entries > target depth
	ptr      string // for dropKindStruct: alloca pointer ("%r.addr")
	typeName string // for dropKindStruct: bare type name ("Resource")
	handle   string // for dropKindSyncGuard: alloca pointer holding the wrapper handle ptr
	unlockFn string // for dropKindSyncGuard: runtime function name (e.g. "volt_mutex_unlock")
}

type dropKind int

const (
	dropKindStruct dropKind = iota
	dropKindSyncGuard
)

func (c *funcCtx) newTemp() string {
	n := c.nextTmp
	c.nextTmp++
	return fmt.Sprintf("%%t%d", n)
}

func (c *funcCtx) newLabel(prefix string) string {
	n := c.nextLbl
	c.nextLbl++
	return fmt.Sprintf("%s.%d", prefix, n)
}

func (c *funcCtx) startBlock(label string) {
	fmt.Fprintf(&c.body, "%s:\n", label)
	c.terminated = false
}

// ---------------------------------------------------------------------
// Statements
// ---------------------------------------------------------------------

func (c *funcCtx) emitStmt(s ast.Stmt) error {
	switch s := s.(type) {
	case *ast.ExprStmt:
		_, err := c.emitExpr(s.Expr)
		return err
	case *ast.VarStmt:
		return c.emitVar(s)
	case *ast.RetStmt:
		return c.emitRet(s)
	case *ast.IfStmt:
		return c.emitIf(s)
	case *ast.ForStmt:
		return c.emitFor(s)
	case *ast.AssignStmt:
		return c.emitAssign(s)
	case *ast.DeferStmt:
		c.defers = append(c.defers, s.Call)
		return nil
	case *ast.SwitchStmt:
		return c.emitSwitch(s)
	case *ast.RunStmt:
		return c.emitRun(s)
	case *ast.SendStmt:
		return c.emitSend(s)
	case *ast.SelectStmt:
		return c.emitSelect(s)
	case *ast.MultiVarStmt:
		return c.emitMultiVar(s)
	case *ast.MultiAssignStmt:
		return c.emitMultiAssign(s)
	case *ast.BreakStmt:
		if len(c.loops) == 0 {
			return fmt.Errorf("%s: break outside loop", s.Pos())
		}
		lf := c.loops[len(c.loops)-1]
		c.emitDropsAbove(lf.scopeDepth)
		fmt.Fprintf(&c.body, "  br label %%%s\n", lf.breakLbl)
		c.terminated = true
		return nil
	case *ast.ContinueStmt:
		if len(c.loops) == 0 {
			return fmt.Errorf("%s: continue outside loop", s.Pos())
		}
		lf := c.loops[len(c.loops)-1]
		c.emitDropsAbove(lf.scopeDepth)
		fmt.Fprintf(&c.body, "  br label %%%s\n", lf.continueLbl)
		c.terminated = true
		return nil
	}
	return fmt.Errorf("%s: unsupported statement %T", s.Pos(), s)
}

// tryRecv2 detects a channel receive used as a multi-value source —
// either `<-ch` (legacy) or `read(ch)` (canonical). Returns the
// aggregate SSA name and the two field types {i64, i64} on success.
func (c *funcCtx) tryRecv2(rhs ast.Expr) (string, []string, bool) {
	var chExpr ast.Expr
	switch r := rhs.(type) {
	case *ast.UnaryExpr:
		if r.Op != "<-" {
			return "", nil, false
		}
		chExpr = r.X
	case *ast.CallExpr:
		fn, ok := r.Fun.(*ast.IdentExpr)
		if !ok || fn.Name != "read" || len(r.Args) != 1 {
			return "", nil, false
		}
		chExpr = r.Args[0]
	default:
		return "", nil, false
	}
	ch, err := c.emitExpr(chExpr)
	if err != nil {
		return "", nil, false
	}
	c.e.ensureDeclare("declare {i64, i64} @volt_chan_recv2(ptr)")
	agg := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call {i64, i64} @volt_chan_recv2(ptr %s)\n", agg, ch.Name)
	return agg, []string{"i64", "i64"}, true
}

// emitMultiVar handles `a, b := foo()` where foo() returns multiple values.
// Also recognizes `v, ok := <-ch` and routes to volt_chan_recv2.
func (c *funcCtx) emitMultiVar(s *ast.MultiVarStmt) error {
	if agg, fieldTypes, ok := c.tryRecv2(s.RHS); ok {
		if len(s.Names) != 2 {
			return fmt.Errorf("%s: `<-ch` two-value form requires exactly two LHS names", s.Pos())
		}
		aggT := "{i64, i64}"
		for i, name := range s.Names {
			resultT := fieldTypes[i]
			ptr := fmt.Sprintf("%%%s.addr", name)
			fmt.Fprintf(&c.body, "  %s = alloca %s\n", ptr, resultT)
			ev := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = extractvalue %s %s, %d\n", ev, aggT, agg, i)
			fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", resultT, ev, ptr)
			c.symbols[name] = symbol{Ptr: ptr, Type: resultT}
		}
		return nil
	}
	agg, fieldTypes, err := c.emitMultiReturnCall(s.RHS)
	if err != nil {
		return err
	}
	if len(fieldTypes) != len(s.Names) {
		return fmt.Errorf("%s: call returns %d values but %d names declared",
			s.Pos(), len(fieldTypes), len(s.Names))
	}
	aggT := aggregateType(fieldTypes)
	for i, name := range s.Names {
		resultT := fieldTypes[i]
		ptr := fmt.Sprintf("%%%s.addr", name)
		fmt.Fprintf(&c.body, "  %s = alloca %s\n", ptr, resultT)
		ev := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = extractvalue %s %s, %d\n", ev, aggT, agg, i)
		fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", resultT, ev, ptr)
		c.symbols[name] = symbol{Ptr: ptr, Type: resultT}
	}
	return nil
}

// emitMultiAssign handles `a, b = foo()` into existing lvalues.
// Also handles `v, ok = read(ch)` / `v, ok = <-ch`.
func (c *funcCtx) emitMultiAssign(s *ast.MultiAssignStmt) error {
	agg, fieldTypes, ok := c.tryRecv2(s.RHS)
	if !ok {
		var err error
		agg, fieldTypes, err = c.emitMultiReturnCall(s.RHS)
		if err != nil {
			return err
		}
	}
	if len(fieldTypes) != len(s.LHS) {
		return fmt.Errorf("%s: call returns %d values but %d LHS targets",
			s.Pos(), len(fieldTypes), len(s.LHS))
	}
	aggT := aggregateType(fieldTypes)
	for i, lhs := range s.LHS {
		id, ok := lhs.(*ast.IdentExpr)
		if !ok {
			return fmt.Errorf("%s: multi-assign LHS must be identifiers in v0.5", lhs.Pos())
		}
		sym, ok := c.symbols[id.Name]
		if !ok {
			return fmt.Errorf("%s: undefined variable %q", id.Pos(), id.Name)
		}
		ev := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = extractvalue %s %s, %d\n", ev, aggT, agg, i)
		// Convert int width if needed.
		v := c.convertInt(Value{Name: ev, Type: fieldTypes[i]}, sym.Type)
		fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", sym.Type, v.Name, sym.Ptr)
	}
	return nil
}

// emitMultiReturnCall lowers a function call that yields multiple values.
// Returns the aggregate SSA name and the field LLVM types.
func (c *funcCtx) emitMultiReturnCall(expr ast.Expr) (string, []string, error) {
	call, ok := expr.(*ast.CallExpr)
	if !ok {
		return "", nil, fmt.Errorf("%s: multi-result RHS must be a call", expr.Pos())
	}
	id, ok := call.Fun.(*ast.IdentExpr)
	if !ok {
		return "", nil, fmt.Errorf("%s: multi-return only via direct calls in v0.5", call.Pos())
	}
	sig, ok := c.e.funcs[id.Name]
	if !ok {
		return "", nil, fmt.Errorf("%s: undefined function %q", call.Pos(), id.Name)
	}
	if len(sig.Results) < 2 {
		return "", nil, fmt.Errorf("%s: %s does not return multiple values", call.Pos(), id.Name)
	}
	if len(call.Args) != len(sig.Params) {
		return "", nil, fmt.Errorf("%s: %s takes %d arg(s), got %d",
			call.Pos(), id.Name, len(sig.Params), len(call.Args))
	}

	fieldTypes := make([]string, len(sig.Results))
	for i, r := range sig.Results {
		fieldTypes[i] = c.e.llvmType(r)
	}
	aggT := aggregateType(fieldTypes)

	var argStrs []string
	for i, arg := range call.Args {
		v, err := c.emitCallArg(arg, sig.Params[i].Type)
		if err != nil {
			return "", nil, err
		}
		paramT := c.e.llvmType(sig.Params[i].Type)
		argStrs = append(argStrs, paramT+" "+v.Name)
	}

	mangled := SymbolName(c.e.pkg, id.Name)
	agg := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call %s @%s(%s)\n",
		agg, aggT, mangled, strings.Join(argStrs, ", "))
	return agg, fieldTypes, nil
}

func aggregateType(fieldTypes []string) string {
	var sb strings.Builder
	sb.WriteByte('{')
	for i, t := range fieldTypes {
		if i > 0 {
			sb.WriteString(", ")
		}
		sb.WriteString(t)
	}
	sb.WriteByte('}')
	return sb.String()
}

// emitRun lowers `run f(...)` (0..6 args) to
// volt_spawn(@f, a1, a2, a3, a4, a5, a6). The runtime spawn primitive
// (start_*.s) accepts a fixed 6 arg-slots — matching the SysV
// register-arg ceiling for the receiving function on amd64 — and
// passes null for any unused tail slot. For >6 args, pack into a
// struct and pass a single ptr.
const spawnMaxArgs = 6

func (c *funcCtx) emitRun(s *ast.RunStmt) error {
	id, ok := s.Call.Fun.(*ast.IdentExpr)
	if !ok {
		return fmt.Errorf("%s: `run` requires a bare function name in v0.5", s.Pos())
	}
	sig, ok := c.e.funcs[id.Name]
	if !ok {
		return fmt.Errorf("%s: undefined function %q", s.Pos(), id.Name)
	}
	if len(sig.Params) > spawnMaxArgs {
		return fmt.Errorf("%s: `run` supports at most %d args; pack additional state into a struct/handle if you need more",
			s.Pos(), spawnMaxArgs)
	}
	if len(s.Call.Args) != len(sig.Params) {
		return fmt.Errorf("%s: %s takes %d arg(s), got %d",
			s.Pos(), id.Name, len(sig.Params), len(s.Call.Args))
	}
	args := make([]string, spawnMaxArgs)
	for i := range args {
		args[i] = "null"
	}
	// Spawn slots are ptr-typed. Most volt scalar args fit in one slot
	// and ride through via inttoptr. A function-value arg (`%fn_value`)
	// is a 16-byte {fn, env} aggregate — SysV passes it in TWO GPRs, so
	// it consumes TWO spawn slots. The receiver's LLVM signature still
	// declares the param as %fn_value and the calling convention
	// reassembles it from rdi+rsi (or the next pair of arg-passing regs).
	slot := 0
	for i, expr := range s.Call.Args {
		v, err := c.emitCallArg(expr, sig.Params[i].Type)
		if err != nil {
			return err
		}
		if v.Type == "%fn_value" {
			if slot+1 >= spawnMaxArgs {
				return fmt.Errorf("%s: closure args consume 2 spawn slots; this run exceeds the %d-slot limit",
					s.Pos(), spawnMaxArgs)
			}
			fnP := c.newTemp()
			envP := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = extractvalue %%fn_value %s, 0\n", fnP, v.Name)
			fmt.Fprintf(&c.body, "  %s = extractvalue %%fn_value %s, 1\n", envP, v.Name)
			args[slot] = fnP
			args[slot+1] = envP
			slot += 2
			continue
		}
		if v.Type == "ptr" {
			args[slot] = v.Name
			slot++
			continue
		}
		conv := c.newTemp()
		widened := c.convertInt(v, "i64")
		fmt.Fprintf(&c.body, "  %s = inttoptr i64 %s to ptr\n", conv, widened.Name)
		args[slot] = conv
		slot++
	}
	mangled := SymbolName(c.e.pkg, id.Name)
	c.e.ensureDeclare("declare void @volt_spawn(ptr, ptr, ptr, ptr, ptr, ptr, ptr)")
	fmt.Fprintf(&c.body, "  call void @volt_spawn(ptr @%s, ptr %s, ptr %s, ptr %s, ptr %s, ptr %s, ptr %s)\n",
		mangled, args[0], args[1], args[2], args[3], args[4], args[5])
	return nil
}

// emitSelect lowers a `select` statement to a polling loop over
// non-blocking try_send/try_recv calls.
//
//   loop:
//     try case 0; if success → case0
//     try case 1; if success → case1
//     ...
//     if default present → default block
//     else volt_yield; goto loop
//
//   case0: ... br end
//   case1: ... br end
//   end:
func (c *funcCtx) emitSelect(s *ast.SelectStmt) error {
	var defaultCase *ast.SelectCase
	channelCases := make([]*ast.SelectCase, 0, len(s.Cases))
	for _, cs := range s.Cases {
		if cs.IsDefault {
			defaultCase = cs
		} else {
			channelCases = append(channelCases, cs)
		}
	}

	loopLbl := c.newLabel("select.loop")
	endLbl := c.newLabel("select.end")
	bodyLbls := make([]string, len(channelCases))
	for i := range channelCases {
		bodyLbls[i] = c.newLabel("select.body")
	}
	var defaultLbl string
	if defaultCase != nil {
		defaultLbl = c.newLabel("select.default")
	}

	// Pre-compute channel pointers and (for send) values OUTSIDE the loop
	// so we don't re-eval side-effecting exprs on every iteration.
	type compiledCase struct {
		chanV Value
		sendV Value
	}
	compiled := make([]compiledCase, len(channelCases))
	for i, cs := range channelCases {
		chV, err := c.emitExpr(cs.Channel)
		if err != nil {
			return err
		}
		compiled[i].chanV = chV
		if cs.SendValue != nil {
			sv, err := c.emitExpr(cs.SendValue)
			if err != nil {
				return err
			}
			sv = c.convertInt(sv, "i64")
			compiled[i].sendV = sv
		}
	}

	fmt.Fprintf(&c.body, "  br label %%%s\n", loopLbl)
	c.terminated = true
	c.startBlock(loopLbl)

	c.e.ensureDeclare("declare i64 @volt_chan_try_send(ptr, i64)")
	c.e.ensureDeclare("declare {i64, i64} @volt_chan_try_recv(ptr)")
	c.e.ensureDeclare("declare void @volt_yield()")

	// Track the {value, ok} aggregate for each recv-case so the body
	// block can extract `v` and `ok` from it.
	recvAggs := make([]string, len(channelCases))

	for i, cs := range channelCases {
		nextLbl := c.newLabel("select.try")
		if cs.SendValue != nil {
			ok := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = call i64 @volt_chan_try_send(ptr %s, i64 %s)\n",
				ok, compiled[i].chanV.Name, compiled[i].sendV.Name)
			cmp := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = icmp ne i64 %s, 0\n", cmp, ok)
			fmt.Fprintf(&c.body, "  br i1 %s, label %%%s, label %%%s\n", cmp, bodyLbls[i], nextLbl)
		} else {
			agg := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = call {i64, i64} @volt_chan_try_recv(ptr %s)\n",
				agg, compiled[i].chanV.Name)
			ok := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = extractvalue {i64, i64} %s, 1\n", ok, agg)
			cmp := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = icmp ne i64 %s, 0\n", cmp, ok)
			recvAggs[i] = agg
			fmt.Fprintf(&c.body, "  br i1 %s, label %%%s, label %%%s\n", cmp, bodyLbls[i], nextLbl)
		}
		c.terminated = true
		c.startBlock(nextLbl)
	}

	// After all cases tried: default or yield+loop.
	if defaultCase != nil {
		fmt.Fprintf(&c.body, "  br label %%%s\n", defaultLbl)
		c.terminated = true
	} else {
		c.body.WriteString("  call void @volt_yield()\n")
		fmt.Fprintf(&c.body, "  br label %%%s\n", loopLbl)
		c.terminated = true
	}

	// Emit each body block.
	for i, cs := range channelCases {
		c.startBlock(bodyLbls[i])
		// Bind recv names if any. Each case is a fresh scope, so we
		// disambiguate the alloca pointer with the case index — two
		// cases binding `v := read(a)` and `v := read(b)` won't collide
		// at the LLVM level.
		if cs.SendValue == nil && len(cs.RecvNames) > 0 {
			agg := recvAggs[i]
			vTmp := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = extractvalue {i64, i64} %s, 0\n", vTmp, agg)
			ptr := fmt.Sprintf("%%%s.case%d.addr", cs.RecvNames[0], i)
			fmt.Fprintf(&c.body, "  %s = alloca i64\n", ptr)
			fmt.Fprintf(&c.body, "  store i64 %s, ptr %s\n", vTmp, ptr)
			c.symbols[cs.RecvNames[0]] = symbol{Ptr: ptr, Type: "i64"}
			if len(cs.RecvNames) == 2 {
				okTmp := c.newTemp()
				fmt.Fprintf(&c.body, "  %s = extractvalue {i64, i64} %s, 1\n", okTmp, agg)
				okPtr := fmt.Sprintf("%%%s.case%d.addr", cs.RecvNames[1], i)
				fmt.Fprintf(&c.body, "  %s = alloca i64\n", okPtr)
				fmt.Fprintf(&c.body, "  store i64 %s, ptr %s\n", okTmp, okPtr)
				c.symbols[cs.RecvNames[1]] = symbol{Ptr: okPtr, Type: "i64"}
			}
		}
		for _, stmt := range cs.Body {
			if err := c.emitStmt(stmt); err != nil {
				return err
			}
		}
		if !c.terminated {
			fmt.Fprintf(&c.body, "  br label %%%s\n", endLbl)
			c.terminated = true
		}
	}

	if defaultCase != nil {
		c.startBlock(defaultLbl)
		for _, stmt := range defaultCase.Body {
			if err := c.emitStmt(stmt); err != nil {
				return err
			}
		}
		if !c.terminated {
			fmt.Fprintf(&c.body, "  br label %%%s\n", endLbl)
			c.terminated = true
		}
	}

	c.startBlock(endLbl)
	return nil
}

// emitSend lowers `ch <- v` to a call into the channel runtime.
// v0.5 supports chan int (i64-sized elements) only.
func (c *funcCtx) emitSend(s *ast.SendStmt) error {
	chV, err := c.emitExpr(s.Channel)
	if err != nil {
		return err
	}
	val, err := c.emitExpr(s.Value)
	if err != nil {
		return err
	}
	val = c.convertInt(val, "i64")
	c.e.ensureDeclare("declare void @volt_chan_send(ptr, i64)")
	fmt.Fprintf(&c.body, "  call void @volt_chan_send(ptr %s, i64 %s)\n", chV.Name, val.Name)
	return nil
}

// emitSwitch lowers a switch statement to cascading icmp/br chains.
func (c *funcCtx) emitSwitch(s *ast.SwitchStmt) error {
	var tagVal Value
	haveTag := s.Tag != nil
	if haveTag {
		v, err := c.emitExpr(s.Tag)
		if err != nil {
			return err
		}
		tagVal = v
	}

	endLbl := c.newLabel("switch.end")
	var defaultCase *ast.CaseClause
	var nonDefault []*ast.CaseClause
	for _, cc := range s.Cases {
		if cc.Vals == nil {
			defaultCase = cc
		} else {
			nonDefault = append(nonDefault, cc)
		}
	}

	bodyLabels := make([]string, len(nonDefault))
	for i := range nonDefault {
		bodyLabels[i] = c.newLabel("switch.case")
	}
	defaultLbl := endLbl
	if defaultCase != nil {
		defaultLbl = c.newLabel("switch.default")
	}

	// Cascading tests
	for i, cc := range nonDefault {
		for _, vExpr := range cc.Vals {
			vv, err := c.emitExpr(vExpr)
			if err != nil {
				return err
			}
			var cmpName string
			if haveTag {
				cmp := c.newTemp()
				fmt.Fprintf(&c.body, "  %s = icmp eq %s %s, %s\n",
					cmp, tagVal.Type, tagVal.Name, vv.Name)
				cmpName = cmp
			} else {
				// tag-less switch: each val is itself a bool expression
				cmpName = c.toBool(vv).Name
			}
			nextLbl := c.newLabel("switch.next")
			fmt.Fprintf(&c.body, "  br i1 %s, label %%%s, label %%%s\n",
				cmpName, bodyLabels[i], nextLbl)
			c.terminated = true
			c.startBlock(nextLbl)
		}
	}
	// All tests fell through → default (or end).
	fmt.Fprintf(&c.body, "  br label %%%s\n", defaultLbl)
	c.terminated = true

	for i, cc := range nonDefault {
		c.startBlock(bodyLabels[i])
		for _, stmt := range cc.Stmts {
			if err := c.emitStmt(stmt); err != nil {
				return err
			}
		}
		if !c.terminated {
			fmt.Fprintf(&c.body, "  br label %%%s\n", endLbl)
			c.terminated = true
		}
	}

	if defaultCase != nil {
		c.startBlock(defaultLbl)
		for _, stmt := range defaultCase.Stmts {
			if err := c.emitStmt(stmt); err != nil {
				return err
			}
		}
		if !c.terminated {
			fmt.Fprintf(&c.body, "  br label %%%s\n", endLbl)
			c.terminated = true
		}
	}

	c.startBlock(endLbl)
	return nil
}

// emitDefers emits all currently-registered defers in reverse (LIFO) order.
// Called immediately before any ret or at function fallthrough.
func (c *funcCtx) emitDefers() error {
	for i := len(c.defers) - 1; i >= 0; i-- {
		if _, err := c.emitCall(c.defers[i]); err != nil {
			return err
		}
	}
	return nil
}

// guardCall captures the per-receiver-kind dispatch for guard-creating
// methods. lockFn / unlockFn are the runtime symbol names; readOnly
// flags reader-only guards (reject writes). elem is the wrapped T.
type guardCall struct {
	lockFn   string
	unlockFn string
	readOnly bool
	elem     ast.Type
}

// classifyGuardCall reports whether expr is a guard-creating call
// (mutex.Lock, rwmutex.Lock, or rwmutex.LockRead) on a receiver
// variable. On a hit it returns the runtime dispatch to use.
func (c *funcCtx) classifyGuardCall(expr ast.Expr) (guardCall, bool) {
	call, ok := expr.(*ast.CallExpr)
	if !ok {
		return guardCall{}, false
	}
	sel, ok := call.Fun.(*ast.SelectorExpr)
	if !ok {
		return guardCall{}, false
	}
	id, ok := sel.X.(*ast.IdentExpr)
	if !ok {
		return guardCall{}, false
	}
	sym, ok := c.symbols[id.Name]
	if !ok {
		return guardCall{}, false
	}
	switch t := sym.AstType.(type) {
	case *ast.MutexType:
		if sel.Sel == "Lock" {
			return guardCall{lockFn: "volt_mutex_lock", unlockFn: "volt_mutex_unlock", elem: t.Elem}, true
		}
	case *ast.RwMutexType:
		switch sel.Sel {
		case "Lock":
			return guardCall{lockFn: "volt_rwmutex_lock", unlockFn: "volt_rwmutex_unlock", elem: t.Elem}, true
		case "LockRead":
			return guardCall{lockFn: "volt_rwmutex_lock_read", unlockFn: "volt_rwmutex_unlock_read", readOnly: true, elem: t.Elem}, true
		}
	}
	return guardCall{}, false
}

// isGuardCreatingCall is the boolean form used by emitVar to gate the
// special-case emission. Kept thin so emitGuardVar can re-classify
// against the same predicate.
func (c *funcCtx) isGuardCreatingCall(expr ast.Expr) bool {
	_, ok := c.classifyGuardCall(expr)
	return ok
}

// emitGuardVar lowers `var v T = m.Lock()`, `var v T = r.Lock()`, or
// `var v T = r.LockRead()` into a guard binding. It:
//  1. allocates two slots — one for the wrapper handle (needed by Drop)
//     and one for the payload pointer (what the user accesses through v),
//  2. calls the lock entry point to acquire and get the payload ptr,
//  3. registers a scope-local drop that calls the matching unlock fn.
//
// The resulting symbol behaves like a borrow: sym.Type="ptr",
// sym.Elem=<llvm of T>. Field reads/writes flow through the existing
// borrow paths. Reader-only guards set IsReadOnly to reject writes.
func (c *funcCtx) emitGuardVar(s *ast.VarStmt) error {
	gc, _ := c.classifyGuardCall(s.Value)
	call := s.Value.(*ast.CallExpr)
	sel := call.Fun.(*ast.SelectorExpr)
	if len(call.Args) != 0 {
		return fmt.Errorf("%s: %s takes no arguments", call.Pos(), sel.Sel)
	}
	recvIdent := sel.X.(*ast.IdentExpr)
	recvSym := c.symbols[recvIdent.Name]

	elemT := c.e.llvmType(gc.elem)
	if s.Type != nil {
		want := c.e.llvmType(s.Type)
		if want != elemT {
			return fmt.Errorf("%s: guard type %s does not match payload type %s",
				s.Pos(), want, elemT)
		}
	}

	handlePtr := fmt.Sprintf("%%%s.handle", s.Name)
	addrPtr := fmt.Sprintf("%%%s.addr", s.Name)

	fmt.Fprintf(&c.body, "  %s = alloca ptr\n", handlePtr)
	fmt.Fprintf(&c.body, "  %s = alloca ptr\n", addrPtr)

	// Load the wrapper handle from the receiver var, stash it for Drop.
	h := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", h, recvSym.Ptr)
	fmt.Fprintf(&c.body, "  store ptr %s, ptr %s\n", h, handlePtr)

	// Acquire the lock and store the returned payload pointer.
	c.e.ensureDeclare(fmt.Sprintf("declare ptr @%s(ptr)", gc.lockFn))
	pl := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call ptr @%s(ptr %s)\n", pl, gc.lockFn, h)
	fmt.Fprintf(&c.body, "  store ptr %s, ptr %s\n", pl, addrPtr)

	c.symbols[s.Name] = symbol{
		Ptr:        addrPtr,
		Type:       "ptr",
		Elem:       elemT,
		IsGuard:    true,
		IsReadOnly: gc.readOnly,
		AstType:    gc.elem,
	}

	c.drops = append(c.drops, dropEntry{
		kind:     dropKindSyncGuard,
		depth:    c.scopeDepth,
		handle:   handlePtr,
		unlockFn: gc.unlockFn,
	})
	return nil
}

// isErrorType reports whether `t` is the built-in `error` interface
// (a `NamedType` literally named "error").
func isErrorType(t ast.Type) bool {
	nt, ok := t.(*ast.NamedType)
	return ok && nt.Name == "error"
}

// isAnyType reports whether `t` is the built-in `any` interface — the
// type-erased empty interface. v0.7: stores any value heap-allocated
// behind a single ptr; no method dispatch (no methods to dispatch),
// no type recovery (no type tag yet — that's a future addition).
func isAnyType(t ast.Type) bool {
	nt, ok := t.(*ast.NamedType)
	return ok && nt.Name == "any"
}

// emitAnyBox heap-allocates a copy of `val` and returns the data ptr.
// Used when assigning any concrete value to an `any`-typed variable.
// No vtable, no fat pointer — `any` has no methods to dispatch and no
// type tag to read back, so storing the data ptr is sufficient.
func (c *funcCtx) emitAnyBox(_ lex.Pos, val Value) (Value, error) {
	szPtr := c.newTemp()
	szInt := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = getelementptr %s, ptr null, i32 1\n", szPtr, val.Type)
	fmt.Fprintf(&c.body, "  %s = ptrtoint ptr %s to i64\n", szInt, szPtr)
	c.e.ensureDeclare("declare ptr @volt_alloc(i64)")
	dataPtr := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call ptr @volt_alloc(i64 %s)\n", dataPtr, szInt)
	fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", val.Type, val.Name, dataPtr)
	return Value{Name: dataPtr, Type: "ptr"}, nil
}

// userInterfaceName returns the interface name if `t` refers to a
// user-declared interface type (and not the built-in `error`/`any`).
func (c *funcCtx) userInterfaceName(t ast.Type) string {
	nt, ok := t.(*ast.NamedType)
	if !ok {
		return ""
	}
	if _, ok := c.e.interfaceDecls[nt.Name]; ok {
		return nt.Name
	}
	return ""
}

// emitIfaceBox lowers `var v Iface = X{...}` (where X is a concrete
// type that implements Iface) into a heap-boxed fat pointer pointing
// at the right vtable. Mirrors emitErrorBox but with a vtable pointer
// in the second slot instead of a single fn pointer.
func (c *funcCtx) emitIfaceBox(pos lex.Pos, val Value, ifaceName string) (Value, error) {
	typeName := strings.TrimPrefix(val.Type, "%")
	if !c.e.ifaceImpls[typeName][ifaceName] {
		return Value{}, fmt.Errorf("%s: type %s does not implement interface %s (missing one of its methods)",
			pos, typeName, ifaceName)
	}
	// Allocate space for the concrete value and store the SSA value.
	szPtr := c.newTemp()
	szInt := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = getelementptr %s, ptr null, i32 1\n", szPtr, val.Type)
	fmt.Fprintf(&c.body, "  %s = ptrtoint ptr %s to i64\n", szInt, szPtr)
	c.e.ensureDeclare("declare ptr @volt_alloc(i64)")
	dataPtr := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call ptr @volt_alloc(i64 %s)\n", dataPtr, szInt)
	fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", val.Type, val.Name, dataPtr)

	// Allocate the 16-byte fat pointer box {ptr data, ptr vtable}.
	// We reuse %error_box's layout (same shape — the second slot is
	// just opaque; error stores a fn ptr, user-iface stores a vtable
	// ptr; the dispatch path knows which kind it has).
	boxPtr := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call ptr @volt_alloc(i64 16)\n", boxPtr)
	vtableSym := fmt.Sprintf("%s_%s_vtable", typeName, ifaceName)
	gepData := c.newTemp()
	gepVT := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = getelementptr %%error_box, ptr %s, i32 0, i32 0\n", gepData, boxPtr)
	fmt.Fprintf(&c.body, "  store ptr %s, ptr %s\n", dataPtr, gepData)
	fmt.Fprintf(&c.body, "  %s = getelementptr %%error_box, ptr %s, i32 0, i32 1\n", gepVT, boxPtr)
	fmt.Fprintf(&c.body, "  store ptr @%s, ptr %s\n", vtableSym, gepVT)
	return Value{Name: boxPtr, Type: "ptr"}, nil
}

// emitIfaceMethod dispatches a method call whose receiver is a user-
// declared interface type. Looks up the method's index in the
// interface declaration (declaration order = vtable order), loads the
// fn pointer from vtable[index], indirect-calls with data ptr as the
// hidden first arg ("this").
func (c *funcCtx) emitIfaceMethod(call *ast.CallExpr, recvSym symbol, ifaceName, method string) (Value, error) {
	iface := c.e.interfaceDecls[ifaceName]
	if iface == nil {
		return Value{}, fmt.Errorf("%s: unknown interface %s", call.Pos(), ifaceName)
	}
	methodIdx := -1
	var methodFt *ast.FuncType
	for i, m := range iface.Methods {
		if m.Name == method {
			methodIdx = i
			methodFt, _ = m.Type.(*ast.FuncType)
			break
		}
	}
	if methodIdx < 0 {
		return Value{}, fmt.Errorf("%s: interface %s has no method %q", call.Pos(), ifaceName, method)
	}
	if methodFt == nil {
		return Value{}, fmt.Errorf("%s: interface %s method %s lost its signature", call.Pos(), ifaceName, method)
	}
	if len(call.Args) != len(methodFt.Params) {
		return Value{}, fmt.Errorf("%s: %s.%s takes %d arg(s), got %d",
			call.Pos(), ifaceName, method, len(methodFt.Params), len(call.Args))
	}

	box := c.newTemp()
	dataGep := c.newTemp()
	dataPtr := c.newTemp()
	vtGep := c.newTemp()
	vtPtr := c.newTemp()
	fnGep := c.newTemp()
	fnPtr := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", box, recvSym.Ptr)
	fmt.Fprintf(&c.body, "  %s = getelementptr %%error_box, ptr %s, i32 0, i32 0\n", dataGep, box)
	fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", dataPtr, dataGep)
	fmt.Fprintf(&c.body, "  %s = getelementptr %%error_box, ptr %s, i32 0, i32 1\n", vtGep, box)
	fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", vtPtr, vtGep)
	// GEP into the vtable array at this method's index.
	fmt.Fprintf(&c.body, "  %s = getelementptr ptr, ptr %s, i32 %d\n", fnGep, vtPtr, methodIdx)
	fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", fnPtr, fnGep)

	retT := "void"
	if len(methodFt.Results) > 0 {
		retT = c.e.llvmType(methodFt.Results[0])
	}
	argStrs := []string{"ptr " + dataPtr}
	for i, arg := range call.Args {
		v, err := c.emitCallArg(arg, methodFt.Params[i].Type)
		if err != nil {
			return Value{}, err
		}
		paramT := c.e.llvmType(methodFt.Params[i].Type)
		argStrs = append(argStrs, paramT+" "+v.Name)
	}
	if retT == "void" {
		fmt.Fprintf(&c.body, "  call void %s(%s)\n", fnPtr, strings.Join(argStrs, ", "))
		return Value{Name: "", Type: "void"}, nil
	}
	result := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call %s %s(%s)\n", result, retT, fnPtr, strings.Join(argStrs, ", "))
	return Value{Name: result, Type: retT}, nil
}

// emitErrorBox boxes a concrete struct value into an `%error_box`. The
// returned value is a `ptr` (LLVM-level alias for an `error` value).
// The caller (typically emitVar) replaces the original RHS with this
// boxed pointer. Both the data box and the box-struct itself are
// heap-allocated via volt_alloc; ownership is shared (no auto-free
// today, same as channels).
func (c *funcCtx) emitErrorBox(pos lex.Pos, val Value) (Value, error) {
	typeName := strings.TrimPrefix(val.Type, "%")
	if !c.e.errorImpls[typeName] {
		return Value{}, fmt.Errorf("%s: type %s does not implement `error` (needs `fun (r *%s) Error() string`)",
			pos, typeName, typeName)
	}

	// Allocate space for the concrete value and store the SSA value.
	szPtr := c.newTemp()
	szInt := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = getelementptr %s, ptr null, i32 1\n", szPtr, val.Type)
	fmt.Fprintf(&c.body, "  %s = ptrtoint ptr %s to i64\n", szInt, szPtr)
	c.e.ensureDeclare("declare ptr @volt_alloc(i64)")
	dataPtr := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call ptr @volt_alloc(i64 %s)\n", dataPtr, szInt)
	fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", val.Type, val.Name, dataPtr)

	// Allocate the fat-pointer box and populate {data_ptr, error_fn}.
	boxPtr := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call ptr @volt_alloc(i64 16)\n", boxPtr)
	fnSym := methodSymbol(c.e.pkg, typeName, "Error")
	gepData := c.newTemp()
	gepFn := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = getelementptr %%error_box, ptr %s, i32 0, i32 0\n", gepData, boxPtr)
	fmt.Fprintf(&c.body, "  store ptr %s, ptr %s\n", dataPtr, gepData)
	fmt.Fprintf(&c.body, "  %s = getelementptr %%error_box, ptr %s, i32 0, i32 1\n", gepFn, boxPtr)
	fmt.Fprintf(&c.body, "  store ptr @%s, ptr %s\n", fnSym, gepFn)
	return Value{Name: boxPtr, Type: "ptr"}, nil
}

func (c *funcCtx) emitVar(s *ast.VarStmt) error {
	// Type-hint passthrough: `var x T = new(...)` / `new{...}` short
	// forms have no type on the `new` expression itself — pull it from
	// the var's declared type before emission.
	if ne, ok := s.Value.(*ast.NewExpr); ok && ne.Type == nil && s.Type != nil {
		ne.Type = s.Type
	}

	// `var v T = m.Lock()` (mutex), `r.Lock()` / `r.LockRead()` (rwmutex)
	// create a guard, not a plain T value. The guard variable holds a
	// payload pointer into the wrapper's storage; field access
	// reads/writes through that pointer; the lock releases at scope
	// exit via a registered drop.
	if c.isGuardCreatingCall(s.Value) {
		return c.emitGuardVar(s)
	}

	var val Value
	var err error
	if s.Value != nil {
		val, err = c.emitExpr(s.Value)
		if err != nil {
			return err
		}
	}
	typeStr := "i64"
	if s.Type != nil {
		typeStr = c.e.llvmType(s.Type)
	} else if s.Value != nil {
		typeStr = val.Type
	}

	// Implicit conversion: assigning a concrete struct value to an
	// `error`-typed variable boxes the struct and stores its Error
	// method pointer alongside. The resulting value is a `ptr` to an
	// `%error_box`. Codegen for `e.Error()` reads the box and dispatches.
	if s.Value != nil && isErrorType(s.Type) && strings.HasPrefix(val.Type, "%") && val.Type != "%string" && val.Type != "%slice" && val.Type != "%error_box" {
		boxed, berr := c.emitErrorBox(s.Pos(), val)
		if berr != nil {
			return berr
		}
		val = boxed
	}
	// Same shape for user-declared interfaces: concrete struct value
	// → fat pointer pointing at the matching (T, Iface) vtable.
	if s.Value != nil && strings.HasPrefix(val.Type, "%") && val.Type != "%string" && val.Type != "%slice" {
		if iname := c.userInterfaceName(s.Type); iname != "" {
			boxed, berr := c.emitIfaceBox(s.Pos(), val, iname)
			if berr != nil {
				return berr
			}
			val = boxed
		}
	}
	// `any` storage box: heap-copy the concrete value, store the ptr.
	// Works for any non-ptr concrete type (struct, primitive, etc.).
	// No type tag yet — values stuffed into `any` can be passed around
	// and compared to nil, but can't be unboxed back to their original
	// type (that needs a type-assertion mechanism, future work).
	if s.Value != nil && isAnyType(s.Type) && val.Type != "ptr" {
		boxed, berr := c.emitAnyBox(s.Pos(), val)
		if berr != nil {
			return berr
		}
		val = boxed
	}
	var elem, sliceElem string
	if s.Type != nil {
		elem = c.e.elemType(s.Type)
		sliceElem = c.e.sliceElemLLVM(s.Type)
	} else if s.Value != nil {
		sliceElem = val.SliceElem
	}
	ptr := "%" + c.allocaName(s.Name)
	fmt.Fprintf(&c.body, "  %s = alloca %s\n", ptr, typeStr)
	if s.Value != nil {
		val = c.convertInt(val, typeStr)
		fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", typeStr, val.Name, ptr)
	}
	isMap := false
	if s.Type != nil {
		isMap = isMapType(s.Type)
	}
	c.symbols[s.Name] = symbol{Ptr: ptr, Type: typeStr, Elem: elem, SliceElem: sliceElem, IsMap: isMap, AstType: s.Type}

	// If the variable is an owned struct value AND its type (or any
	// transitively-owned struct field) has a Drop() method, register
	// the chain of drops at scope exit. Field drops run AFTER the
	// parent's own Drop, in reverse declaration order — matching
	// C++/Rust destruction semantics.
	if len(typeStr) > 1 && typeStr[0] == '%' && typeStr != "%string" && typeStr != "%slice" {
		typeName := strings.TrimPrefix(typeStr, "%")
		c.registerStructDrops(ptr, typeName, c.scopeDepth, make(map[string]bool))
	}
	return nil
}

// registerStructDrops walks a struct type and registers Drop calls for
// the struct itself and recursively for every field whose type has a
// Drop method. Registration order is:
//   1. each Drop-bearing field, in declaration order (recurses first)
//   2. the parent's own Drop (last, so it pops FIRST under LIFO)
//
// With LIFO emission, that yields: parent.Drop runs, then fields run
// in REVERSE declaration order, then nested-field drops, and so on.
// `visiting` guards against pathological cyclic struct definitions.
func (c *funcCtx) registerStructDrops(ptr, typeName string, depth int, visiting map[string]bool) {
	if visiting[typeName] {
		return
	}
	visiting[typeName] = true
	defer delete(visiting, typeName)

	info := c.e.structs[typeName]
	if info == nil {
		return
	}
	// Field drops first.
	for i, f := range info.Fields {
		nt, ok := f.Type.(*ast.NamedType)
		if !ok {
			continue
		}
		if !c.structHasDrop(nt.Name, make(map[string]bool)) {
			continue
		}
		fp := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = getelementptr %%%s, ptr %s, i32 0, i32 %d\n",
			fp, typeName, ptr, i)
		c.registerStructDrops(fp, nt.Name, depth, visiting)
	}
	// Parent's own Drop last.
	if c.e.methods[typeName] != nil {
		if _, ok := c.e.methods[typeName]["Drop"]; ok {
			c.drops = append(c.drops, dropEntry{
				kind:     dropKindStruct,
				depth:    depth,
				ptr:      ptr,
				typeName: typeName,
			})
		}
	}
}

// structHasDrop reports whether the named struct type owns any Drop
// behavior — either its own Drop method, or a Drop-bearing struct
// field (transitively).
func (c *funcCtx) structHasDrop(typeName string, visiting map[string]bool) bool {
	if visiting[typeName] {
		return false
	}
	visiting[typeName] = true
	if c.e.methods[typeName] != nil {
		if _, ok := c.e.methods[typeName]["Drop"]; ok {
			return true
		}
	}
	info := c.e.structs[typeName]
	if info == nil {
		return false
	}
	for _, f := range info.Fields {
		if nt, ok := f.Type.(*ast.NamedType); ok {
			if c.structHasDrop(nt.Name, visiting) {
				return true
			}
		}
	}
	return false
}

// pushScope opens a new block scope. Drops registered while this scope
// is active fire when popScope is called (natural fall-through) or
// when break/continue/ret crosses the boundary.
func (c *funcCtx) pushScope() {
	c.scopeDepth++
}

// popScope emits inline cleanups for drops registered at the current
// scope depth (in LIFO order) and removes them from the queue. Call
// this at the natural end of a block — NOT before an early exit (use
// emitDropsAbove for that, since control isn't returning here).
func (c *funcCtx) popScope() {
	target := c.scopeDepth
	keep := c.drops[:0:0]
	tail := []dropEntry{}
	for _, d := range c.drops {
		if d.depth >= target {
			tail = append(tail, d)
		} else {
			keep = append(keep, d)
		}
	}
	for i := len(tail) - 1; i >= 0; i-- {
		c.emitOneDrop(tail[i])
	}
	c.drops = keep
	c.scopeDepth--
}

// emitDropsAbove emits inline cleanups for drops registered at depth
// strictly greater than `floor`, in LIFO order, WITHOUT removing them
// from c.drops. Use this on early-exit edges (break, continue, ret) —
// control is jumping out, so the natural popScope at the block's end
// will not re-fire these (it runs in a different basic block).
func (c *funcCtx) emitDropsAbove(floor int) {
	for i := len(c.drops) - 1; i >= 0; i-- {
		d := c.drops[i]
		if d.depth > floor {
			c.emitOneDrop(d)
		}
	}
}

// discardDropsAbove removes drops registered at depth > floor without
// emitting them. Use this after an early exit (break/continue/ret) has
// already emitted them inline — keeping the entries would cause a
// later popScope/emitDrops to re-fire them on an unrelated code path.
func (c *funcCtx) discardDropsAbove(floor int) {
	kept := c.drops[:0:0]
	for _, d := range c.drops {
		if d.depth <= floor {
			kept = append(kept, d)
		}
	}
	c.drops = kept
}

// emitDrops runs ALL registered destructors in LIFO order. Called from
// emitRet and the function fallthrough — drops every active depth.
func (c *funcCtx) emitDrops() {
	c.emitDropsAbove(-1)
}

func (c *funcCtx) emitOneDrop(d dropEntry) {
	switch d.kind {
	case dropKindStruct:
		sym := methodSymbol(c.e.pkg, d.typeName, "Drop")
		// Drop methods we register here are always same-package (we found
		// them in c.e.methods at registration time), so no `declare` is
		// needed — the `define` is in this same module.
		fmt.Fprintf(&c.body, "  call void @%s(ptr %s)\n", sym, d.ptr)
	case dropKindSyncGuard:
		c.e.ensureDeclare(fmt.Sprintf("declare void @%s(ptr)", d.unlockFn))
		h := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", h, d.handle)
		fmt.Fprintf(&c.body, "  call void @%s(ptr %s)\n", d.unlockFn, h)
	}
}

func (c *funcCtx) emitAssign(s *ast.AssignStmt) error {
	switch lhs := s.LHS.(type) {
	case *ast.IdentExpr:
		return c.emitIdentAssign(lhs, s.RHS)
	case *ast.SelectorExpr:
		return c.emitFieldAssign(lhs, s.RHS)
	case *ast.IndexExpr:
		// m[k] = v on a map variable.
		if id, ok := lhs.X.(*ast.IdentExpr); ok {
			if sym, ok := c.symbols[id.Name]; ok && sym.IsMap {
				return c.emitMapSet(sym, lhs.Index, s.RHS, lhs.Pos())
			}
		}
		return fmt.Errorf("%s: indexed assignment only supported on map variables in v0.5", lhs.Pos())
	}
	return fmt.Errorf("%s: assignment target must be a variable or field/index access", s.LHS.Pos())
}

func (c *funcCtx) emitIdentAssign(lhs *ast.IdentExpr, rhsExpr ast.Expr) error {
	sym, ok := c.symbols[lhs.Name]
	if !ok {
		return fmt.Errorf("%s: undefined variable %q", lhs.Pos(), lhs.Name)
	}
	if sym.IsReadOnly {
		return fmt.Errorf("%s: %s is a read-only guard — writes are not allowed (acquire with Lock() instead of LockRead() if you need to mutate)",
			lhs.Pos(), lhs.Name)
	}
	val, err := c.emitExpr(rhsExpr)
	if err != nil {
		return err
	}
	// If the variable is itself a borrow/pointer (sym.Elem set), `x = v`
	// means "write v through x to the pointee" — deref then store.
	// Otherwise it's an ordinary store into the variable's own slot.
	if sym.Elem != "" {
		val = c.convertInt(val, sym.Elem)
		ptr := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", ptr, sym.Ptr)
		fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", sym.Elem, val.Name, ptr)
		return nil
	}
	val = c.convertInt(val, sym.Type)
	fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", sym.Type, val.Name, sym.Ptr)
	return nil
}

func (c *funcCtx) emitFieldAssign(lhs *ast.SelectorExpr, rhsExpr ast.Expr) error {
	recvIdent, ok := lhs.X.(*ast.IdentExpr)
	if !ok {
		return fmt.Errorf("%s: field assignment target must be `var.field`", lhs.Pos())
	}
	sym, ok := c.symbols[recvIdent.Name]
	if !ok {
		return fmt.Errorf("%s: undefined identifier %q", lhs.Pos(), recvIdent.Name)
	}
	if sym.IsReadOnly {
		return fmt.Errorf("%s: %s is a read-only guard — field writes are not allowed (acquire with Lock() instead of LockRead() if you need to mutate)",
			lhs.Pos(), recvIdent.Name)
	}

	var typeName, baseAddr string
	switch {
	case sym.Elem != "" && strings.HasPrefix(sym.Elem, "%") && sym.Elem != "%string":
		// Borrow: load the borrowed pointer.
		ptr := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", ptr, sym.Ptr)
		baseAddr = ptr
		typeName = strings.TrimPrefix(sym.Elem, "%")
	case strings.HasPrefix(sym.Type, "%") && sym.Type != "%string":
		baseAddr = sym.Ptr
		typeName = strings.TrimPrefix(sym.Type, "%")
	default:
		return fmt.Errorf("%s: cannot assign field on non-struct type %s", lhs.Pos(), sym.Type)
	}

	info := c.e.structs[typeName]
	if info == nil {
		return fmt.Errorf("%s: %s is not a struct", lhs.Pos(), typeName)
	}
	idx, ok := info.Index[lhs.Sel]
	if !ok {
		return fmt.Errorf("%s: %s has no field %q", lhs.Pos(), typeName, lhs.Sel)
	}
	fieldT := c.e.llvmType(info.Fields[idx].Type)

	val, err := c.emitExpr(rhsExpr)
	if err != nil {
		return err
	}
	fp := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = getelementptr %%%s, ptr %s, i32 0, i32 %d\n",
		fp, typeName, baseAddr, idx)
	fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", fieldT, val.Name, fp)
	return nil
}

func (c *funcCtx) emitRet(s *ast.RetStmt) error {
	// A guard variable cannot be returned — the lock must release in
	// the scope that acquired it.
	for _, e := range s.Values {
		if id, ok := e.(*ast.IdentExpr); ok {
			if sym, ok := c.symbols[id.Name]; ok && sym.IsGuard {
				return fmt.Errorf("%s: %s is a mutex guard — it cannot be returned (the lock must release in the scope that acquired it)",
					e.Pos(), id.Name)
			}
		}
	}
	// Evaluate return values BEFORE running defers, so the result isn't
	// affected by deferred operations.
	values := make([]Value, 0, len(s.Values))
	for _, e := range s.Values {
		v, err := c.emitExpr(e)
		if err != nil {
			return err
		}
		values = append(values, v)
	}
	if err := c.emitDefers(); err != nil {
		return err
	}
	c.emitDrops()

	switch len(values) {
	case 0:
		switch {
		case c.isMain:
			c.body.WriteString("  ret i64 0\n")
		case c.retType == "void":
			c.body.WriteString("  ret void\n")
		default:
			fmt.Fprintf(&c.body, "  ret %s 0\n", c.retType)
		}
	case 1:
		// Single value: convert to retType if needed, then ret.
		// Special case: if the function returns a ptr and the source was
		// a borrow-typed variable, we already over-emitted (auto-deref).
		// Re-emit the same identifier without dereferencing.
		if c.retType == "ptr" {
			if id, ok := s.Values[0].(*ast.IdentExpr); ok {
				if sym, ok := c.symbols[id.Name]; ok {
					if sym.Elem != "" {
						// Borrow var: load the ptr without dereferencing.
						t := c.newTemp()
						fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", t, sym.Ptr)
						c.body.WriteString(fmt.Sprintf("  ret ptr %s\n", t))
						c.terminated = true
						return nil
					}
				}
			}
		}
		v := c.convertInt(values[0], c.retType)
		fmt.Fprintf(&c.body, "  ret %s %s\n", c.retType, v.Name)
	default:
		// Multi-return: build aggregate via insertvalue chain.
		// retType is like "{i64, i1}" — parse field types out for the inserts.
		fieldTypes := parseAggregateFields(c.retType)
		if len(fieldTypes) != len(values) {
			return fmt.Errorf("%s: function returns %d values but ret has %d",
				s.Pos(), len(fieldTypes), len(values))
		}
		prev := "zeroinitializer"
		for i, v := range values {
			vc := c.convertInt(v, fieldTypes[i])
			t := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = insertvalue %s %s, %s %s, %d\n",
				t, c.retType, prev, fieldTypes[i], vc.Name, i)
			prev = t
		}
		fmt.Fprintf(&c.body, "  ret %s %s\n", c.retType, prev)
	}
	c.terminated = true
	return nil
}

// parseAggregateFields splits "{i64, i1, ptr}" into ["i64", "i1", "ptr"].
// Handles only simple comma-separated types (no nested aggregates).
func parseAggregateFields(t string) []string {
	if len(t) < 2 || t[0] != '{' || t[len(t)-1] != '}' {
		return nil
	}
	inner := t[1 : len(t)-1]
	parts := strings.Split(inner, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		out = append(out, strings.TrimSpace(p))
	}
	return out
}

func (c *funcCtx) emitIf(s *ast.IfStmt) error {
	// Optional init clause: scope its bindings to the whole if/else chain.
	// We push an outer scope, emit the init, then pop after the chain so
	// any drops fire at the join point.
	hasInit := s.Init != nil
	if hasInit {
		c.pushScope()
		if err := c.emitStmt(s.Init); err != nil {
			return err
		}
	}
	condVal, err := c.emitExpr(s.Cond)
	if err != nil {
		return err
	}
	condVal = c.toBool(condVal)

	thenLbl := c.newLabel("if.then")
	endLbl := c.newLabel("if.end")
	elseLbl := endLbl
	if s.Else != nil {
		elseLbl = c.newLabel("if.else")
	}

	fmt.Fprintf(&c.body, "  br i1 %s, label %%%s, label %%%s\n", condVal.Name, thenLbl, elseLbl)
	c.terminated = true

	c.startBlock(thenLbl)
	c.pushScope()
	for _, stmt := range s.Then.Stmts {
		if err := c.emitStmt(stmt); err != nil {
			return err
		}
	}
	thenTerm := c.terminated
	if !thenTerm {
		c.popScope()
		fmt.Fprintf(&c.body, "  br label %%%s\n", endLbl)
		c.terminated = true
	} else {
		c.scopeDepth--
		c.discardDropsAbove(c.scopeDepth)
	}

	elseTerm := true
	if s.Else != nil {
		c.startBlock(elseLbl)
		c.pushScope()
		switch es := s.Else.(type) {
		case *ast.Block:
			for _, stmt := range es.Stmts {
				if err := c.emitStmt(stmt); err != nil {
					return err
				}
			}
		case *ast.IfStmt:
			if err := c.emitIf(es); err != nil {
				return err
			}
		}
		elseTerm = c.terminated
		if !elseTerm {
			c.popScope()
			fmt.Fprintf(&c.body, "  br label %%%s\n", endLbl)
			c.terminated = true
		} else {
			c.scopeDepth--
			c.discardDropsAbove(c.scopeDepth)
		}
	}

	endReachable := s.Else == nil || !thenTerm || !elseTerm
	if endReachable {
		c.startBlock(endLbl)
	}
	if hasInit {
		// Pop the init scope. If end is reachable, drops fire here; if
		// every branch terminated, the scope is gone and pending drops
		// were already discarded above.
		if endReachable {
			c.popScope()
		} else {
			c.scopeDepth--
			c.discardDropsAbove(c.scopeDepth)
		}
	}
	return nil
}

// emitRangeFor lowers `for i [, v] := range EXPR { body }` to a normal
// index-driven loop. Supported sources:
//   slice []T   → i = index (int), v = element of type T
//   string      → i = byte index (int), v = byte (i8)
//   map[K]V     → DEFERRED (needs runtime iterator)
//
// We synthesize an `i` counter and (if v is bound) load the element
// from the source on each iteration. Bindings are added to c.symbols
// and removed implicitly via block-scoped Drop machinery.
func (c *funcCtx) emitRangeFor(s *ast.ForStmt) error {
	src, err := c.emitExpr(s.RangeOver)
	if err != nil {
		return err
	}
	switch src.Type {
	case "%slice":
		return c.emitRangeOverSlice(s, src)
	case "%string":
		return c.emitRangeOverString(s, src)
	case "ptr":
		// Likely a map handle. Detect via the source identifier's symbol.
		if id, ok := s.RangeOver.(*ast.IdentExpr); ok {
			if sym, ok := c.symbols[id.Name]; ok && sym.IsMap {
				return fmt.Errorf("%s: range over map is not yet supported — index map values manually for now", s.Pos())
			}
		}
		return fmt.Errorf("%s: cannot range over value of type %s", s.Pos(), src.Type)
	}
	return fmt.Errorf("%s: cannot range over value of type %s — supported: slice, string", s.Pos(), src.Type)
}

func (c *funcCtx) emitRangeOverSlice(s *ast.ForStmt, src Value) error {
	// Element LLVM type — needed both to GEP into the backing buffer
	// and to declare the value binding. SliceElem on the Value carries
	// this from emitNewSlice / emitSliceLit; if missing, we can't iterate.
	elemLL := src.SliceElem
	if elemLL == "" {
		return fmt.Errorf("%s: range over slice: element type unknown (assign to a typed variable first)", s.Pos())
	}

	// Extract data ptr + len from the slice header into stable scratch
	// slots (the slice value itself is SSA-only; we re-load each iter).
	dataPtr := c.newTemp()
	lenVal := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = extractvalue %%slice %s, 0\n", dataPtr, src.Name)
	fmt.Fprintf(&c.body, "  %s = extractvalue %%slice %s, 1\n", lenVal, src.Name)

	// Index binding `i` — i64. Always allocated; the user may or may
	// not actually reference it but we need it for the loop counter.
	iName := s.RangeI
	if iName == "" || iName == "_" {
		iName = c.uniqueLocal("_range_i")
	}
	// Unique alloca name so multiple range loops with the same binding
	// name (e.g., two `for i, v := range x` loops in one function)
	// don't collide at the LLVM level.
	iPtr := "%" + c.uniqueLocal(iName) + ".addr"
	fmt.Fprintf(&c.body, "  %s = alloca i64\n", iPtr)
	fmt.Fprintf(&c.body, "  store i64 0, ptr %s\n", iPtr)
	c.symbols[iName] = symbol{Ptr: iPtr, Type: "i64", AstType: &ast.NamedType{Name: "int"}}

	// Value binding `v` (optional) — typed to the slice element.
	if s.RangeV != "" && s.RangeV != "_" {
		vPtr := "%" + c.uniqueLocal(s.RangeV) + ".addr"
		fmt.Fprintf(&c.body, "  %s = alloca %s\n", vPtr, elemLL)
		c.symbols[s.RangeV] = symbol{Ptr: vPtr, Type: elemLL}
	}

	condLbl := c.newLabel("range.cond")
	bodyLbl := c.newLabel("range.body")
	postLbl := c.newLabel("range.post")
	endLbl := c.newLabel("range.end")
	c.loops = append(c.loops, loopFrame{breakLbl: endLbl, continueLbl: postLbl, scopeDepth: c.scopeDepth})
	defer func() { c.loops = c.loops[:len(c.loops)-1] }()

	fmt.Fprintf(&c.body, "  br label %%%s\n", condLbl)
	c.terminated = true
	c.startBlock(condLbl)
	iCur := c.newTemp()
	cmp := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = load i64, ptr %s\n", iCur, iPtr)
	fmt.Fprintf(&c.body, "  %s = icmp slt i64 %s, %s\n", cmp, iCur, lenVal)
	fmt.Fprintf(&c.body, "  br i1 %s, label %%%s, label %%%s\n", cmp, bodyLbl, endLbl)
	c.terminated = true

	c.startBlock(bodyLbl)
	c.pushScope()
	// Load v = data[i] when the user bound it.
	if s.RangeV != "" && s.RangeV != "_" {
		gep := c.newTemp()
		ld := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = getelementptr %s, ptr %s, i64 %s\n", gep, elemLL, dataPtr, iCur)
		fmt.Fprintf(&c.body, "  %s = load %s, ptr %s\n", ld, elemLL, gep)
		fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", elemLL, ld, c.symbols[s.RangeV].Ptr)
	}
	for _, stmt := range s.Body.Stmts {
		if err := c.emitStmt(stmt); err != nil {
			return err
		}
	}
	if !c.terminated {
		c.popScope()
		fmt.Fprintf(&c.body, "  br label %%%s\n", postLbl)
		c.terminated = true
	} else {
		c.scopeDepth--
		c.discardDropsAbove(c.scopeDepth)
	}

	c.startBlock(postLbl)
	iNew := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = load i64, ptr %s\n", iNew, iPtr)
	iInc := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = add i64 %s, 1\n", iInc, iNew)
	fmt.Fprintf(&c.body, "  store i64 %s, ptr %s\n", iInc, iPtr)
	fmt.Fprintf(&c.body, "  br label %%%s\n", condLbl)
	c.terminated = true

	c.startBlock(endLbl)
	return nil
}

func (c *funcCtx) emitRangeOverString(s *ast.ForStmt, src Value) error {
	// %string = {ptr data, i64 len}. Same shape as slice-over-i8.
	dataPtr := c.newTemp()
	lenVal := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 0\n", dataPtr, src.Name)
	fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 1\n", lenVal, src.Name)

	iName := s.RangeI
	if iName == "" || iName == "_" {
		iName = c.uniqueLocal("_range_i")
	}
	// Unique alloca name so multiple range loops with the same binding
	// name (e.g., two `for i, v := range x` loops in one function)
	// don't collide at the LLVM level.
	iPtr := "%" + c.uniqueLocal(iName) + ".addr"
	fmt.Fprintf(&c.body, "  %s = alloca i64\n", iPtr)
	fmt.Fprintf(&c.body, "  store i64 0, ptr %s\n", iPtr)
	c.symbols[iName] = symbol{Ptr: iPtr, Type: "i64", AstType: &ast.NamedType{Name: "int"}}

	if s.RangeV != "" && s.RangeV != "_" {
		vPtr := "%" + c.uniqueLocal(s.RangeV) + ".addr"
		fmt.Fprintf(&c.body, "  %s = alloca i8\n", vPtr)
		c.symbols[s.RangeV] = symbol{Ptr: vPtr, Type: "i8", AstType: &ast.NamedType{Name: "byte"}}
	}

	condLbl := c.newLabel("range.cond")
	bodyLbl := c.newLabel("range.body")
	postLbl := c.newLabel("range.post")
	endLbl := c.newLabel("range.end")
	c.loops = append(c.loops, loopFrame{breakLbl: endLbl, continueLbl: postLbl, scopeDepth: c.scopeDepth})
	defer func() { c.loops = c.loops[:len(c.loops)-1] }()

	fmt.Fprintf(&c.body, "  br label %%%s\n", condLbl)
	c.terminated = true
	c.startBlock(condLbl)
	iCur := c.newTemp()
	cmp := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = load i64, ptr %s\n", iCur, iPtr)
	fmt.Fprintf(&c.body, "  %s = icmp slt i64 %s, %s\n", cmp, iCur, lenVal)
	fmt.Fprintf(&c.body, "  br i1 %s, label %%%s, label %%%s\n", cmp, bodyLbl, endLbl)
	c.terminated = true

	c.startBlock(bodyLbl)
	c.pushScope()
	if s.RangeV != "" && s.RangeV != "_" {
		gep := c.newTemp()
		ld := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = getelementptr i8, ptr %s, i64 %s\n", gep, dataPtr, iCur)
		fmt.Fprintf(&c.body, "  %s = load i8, ptr %s\n", ld, gep)
		fmt.Fprintf(&c.body, "  store i8 %s, ptr %s\n", ld, c.symbols[s.RangeV].Ptr)
	}
	for _, stmt := range s.Body.Stmts {
		if err := c.emitStmt(stmt); err != nil {
			return err
		}
	}
	if !c.terminated {
		c.popScope()
		fmt.Fprintf(&c.body, "  br label %%%s\n", postLbl)
		c.terminated = true
	} else {
		c.scopeDepth--
		c.discardDropsAbove(c.scopeDepth)
	}

	c.startBlock(postLbl)
	iNew := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = load i64, ptr %s\n", iNew, iPtr)
	iInc := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = add i64 %s, 1\n", iInc, iNew)
	fmt.Fprintf(&c.body, "  store i64 %s, ptr %s\n", iInc, iPtr)
	fmt.Fprintf(&c.body, "  br label %%%s\n", condLbl)
	c.terminated = true

	c.startBlock(endLbl)
	return nil
}

// uniqueLocal returns a fresh local symbol name with the given prefix.
func (c *funcCtx) uniqueLocal(prefix string) string {
	n := c.nextTmp
	c.nextTmp++
	return fmt.Sprintf("%s.%d", prefix, n)
}

// allocaName picks an LLVM-level alloca name for a source identifier,
// uniquifying if the same name was already used in this function (e.g.
// two sequential `for i := 0; i < N; i++` loops in the same body would
// both want `%i.addr`).
func (c *funcCtx) allocaName(srcName string) string {
	base := srcName + ".addr"
	if c.usedAddrs == nil {
		c.usedAddrs = make(map[string]int)
	}
	n := c.usedAddrs[base]
	c.usedAddrs[base] = n + 1
	if n == 0 {
		return base
	}
	return fmt.Sprintf("%s.%d", base, n)
}

func (c *funcCtx) emitFor(s *ast.ForStmt) error {
	if s.RangeOver != nil {
		return c.emitRangeFor(s)
	}
	if s.Init != nil {
		if err := c.emitStmt(s.Init); err != nil {
			return err
		}
	}

	condLbl := c.newLabel("for.cond")
	bodyLbl := c.newLabel("for.body")
	postLbl := condLbl
	if s.Post != nil {
		postLbl = c.newLabel("for.post")
	} else if s.Cond == nil {
		// Infinite loop: no cond block; fall-through back to body.
		postLbl = bodyLbl
	}
	endLbl := c.newLabel("for.end")

	// Make break/continue inside the body target this loop. Record the
	// current scopeDepth so cleanup on break/continue knows where to stop.
	c.loops = append(c.loops, loopFrame{breakLbl: endLbl, continueLbl: postLbl, scopeDepth: c.scopeDepth})
	defer func() { c.loops = c.loops[:len(c.loops)-1] }()

	if s.Cond != nil {
		fmt.Fprintf(&c.body, "  br label %%%s\n", condLbl)
		c.terminated = true

		c.startBlock(condLbl)
		condVal, err := c.emitExpr(s.Cond)
		if err != nil {
			return err
		}
		condVal = c.toBool(condVal)
		fmt.Fprintf(&c.body, "  br i1 %s, label %%%s, label %%%s\n", condVal.Name, bodyLbl, endLbl)
		c.terminated = true
	} else {
		fmt.Fprintf(&c.body, "  br label %%%s\n", bodyLbl)
		c.terminated = true
	}

	c.startBlock(bodyLbl)
	c.pushScope()
	for _, stmt := range s.Body.Stmts {
		if err := c.emitStmt(stmt); err != nil {
			return err
		}
	}
	if !c.terminated {
		c.popScope()
		fmt.Fprintf(&c.body, "  br label %%%s\n", postLbl)
		c.terminated = true
	} else {
		// Body ended with an early exit (break/continue/ret) that already
		// emitted scope cleanups inline. Drop the scope marker and trim
		// the now-unreachable entries so a later popScope can't mis-fire them.
		c.scopeDepth--
		c.discardDropsAbove(c.scopeDepth)
	}

	if s.Post != nil {
		c.startBlock(postLbl)
		if err := c.emitStmt(s.Post); err != nil {
			return err
		}
		target := condLbl
		if s.Cond == nil {
			target = bodyLbl
		}
		fmt.Fprintf(&c.body, "  br label %%%s\n", target)
		c.terminated = true
	}

	// Always start the end block so `break` has a valid target and any
	// statements after the for-loop land in a fresh basic block.
	c.startBlock(endLbl)
	return nil
}

// ---------------------------------------------------------------------
// Expressions — produce a typed Value.
// ---------------------------------------------------------------------

func (c *funcCtx) emitExpr(e ast.Expr) (Value, error) {
	switch ex := e.(type) {
	case *ast.IntLit:
		return Value{Name: fmt.Sprintf("%d", ex.Value), Type: "i64"}, nil
	case *ast.FloatLit:
		// LLVM accepts decimal float literals directly. The type is
		// inferred at the assignment / call site via convertInt — for now
		// default to `double` (LLVM's 64-bit float, matching volt's
		// `float` / `float64`).
		return Value{Name: ex.Text, Type: "double"}, nil
	case *ast.BoolLit:
		if ex.Value {
			return Value{Name: "1", Type: "i1"}, nil
		}
		return Value{Name: "0", Type: "i1"}, nil
	case *ast.NilLit:
		return Value{Name: "null", Type: "ptr"}, nil
	case *ast.StringLit:
		return c.emitStringLit(ex)
	case *ast.IdentExpr:
		return c.emitIdent(ex)
	case *ast.SelectorExpr:
		return c.emitFieldAccess(ex)
	case *ast.UnaryExpr:
		return c.emitUnary(ex)
	case *ast.BinaryExpr:
		return c.emitBinary(ex)
	case *ast.CallExpr:
		return c.emitCall(ex)
	case *ast.NewExpr:
		return c.emitNew(ex)
	case *ast.SliceLit:
		return c.emitSliceLit(ex)
	case *ast.IndexExpr:
		return c.emitIndex(ex)
	case *ast.FuncLit:
		return c.emitFuncLit(ex)
	}
	return Value{}, fmt.Errorf("%s: unsupported expression %T", e.Pos(), e)
}

func (c *funcCtx) emitSliceLit(ex *ast.SliceLit) (Value, error) {
	elemT := c.e.llvmType(ex.Elem)
	n := len(ex.Elems)
	// Allocate stack array, fill, then build slice header pointing at it.
	arr := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = alloca [%d x %s]\n", arr, n, elemT)
	for i, e := range ex.Elems {
		v, err := c.emitExpr(e)
		if err != nil {
			return Value{}, err
		}
		fp := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = getelementptr [%d x %s], ptr %s, i32 0, i32 %d\n",
			fp, n, elemT, arr, i)
		fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", elemT, v.Name, fp)
	}
	t1 := c.newTemp()
	t2 := c.newTemp()
	t3 := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = insertvalue %%slice zeroinitializer, ptr %s, 0\n", t1, arr)
	fmt.Fprintf(&c.body, "  %s = insertvalue %%slice %s, i64 %d, 1\n", t2, t1, n)
	fmt.Fprintf(&c.body, "  %s = insertvalue %%slice %s, i64 %d, 2\n", t3, t2, n)
	return Value{Name: t3, Type: "%slice", SliceElem: elemT}, nil
}

func (c *funcCtx) emitIndex(ex *ast.IndexExpr) (Value, error) {
	// Map[key] lookup if X is a map-typed variable.
	if id, ok := ex.X.(*ast.IdentExpr); ok {
		if sym, ok := c.symbols[id.Name]; ok && sym.IsMap {
			return c.emitMapGet(sym, ex.Index, ex.Pos())
		}
	}

	xv, err := c.emitExpr(ex.X)
	if err != nil {
		return Value{}, err
	}
	if xv.Type != "%slice" {
		return Value{}, fmt.Errorf("%s: indexing requires a slice, got %s", ex.Pos(), xv.Type)
	}
	if xv.SliceElem == "" {
		return Value{}, fmt.Errorf("%s: slice element type unknown — was it created via []T{...}?", ex.Pos())
	}
	idx, err := c.emitExpr(ex.Index)
	if err != nil {
		return Value{}, err
	}
	ptr := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = extractvalue %%slice %s, 0\n", ptr, xv.Name)
	fp := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = getelementptr %s, ptr %s, i64 %s\n", fp, xv.SliceElem, ptr, idx.Name)
	v := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = load %s, ptr %s\n", v, xv.SliceElem, fp)
	return Value{Name: v, Type: xv.SliceElem}, nil
}

// emitFieldAccess handles `X.field` when X is a value (not a package name).
// If X is a package name (qualified function reference outside a Call), it's
// an error in v0.4 — function values aren't supported yet.
func (c *funcCtx) emitFieldAccess(ex *ast.SelectorExpr) (Value, error) {
	if id, ok := ex.X.(*ast.IdentExpr); ok && c.e.imported[id.Name] {
		// time.X — compile-time constants for duration units.
		if id.Name == "time" {
			var lit int64
			switch ex.Sel {
			case "Nanosecond":
				lit = 1
			case "Microsecond":
				lit = 1000
			case "Millisecond":
				lit = 1000000
			case "Second":
				lit = 1000000000
			default:
				return Value{}, fmt.Errorf("%s: time.%s not supported as a value", ex.Pos(), ex.Sel)
			}
			t := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = add i64 0, %d\n", t, lit)
			return Value{Name: t, Type: "i64"}, nil
		}
		return Value{}, fmt.Errorf("%s: %s.%s referenced as a value (only call form supported)",
			ex.Pos(), id.Name, ex.Sel)
	}

	xv, err := c.emitExpr(ex.X)
	if err != nil {
		return Value{}, err
	}
	// xv.Type is something like "%Counter". Strip the leading '%' to look up.
	typeName := strings.TrimPrefix(xv.Type, "%")
	info, ok := c.e.structs[typeName]
	if !ok {
		return Value{}, fmt.Errorf("%s: %s is not a struct (type %s)", ex.Pos(), ex.Sel, xv.Type)
	}
	idx, ok := info.Index[ex.Sel]
	if !ok {
		return Value{}, fmt.Errorf("%s: %s has no field %q", ex.Pos(), typeName, ex.Sel)
	}
	fieldT := c.e.llvmType(info.Fields[idx].Type)
	t := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = extractvalue %s %s, %d\n", t, xv.Type, xv.Name, idx)
	return Value{Name: t, Type: fieldT}, nil
}

// emitCompositeStruct lowers a struct composite literal — used by both
// `new T{...}` and the bare `T{...}` shorthand at primary positions.
// Returns the populated %T value.
func (c *funcCtx) emitCompositeStruct(pos lex.Pos, typeName string, pairs []*ast.KeyValuePair) (Value, error) {
	info, ok := c.e.structs[typeName]
	if !ok {
		return Value{}, fmt.Errorf("%s: unknown type %s", pos, typeName)
	}
	llT := "%" + typeName
	provided := make(map[string]ast.Expr)
	for _, kv := range pairs {
		provided[kv.Key] = kv.Value
	}
	prev := "zeroinitializer"
	for i, f := range info.Fields {
		fieldT := c.e.llvmType(f.Type)
		var v Value
		if expr, ok := provided[f.Name]; ok {
			val, err := c.emitExpr(expr)
			if err != nil {
				return Value{}, err
			}
			v = val
		} else {
			v = zeroValue(fieldT)
		}
		v = c.convertInt(v, fieldT)
		t := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = insertvalue %s %s, %s %s, %d\n",
			t, llT, prev, fieldT, v.Name, i)
		prev = t
	}
	return Value{Name: prev, Type: llT}, nil
}

// emitNew lowers `new T{...}` (struct composite literal) or `new T()` to
// an SSA struct value built via insertvalue. The result is an owned T —
// the caller (typically a var declaration) puts it in storage.
func (c *funcCtx) emitNew(ex *ast.NewExpr) (Value, error) {
	if ex.Type == nil {
		return Value{}, fmt.Errorf("%s: short-form `new` requires an LHS type annotation (e.g. `var x T = new(...)`)", ex.Pos())
	}

	switch t := ex.Type.(type) {
	case *ast.MapType:
		return c.emitNewMap(ex, t)
	case *ast.ChanType:
		return c.emitNewChan(ex)
	case *ast.SliceType:
		return c.emitNewSlice(ex, t)
	case *ast.NamedType:
		return c.emitNewStruct(ex, t)
	case *ast.AtomicType:
		return c.emitNewAtomic(ex, t.Elem)
	case *ast.MutexType:
		return c.emitNewSyncInline(ex, t.Elem, "volt_mutex_new")
	case *ast.RwMutexType:
		return c.emitNewSyncInline(ex, t.Elem, "volt_rwmutex_new")
	case *ast.WaitgroupType:
		return c.emitNewWaitgroup(ex)
	case *ast.OnceType:
		return c.emitNewOnce(ex)
	}
	return Value{}, fmt.Errorf("%s: `new` does not support type %T", ex.Pos(), ex.Type)
}

// emitNewSyncInline lowers the braces-form initializer for any inline-
// payload sync wrapper (mutex T, rwmutex T). It evaluates the initial
// T value, stashes it on the stack, and calls the named ctor with
// sizeof(T) + a pointer to the initial bytes. The runtime copies the
// bytes into the wrapper's inline payload region; Lock/LockRead later
// return a pointer into it.
//
// Conforms to the unified `new (SIZE) {INITIATOR_LIST}` rule: mutex
// and rwmutex have no size (each wraps exactly one T), so parens are
// rejected. Init shape depends on the payload kind:
//
//	primitive T  →  new{}            (zero) or new{value}    (positional)
//	struct T     →  new{}            (zero) or new{f1: v1, ...} (keyed)
func (c *funcCtx) emitNewSyncInline(ex *ast.NewExpr, elem ast.Type, ctor string) (Value, error) {
	if ex.HasParens {
		return Value{}, fmt.Errorf("%s: this sync wrapper has no size — use `new{...}` for the initial value", ex.Pos())
	}
	elemT := c.e.llvmType(elem)
	isStructPayload := false
	if nt, ok := elem.(*ast.NamedType); ok {
		if _, isStruct := c.e.structs[nt.Name]; isStruct {
			isStructPayload = true
		}
	}

	// Build the initial T value as an SSA register.
	var initVal Value
	switch {
	case isStructPayload:
		if len(ex.SliceElems) > 0 || len(ex.MapEntries) > 0 {
			return Value{}, fmt.Errorf("%s: struct-payload init uses `name: value` field syntax", ex.Pos())
		}
		nt := elem.(*ast.NamedType)
		v, err := c.emitCompositeStruct(ex.Pos(), nt.Name, ex.Pairs)
		if err != nil {
			return Value{}, err
		}
		initVal = v
	default: // primitive payload
		if len(ex.Pairs) > 0 || len(ex.MapEntries) > 0 {
			return Value{}, fmt.Errorf("%s: primitive-payload init takes a single positional value, not `name:` or `key: value`", ex.Pos())
		}
		if len(ex.SliceElems) > 1 {
			return Value{}, fmt.Errorf("%s: sync wrapper holds exactly one value — got %d initiators", ex.Pos(), len(ex.SliceElems))
		}
		if len(ex.SliceElems) == 1 {
			v, err := c.emitExpr(ex.SliceElems[0])
			if err != nil {
				return Value{}, err
			}
			initVal = c.convertInt(v, elemT)
		} else {
			initVal = zeroValue(elemT)
		}
	}

	// Stack-allocate a slot for the initial value, store it, then pass
	// the slot pointer + sizeof(T) to the runtime. The sizeof(T) trick
	// is `getelementptr T, ptr null, i32 1; ptrtoint to i64` — LLVM
	// folds that to the layout-correct constant.
	slot := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = alloca %s\n", slot, elemT)
	fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", elemT, initVal.Name, slot)

	szPtr := c.newTemp()
	szInt := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = getelementptr %s, ptr null, i32 1\n", szPtr, elemT)
	fmt.Fprintf(&c.body, "  %s = ptrtoint ptr %s to i64\n", szInt, szPtr)

	c.e.ensureDeclare(fmt.Sprintf("declare ptr @%s(i64, ptr)", ctor))
	t := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call ptr @%s(i64 %s, ptr %s)\n", t, ctor, szInt, slot)
	return Value{Name: t, Type: "ptr"}, nil
}

// atomicSuffix maps a supported atomic element type to the runtime
// function-name suffix and the LLVM scalar used to carry the value
// across the ABI. Returns ok=false for unsupported widths.
//
// Supported: int / int64 (i64, no suffix), int32 (i32), int16 (i16),
// int8 / byte (i8), bool (carried as i8 — atomicity on i1 is fiddly
// and most hardware treats single-bit atomics as a byte op anyway),
// and ptr (no Add).
func atomicSuffix(elemT string) (suffix, llT string, ok bool) {
	switch elemT {
	case "i64":
		return "", "i64", true
	case "i32":
		return "_i32", "i32", true
	case "i16":
		return "_i16", "i16", true
	case "i8":
		return "_i8", "i8", true
	case "i1":
		// bool atomics carry over the ABI as i8 (truncate/extend at the
		// boundaries) — the runtime function name is _bool.
		return "_bool", "i8", true
	case "ptr":
		return "_ptr", "ptr", true
	}
	return "", "", false
}

// emitNewWaitgroup lowers `new()` (start at 0) or `new(N)` (start at
// N) for a waitgroup. Initial count goes in parens — it's a count,
// not a payload — so braces are rejected. The default count is 0
// because the typical pattern is wg.Add(1) per worker as they spawn.
func (c *funcCtx) emitNewWaitgroup(ex *ast.NewExpr) (Value, error) {
	if ex.HasBraces {
		return Value{}, fmt.Errorf("%s: waitgroup takes only `new()` or `new(N)` (initial count), not `{...}`", ex.Pos())
	}
	var initVal Value
	if len(ex.SizeArgs) > 0 {
		v, err := c.emitExpr(ex.SizeArgs[0])
		if err != nil {
			return Value{}, err
		}
		initVal = c.convertInt(v, "i64")
	} else {
		initVal = Value{Name: "0", Type: "i64"}
	}
	c.e.ensureDeclare("declare ptr @volt_waitgroup_new(i64)")
	t := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call ptr @volt_waitgroup_new(i64 %s)\n", t, initVal.Name)
	return Value{Name: t, Type: "ptr"}, nil
}

// emitNewOnce lowers `new()` for a once primitive. No size, no init
// list — it's just a coordination handle.
func (c *funcCtx) emitNewOnce(ex *ast.NewExpr) (Value, error) {
	if ex.HasBraces {
		return Value{}, fmt.Errorf("%s: once takes only `new()`, not `{...}`", ex.Pos())
	}
	if len(ex.SizeArgs) > 0 {
		return Value{}, fmt.Errorf("%s: once has no size — use bare `new()`", ex.Pos())
	}
	c.e.ensureDeclare("declare ptr @volt_once_new()")
	t := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call ptr @volt_once_new()\n", t)
	return Value{Name: t, Type: "ptr"}, nil
}

// emitNewAtomic lowers `new{}` (zero) or `new{initial}` (single
// positional initiator) for an atomic T. The runtime ctor is picked
// per width (volt_atomic_new, volt_atomic_new_i32, volt_atomic_new_ptr)
// so the initial value's LLVM type matches the storage layout.
//
// Conforms to the unified `new (SIZE) {INITIATOR_LIST}` rule: atomic
// has no size (it wraps exactly one T), so parens are rejected.
func (c *funcCtx) emitNewAtomic(ex *ast.NewExpr, elem ast.Type) (Value, error) {
	if ex.HasParens {
		return Value{}, fmt.Errorf("%s: atomic has no size — use `new{initial}` or `new{}` for zero", ex.Pos())
	}
	if len(ex.Pairs) > 0 || len(ex.MapEntries) > 0 {
		return Value{}, fmt.Errorf("%s: atomic initiator list takes a single positional value, not `name:` or `key: value`", ex.Pos())
	}
	if len(ex.SliceElems) > 1 {
		return Value{}, fmt.Errorf("%s: atomic wraps exactly one value — got %d initiators", ex.Pos(), len(ex.SliceElems))
	}
	elemT := c.e.llvmType(elem)
	suffix, llT, ok := atomicSuffix(elemT)
	if !ok {
		return Value{}, fmt.Errorf("%s: atomic %s is not supported (only int, int32, ptr in v0.5)", ex.Pos(), elemT)
	}

	var initVal Value
	if len(ex.SliceElems) == 1 {
		v, err := c.emitExpr(ex.SliceElems[0])
		if err != nil {
			return Value{}, err
		}
		if llT == "ptr" {
			initVal = v
		} else {
			initVal = c.convertInt(v, llT)
		}
	} else {
		initVal = zeroValue(llT)
	}

	ctor := "volt_atomic_new" + suffix
	c.e.ensureDeclare(fmt.Sprintf("declare ptr @%s(%s)", ctor, llT))
	t := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call ptr @%s(%s %s)\n", t, ctor, llT, initVal.Name)
	return Value{Name: t, Type: "ptr"}, nil
}

// emitNewMap lowers `new map[K]V{}`, `new map[K]V(cap)`, `new map[K]V{k:v}`,
// `new map[K]V(cap){k:v}`. The `(cap)` arg is currently advisory — the
// runtime map ignores it (always allocates the default bucket count).
//
// The bare form `new map[K]V` (no parens, no braces) is intentionally
// not accepted — write `new map[K]V{}` or the short form `new{}` instead.
func (c *funcCtx) emitNewMap(ex *ast.NewExpr, _ *ast.MapType) (Value, error) {
	if !ex.HasParens && !ex.HasBraces {
		return Value{}, fmt.Errorf("%s: bare `new map[K]V` is not allowed; use `new map[K]V{}` for an empty map", ex.Pos())
	}
	if len(ex.Pairs) > 0 || len(ex.SliceElems) > 0 {
		return Value{}, fmt.Errorf("%s: map composite literal uses `key: value` entries (not field names or bare expressions)", ex.Pos())
	}
	c.e.ensureDeclare("declare ptr @volt_map_new()")
	mapTmp := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call ptr @volt_map_new()\n", mapTmp)

	for _, ent := range ex.MapEntries {
		k, err := c.emitExpr(ent.Key)
		if err != nil {
			return Value{}, err
		}
		if k.Type != "%string" {
			return Value{}, fmt.Errorf("%s: map key must be a string in v0.5, got %s", ent.Pos(), k.Type)
		}
		v, err := c.emitExpr(ent.Value)
		if err != nil {
			return Value{}, err
		}
		v = c.convertInt(v, "i64")
		kp := c.newTemp()
		kl := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 0\n", kp, k.Name)
		fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 1\n", kl, k.Name)
		c.e.ensureDeclare("declare void @volt_map_set(ptr, ptr, i64, i64)")
		fmt.Fprintf(&c.body, "  call void @volt_map_set(ptr %s, ptr %s, i64 %s, i64 %s)\n",
			mapTmp, kp, kl, v.Name)
	}
	return Value{Name: mapTmp, Type: "ptr"}, nil
}

// emitNewChan lowers `new chan T` and `new chan T(capacity)`.
func (c *funcCtx) emitNewChan(ex *ast.NewExpr) (Value, error) {
	if ex.HasBraces {
		return Value{}, fmt.Errorf("%s: `new chan T` does not take `{}` init; use `new chan T(cap)`", ex.Pos())
	}
	var capVal Value
	if len(ex.SizeArgs) > 0 {
		v, err := c.emitExpr(ex.SizeArgs[0])
		if err != nil {
			return Value{}, err
		}
		capVal = c.convertInt(v, "i64")
	} else {
		capVal = Value{Name: "0", Type: "i64"}
	}
	c.e.ensureDeclare("declare ptr @volt_chan_new(i64)")
	t := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call ptr @volt_chan_new(i64 %s)\n", t, capVal.Name)
	return Value{Name: t, Type: "ptr"}, nil
}

// emitNewSlice lowers `new []T(N)`, `new []T{e1, e2}`, `new []T(N){e1, e2}`.
// Semantics: length = N if (...) present, else len(SliceElems). First
// len(SliceElems) slots are initialized; the rest are zero.
func (c *funcCtx) emitNewSlice(ex *ast.NewExpr, st *ast.SliceType) (Value, error) {
	if len(ex.Pairs) > 0 || len(ex.MapEntries) > 0 {
		return Value{}, fmt.Errorf("%s: slice composite literal takes positional elements, not `name:` or `key: value`", ex.Pos())
	}
	elemLL := c.e.llvmType(st.Elem)

	var lenVal Value
	if len(ex.SizeArgs) > 0 {
		v, err := c.emitExpr(ex.SizeArgs[0])
		if err != nil {
			return Value{}, err
		}
		lenVal = c.convertInt(v, "i64")
	} else {
		lenVal = Value{Name: fmt.Sprintf("%d", len(ex.SliceElems)), Type: "i64"}
	}

	// Element-size bytes for the allocation.
	elemSize := llvmTypeBytes(elemLL)
	bytesTmp := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = mul i64 %s, %d\n", bytesTmp, lenVal.Name, elemSize)

	c.e.ensureDeclare("declare ptr @volt_alloc(i64)")
	dataTmp := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call ptr @volt_alloc(i64 %s)\n", dataTmp, bytesTmp)

	// Initialize each provided element.
	for i, el := range ex.SliceElems {
		v, err := c.emitExpr(el)
		if err != nil {
			return Value{}, err
		}
		v = c.convertInt(v, elemLL)
		gepTmp := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = getelementptr %s, ptr %s, i64 %d\n", gepTmp, elemLL, dataTmp, i)
		fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", elemLL, v.Name, gepTmp)
	}

	// Build the {ptr, len, cap} slice value. cap == len at construction;
	// append() grows it when more elements are added later.
	s1 := c.newTemp()
	s2 := c.newTemp()
	s3 := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = insertvalue %%slice zeroinitializer, ptr %s, 0\n", s1, dataTmp)
	fmt.Fprintf(&c.body, "  %s = insertvalue %%slice %s, i64 %s, 1\n", s2, s1, lenVal.Name)
	fmt.Fprintf(&c.body, "  %s = insertvalue %%slice %s, i64 %s, 2\n", s3, s2, lenVal.Name)
	return Value{Name: s3, Type: "%slice", SliceElem: elemLL}, nil
}

// emitNewStruct lowers `new T{field: value, ...}` or `new T{}` for a
// named struct type.
func (c *funcCtx) emitNewStruct(ex *ast.NewExpr, nt *ast.NamedType) (Value, error) {
	if len(ex.MapEntries) > 0 || len(ex.SliceElems) > 0 {
		return Value{}, fmt.Errorf("%s: struct composite literal uses `name: value` field syntax", ex.Pos())
	}
	if len(ex.SizeArgs) > 0 {
		return Value{}, fmt.Errorf("%s: struct `new` does not take a size argument", ex.Pos())
	}
	info, ok := c.e.structs[nt.Name]
	if !ok {
		return Value{}, fmt.Errorf("%s: unknown type %s", ex.Pos(), nt.Name)
	}
	llT := "%" + nt.Name

	provided := make(map[string]ast.Expr)
	for _, kv := range ex.Pairs {
		provided[kv.Key] = kv.Value
	}

	prev := "zeroinitializer"
	for i, f := range info.Fields {
		fieldT := c.e.llvmType(f.Type)
		var v Value
		if expr, ok := provided[f.Name]; ok {
			val, err := c.emitExpr(expr)
			if err != nil {
				return Value{}, err
			}
			v = val
		} else {
			v = zeroValue(fieldT)
		}
		v = c.convertInt(v, fieldT)
		t := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = insertvalue %s %s, %s %s, %d\n",
			t, llT, prev, fieldT, v.Name, i)
		prev = t
	}
	return Value{Name: prev, Type: llT}, nil
}

// llvmTypeBytes returns the size in bytes of a primitive LLVM type.
// (Aggregates are not currently used as slice element types in v0.5.)
func llvmTypeBytes(llT string) int {
	switch llT {
	case "i1", "i8":
		return 1
	case "i16":
		return 2
	case "i32", "float":
		return 4
	default:
		// i64, double, ptr, %string, %slice — treat as 8 bytes for the
		// element-size calculation. %string and %slice are wider in
		// practice (16 bytes) but slices-of-strings aren't in scope here.
		return 8
	}
}

func zeroValue(llvmType string) Value {
	switch llvmType {
	case "i1":
		return Value{Name: "0", Type: "i1"}
	case "i8", "i16", "i32", "i64":
		return Value{Name: "0", Type: llvmType}
	case "double", "float":
		return Value{Name: "0.0", Type: llvmType}
	case "ptr":
		return Value{Name: "null", Type: "ptr"}
	case "%string":
		return Value{Name: "zeroinitializer", Type: "%string"}
	}
	return Value{Name: "zeroinitializer", Type: llvmType}
}

// isLiteral reports whether v's name is a constant (not %sym or @sym).
func isLiteral(name string) bool {
	return name != "" && name[0] != '%' && name[0] != '@'
}

func intBitSize(t string) int {
	switch t {
	case "i1":
		return 1
	case "i8":
		return 8
	case "i16":
		return 16
	case "i32":
		return 32
	case "i64":
		return 64
	}
	return 0
}

// convertInt converts an integer value to targetType, emitting trunc/sext
// for SSA values or just relabeling literals. Returns v unchanged if either
// side isn't an integer type.
func (c *funcCtx) convertInt(v Value, targetType string) Value {
	if v.Type == targetType {
		return v
	}
	// Float-to-float — LLVM requires fpext/fptrunc when widths differ.
	if isFloatLLVM(v.Type) && isFloatLLVM(targetType) {
		t := c.newTemp()
		op := "fpext"
		if floatBitSize(v.Type) > floatBitSize(targetType) {
			op = "fptrunc"
		}
		fmt.Fprintf(&c.body, "  %s = %s %s %s to %s\n", t, op, v.Type, v.Name, targetType)
		return Value{Name: t, Type: targetType}
	}
	src := intBitSize(v.Type)
	dst := intBitSize(targetType)
	if src == 0 || dst == 0 {
		return v
	}
	if isLiteral(v.Name) {
		// Integer literals are typeless in LLVM IR — just re-label.
		return Value{Name: v.Name, Type: targetType}
	}
	if src == dst {
		return Value{Name: v.Name, Type: targetType}
	}
	t := c.newTemp()
	op := "sext"
	if src > dst {
		op = "trunc"
	}
	fmt.Fprintf(&c.body, "  %s = %s %s %s to %s\n", t, op, v.Type, v.Name, targetType)
	return Value{Name: t, Type: targetType}
}

func isFloatLLVM(t string) bool {
	return t == "float" || t == "double"
}

func floatBitSize(t string) int {
	switch t {
	case "float":
		return 32
	case "double":
		return 64
	}
	return 0
}

func (c *funcCtx) emitStringLit(ex *ast.StringLit) (Value, error) {
	gname, glen := c.e.internString(ex.Text)
	t1 := c.newTemp()
	t2 := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = insertvalue %%string zeroinitializer, ptr %s, 0\n", t1, gname)
	fmt.Fprintf(&c.body, "  %s = insertvalue %%string %s, i64 %d, 1\n", t2, t1, glen)
	return Value{Name: t2, Type: "%string"}, nil
}

// emitFuncLit lowers a `fun(params) result { body }` expression to a
// %fn_value. Walks the body for free identifiers that resolve to
// enclosing-scope locals — those become captures, copied into a
// heap-allocated env struct. Bodies without captures get a null env.
//
// Captures move ownership: a non-Copy captured value is consumed at
// the literal site (subsequent use in the enclosing scope is a
// compile error). Capture of borrows (&T / *T) is rejected — the
// closure could outlive the borrowed storage.
func (c *funcCtx) emitFuncLit(ex *ast.FuncLit) (Value, error) {
	captures := c.collectCaptures(ex)
	ex.Captures = captures

	id := c.e.closureLitID
	c.e.closureLitID++
	bodySym := fmt.Sprintf("%s_$lit_%d", c.e.pkg, id)
	envTy := ""
	if len(captures) > 0 {
		envTy = fmt.Sprintf("%%env_$%d", id)
	}

	// Reject borrow captures up front (clearer error than a downstream
	// LLVM mismatch).
	for _, name := range captures {
		sym := c.symbols[name]
		if isBorrowOrPointerLLVM(sym) {
			return Value{}, fmt.Errorf("%s: closure cannot capture borrow / pointer variable %q — borrows are scope-bound and the closure may outlive them",
				ex.Pos(), name)
		}
	}

	// Emit the synthesized body function and (if non-empty) the env
	// struct type.
	if err := c.emitClosureBody(ex, bodySym, envTy, captures); err != nil {
		return Value{}, err
	}

	// At the literal site: build the env (heap-allocated if any
	// captures), then assemble the %fn_value.
	envPtr := "null"
	if envTy != "" {
		ep, err := c.emitEnvInit(ex.Pos(), envTy, captures)
		if err != nil {
			return Value{}, err
		}
		envPtr = ep
	}

	// Mark non-Copy captures as moved at the literal site.
	for _, name := range captures {
		sym := c.symbols[name]
		if !isLLVMTypeCopy(sym.Type) {
			// (Move tracking lives in the checker; codegen just records
			// the consumption by leaving the variable's storage intact.
			// The checker has already flagged subsequent uses for us.)
			_ = sym
		}
	}

	t1 := c.newTemp()
	t2 := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = insertvalue %%fn_value zeroinitializer, ptr @%s, 0\n", t1, bodySym)
	fmt.Fprintf(&c.body, "  %s = insertvalue %%fn_value %s, ptr %s, 1\n", t2, t1, envPtr)
	return Value{Name: t2, Type: "%fn_value"}, nil
}

// collectCaptures walks the literal's body and returns the names of
// free identifiers that resolve to locals of the enclosing function.
// Names declared inside the literal (its own params + locals) shadow
// outer bindings and are NOT captured.
//
// Result is in encounter order (stable across compilations) so the
// env struct layout matches the body's load order.
func (c *funcCtx) collectCaptures(ex *ast.FuncLit) []string {
	visible := make(map[string]bool, len(ex.Params))
	for _, p := range ex.Params {
		visible[p.Name] = true
	}
	seen := make(map[string]bool)
	var order []string
	add := func(name string) {
		if seen[name] {
			return
		}
		// Top-level functions/consts aren't captures — they're symbols
		// at link time. Top-level funcs aren't in c.symbols; consts
		// aren't either. Only outer-scope locals appear in c.symbols.
		if _, ok := c.symbols[name]; !ok {
			return
		}
		seen[name] = true
		order = append(order, name)
	}
	var walkE func(ast.Expr)
	var walkS func(ast.Stmt)
	walkE = func(e ast.Expr) {
		if e == nil {
			return
		}
		switch n := e.(type) {
		case *ast.IdentExpr:
			if !visible[n.Name] {
				add(n.Name)
			}
		case *ast.CallExpr:
			walkE(n.Fun)
			for _, a := range n.Args {
				walkE(a)
			}
		case *ast.BinaryExpr:
			walkE(n.X)
			walkE(n.Y)
		case *ast.UnaryExpr:
			walkE(n.X)
		case *ast.SelectorExpr:
			walkE(n.X)
		case *ast.IndexExpr:
			walkE(n.X)
			walkE(n.Index)
		case *ast.NewExpr:
			for _, a := range n.SizeArgs {
				walkE(a)
			}
			for _, kv := range n.Pairs {
				walkE(kv.Value)
			}
			for _, el := range n.SliceElems {
				walkE(el)
			}
			for _, me := range n.MapEntries {
				walkE(me.Key)
				walkE(me.Value)
			}
		case *ast.SliceLit:
			for _, el := range n.Elems {
				walkE(el)
			}
		case *ast.FuncLit:
			// Nested literal: anything it captures comes from OUR scope
			// (or further out). Recurse — but bindings declared inside
			// it shadow OUR visible set the same way.
			//
			// For correctness, we want: a name referenced inside the
			// nested literal that resolves to OUR outer scope should
			// count as captured by US too (because we need to capture
			// it to pass it down to the nested closure).
			inner := c.collectCaptures(n)
			for _, name := range inner {
				if !visible[name] {
					add(name)
				}
			}
		}
	}
	walkS = func(s ast.Stmt) {
		if s == nil {
			return
		}
		switch n := s.(type) {
		case *ast.VarStmt:
			walkE(n.Value)
			visible[n.Name] = true
		case *ast.MultiVarStmt:
			walkE(n.RHS)
			for _, nm := range n.Names {
				visible[nm] = true
			}
		case *ast.AssignStmt:
			walkE(n.LHS)
			walkE(n.RHS)
		case *ast.MultiAssignStmt:
			walkE(n.RHS)
			for _, lhs := range n.LHS {
				walkE(lhs)
			}
		case *ast.ExprStmt:
			walkE(n.Expr)
		case *ast.RetStmt:
			for _, v := range n.Values {
				walkE(v)
			}
		case *ast.IfStmt:
			if n.Init != nil {
				walkS(n.Init)
			}
			walkE(n.Cond)
			if n.Then != nil {
				for _, ss := range n.Then.Stmts {
					walkS(ss)
				}
			}
			if n.Else != nil {
				walkS(n.Else)
			}
		case *ast.ForStmt:
			if n.Init != nil {
				walkS(n.Init)
			}
			walkE(n.Cond)
			if n.Post != nil {
				walkS(n.Post)
			}
			if n.Body != nil {
				for _, ss := range n.Body.Stmts {
					walkS(ss)
				}
			}
		case *ast.Block:
			for _, ss := range n.Stmts {
				walkS(ss)
			}
		case *ast.SendStmt:
			walkE(n.Channel)
			walkE(n.Value)
		case *ast.RunStmt:
			if n.Call != nil {
				walkE(n.Call)
			}
		case *ast.SelectStmt:
			for _, cs := range n.Cases {
				if cs == nil {
					continue
				}
				walkE(cs.Channel)
				walkE(cs.SendValue)
				for _, nm := range cs.RecvNames {
					visible[nm] = true
				}
				for _, ss := range cs.Body {
					walkS(ss)
				}
			}
		case *ast.DeferStmt:
			if n.Call != nil {
				walkE(n.Call)
			}
		}
	}
	if ex.Body != nil {
		for _, s := range ex.Body.Stmts {
			walkS(s)
		}
	}
	return order
}

// emitClosureBody emits the LLVM definition for a synthesized closure
// body. Signature: `(ptr env, params...) -> result`. The body loads
// captures from env via GEP at entry, then runs the literal's body.
// If captures is non-empty, also emits the env struct type definition
// into the header.
func (c *funcCtx) emitClosureBody(ex *ast.FuncLit, bodySym, envTy string, captures []string) error {
	if envTy != "" {
		var fields []string
		for _, name := range captures {
			fields = append(fields, c.symbols[name].Type)
		}
		fmt.Fprintf(&c.e.header, "%s = type { %s }\n", envTy, strings.Join(fields, ", "))
	}

	// Build a child funcCtx that emits into trampolineDefs.
	child := &funcCtx{
		e:         c.e,
		symbols:   make(map[string]symbol),
		retType:   "void",
		isMain:    false,
		usedAddrs: make(map[string]int),
	}
	if len(ex.Results) > 0 {
		child.retType = c.e.llvmType(ex.Results[0])
	}

	// Function header.
	fmt.Fprintf(&child.body, "define internal %s @%s(ptr %%_env", child.retType, bodySym)
	for _, p := range ex.Params {
		pt := c.e.llvmType(p.Type)
		fmt.Fprintf(&child.body, ", %s %%%s", pt, p.Name)
	}
	child.body.WriteString(") {\nentry:\n")

	// Spill params into alloca slots so the existing emit paths work.
	for _, p := range ex.Params {
		pt := c.e.llvmType(p.Type)
		ptr := "%" + p.Name + ".addr"
		fmt.Fprintf(&child.body, "  %s = alloca %s\n", ptr, pt)
		fmt.Fprintf(&child.body, "  store %s %%%s, ptr %s\n", pt, p.Name, ptr)
		child.symbols[p.Name] = symbol{
			Ptr:       ptr,
			Type:      pt,
			Elem:      c.e.elemType(p.Type),
			SliceElem: c.e.sliceElemLLVM(p.Type),
			IsMap:     isMapType(p.Type),
			AstType:   p.Type,
		}
	}
	// Load captures from env into alloca slots that look like locals.
	for i, name := range captures {
		src := c.symbols[name]
		ptr := "%" + name + ".addr"
		fmt.Fprintf(&child.body, "  %s = alloca %s\n", ptr, src.Type)
		gp := child.newTemp()
		ld := child.newTemp()
		fmt.Fprintf(&child.body, "  %s = getelementptr %s, ptr %%_env, i32 0, i32 %d\n", gp, envTy, i)
		fmt.Fprintf(&child.body, "  %s = load %s, ptr %s\n", ld, src.Type, gp)
		fmt.Fprintf(&child.body, "  store %s %s, ptr %s\n", src.Type, ld, ptr)
		child.symbols[name] = symbol{
			Ptr:       ptr,
			Type:      src.Type,
			Elem:      src.Elem,
			SliceElem: src.SliceElem,
			IsMap:     src.IsMap,
			AstType:   src.AstType,
		}
	}

	if ex.Body != nil {
		for _, s := range ex.Body.Stmts {
			if err := child.emitStmt(s); err != nil {
				return err
			}
		}
	}
	if !child.terminated {
		switch child.retType {
		case "void":
			child.body.WriteString("  ret void\n")
		case "ptr":
			child.body.WriteString("  ret ptr null\n")
		default:
			fmt.Fprintf(&child.body, "  ret %s 0\n", child.retType)
		}
	}
	child.body.WriteString("}\n\n")
	c.e.trampolineDefs.WriteString(child.body.String())
	return nil
}

// emitEnvInit allocates the env struct on the heap and stores each
// captured value into the matching slot. Returns the env pointer
// (already typed as ptr).
func (c *funcCtx) emitEnvInit(_ lex.Pos, envTy string, captures []string) (string, error) {
	szPtr := c.newTemp()
	szInt := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = getelementptr %s, ptr null, i32 1\n", szPtr, envTy)
	fmt.Fprintf(&c.body, "  %s = ptrtoint ptr %s to i64\n", szInt, szPtr)
	c.e.ensureDeclare("declare ptr @volt_alloc(i64)")
	env := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call ptr @volt_alloc(i64 %s)\n", env, szInt)
	for i, name := range captures {
		src := c.symbols[name]
		gp := c.newTemp()
		ld := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = getelementptr %s, ptr %s, i32 0, i32 %d\n", gp, envTy, env, i)
		fmt.Fprintf(&c.body, "  %s = load %s, ptr %s\n", ld, src.Type, src.Ptr)
		fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", src.Type, ld, gp)
	}
	return env, nil
}

// isBorrowOrPointerLLVM reports whether the symbol's declared AST type
// is &T or *T (used to reject capturing borrows).
func isBorrowOrPointerLLVM(sym symbol) bool {
	if sym.AstType == nil {
		return false
	}
	_, b := sym.AstType.(*ast.BorrowType)
	_, p := sym.AstType.(*ast.PointerType)
	return b || p
}

// isLLVMTypeCopy reports whether the given LLVM type is Copy
// (primitive integer/float/bool). Strings, slices, maps, ptrs, and
// named struct types are non-Copy at the volt level.
func isLLVMTypeCopy(t string) bool {
	switch t {
	case "i1", "i8", "i16", "i32", "i64", "float", "double":
		return true
	}
	return false
}

// emitFuncRefAsValue builds a %fn_value SSA referring to a top-level
// function. The function's bare-ABI signature `(args) -> ret` doesn't
// match the closure ABI `(env, args) -> ret`, so we synthesize a
// trampoline @<sym>_$fn that ignores env and tail-calls the real one.
// One trampoline per uniquely-referenced function — cached in
// c.e.fnTrampolines.
func (c *funcCtx) emitFuncRefAsValue(name string, fd *ast.FuncDecl) (Value, error) {
	mangled := SymbolName(c.e.pkg, name)
	tramp, cached := c.e.fnTrampolines[mangled]
	if !cached {
		tramp = mangled + "_$fn"
		c.e.fnTrampolines[mangled] = tramp
		c.emitFuncTrampoline(tramp, mangled, fd)
	}
	// Build the %fn_value { ptr trampoline, ptr null } SSA.
	t1 := c.newTemp()
	t2 := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = insertvalue %%fn_value zeroinitializer, ptr @%s, 0\n", t1, tramp)
	fmt.Fprintf(&c.body, "  %s = insertvalue %%fn_value %s, ptr null, 1\n", t2, t1)
	return Value{Name: t2, Type: "%fn_value"}, nil
}

// emitFuncTrampoline writes the synthesized adapter IR. The signature
// is `(ptr _env, <fd params>) -> <fd result>` and the body just forwards
// to the bare function with env discarded.
func (c *funcCtx) emitFuncTrampoline(tramp, target string, fd *ast.FuncDecl) {
	var paramTypes []string
	var paramNames []string
	for _, p := range fd.Params {
		pt := c.e.llvmType(p.Type)
		paramTypes = append(paramTypes, pt)
		paramNames = append(paramNames, "%a"+fmt.Sprint(len(paramNames)))
	}
	retT := "void"
	if len(fd.Results) > 0 {
		retT = c.e.llvmType(fd.Results[0])
	}
	// Function header.
	fmt.Fprintf(&c.e.trampolineDefs, "define internal %s @%s(ptr %%_env", retT, tramp)
	for i, pt := range paramTypes {
		fmt.Fprintf(&c.e.trampolineDefs, ", %s %s", pt, paramNames[i])
	}
	c.e.trampolineDefs.WriteString(") {\nentry:\n")
	// Forward call.
	var callArgs []string
	for i, pt := range paramTypes {
		callArgs = append(callArgs, pt+" "+paramNames[i])
	}
	if retT == "void" {
		fmt.Fprintf(&c.e.trampolineDefs, "  call void @%s(%s)\n", target, strings.Join(callArgs, ", "))
		c.e.trampolineDefs.WriteString("  ret void\n")
	} else {
		fmt.Fprintf(&c.e.trampolineDefs, "  %%r = call %s @%s(%s)\n", retT, target, strings.Join(callArgs, ", "))
		fmt.Fprintf(&c.e.trampolineDefs, "  ret %s %%r\n", retT)
	}
	c.e.trampolineDefs.WriteString("}\n\n")
}

func (c *funcCtx) emitIdent(ex *ast.IdentExpr) (Value, error) {
	// Top-level const? Substitute its value expression.
	if cv, ok := c.e.consts[ex.Name]; ok {
		return c.emitExpr(cv)
	}
	// Top-level function name used as a value (not a call). Emit/cache
	// a trampoline that adapts the bare-fn ABI to the closure ABI and
	// build a %fn_value with null env.
	if fd, ok := c.e.funcs[ex.Name]; ok {
		if _, isVar := c.symbols[ex.Name]; !isVar {
			return c.emitFuncRefAsValue(ex.Name, fd)
		}
	}
	sym, ok := c.symbols[ex.Name]
	if !ok {
		return Value{}, fmt.Errorf("%s: undefined identifier %q", ex.Pos(), ex.Name)
	}
	// Borrow/pointer: auto-deref to the pointee value.
	if sym.Elem != "" {
		ptr := c.newTemp()
		val := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", ptr, sym.Ptr)
		fmt.Fprintf(&c.body, "  %s = load %s, ptr %s\n", val, sym.Elem, ptr)
		return Value{Name: val, Type: sym.Elem}, nil
	}
	t := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = load %s, ptr %s\n", t, sym.Type, sym.Ptr)
	return Value{Name: t, Type: sym.Type, SliceElem: sym.SliceElem}, nil
}

func (c *funcCtx) emitUnary(ex *ast.UnaryExpr) (Value, error) {
	x, err := c.emitExpr(ex.X)
	if err != nil {
		return Value{}, err
	}
	t := c.newTemp()
	switch ex.Op {
	case "!":
		bv := c.toBool(x)
		fmt.Fprintf(&c.body, "  %s = xor i1 %s, true\n", t, bv.Name)
		return Value{Name: t, Type: "i1"}, nil
	case "-":
		fmt.Fprintf(&c.body, "  %s = sub i64 0, %s\n", t, x.Name)
		return Value{Name: t, Type: "i64"}, nil
	case "<-":
		// Channel receive. x must be a chan (ptr).
		c.e.ensureDeclare("declare i64 @volt_chan_recv(ptr)")
		fmt.Fprintf(&c.body, "  %s = call i64 @volt_chan_recv(ptr %s)\n", t, x.Name)
		return Value{Name: t, Type: "i64"}, nil
	}
	return Value{}, fmt.Errorf("%s: unsupported unary op %q", ex.Pos(), ex.Op)
}

func (c *funcCtx) emitBinary(ex *ast.BinaryExpr) (Value, error) {
	x, err := c.emitExpr(ex.X)
	if err != nil {
		return Value{}, err
	}
	y, err := c.emitExpr(ex.Y)
	if err != nil {
		return Value{}, err
	}
	// Harmonize types: floats win over integer literals (a literal `3`
	// promotes to `3.0` when the other operand is a float); when both
	// integers, widen the smaller. Same-typed-floats pass through.
	opT := x.Type
	floatX := isFloatLLVM(x.Type)
	floatY := isFloatLLVM(y.Type)
	switch {
	case floatX && floatY:
		// Widen the narrower one. Use convertInt's float branch.
		if floatBitSize(x.Type) >= floatBitSize(y.Type) {
			y = c.convertInt(y, x.Type)
			opT = x.Type
		} else {
			x = c.convertInt(x, y.Type)
			opT = y.Type
		}
	case floatX && intBitSize(y.Type) > 0:
		// Integer literal/value alongside a float — promote int → float.
		if isLiteral(y.Name) {
			y = Value{Name: y.Name + ".0", Type: x.Type}
		} else {
			t := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = sitofp %s %s to %s\n", t, y.Type, y.Name, x.Type)
			y = Value{Name: t, Type: x.Type}
		}
		opT = x.Type
	case floatY && intBitSize(x.Type) > 0:
		if isLiteral(x.Name) {
			x = Value{Name: x.Name + ".0", Type: y.Type}
		} else {
			t := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = sitofp %s %s to %s\n", t, x.Type, x.Name, y.Type)
			x = Value{Name: t, Type: y.Type}
		}
		opT = y.Type
	case intBitSize(x.Type) > 0 && intBitSize(y.Type) > 0:
		if intBitSize(x.Type) >= intBitSize(y.Type) {
			y = c.convertInt(y, x.Type)
			opT = x.Type
		} else {
			x = c.convertInt(x, y.Type)
			opT = y.Type
		}
	}
	isFloat := isFloatLLVM(opT)
	t := c.newTemp()
	switch ex.Op {
	case "+":
		op := "add"
		if isFloat {
			op = "fadd"
		}
		fmt.Fprintf(&c.body, "  %s = %s %s %s, %s\n", t, op, opT, x.Name, y.Name)
		return Value{Name: t, Type: opT}, nil
	case "-":
		op := "sub"
		if isFloat {
			op = "fsub"
		}
		fmt.Fprintf(&c.body, "  %s = %s %s %s, %s\n", t, op, opT, x.Name, y.Name)
		return Value{Name: t, Type: opT}, nil
	case "*":
		op := "mul"
		if isFloat {
			op = "fmul"
		}
		fmt.Fprintf(&c.body, "  %s = %s %s %s, %s\n", t, op, opT, x.Name, y.Name)
		return Value{Name: t, Type: opT}, nil
	case "/":
		op := "sdiv"
		if isFloat {
			op = "fdiv"
		}
		fmt.Fprintf(&c.body, "  %s = %s %s %s, %s\n", t, op, opT, x.Name, y.Name)
		return Value{Name: t, Type: opT}, nil
	case "%":
		op := "srem"
		if isFloat {
			op = "frem"
		}
		fmt.Fprintf(&c.body, "  %s = %s %s %s, %s\n", t, op, opT, x.Name, y.Name)
		return Value{Name: t, Type: opT}, nil
	case "==", "!=", "<", "<=", ">", ">=":
		if isFloat {
			pred := map[string]string{
				"==": "oeq", "!=": "one",
				"<": "olt", "<=": "ole",
				">": "ogt", ">=": "oge",
			}[ex.Op]
			fmt.Fprintf(&c.body, "  %s = fcmp %s %s %s, %s\n", t, pred, opT, x.Name, y.Name)
		} else {
			pred := map[string]string{
				"==": "eq", "!=": "ne",
				"<": "slt", "<=": "sle",
				">": "sgt", ">=": "sge",
			}[ex.Op]
			fmt.Fprintf(&c.body, "  %s = icmp %s %s %s, %s\n", t, pred, opT, x.Name, y.Name)
		}
		return Value{Name: t, Type: "i1"}, nil
	case "&&":
		fmt.Fprintf(&c.body, "  %s = and i1 %s, %s\n", t, x.Name, y.Name)
		return Value{Name: t, Type: "i1"}, nil
	case "||":
		fmt.Fprintf(&c.body, "  %s = or i1 %s, %s\n", t, x.Name, y.Name)
		return Value{Name: t, Type: "i1"}, nil
	}
	return Value{}, fmt.Errorf("%s: unsupported binary op %q", ex.Pos(), ex.Op)
}

func (c *funcCtx) emitCall(call *ast.CallExpr) (Value, error) {
	switch fn := call.Fun.(type) {
	case *ast.SelectorExpr:
		return c.emitQualifiedCall(call, fn)
	case *ast.IdentExpr:
		// Built-in functions.
		switch fn.Name {
		case "len":
			return c.emitBuiltinLen(call)
		case "cap":
			return c.emitBuiltinCap(call)
		case "append":
			return c.emitBuiltinAppend(call)
		case "close":
			return c.emitBuiltinClose(call)
		case "read":
			return c.emitBuiltinRead(call)
		case "write":
			return c.emitBuiltinWrite(call)
		case "clone":
			return c.emitBuiltinClone(call)
		}
		return c.emitUnqualifiedCall(call, fn)
	}
	return Value{}, fmt.Errorf("%s: unsupported call form", call.Pos())
}

// emitBuiltinRead lowers `read(ch)` to volt_chan_recv(ch).
// The two-value form `v, ok := read(ch)` is handled via tryRecv2 in
// emitMultiVar — this single-value path returns only the received value.
// chanDirOf returns the declared direction of the channel argument
// `arg`, looked up via the symbol table. Bare expressions (not a
// variable) default to `ChanBoth` — there's no type info to consult.
func (c *funcCtx) chanDirOf(arg ast.Expr) ast.ChanDir {
	id, ok := arg.(*ast.IdentExpr)
	if !ok {
		return ast.ChanBoth
	}
	sym, ok := c.symbols[id.Name]
	if !ok {
		return ast.ChanBoth
	}
	if ct, ok := sym.AstType.(*ast.ChanType); ok {
		return ct.Dir
	}
	return ast.ChanBoth
}

func (c *funcCtx) emitBuiltinRead(call *ast.CallExpr) (Value, error) {
	if len(call.Args) != 1 {
		return Value{}, fmt.Errorf("%s: read takes exactly 1 argument", call.Pos())
	}
	if c.chanDirOf(call.Args[0]) == ast.ChanWrite {
		return Value{}, fmt.Errorf("%s: cannot read from a write-only channel (declared `chan write T`)", call.Pos())
	}
	ch, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	if ch.Type != "ptr" {
		return Value{}, fmt.Errorf("%s: read requires a channel, got %s", call.Pos(), ch.Type)
	}
	c.e.ensureDeclare("declare i64 @volt_chan_recv(ptr)")
	t := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call i64 @volt_chan_recv(ptr %s)\n", t, ch.Name)
	return Value{Name: t, Type: "i64"}, nil
}

// emitBuiltinWrite lowers `write(ch, v)` to volt_chan_send(ch, v).
// Replaces the legacy `ch <- v` send-statement form so that channel
// operations are a uniform read/write/close trio of built-ins.
func (c *funcCtx) emitBuiltinWrite(call *ast.CallExpr) (Value, error) {
	if len(call.Args) != 2 {
		return Value{}, fmt.Errorf("%s: write takes exactly 2 arguments: write(ch, value)", call.Pos())
	}
	if c.chanDirOf(call.Args[0]) == ast.ChanRead {
		return Value{}, fmt.Errorf("%s: cannot write to a read-only channel (declared `chan read T`)", call.Pos())
	}
	ch, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	if ch.Type != "ptr" {
		return Value{}, fmt.Errorf("%s: write requires a channel as the first argument, got %s", call.Pos(), ch.Type)
	}
	val, err := c.emitExpr(call.Args[1])
	if err != nil {
		return Value{}, err
	}
	val = c.convertInt(val, "i64")
	c.e.ensureDeclare("declare void @volt_chan_send(ptr, i64)")
	fmt.Fprintf(&c.body, "  call void @volt_chan_send(ptr %s, i64 %s)\n", ch.Name, val.Name)
	return Value{Name: "", Type: "void"}, nil
}

// ---- sync-primitive method dispatch -------------------------------------
//
// All three (atomic / mutex / rwmutex) wrap a single i64 value at runtime.
// Method calls intercept here from emitMethodCall and lower to direct
// runtime function calls — no user-defined methods table involved.

// emitAtomicMethod handles a.Read(), a.Write(v), a.Add(d),
// a.CompSwap(old, new). Dispatches to the per-width runtime entry
// point based on the atomic's element type. Add is rejected on
// ptr-typed atomics (no natural pointer addition).
func (c *funcCtx) emitAtomicMethod(call *ast.CallExpr, recvSym symbol, method string) (Value, error) {
	at, ok := recvSym.AstType.(*ast.AtomicType)
	if !ok {
		return Value{}, fmt.Errorf("%s: atomic method receiver lost type info", call.Pos())
	}
	elemT := c.e.llvmType(at.Elem)
	suffix, llT, ok := atomicSuffix(elemT)
	if !ok {
		return Value{}, fmt.Errorf("%s: atomic %s is not supported (only int, int32, ptr in v0.5)", call.Pos(), elemT)
	}

	handle := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", handle, recvSym.Ptr)

	convArg := func(v Value) Value {
		if llT == "ptr" {
			return v
		}
		return c.convertInt(v, llT)
	}

	switch method {
	case "Read":
		if len(call.Args) != 0 {
			return Value{}, fmt.Errorf("%s: atomic.Read takes no arguments", call.Pos())
		}
		fn := "volt_atomic_load" + suffix
		c.e.ensureDeclare(fmt.Sprintf("declare %s @%s(ptr)", llT, fn))
		t := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = call %s @%s(ptr %s)\n", t, llT, fn, handle)
		return Value{Name: t, Type: llT}, nil

	case "Write":
		if len(call.Args) != 1 {
			return Value{}, fmt.Errorf("%s: atomic.Write takes exactly 1 argument", call.Pos())
		}
		v, err := c.emitExpr(call.Args[0])
		if err != nil {
			return Value{}, err
		}
		v = convArg(v)
		fn := "volt_atomic_store" + suffix
		c.e.ensureDeclare(fmt.Sprintf("declare void @%s(ptr, %s)", fn, llT))
		fmt.Fprintf(&c.body, "  call void @%s(ptr %s, %s %s)\n", fn, handle, llT, v.Name)
		return Value{Name: "", Type: "void"}, nil

	case "Add":
		if llT == "ptr" {
			return Value{}, fmt.Errorf("%s: atomic.Add is not defined for ptr-typed atomics", call.Pos())
		}
		if suffix == "_bool" {
			return Value{}, fmt.Errorf("%s: atomic.Add is not defined for bool atomics — use Write/CompSwap", call.Pos())
		}
		if len(call.Args) != 1 {
			return Value{}, fmt.Errorf("%s: atomic.Add takes exactly 1 argument", call.Pos())
		}
		v, err := c.emitExpr(call.Args[0])
		if err != nil {
			return Value{}, err
		}
		v = convArg(v)
		fn := "volt_atomic_add" + suffix
		c.e.ensureDeclare(fmt.Sprintf("declare %s @%s(ptr, %s)", llT, fn, llT))
		t := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = call %s @%s(ptr %s, %s %s)\n", t, llT, fn, handle, llT, v.Name)
		return Value{Name: t, Type: llT}, nil

	case "CompSwap":
		if len(call.Args) != 2 {
			return Value{}, fmt.Errorf("%s: atomic.CompSwap takes exactly 2 arguments (old, new)", call.Pos())
		}
		oldV, err := c.emitExpr(call.Args[0])
		if err != nil {
			return Value{}, err
		}
		newV, err := c.emitExpr(call.Args[1])
		if err != nil {
			return Value{}, err
		}
		oldV = convArg(oldV)
		newV = convArg(newV)
		fn := "volt_atomic_cas" + suffix
		c.e.ensureDeclare(fmt.Sprintf("declare i64 @%s(ptr, %s, %s)", fn, llT, llT))
		raw := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = call i64 @%s(ptr %s, %s %s, %s %s)\n",
			raw, fn, handle, llT, oldV.Name, llT, newV.Name)
		// The runtime returns 1/0; surface as bool. The icmp folds into
		// the cmpxchg's zero flag at -O — no extra instruction at runtime.
		t := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = icmp ne i64 %s, 0\n", t, raw)
		return Value{Name: t, Type: "i1"}, nil
	}
	return Value{}, fmt.Errorf("%s: atomic has no method %q (expected Read, Write, Add, CompSwap)",
		call.Pos(), method)
}

// emitMutexMethod handles m.Lock(). Lock returns a guard that is only
// legal as the RHS of `var v T = m.Lock()` — that path is special-cased
// in emitVar (emitGuardVar). Direct calls in any other context are
// rejected. Unlock is gone: release happens automatically when the
// guard variable goes out of scope. There is no LockRead on mutex —
// reach for rwmutex T when you need a read-only / parallel-reader path.
func (c *funcCtx) emitMutexMethod(call *ast.CallExpr, _ symbol, method string) (Value, error) {
	switch method {
	case "Lock":
		return Value{}, fmt.Errorf("%s: mutex.Lock() can only appear as the RHS of `var x T = m.Lock()` — the guard must bind to a variable so it can be auto-released at scope end", call.Pos())
	case "LockRead":
		return Value{}, fmt.Errorf("%s: mutex has no LockRead — it serializes all access. For parallel readers + read-only enforcement use `rwmutex T` and call .LockRead() on that", call.Pos())
	case "Unlock":
		return Value{}, fmt.Errorf("%s: mutex.Unlock no longer exists — the lock releases automatically when the guard variable from `var x T = m.Lock()` goes out of scope", call.Pos())
	}
	return Value{}, fmt.Errorf("%s: mutex has no method %q (only Lock is exposed; release is automatic)",
		call.Pos(), method)
}

// emitRwMutexMethod gates all rwmutex method calls. Lock and LockRead
// can only appear as the RHS of `var v T = r.Lock()` /
// `var v T = r.LockRead()` — the guard binding is special-cased in
// emitVar. Unlock and UnlockRead are gone: the guard's Drop handles
// release automatically.
func (c *funcCtx) emitRwMutexMethod(call *ast.CallExpr, _ symbol, method string) (Value, error) {
	switch method {
	case "Lock":
		return Value{}, fmt.Errorf("%s: rwmutex.Lock() can only appear as the RHS of `var x T = r.Lock()` — the guard must bind to a variable so it can be auto-released at scope end", call.Pos())
	case "LockRead":
		return Value{}, fmt.Errorf("%s: rwmutex.LockRead() can only appear as the RHS of `var x T = r.LockRead()` — the guard must bind to a variable so it can be auto-released at scope end", call.Pos())
	case "Unlock", "UnlockRead":
		return Value{}, fmt.Errorf("%s: rwmutex.%s no longer exists — the lock releases automatically when the guard variable from `var x T = r.Lock()` or `r.LockRead()` goes out of scope", call.Pos(), method)
	}
	return Value{}, fmt.Errorf("%s: rwmutex has no method %q (only Lock and LockRead are exposed; release is automatic)",
		call.Pos(), method)
}

// emitErrorMethod dispatches a method call whose receiver is `error`-
// typed. The receiver var holds a ptr to an `%error_box` (set up by
// emitErrorBox at construction time). Box layout: { ptr data, ptr fn }.
// Load both, call the stored fn with the data pointer as receiver.
//
// v0.7: only `Error() string` is dispatched. Future user-defined
// interfaces will reuse this shape with a real vtable.
func (c *funcCtx) emitErrorMethod(call *ast.CallExpr, recvSym symbol, method string) (Value, error) {
	if method != "Error" {
		return Value{}, fmt.Errorf("%s: error has no method %q (only Error() is defined)", call.Pos(), method)
	}
	if len(call.Args) != 0 {
		return Value{}, fmt.Errorf("%s: error.Error takes no arguments", call.Pos())
	}
	box := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", box, recvSym.Ptr)
	dataGep := c.newTemp()
	dataPtr := c.newTemp()
	fnGep := c.newTemp()
	fnPtr := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = getelementptr %%error_box, ptr %s, i32 0, i32 0\n", dataGep, box)
	fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", dataPtr, dataGep)
	fmt.Fprintf(&c.body, "  %s = getelementptr %%error_box, ptr %s, i32 0, i32 1\n", fnGep, box)
	fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", fnPtr, fnGep)
	result := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call %%string %s(ptr %s)\n", result, fnPtr, dataPtr)
	return Value{Name: result, Type: "%string"}, nil
}

// emitWaitgroupMethod handles wg.Add(n), wg.Done(), wg.Wait().
//   Add(n)   — change counter by n (n may be negative); broadcasts if it hits 0
//   Done()   — shorthand for Add(-1)
//   Wait()   — block until counter == 0
func (c *funcCtx) emitWaitgroupMethod(call *ast.CallExpr, recvSym symbol, method string) (Value, error) {
	handle := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", handle, recvSym.Ptr)

	switch method {
	case "Add":
		if len(call.Args) != 1 {
			return Value{}, fmt.Errorf("%s: waitgroup.Add takes exactly 1 argument (delta)", call.Pos())
		}
		v, err := c.emitExpr(call.Args[0])
		if err != nil {
			return Value{}, err
		}
		v = c.convertInt(v, "i64")
		c.e.ensureDeclare("declare void @volt_waitgroup_add(ptr, i64)")
		fmt.Fprintf(&c.body, "  call void @volt_waitgroup_add(ptr %s, i64 %s)\n", handle, v.Name)
		return Value{Name: "", Type: "void"}, nil

	case "Done":
		if len(call.Args) != 0 {
			return Value{}, fmt.Errorf("%s: waitgroup.Done takes no arguments", call.Pos())
		}
		c.e.ensureDeclare("declare void @volt_waitgroup_done(ptr)")
		fmt.Fprintf(&c.body, "  call void @volt_waitgroup_done(ptr %s)\n", handle)
		return Value{Name: "", Type: "void"}, nil

	case "Wait":
		if len(call.Args) != 0 {
			return Value{}, fmt.Errorf("%s: waitgroup.Wait takes no arguments", call.Pos())
		}
		c.e.ensureDeclare("declare void @volt_waitgroup_wait(ptr)")
		fmt.Fprintf(&c.body, "  call void @volt_waitgroup_wait(ptr %s)\n", handle)
		return Value{Name: "", Type: "void"}, nil
	}
	return Value{}, fmt.Errorf("%s: waitgroup has no method %q (expected Add, Done, Wait)",
		call.Pos(), method)
}

// emitOnceMethod handles o.Do(fn) — the only method exposed on `once`.
// `Do(fn fun())` is the Go-style closure form: a single call that runs
// `fn` exactly once across all callers; every caller blocks until that
// run completes. Internally: extract (fn_ptr, env) from the fn_value,
// hand them to volt_once_do which gates on once state and indirect-
// calls fn(env) on the first arrival.
func (c *funcCtx) emitOnceMethod(call *ast.CallExpr, recvSym symbol, method string) (Value, error) {
	if method == "Do" {
		return c.emitOnceDo(call, recvSym)
	}
	return Value{}, fmt.Errorf("%s: once has no method %q (only Do is exposed)", call.Pos(), method)
}

// emitOnceDo handles `o.Do(fn)` where fn is a `fun()` value. Extracts
// the fn pointer and env from the closure value and hands them to the
// runtime, which gates first-arriver semantics and indirect-calls
// fn(env) exactly once.
func (c *funcCtx) emitOnceDo(call *ast.CallExpr, recvSym symbol) (Value, error) {
	if len(call.Args) != 1 {
		return Value{}, fmt.Errorf("%s: once.Do takes exactly 1 argument (a `fun()` value)", call.Pos())
	}
	v, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	if v.Type != "%fn_value" {
		return Value{}, fmt.Errorf("%s: once.Do expects a `fun()` value, got %s", call.Pos(), v.Type)
	}
	handle := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", handle, recvSym.Ptr)
	fnP := c.newTemp()
	envP := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = extractvalue %%fn_value %s, 0\n", fnP, v.Name)
	fmt.Fprintf(&c.body, "  %s = extractvalue %%fn_value %s, 1\n", envP, v.Name)
	c.e.ensureDeclare("declare void @volt_once_do(ptr, ptr, ptr)")
	fmt.Fprintf(&c.body, "  call void @volt_once_do(ptr %s, ptr %s, ptr %s)\n", handle, fnP, envP)
	return Value{Name: "", Type: "void"}, nil
}

// emitBuiltinClone lowers `clone(x)` into a fresh owned value of x's type
// with no aliasing to the original. Dispatch on the argument's AST type:
//
//	primitive    → identity (already Copy)
//	string       → deep copy of the backing bytes via volt_buf_clone
//	struct T     → field-wise clone (recursive); a user-defined Clone()
//	               method on T overrides the default
//	chan / &T / *T → compile error (reference-shaped, not cloneable)
//	slice / map  → not supported yet
func (c *funcCtx) emitBuiltinClone(call *ast.CallExpr) (Value, error) {
	if len(call.Args) != 1 {
		return Value{}, fmt.Errorf("%s: clone takes exactly 1 argument", call.Pos())
	}
	id, ok := call.Args[0].(*ast.IdentExpr)
	if !ok {
		return Value{}, fmt.Errorf("%s: clone requires a variable name", call.Pos())
	}
	sym, ok := c.symbols[id.Name]
	if !ok {
		return Value{}, fmt.Errorf("%s: undefined identifier %q", id.Pos(), id.Name)
	}

	// User-defined Clone() override (takes precedence over default deep clone).
	if nt, isNamed := sym.AstType.(*ast.NamedType); isNamed {
		if methods := c.e.methods[nt.Name]; methods != nil {
			if _, has := methods["Clone"]; has {
				sel := &ast.SelectorExpr{P: call.Pos(), X: id, Sel: "Clone"}
				synth := &ast.CallExpr{P: call.Pos(), Fun: sel}
				return c.emitMethodCall(synth, sel)
			}
		}
	}

	// Default path: load the value and deep-clone it.
	val, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	return c.cloneValue(call.Pos(), val, sym.AstType)
}

// cloneValue produces a fresh owned value of type `t` independent of `val`.
// Used recursively by clone() to copy struct fields.
func (c *funcCtx) cloneValue(pos lex.Pos, val Value, t ast.Type) (Value, error) {
	switch tt := t.(type) {
	case *ast.NamedType:
		switch tt.Name {
		case "int", "int8", "int16", "int32", "int64",
			"uint", "uint8", "uint16", "uint32", "uint64",
			"byte", "bool", "float", "float32", "float64":
			return val, nil
		case "string":
			return c.cloneString(val)
		}
		// User struct.
		info, ok := c.e.structs[tt.Name]
		if !ok {
			return Value{}, fmt.Errorf("%s: clone: unknown type %s", pos, tt.Name)
		}
		return c.cloneStruct(pos, val, tt.Name, info)
	case *ast.ChanType:
		return Value{}, fmt.Errorf("%s: clone is not allowed on channels — channels are shared by design", pos)
	case *ast.BorrowType, *ast.PointerType:
		return Value{}, fmt.Errorf("%s: clone is not allowed on borrows (&T / *T) — they are not owned values", pos)
	case *ast.SliceType:
		return c.cloneSlice(val, c.e.llvmType(tt.Elem))
	case *ast.MapType:
		return c.cloneMap(val)
	}
	return Value{}, fmt.Errorf("%s: clone: unsupported type %T", pos, t)
}

// cloneString deep-copies a %string value via volt_buf_clone.
func (c *funcCtx) cloneString(val Value) (Value, error) {
	if val.Type != "%string" {
		return Value{}, fmt.Errorf("clone: expected %%string, got %s", val.Type)
	}
	p := c.newTemp()
	l := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 0\n", p, val.Name)
	fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 1\n", l, val.Name)
	c.e.ensureDeclare("declare ptr @volt_buf_clone(ptr, i64)")
	np := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call ptr @volt_buf_clone(ptr %s, i64 %s)\n", np, p, l)
	t1 := c.newTemp()
	t2 := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = insertvalue %%string zeroinitializer, ptr %s, 0\n", t1, np)
	fmt.Fprintf(&c.body, "  %s = insertvalue %%string %s, i64 %s, 1\n", t2, t1, l)
	return Value{Name: t2, Type: "%string"}, nil
}

// cloneSlice byte-copies the backing storage of a %slice and builds a
// fresh header. Shallow w.r.t. element-level heap data — if elements
// are themselves heap-bound (e.g. strings inside the slice), both
// slices share the inner backing memory. Sufficient for primitive
// element types; struct-element deep-clone is a future widening.
func (c *funcCtx) cloneSlice(val Value, elemLL string) (Value, error) {
	if val.Type != "%slice" {
		return Value{}, fmt.Errorf("clone: expected %%slice, got %s", val.Type)
	}
	ptr := c.newTemp()
	lenVal := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = extractvalue %%slice %s, 0\n", ptr, val.Name)
	fmt.Fprintf(&c.body, "  %s = extractvalue %%slice %s, 1\n", lenVal, val.Name)
	bytesTmp := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = mul i64 %s, %d\n", bytesTmp, lenVal, llvmTypeBytes(elemLL))
	c.e.ensureDeclare("declare ptr @volt_buf_clone(ptr, i64)")
	nptr := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call ptr @volt_buf_clone(ptr %s, i64 %s)\n", nptr, ptr, bytesTmp)
	s1 := c.newTemp()
	s2 := c.newTemp()
	s3 := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = insertvalue %%slice zeroinitializer, ptr %s, 0\n", s1, nptr)
	fmt.Fprintf(&c.body, "  %s = insertvalue %%slice %s, i64 %s, 1\n", s2, s1, lenVal)
	// cap == len for the clone: we copied exactly `len` bytes.
	fmt.Fprintf(&c.body, "  %s = insertvalue %%slice %s, i64 %s, 2\n", s3, s2, lenVal)
	return Value{Name: s3, Type: "%slice", SliceElem: elemLL}, nil
}

// cloneMap calls the runtime's volt_map_clone, which allocates a new
// map table and copies every (key, value) entry. Like cloneSlice, this
// is shallow at the value level — pointer-valued maps share whatever
// the values point at.
func (c *funcCtx) cloneMap(val Value) (Value, error) {
	c.e.ensureDeclare("declare ptr @volt_map_clone(ptr)")
	t := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call ptr @volt_map_clone(ptr %s)\n", t, val.Name)
	return Value{Name: t, Type: "ptr"}, nil
}

// cloneStruct builds a new struct value by extracting each field of `val`
// and recursively cloning it, then inserting into a fresh struct of the
// same LLVM type.
func (c *funcCtx) cloneStruct(pos lex.Pos, val Value, typeName string, info *structInfo) (Value, error) {
	llT := "%" + typeName
	prev := "zeroinitializer"
	for i, f := range info.Fields {
		fieldT := c.e.llvmType(f.Type)
		ev := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = extractvalue %s %s, %d\n", ev, llT, val.Name, i)
		cloned, err := c.cloneValue(pos, Value{Name: ev, Type: fieldT}, f.Type)
		if err != nil {
			return Value{}, err
		}
		nv := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = insertvalue %s %s, %s %s, %d\n", nv, llT, prev, fieldT, cloned.Name, i)
		prev = nv
	}
	return Value{Name: prev, Type: llT}, nil
}

// emitBuiltinClose lowers `close(x)`. Dispatch:
//
//	chan T            → volt_chan_close(x)
//	struct with Close()→ x.Close()  (synthesized method call)
//	anything else      → compile error
//
// The argument must be an identifier so the codegen can look up its
// declared AST type. Composite expressions are not supported.
func (c *funcCtx) emitBuiltinClose(call *ast.CallExpr) (Value, error) {
	if len(call.Args) != 1 {
		return Value{}, fmt.Errorf("%s: close takes exactly 1 argument", call.Pos())
	}
	id, ok := call.Args[0].(*ast.IdentExpr)
	if !ok {
		return Value{}, fmt.Errorf("%s: close requires a variable name", call.Pos())
	}
	sym, ok := c.symbols[id.Name]
	if !ok {
		return Value{}, fmt.Errorf("%s: undefined identifier %q", id.Pos(), id.Name)
	}

	// Case 1: channel.
	if ct, isChan := sym.AstType.(*ast.ChanType); isChan {
		if ct.Dir == ast.ChanRead {
			return Value{}, fmt.Errorf("%s: cannot close a read-only channel (declared `chan read T`) — only the sender side closes", call.Pos())
		}
		t := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", t, sym.Ptr)
		c.e.ensureDeclare("declare void @volt_chan_close(ptr)")
		fmt.Fprintf(&c.body, "  call void @volt_chan_close(ptr %s)\n", t)
		return Value{Name: "", Type: "void"}, nil
	}

	// Case 2: struct value with a Close() method.
	if nt, isNamed := sym.AstType.(*ast.NamedType); isNamed {
		if methods := c.e.methods[nt.Name]; methods != nil {
			if _, hasClose := methods["Close"]; hasClose {
				sel := &ast.SelectorExpr{P: call.Pos(), X: id, Sel: "Close"}
				synth := &ast.CallExpr{P: call.Pos(), Fun: sel}
				return c.emitMethodCall(synth, sel)
			}
		}
		return Value{}, fmt.Errorf("%s: close(%s): type %s has no Close() method", call.Pos(), id.Name, nt.Name)
	}

	return Value{}, fmt.Errorf("%s: close(%s): only channels and types with a Close() method are supported", call.Pos(), id.Name)
}

// emitBuiltinCap lowers `cap(x)` for a slice. Strings and maps don't
// have a separate capacity in this v0.7 model. Returns the third field
// of the %slice header.
func (c *funcCtx) emitBuiltinCap(call *ast.CallExpr) (Value, error) {
	if len(call.Args) != 1 {
		return Value{}, fmt.Errorf("%s: cap takes exactly 1 argument", call.Pos())
	}
	arg, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	if arg.Type != "%slice" {
		return Value{}, fmt.Errorf("%s: cap() requires a slice, got %s", call.Pos(), arg.Type)
	}
	t := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = extractvalue %s %s, 2\n", t, arg.Type, arg.Name)
	return Value{Name: t, Type: "i64"}, nil
}

// emitBuiltinAppend lowers `append(s, v)` for a slice s and a single
// element v. Returns the (possibly grown) slice value — the caller
// must assign the result back, Go-style: `s = append(s, v)`. v0.7
// supports a single trailing element; variadic append comes later.
//
// Implementation: route to the runtime's volt_slice_grow, which
// reallocates when len == cap. The compiler stack-allocates a scratch
// header (modified in place) and a scratch element slot.
func (c *funcCtx) emitBuiltinAppend(call *ast.CallExpr) (Value, error) {
	if len(call.Args) != 2 {
		return Value{}, fmt.Errorf("%s: append takes exactly 2 arguments (slice, element)", call.Pos())
	}
	slice, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	if slice.Type != "%slice" {
		return Value{}, fmt.Errorf("%s: append's first arg must be a slice, got %s", call.Pos(), slice.Type)
	}
	elemT := slice.SliceElem
	if elemT == "" {
		return Value{}, fmt.Errorf("%s: append: slice element type unknown — assign to a typed variable first", call.Pos())
	}
	elem, err := c.emitExpr(call.Args[1])
	if err != nil {
		return Value{}, err
	}
	elem = c.convertInt(elem, elemT)

	// Stack scratch for the slice header (the runtime modifies it in
	// place) and for the new element (the runtime memcpy's its bytes).
	sliceSlot := c.newTemp()
	elemSlot := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = alloca %%slice\n", sliceSlot)
	fmt.Fprintf(&c.body, "  %s = alloca %s\n", elemSlot, elemT)
	fmt.Fprintf(&c.body, "  store %%slice %s, ptr %s\n", slice.Name, sliceSlot)
	fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", elemT, elem.Name, elemSlot)

	// sizeof(elemT) via the GEP-null trick.
	szPtr := c.newTemp()
	szInt := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = getelementptr %s, ptr null, i32 1\n", szPtr, elemT)
	fmt.Fprintf(&c.body, "  %s = ptrtoint ptr %s to i64\n", szInt, szPtr)

	c.e.ensureDeclare("declare void @volt_slice_grow(ptr, i64, ptr)")
	fmt.Fprintf(&c.body, "  call void @volt_slice_grow(ptr %s, i64 %s, ptr %s)\n",
		sliceSlot, szInt, elemSlot)

	result := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = load %%slice, ptr %s\n", result, sliceSlot)
	return Value{Name: result, Type: "%slice", SliceElem: elemT}, nil
}

// emitBuiltinLen lowers `len(x)` where x is a slice, string, or map.
func (c *funcCtx) emitBuiltinLen(call *ast.CallExpr) (Value, error) {
	if len(call.Args) != 1 {
		return Value{}, fmt.Errorf("%s: len takes exactly 1 argument", call.Pos())
	}
	// Map case — len(m) → volt_map_len(m).
	if id, ok := call.Args[0].(*ast.IdentExpr); ok {
		if sym, ok := c.symbols[id.Name]; ok && sym.IsMap {
			mapPtr := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", mapPtr, sym.Ptr)
			c.e.ensureDeclare("declare i64 @volt_map_len(ptr)")
			t := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = call i64 @volt_map_len(ptr %s)\n", t, mapPtr)
			return Value{Name: t, Type: "i64"}, nil
		}
	}
	arg, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	if arg.Type != "%slice" && arg.Type != "%string" {
		return Value{}, fmt.Errorf("%s: len() requires a slice, string, or map, got %s", call.Pos(), arg.Type)
	}
	t := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = extractvalue %s %s, 1\n", t, arg.Type, arg.Name)
	return Value{Name: t, Type: "i64"}, nil
}

// emitMapGet lowers `m[key]` to volt_map_get(m, key_ptr, key_len).
// v0.5 supports only map[string]i64.
func (c *funcCtx) emitMapGet(sym symbol, keyExpr ast.Expr, pos lex.Pos) (Value, error) {
	mapPtr := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", mapPtr, sym.Ptr)

	k, err := c.emitExpr(keyExpr)
	if err != nil {
		return Value{}, err
	}
	if k.Type != "%string" {
		return Value{}, fmt.Errorf("%s: map key must be string in v0.5, got %s", pos, k.Type)
	}
	kp := c.newTemp()
	kl := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 0\n", kp, k.Name)
	fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 1\n", kl, k.Name)
	c.e.ensureDeclare("declare i64 @volt_map_get(ptr, ptr, i64)")
	t := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call i64 @volt_map_get(ptr %s, ptr %s, i64 %s)\n", t, mapPtr, kp, kl)
	return Value{Name: t, Type: "i64"}, nil
}

// emitMapSet lowers `m[key] = v` to volt_map_set(m, key_ptr, key_len, v).
func (c *funcCtx) emitMapSet(sym symbol, keyExpr ast.Expr, valExpr ast.Expr, pos lex.Pos) error {
	mapPtr := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", mapPtr, sym.Ptr)

	k, err := c.emitExpr(keyExpr)
	if err != nil {
		return err
	}
	if k.Type != "%string" {
		return fmt.Errorf("%s: map key must be string in v0.5", pos)
	}
	kp := c.newTemp()
	kl := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 0\n", kp, k.Name)
	fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 1\n", kl, k.Name)

	v, err := c.emitExpr(valExpr)
	if err != nil {
		return err
	}
	v = c.convertInt(v, "i64")
	c.e.ensureDeclare("declare void @volt_map_set(ptr, ptr, i64, i64)")
	fmt.Fprintf(&c.body, "  call void @volt_map_set(ptr %s, ptr %s, i64 %s, i64 %s)\n",
		mapPtr, kp, kl, v.Name)
	return nil
}

func (c *funcCtx) emitQualifiedCall(call *ast.CallExpr, sel *ast.SelectorExpr) (Value, error) {
	pkgIdent, ok := sel.X.(*ast.IdentExpr)
	if !ok || !c.e.imported[pkgIdent.Name] {
		// X isn't a known package → method dispatch on a value.
		return c.emitMethodCall(call, sel)
	}
	pkgName := pkgIdent.Name
	full := pkgName + "." + sel.Sel

	// Compiler intrinsics still implemented inline.
	switch full {
	case "syscall.Write":
		return c.emitSyscallWrite(call)
	case "syscall.Exit", "os.Exit":
		// `os.Exit(code)` is the ergonomic name; both lower to the same
		// volt_exit syscall stub. The `os.Exit` form is preferred in
		// user code; `syscall.Exit` is the raw form kept for stdlib use.
		return c.emitSyscallExit(call)
	case "syscall.Nanosleep":
		return c.emitSyscallNanosleep(call)
	case "log.Println":
		return c.emitLogFormatCall(call, true)
	case "log.Print":
		return c.emitLogFormatCall(call, false)
	}

	// Otherwise: call into the imported package's mangled symbol.
	symbol := SymbolName(pkgName, sel.Sel)
	return c.emitForeignCall(call, symbol)
}

// emitMethodCall handles `obj.method(args)` where obj is a value (or a
// borrow). Looks up the method on obj's type and dispatches.
func (c *funcCtx) emitMethodCall(call *ast.CallExpr, sel *ast.SelectorExpr) (Value, error) {
	recvIdent, ok := sel.X.(*ast.IdentExpr)
	if !ok {
		return Value{}, fmt.Errorf("%s: method receiver must be a variable in v0.4", call.Pos())
	}
	recvSym, ok := c.symbols[recvIdent.Name]
	if !ok {
		return Value{}, fmt.Errorf("%s: undefined identifier %q", call.Pos(), recvIdent.Name)
	}

	// Intercept sync-primitive method calls (atomic / mutex / rwmutex).
	// These have no user-defined methods table — they dispatch directly
	// to runtime functions.
	if recvSym.AstType != nil {
		switch recvSym.AstType.(type) {
		case *ast.AtomicType:
			return c.emitAtomicMethod(call, recvSym, sel.Sel)
		case *ast.MutexType:
			return c.emitMutexMethod(call, recvSym, sel.Sel)
		case *ast.RwMutexType:
			return c.emitRwMutexMethod(call, recvSym, sel.Sel)
		case *ast.WaitgroupType:
			return c.emitWaitgroupMethod(call, recvSym, sel.Sel)
		case *ast.OnceType:
			return c.emitOnceMethod(call, recvSym, sel.Sel)
		}
	}

	// Interface dispatch: `e.Error()` on an error-typed variable. The
	// receiver holds an `%error_box` ptr; load the data pointer and the
	// stored Error fn pointer, then indirect-call.
	if isErrorType(recvSym.AstType) {
		return c.emitErrorMethod(call, recvSym, sel.Sel)
	}
	if iname := c.userInterfaceName(recvSym.AstType); iname != "" {
		return c.emitIfaceMethod(call, recvSym, iname, sel.Sel)
	}

	// Determine the bare struct type name.
	var typeName string
	switch {
	case recvSym.Elem != "" && strings.HasPrefix(recvSym.Elem, "%"):
		typeName = strings.TrimPrefix(recvSym.Elem, "%")
	case strings.HasPrefix(recvSym.Type, "%") && recvSym.Type != "%string":
		typeName = strings.TrimPrefix(recvSym.Type, "%")
	default:
		return Value{}, fmt.Errorf("%s: cannot call method on %s", call.Pos(), recvSym.Type)
	}

	methods := c.e.methods[typeName]
	if methods == nil {
		return Value{}, fmt.Errorf("%s: no methods on type %s", call.Pos(), typeName)
	}
	method, ok := methods[sel.Sel]
	if !ok {
		return Value{}, fmt.Errorf("%s: %s has no method %q", call.Pos(), typeName, sel.Sel)
	}

	var retT string
	if len(method.Results) == 0 {
		retT = "void"
	} else {
		retT = c.e.llvmType(method.Results[0])
	}

	// Receiver argument — uses bare-name inference like any other arg.
	recvArg, err := c.emitCallArg(recvIdent, method.Receiver.Type)
	if err != nil {
		return Value{}, err
	}
	recvT := c.e.llvmType(method.Receiver.Type)
	argStrs := []string{recvT + " " + recvArg.Name}

	if len(call.Args) != len(method.Params) {
		return Value{}, fmt.Errorf("%s: method %s takes %d arg(s), got %d",
			call.Pos(), sel.Sel, len(method.Params), len(call.Args))
	}
	for i, arg := range call.Args {
		v, err := c.emitCallArg(arg, method.Params[i].Type)
		if err != nil {
			return Value{}, err
		}
		paramT := c.e.llvmType(method.Params[i].Type)
		argStrs = append(argStrs, paramT+" "+v.Name)
	}

	mangled := methodSymbol(c.e.pkg, typeName, sel.Sel)
	if retT == "void" {
		fmt.Fprintf(&c.body, "  call void @%s(%s)\n", mangled, strings.Join(argStrs, ", "))
		return Value{Name: "", Type: "void"}, nil
	}
	t := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call %s @%s(%s)\n", t, retT, mangled, strings.Join(argStrs, ", "))
	return Value{Name: t, Type: retT}, nil
}

// emitForeignCall handles calls to functions in other packages whose
// signatures we don't have access to (no real type checker yet). v0.3
// recognizes log.Println(s string) → void as the only such pattern.
func (c *funcCtx) emitForeignCall(call *ast.CallExpr, symbol string) (Value, error) {
	// v0.3: only stringly-typed single-arg void functions supported.
	if len(call.Args) != 1 {
		return Value{}, fmt.Errorf("%s: cross-package calls limited to one arg in v0.3", call.Pos())
	}
	arg, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	c.e.ensureDeclare(fmt.Sprintf("declare void @%s(%s)", symbol, arg.Type))
	fmt.Fprintf(&c.body, "  call void @%s(%s %s)\n", symbol, arg.Type, arg.Name)
	return Value{Name: "", Type: "void"}, nil
}

// emitIndirectCall lowers `f(args...)` where `f` is a fn-typed local.
// Loads the %fn_value, extracts the fn pointer and env pointer, then
// calls fn(env, args...). The function pointer is opaque (`ptr`) at the
// LLVM level; the signature for the indirect call is reconstructed from
// the variable's declared FuncType.
func (c *funcCtx) emitIndirectCall(call *ast.CallExpr, sym symbol, ft *ast.FuncType) (Value, error) {
	if len(call.Args) != len(ft.Params) {
		return Value{}, fmt.Errorf("%s: function value takes %d arg(s), got %d",
			call.Pos(), len(ft.Params), len(call.Args))
	}
	fv := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = load %%fn_value, ptr %s\n", fv, sym.Ptr)
	fnP := c.newTemp()
	envP := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = extractvalue %%fn_value %s, 0\n", fnP, fv)
	fmt.Fprintf(&c.body, "  %s = extractvalue %%fn_value %s, 1\n", envP, fv)

	retT := "void"
	if len(ft.Results) > 0 {
		retT = c.e.llvmType(ft.Results[0])
	}

	argStrs := []string{"ptr " + envP}
	for i, arg := range call.Args {
		v, err := c.emitCallArg(arg, ft.Params[i].Type)
		if err != nil {
			return Value{}, err
		}
		paramT := c.e.llvmType(ft.Params[i].Type)
		argStrs = append(argStrs, paramT+" "+v.Name)
	}

	if retT == "void" {
		fmt.Fprintf(&c.body, "  call void %s(%s)\n", fnP, strings.Join(argStrs, ", "))
		return Value{Name: "", Type: "void"}, nil
	}
	r := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call %s %s(%s)\n", r, retT, fnP, strings.Join(argStrs, ", "))
	return Value{Name: r, Type: retT}, nil
}

func (c *funcCtx) emitUnqualifiedCall(call *ast.CallExpr, fn *ast.IdentExpr) (Value, error) {
	// Indirect call: the identifier resolves to a fn-typed local
	// (parameter, var, or `var = fun(...){ ... }` literal). Load the
	// %fn_value, extract fn+env, indirect-call with env as first arg.
	if sym, ok := c.symbols[fn.Name]; ok {
		if ft, ok := sym.AstType.(*ast.FuncType); ok {
			return c.emitIndirectCall(call, sym, ft)
		}
	}
	sig, ok := c.e.funcs[fn.Name]
	if !ok {
		return Value{}, fmt.Errorf("%s: undefined function %q", call.Pos(), fn.Name)
	}
	if len(call.Args) != len(sig.Params) {
		return Value{}, fmt.Errorf("%s: %s takes %d arg(s), got %d",
			call.Pos(), fn.Name, len(sig.Params), len(call.Args))
	}

	var retT string
	switch {
	case fn.Name == "main" && c.e.pkg == "main":
		retT = "i64"
	case len(sig.Results) == 0:
		retT = "void"
	default:
		retT = c.e.llvmType(sig.Results[0])
	}

	var argStrs []string
	for i, arg := range call.Args {
		v, err := c.emitCallArg(arg, sig.Params[i].Type)
		if err != nil {
			return Value{}, err
		}
		paramT := c.e.llvmType(sig.Params[i].Type)
		argStrs = append(argStrs, paramT+" "+v.Name)
	}

	mangled := SymbolName(c.e.pkg, fn.Name)
	if retT == "void" {
		fmt.Fprintf(&c.body, "  call void @%s(%s)\n", mangled, strings.Join(argStrs, ", "))
		return Value{Name: "", Type: "void"}, nil
	}
	t := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call %s @%s(%s)\n", t, retT, mangled, strings.Join(argStrs, ", "))
	return Value{Name: t, Type: retT}, nil
}

// emitCallArg emits one call-site argument. If the parameter is a
// borrow/pointer type and the argument is a plain identifier, the bare
// name is interpreted as "borrow this variable" — we pass the alloca
// pointer instead of loading the value. This is the bare-name inference
// rule from the language design.
func (c *funcCtx) emitCallArg(arg ast.Expr, paramType ast.Type) (Value, error) {
	// A guard variable cannot be passed to another function — its lifetime
	// is bound to the declaring scope and it must release at scope end.
	if id, ok := arg.(*ast.IdentExpr); ok {
		if sym, ok := c.symbols[id.Name]; ok && sym.IsGuard {
			return Value{}, fmt.Errorf("%s: %s is a mutex guard — it cannot be passed to a function (the lock must release in the scope that acquired it)",
				arg.Pos(), id.Name)
		}
	}
	if !isBorrowOrPointer(paramType) {
		return c.emitExpr(arg)
	}
	id, ok := arg.(*ast.IdentExpr)
	if !ok {
		return Value{}, fmt.Errorf("%s: can only borrow from a variable in v0.3", arg.Pos())
	}
	sym, ok := c.symbols[id.Name]
	if !ok {
		return Value{}, fmt.Errorf("%s: undefined identifier %q", id.Pos(), id.Name)
	}
	if sym.Elem != "" {
		// Source variable is itself a borrow — re-pass the stored ptr.
		t := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", t, sym.Ptr)
		return Value{Name: t, Type: "ptr"}, nil
	}
	// Source variable is owned — pass its alloca address.
	return Value{Name: sym.Ptr, Type: "ptr"}, nil
}

// emitSyscallWrite lowers syscall.Write(fd int, s string) → runtime volt_write.
func (c *funcCtx) emitSyscallWrite(call *ast.CallExpr) (Value, error) {
	if len(call.Args) != 2 {
		return Value{}, fmt.Errorf("%s: syscall.Write takes (fd int, s string)", call.Pos())
	}
	fd, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	str, err := c.emitExpr(call.Args[1])
	if err != nil {
		return Value{}, err
	}
	if str.Type != "%string" {
		return Value{}, fmt.Errorf("%s: syscall.Write second arg must be string, got %s", call.Pos(), str.Type)
	}
	pTmp := c.newTemp()
	lTmp := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 0\n", pTmp, str.Name)
	fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 1\n", lTmp, str.Name)
	c.e.ensureDeclare("declare void @volt_write(i64, ptr, i64)")
	fmt.Fprintf(&c.body, "  call void @volt_write(i64 %s, ptr %s, i64 %s)\n", fd.Name, pTmp, lTmp)
	return Value{Name: "", Type: "void"}, nil
}

// emitSyscallNanosleep lowers syscall.Nanosleep(ns int) → runtime volt_sleep.
func (c *funcCtx) emitSyscallNanosleep(call *ast.CallExpr) (Value, error) {
	if len(call.Args) != 1 {
		return Value{}, fmt.Errorf("%s: syscall.Nanosleep takes (ns int)", call.Pos())
	}
	ns, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	c.e.ensureDeclare("declare void @volt_sleep(i64)")
	fmt.Fprintf(&c.body, "  call void @volt_sleep(i64 %s)\n", ns.Name)
	return Value{Name: "", Type: "void"}, nil
}

// emitLogFormatCall is the shared compiler intrinsic for log.Println and
// log.Print. They differ only by whether a trailing "\n" is appended.
//
// Two shapes:
//
//	log.Print(s string)   /  log.Println(s string)
//	  → emit `volt_write(2, s.ptr, s.len)` then optionally `volt_write(2, "\n", 1)`
//
//	log.Print(fmtLit string, args...)   /  log.Println(fmtLit string, args...)
//	  → first arg must be a STRING LITERAL parsed at compile time.
//	    Supported verbs: %d (i64), %s (string), %t (bool), %v (auto),
//	    %% (literal %). Each verb consumes one positional argument in
//	    order. Literal runs between verbs are interned and written as-is.
//	    Output is optionally terminated with a single "\n".
func (c *funcCtx) emitLogFormatCall(call *ast.CallExpr, addNewline bool) (Value, error) {
	name := "log.Print"
	if addNewline {
		name = "log.Println"
	}
	if len(call.Args) == 0 {
		return Value{}, fmt.Errorf("%s: %s requires at least one argument", call.Pos(), name)
	}

	// Single-arg form: just print the string (+ optional newline).
	if len(call.Args) == 1 {
		s, err := c.emitExpr(call.Args[0])
		if err != nil {
			return Value{}, err
		}
		if s.Type != "%string" {
			return Value{}, fmt.Errorf("%s: %s single-arg form takes a string, got %s", call.Pos(), name, s.Type)
		}
		c.emitWriteString(s)
		if addNewline {
			c.emitWriteCStringLiteral("\n")
		}
		return Value{Name: "", Type: "void"}, nil
	}

	// Variadic form: parse the format literal at compile time.
	fmtLit, ok := call.Args[0].(*ast.StringLit)
	if !ok {
		return Value{}, fmt.Errorf("%s: %s with multiple args requires a string literal as the format string", call.Pos(), name)
	}
	chunks, verbs, err := parseLogFormat(fmtLit.Text)
	if err != nil {
		return Value{}, fmt.Errorf("%s: %v", call.Pos(), err)
	}
	if len(verbs) != len(call.Args)-1 {
		return Value{}, fmt.Errorf("%s: %s: format string has %d verbs but %d args provided",
			call.Pos(), name, len(verbs), len(call.Args)-1)
	}

	// Emit alternating literal chunk / formatted arg.
	argIdx := 0
	for i, lit := range chunks {
		if lit != "" {
			c.emitWriteCStringLiteral(lit)
		}
		if i < len(verbs) {
			argExpr := call.Args[1+argIdx]
			argVal, err := c.emitExpr(argExpr)
			if err != nil {
				return Value{}, err
			}
			if err := c.emitFormattedArg(argExpr, argVal, verbs[i]); err != nil {
				return Value{}, err
			}
			argIdx++
		}
	}
	if addNewline {
		c.emitWriteCStringLiteral("\n")
	}
	return Value{Name: "", Type: "void"}, nil
}

// emitWriteString writes a %string value (ptr + len) to fd 2 (stderr).
func (c *funcCtx) emitWriteString(s Value) {
	pTmp := c.newTemp()
	lTmp := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 0\n", pTmp, s.Name)
	fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 1\n", lTmp, s.Name)
	c.e.ensureDeclare("declare void @volt_write(i64, ptr, i64)")
	fmt.Fprintf(&c.body, "  call void @volt_write(i64 2, ptr %s, i64 %s)\n", pTmp, lTmp)
}

// emitWriteCStringLiteral interns the given literal text and emits a
// volt_write call for it. Skips the call if the literal is empty.
func (c *funcCtx) emitWriteCStringLiteral(s string) {
	if s == "" {
		return
	}
	gname, glen := c.e.internString(s)
	c.e.ensureDeclare("declare void @volt_write(i64, ptr, i64)")
	fmt.Fprintf(&c.body, "  call void @volt_write(i64 2, ptr %s, i64 %d)\n", gname, glen)
}

// emitFormattedArg writes one argument according to a format verb.
func (c *funcCtx) emitFormattedArg(argExpr ast.Expr, v Value, verb byte) error {
	switch verb {
	case 'd':
		if !isIntLLVM(v.Type) {
			return fmt.Errorf("%s: %%d expects an integer, got %s", argExpr.Pos(), v.Type)
		}
		v = c.convertInt(v, "i64")
		c.e.ensureDeclare("declare void @volt_write_int(i64, i64)")
		fmt.Fprintf(&c.body, "  call void @volt_write_int(i64 2, i64 %s)\n", v.Name)
	case 's':
		if v.Type != "%string" {
			return fmt.Errorf("%s: %%s expects a string, got %s", argExpr.Pos(), v.Type)
		}
		c.emitWriteString(v)
	case 't':
		if v.Type != "i1" {
			return fmt.Errorf("%s: %%t expects a bool, got %s", argExpr.Pos(), v.Type)
		}
		ext := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = zext i1 %s to i64\n", ext, v.Name)
		c.e.ensureDeclare("declare void @volt_write_bool(i64, i64)")
		fmt.Fprintf(&c.body, "  call void @volt_write_bool(i64 2, i64 %s)\n", ext)
	case 'v':
		switch {
		case v.Type == "%string":
			c.emitWriteString(v)
		case v.Type == "i1":
			ext := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = zext i1 %s to i64\n", ext, v.Name)
			c.e.ensureDeclare("declare void @volt_write_bool(i64, i64)")
			fmt.Fprintf(&c.body, "  call void @volt_write_bool(i64 2, i64 %s)\n", ext)
		case isIntLLVM(v.Type):
			v = c.convertInt(v, "i64")
			c.e.ensureDeclare("declare void @volt_write_int(i64, i64)")
			fmt.Fprintf(&c.body, "  call void @volt_write_int(i64 2, i64 %s)\n", v.Name)
		default:
			return fmt.Errorf("%s: %%v: unsupported value type %s", argExpr.Pos(), v.Type)
		}
	default:
		return fmt.Errorf("%s: unsupported format verb %%%c", argExpr.Pos(), verb)
	}
	return nil
}

func isIntLLVM(t string) bool {
	switch t {
	case "i8", "i16", "i32", "i64":
		return true
	}
	return false
}

// parseLogFormat splits a format string into literal-text chunks and a
// parallel verbs slice. The returned slice has len(verbs)+1 chunks if
// there's a trailing literal, or len(verbs) if the string ends in a verb.
// Caller emits chunks[i] then verbs[i] in lockstep.
//
// Supported verbs: %d, %s, %t, %v. %% is a literal '%'.
func parseLogFormat(s string) (chunks []string, verbs []byte, err error) {
	var cur strings.Builder
	for i := 0; i < len(s); i++ {
		if s[i] != '%' {
			cur.WriteByte(s[i])
			continue
		}
		// Saw '%' — peek next.
		if i+1 >= len(s) {
			return nil, nil, fmt.Errorf("log.Println: trailing %% in format string")
		}
		next := s[i+1]
		i++
		if next == '%' {
			cur.WriteByte('%')
			continue
		}
		switch next {
		case 'd', 's', 't', 'v':
			chunks = append(chunks, cur.String())
			cur.Reset()
			verbs = append(verbs, next)
		default:
			return nil, nil, fmt.Errorf("log.Println: unsupported format verb %%%c", next)
		}
	}
	if cur.Len() > 0 {
		chunks = append(chunks, cur.String())
	}
	return chunks, verbs, nil
}

// emitSyscallExit lowers syscall.Exit(code int) → runtime volt_exit.
func (c *funcCtx) emitSyscallExit(call *ast.CallExpr) (Value, error) {
	if len(call.Args) != 1 {
		return Value{}, fmt.Errorf("%s: syscall.Exit takes (code int)", call.Pos())
	}
	code, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	c.e.ensureDeclare("declare void @volt_exit(i64)")
	fmt.Fprintf(&c.body, "  call void @volt_exit(i64 %s)\n", code.Name)
	c.body.WriteString("  unreachable\n")
	c.terminated = true
	return Value{Name: "", Type: "void"}, nil
}

// ---------------------------------------------------------------------
// toBool — convert a Value to i1 if needed (for if/for conditions, !).
// ---------------------------------------------------------------------

func (c *funcCtx) toBool(v Value) Value {
	if v.Type == "i1" {
		return v
	}
	t := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = icmp ne %s %s, 0\n", t, v.Type, v.Name)
	return Value{Name: t, Type: "i1"}
}

// ---------------------------------------------------------------------
// String / declaration interning
// ---------------------------------------------------------------------

func (e *Emitter) internString(s string) (string, int) {
	name := fmt.Sprintf("@%s_str.%d", e.pkg, e.stringID)
	e.stringID++
	n := len(s)
	fmt.Fprintf(&e.stringDefs,
		"%s = private constant [%d x i8] c%s\n",
		name, n, llvmStringLiteral(s),
	)
	return name, n
}

func (e *Emitter) ensureDeclare(line string) {
	e.declares[line] = true
}

func llvmStringLiteral(s string) string {
	var b strings.Builder
	b.WriteByte('"')
	for i := 0; i < len(s); i++ {
		c := s[i]
		if c == '\\' || c == '"' || c < 0x20 || c > 0x7E {
			fmt.Fprintf(&b, "\\%02X", c)
		} else {
			b.WriteByte(c)
		}
	}
	b.WriteByte('"')
	return b.String()
}
