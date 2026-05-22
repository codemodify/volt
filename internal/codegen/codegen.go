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
}

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
		structs:  make(map[string]*structInfo),
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
		case *ast.TypeDecl:
			if st, ok := d.Type.(*ast.StructType); ok {
				idx := make(map[string]int, len(st.Fields))
				for i, f := range st.Fields {
					idx[f.Name] = i
				}
				e.structs[d.Name] = &structInfo{Fields: st.Fields, Index: idx}
			}
		}
	}

	fmt.Fprintf(&e.header, "; module: %s\n", file.Package)
	e.header.WriteString("target triple = \"x86_64-pc-linux-gnu\"\n\n")
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
		}
		// User-defined type (struct) declared in this file?
		if _, ok := e.structs[tt.Name]; ok {
			return "%" + tt.Name
		}
	case *ast.BorrowType, *ast.PointerType:
		return "ptr"
	case *ast.SliceType:
		return "%slice"
	case *ast.ChanType:
		// Channels are runtime-allocated; we carry an opaque ptr.
		return "ptr"
	}
	return "void"
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
		// Synthesize fall-through: run defers, then ret.
		if err := c.emitDefers(); err != nil {
			return err
		}
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
	Ptr       string // alloca pointer name (e.g., "%x.addr")
	Type      string // LLVM type stored at alloca (e.g., "i64", "%string", "%slice", "ptr")
	Elem      string // for borrow/pointer symbols: the pointee LLVM type
	SliceElem string // for %slice symbols: the LLVM element type
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
	loops      []loopFrame // innermost last
}

type loopFrame struct {
	breakLbl    string
	continueLbl string
}

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
	case *ast.MultiVarStmt:
		return c.emitMultiVar(s)
	case *ast.MultiAssignStmt:
		return c.emitMultiAssign(s)
	case *ast.BreakStmt:
		if len(c.loops) == 0 {
			return fmt.Errorf("%s: break outside loop", s.Pos())
		}
		fmt.Fprintf(&c.body, "  br label %%%s\n", c.loops[len(c.loops)-1].breakLbl)
		c.terminated = true
		return nil
	case *ast.ContinueStmt:
		if len(c.loops) == 0 {
			return fmt.Errorf("%s: continue outside loop", s.Pos())
		}
		fmt.Fprintf(&c.body, "  br label %%%s\n", c.loops[len(c.loops)-1].continueLbl)
		c.terminated = true
		return nil
	}
	return fmt.Errorf("%s: unsupported statement %T", s.Pos(), s)
}

