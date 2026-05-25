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
		structs:    make(map[string]*structInfo),
		interfaces: make(map[string]bool),
		consts:     make(map[string]ast.Expr),
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
			}
		}
	}

	fmt.Fprintf(&e.header, "; module: %s\n", file.Package)
	if e.targetTriple != "" {
		fmt.Fprintf(&e.header, "target triple = %q\n\n", e.targetTriple)
	} else {
		e.header.WriteString("\n")
	}
	e.header.WriteString("%string = type { ptr, i64 }\n")
	e.header.WriteString("%slice = type { ptr, i64 }\n")

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
		e:       e,
		symbols: make(map[string]symbol),
		retType: retType,
		isMain:  isMain,
	}

	for _, p := range allParams {
		pt := e.llvmType(p.Type)
		ptr := fmt.Sprintf("%%%s.addr", p.Name)
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

// emitRun lowers `run f(...)` (0..4 args) to volt_spawn(@f, a1, a2, a3,
// a4). The runtime spawn primitive (start_*.s) accepts a fixed 4
// arg-slots; unused tail slots are passed as null. For >4 args, pack
// into a struct and pass a single ptr.
const spawnMaxArgs = 4

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
	// All spawn slots are typed `ptr` in the ABI. Non-ptr scalar args
	// (e.g. an int passed as a worker config value) get inttoptr'd into
	// place — the receiver picks them up as integer-sized registers and
	// the volt callee's signature reinterprets them as the original
	// scalar type. Ptr-typed args pass through unchanged.
	for i, expr := range s.Call.Args {
		v, err := c.emitCallArg(expr, sig.Params[i].Type)
		if err != nil {
			return err
		}
		if v.Type == "ptr" {
			args[i] = v.Name
			continue
		}
		conv := c.newTemp()
		// Widen to i64 first if narrower, then inttoptr.
		widened := c.convertInt(v, "i64")
		fmt.Fprintf(&c.body, "  %s = inttoptr i64 %s to ptr\n", conv, widened.Name)
		args[i] = conv
	}
	mangled := SymbolName(c.e.pkg, id.Name)
	c.e.ensureDeclare("declare void @volt_spawn(ptr, ptr, ptr, ptr, ptr)")
	fmt.Fprintf(&c.body, "  call void @volt_spawn(ptr @%s, ptr %s, ptr %s, ptr %s, ptr %s)\n",
		mangled, args[0], args[1], args[2], args[3])
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
		// Bind recv names if any.
		if cs.SendValue == nil && len(cs.RecvNames) > 0 {
			agg := recvAggs[i]
			vTmp := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = extractvalue {i64, i64} %s, 0\n", vTmp, agg)
			ptr := fmt.Sprintf("%%%s.addr", cs.RecvNames[0])
			fmt.Fprintf(&c.body, "  %s = alloca i64\n", ptr)
			fmt.Fprintf(&c.body, "  store i64 %s, ptr %s\n", vTmp, ptr)
			c.symbols[cs.RecvNames[0]] = symbol{Ptr: ptr, Type: "i64"}
			if len(cs.RecvNames) == 2 {
				okTmp := c.newTemp()
				fmt.Fprintf(&c.body, "  %s = extractvalue {i64, i64} %s, 1\n", okTmp, agg)
				okPtr := fmt.Sprintf("%%%s.addr", cs.RecvNames[1])
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
		switch sel.Sel {
		case "Lock":
			return guardCall{lockFn: "volt_mutex_lock", unlockFn: "volt_mutex_unlock", elem: t.Elem}, true
		case "LockRead":
			// Same lock acquisition as Lock — `mutex T` has no separate read
			// path — but the resulting guard is read-only, so field writes
			// become compile errors. Useful when the critical section only
			// observes and you want the compiler to enforce it.
			return guardCall{lockFn: "volt_mutex_lock", unlockFn: "volt_mutex_unlock", readOnly: true, elem: t.Elem}, true
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
	var elem, sliceElem string
	if s.Type != nil {
		elem = c.e.elemType(s.Type)
		sliceElem = c.e.sliceElemLLVM(s.Type)
	} else if s.Value != nil {
		sliceElem = val.SliceElem
	}
	ptr := fmt.Sprintf("%%%s.addr", s.Name)
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

	// If the variable is an owned struct value AND its type has a Drop()
	// method, register an automatic drop at scope exit.
	if len(typeStr) > 1 && typeStr[0] == '%' && typeStr != "%string" && typeStr != "%slice" {
		typeName := strings.TrimPrefix(typeStr, "%")
		if c.e.methods[typeName] != nil {
			if _, ok := c.e.methods[typeName]["Drop"]; ok {
				c.drops = append(c.drops, dropEntry{
					kind:     dropKindStruct,
					depth:    c.scopeDepth,
					ptr:      ptr,
					typeName: typeName,
				})
			}
		}
	}
	return nil
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
	return nil
}

func (c *funcCtx) emitFor(s *ast.ForStmt) error {
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
	fmt.Fprintf(&c.body, "  %s = insertvalue %%slice zeroinitializer, ptr %s, 0\n", t1, arr)
	fmt.Fprintf(&c.body, "  %s = insertvalue %%slice %s, i64 %d, 1\n", t2, t1, n)
	return Value{Name: t2, Type: "%slice", SliceElem: elemT}, nil
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
// Supported: int / int64 (i64, no suffix), int32 (i32), ptr.
// int8/int16/bool deferred (alignment + atomicity-on-i1 nuance).
func atomicSuffix(elemT string) (suffix, llT string, ok bool) {
	switch elemT {
	case "i64":
		return "", "i64", true
	case "i32":
		return "_i32", "i32", true
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

	// Build the {ptr, len} slice value.
	s1 := c.newTemp()
	s2 := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = insertvalue %%slice zeroinitializer, ptr %s, 0\n", s1, dataTmp)
	fmt.Fprintf(&c.body, "  %s = insertvalue %%slice %s, i64 %s, 1\n", s2, s1, lenVal.Name)
	return Value{Name: s2, Type: "%slice", SliceElem: elemLL}, nil
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

func (c *funcCtx) emitStringLit(ex *ast.StringLit) (Value, error) {
	gname, glen := c.e.internString(ex.Text)
	t1 := c.newTemp()
	t2 := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = insertvalue %%string zeroinitializer, ptr %s, 0\n", t1, gname)
	fmt.Fprintf(&c.body, "  %s = insertvalue %%string %s, i64 %d, 1\n", t2, t1, glen)
	return Value{Name: t2, Type: "%string"}, nil
}

func (c *funcCtx) emitIdent(ex *ast.IdentExpr) (Value, error) {
	// Top-level const? Substitute its value expression.
	if cv, ok := c.e.consts[ex.Name]; ok {
		return c.emitExpr(cv)
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
	// Harmonize integer types: if x is i32 and y is i64 (or vice versa),
	// widen the smaller one. (Both literals or both same type: pass-through.)
	opT := x.Type
	if intBitSize(x.Type) > 0 && intBitSize(y.Type) > 0 {
		if intBitSize(x.Type) >= intBitSize(y.Type) {
			y = c.convertInt(y, x.Type)
			opT = x.Type
		} else {
			x = c.convertInt(x, y.Type)
			opT = y.Type
		}
	}
	t := c.newTemp()
	switch ex.Op {
	case "+":
		fmt.Fprintf(&c.body, "  %s = add %s %s, %s\n", t, opT, x.Name, y.Name)
		return Value{Name: t, Type: opT}, nil
	case "-":
		fmt.Fprintf(&c.body, "  %s = sub %s %s, %s\n", t, opT, x.Name, y.Name)
		return Value{Name: t, Type: opT}, nil
	case "*":
		fmt.Fprintf(&c.body, "  %s = mul %s %s, %s\n", t, opT, x.Name, y.Name)
		return Value{Name: t, Type: opT}, nil
	case "/":
		fmt.Fprintf(&c.body, "  %s = sdiv %s %s, %s\n", t, opT, x.Name, y.Name)
		return Value{Name: t, Type: opT}, nil
	case "%":
		fmt.Fprintf(&c.body, "  %s = srem %s %s, %s\n", t, opT, x.Name, y.Name)
		return Value{Name: t, Type: opT}, nil
	case "==", "!=", "<", "<=", ">", ">=":
		pred := map[string]string{
			"==": "eq", "!=": "ne",
			"<": "slt", "<=": "sle",
			">": "sgt", ">=": "sge",
		}[ex.Op]
		fmt.Fprintf(&c.body, "  %s = icmp %s %s %s, %s\n", t, pred, opT, x.Name, y.Name)
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
func (c *funcCtx) emitBuiltinRead(call *ast.CallExpr) (Value, error) {
	if len(call.Args) != 1 {
		return Value{}, fmt.Errorf("%s: read takes exactly 1 argument", call.Pos())
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

// emitAtomicMethod handles a.Load(), a.Store(v), a.Add(d),
// a.CompareAndSwap(old, new). Dispatches to the per-width runtime
// entry point based on the atomic's element type. Add is rejected on
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
	case "Load":
		if len(call.Args) != 0 {
			return Value{}, fmt.Errorf("%s: atomic.Load takes no arguments", call.Pos())
		}
		fn := "volt_atomic_load" + suffix
		c.e.ensureDeclare(fmt.Sprintf("declare %s @%s(ptr)", llT, fn))
		t := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = call %s @%s(ptr %s)\n", t, llT, fn, handle)
		return Value{Name: t, Type: llT}, nil

	case "Store":
		if len(call.Args) != 1 {
			return Value{}, fmt.Errorf("%s: atomic.Store takes exactly 1 argument", call.Pos())
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

	case "CompareAndSwap":
		if len(call.Args) != 2 {
			return Value{}, fmt.Errorf("%s: atomic.CompareAndSwap takes exactly 2 arguments", call.Pos())
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
		t := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = call i64 @%s(ptr %s, %s %s, %s %s)\n",
			t, fn, handle, llT, oldV.Name, llT, newV.Name)
		return Value{Name: t, Type: "i64"}, nil
	}
	return Value{}, fmt.Errorf("%s: atomic has no method %q (expected Load, Store, Add, CompareAndSwap)",
		call.Pos(), method)
}

// emitMutexMethod handles m.Lock() / m.LockRead(). Both return guards
// that are only legal as the RHS of a `var v T = m.Lock()` /
// `m.LockRead()` declaration — that path is special-cased in emitVar
// (emitGuardVar). Direct calls in any other context are rejected.
// Unlock is gone: release happens automatically when the guard variable
// goes out of scope.
func (c *funcCtx) emitMutexMethod(call *ast.CallExpr, _ symbol, method string) (Value, error) {
	switch method {
	case "Lock":
		return Value{}, fmt.Errorf("%s: mutex.Lock() can only appear as the RHS of `var x T = m.Lock()` — the guard must bind to a variable so it can be auto-released at scope end", call.Pos())
	case "LockRead":
		return Value{}, fmt.Errorf("%s: mutex.LockRead() can only appear as the RHS of `var x T = m.LockRead()` — the guard must bind to a variable so it can be auto-released at scope end", call.Pos())
	case "Unlock":
		return Value{}, fmt.Errorf("%s: mutex.Unlock no longer exists — the lock releases automatically when the guard variable from `var x T = m.Lock()` goes out of scope", call.Pos())
	}
	return Value{}, fmt.Errorf("%s: mutex has no method %q (only Lock and LockRead are exposed; release is automatic)",
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

// emitOnceMethod handles o.Begin() and o.Done().
//   Begin()  — returns 1 on the FIRST caller (caller must Done() after init);
//              blocks every subsequent caller until Done() is called, then returns 0
//   Done()   — marks initialization complete; wakes everyone blocked in Begin()
func (c *funcCtx) emitOnceMethod(call *ast.CallExpr, recvSym symbol, method string) (Value, error) {
	handle := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", handle, recvSym.Ptr)

	switch method {
	case "Begin":
		if len(call.Args) != 0 {
			return Value{}, fmt.Errorf("%s: once.Begin takes no arguments", call.Pos())
		}
		c.e.ensureDeclare("declare i64 @volt_once_begin(ptr)")
		t := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = call i64 @volt_once_begin(ptr %s)\n", t, handle)
		return Value{Name: t, Type: "i64"}, nil

	case "Done":
		if len(call.Args) != 0 {
			return Value{}, fmt.Errorf("%s: once.Done takes no arguments", call.Pos())
		}
		c.e.ensureDeclare("declare void @volt_once_done(ptr)")
		fmt.Fprintf(&c.body, "  call void @volt_once_done(ptr %s)\n", handle)
		return Value{Name: "", Type: "void"}, nil
	}
	return Value{}, fmt.Errorf("%s: once has no method %q (expected Begin, Done)",
		call.Pos(), method)
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
		return Value{}, fmt.Errorf("%s: clone of slices not yet implemented", pos)
	case *ast.MapType:
		return Value{}, fmt.Errorf("%s: clone of maps not yet implemented", pos)
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
	if _, isChan := sym.AstType.(*ast.ChanType); isChan {
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
	case "syscall.Exit":
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

func (c *funcCtx) emitUnqualifiedCall(call *ast.CallExpr, fn *ast.IdentExpr) (Value, error) {
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