// emitMultiVar handles `a, b := foo()` where foo() returns multiple values.
func (c *funcCtx) emitMultiVar(s *ast.MultiVarStmt) error {
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
func (c *funcCtx) emitMultiAssign(s *ast.MultiAssignStmt) error {
	agg, fieldTypes, err := c.emitMultiReturnCall(s.RHS)
	if err != nil {
		return err
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

// emitRun lowers `run f()`, `run f(x)`, or `run f(x, y)` to
// volt_spawn(@f, arg1, arg2). v0.5 supports up to two ptr-sized args
// (typically chan/borrow handles). Closures and >2-arg goroutines come
// later — pack into a struct if you need more.
func (c *funcCtx) emitRun(s *ast.RunStmt) error {
	id, ok := s.Call.Fun.(*ast.IdentExpr)
	if !ok {
		return fmt.Errorf("%s: `run` requires a bare function name in v0.5", s.Pos())
	}
	sig, ok := c.e.funcs[id.Name]
	if !ok {
		return fmt.Errorf("%s: undefined function %q", s.Pos(), id.Name)
	}
	if len(sig.Params) > 2 {
		return fmt.Errorf("%s: `run` supports at most 2 args in v0.5", s.Pos())
	}
	if len(s.Call.Args) != len(sig.Params) {
		return fmt.Errorf("%s: %s takes %d arg(s), got %d",
			s.Pos(), id.Name, len(sig.Params), len(s.Call.Args))
	}
	args := []string{"null", "null"}
	for i, expr := range s.Call.Args {
		v, err := c.emitCallArg(expr, sig.Params[i].Type)
		if err != nil {
			return err
		}
		args[i] = v.Name
	}
	mangled := SymbolName(c.e.pkg, id.Name)
	c.e.ensureDeclare("declare void @volt_spawn(ptr, ptr, ptr)")
	fmt.Fprintf(&c.body, "  call void @volt_spawn(ptr @%s, ptr %s, ptr %s)\n",
		mangled, args[0], args[1])
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

func (c *funcCtx) emitVar(s *ast.VarStmt) error {
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
	c.symbols[s.Name] = symbol{Ptr: ptr, Type: typeStr, Elem: elem, SliceElem: sliceElem}
	return nil
}

func (c *funcCtx) emitAssign(s *ast.AssignStmt) error {
	switch lhs := s.LHS.(type) {
	case *ast.IdentExpr:
		return c.emitIdentAssign(lhs, s.RHS)
	case *ast.SelectorExpr:
		return c.emitFieldAssign(lhs, s.RHS)
	}
	return fmt.Errorf("%s: assignment target must be a variable or field access", s.LHS.Pos())
}

func (c *funcCtx) emitIdentAssign(lhs *ast.IdentExpr, rhsExpr ast.Expr) error {
	sym, ok := c.symbols[lhs.Name]
	if !ok {
		return fmt.Errorf("%s: undefined variable %q", lhs.Pos(), lhs.Name)
	}
	val, err := c.emitExpr(rhsExpr)
	if err != nil {
		return err
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
	for _, stmt := range s.Then.Stmts {
		if err := c.emitStmt(stmt); err != nil {
			return err
		}
	}
	thenTerm := c.terminated
	if !thenTerm {
		fmt.Fprintf(&c.body, "  br label %%%s\n", endLbl)
		c.terminated = true
	}

	elseTerm := true
	if s.Else != nil {
		c.startBlock(elseLbl)
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
			fmt.Fprintf(&c.body, "  br label %%%s\n", endLbl)
			c.terminated = true
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
	}
	endLbl := c.newLabel("for.end")

	// Make break/continue inside the body target this loop.
	c.loops = append(c.loops, loopFrame{breakLbl: endLbl, continueLbl: postLbl})
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
	for _, stmt := range s.Body.Stmts {
		if err := c.emitStmt(stmt); err != nil {
			return err
		}
	}
	if !c.terminated {
		fmt.Fprintf(&c.body, "  br label %%%s\n", postLbl)
		c.terminated = true
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

	if s.Cond != nil {
		c.startBlock(endLbl)
	}
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

// emitNew lowers `new T{...}` (struct composite literal) or `new T()` to
// an SSA struct value built via insertvalue. The result is an owned T —
// the caller (typically a var declaration) puts it in storage.
func (c *funcCtx) emitNew(ex *ast.NewExpr) (Value, error) {
	// Special-case: `new chan T(capacity)` → runtime call.
	if _, ok := ex.Type.(*ast.ChanType); ok {
		var capVal Value
		if len(ex.Args) > 0 {
			v, err := c.emitExpr(ex.Args[0])
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

	nt, ok := ex.Type.(*ast.NamedType)
	if !ok {
		return Value{}, fmt.Errorf("%s: `new` only supports named or chan types in v0.5", ex.Pos())
	}
	info, ok := c.e.structs[nt.Name]
	if !ok {
		return Value{}, fmt.Errorf("%s: unknown type %s", ex.Pos(), nt.Name)
	}
	llT := "%" + nt.Name

	// Determine each field's value: from a key in Pairs, or zero-default.
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
			// Default for unspecified field.
			v = zeroValue(fieldT)
		}
		t := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = insertvalue %s %s, %s %s, %d\n",
			t, llT, prev, fieldT, v.Name, i)
		prev = t
	}
	// `prev` now holds the fully-populated struct.
	return Value{Name: prev, Type: llT}, nil
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
		}
		return c.emitUnqualifiedCall(call, fn)
	}
	return Value{}, fmt.Errorf("%s: unsupported call form", call.Pos())
}

// emitBuiltinLen lowers `len(x)` where x is a slice or string.
func (c *funcCtx) emitBuiltinLen(call *ast.CallExpr) (Value, error) {
	if len(call.Args) != 1 {
		return Value{}, fmt.Errorf("%s: len takes exactly 1 argument", call.Pos())
	}
	arg, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	if arg.Type != "%slice" && arg.Type != "%string" {
		return Value{}, fmt.Errorf("%s: len() requires a slice or string, got %s", call.Pos(), arg.Type)
	}
	t := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = extractvalue %s %s, 1\n", t, arg.Type, arg.Name)
	return Value{Name: t, Type: "i64"}, nil
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
