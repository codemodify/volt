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
	"strconv"
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
	// Concrete is the named struct type T when this value is a concrete
	// `*T` pointer (Type == "ptr"). It lets interface boxing tell a
	// concrete `*T` (which must be wrapped in a {data,vtable} fat pointer)
	// apart from an already-boxed interface value — both lower to "ptr".
	// Empty for non-pointers and for already-boxed interfaces.
	Concrete string
	// ConcretePkg is the package that OWNS Concrete's type (declares its
	// methods/vtable). It disambiguates same-named types across packages
	// (volt's type namespace is global), so interface boxing references the
	// right package-qualified vtable. Empty = resolve via vtableOwner.
	ConcretePkg string
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
	// extPkgs gives the codegen access to cross-package function
	// signatures so emitMultiReturnCall / emitForeignCall can mangle
	// the right symbol and produce the right aggregate return type.
	extPkgs    map[string]map[string]*ast.FuncDecl // pkg → func name → decl
	// extConsts: cross-package top-level `const Name = expr` decls.
	// Substituted at the use site by emitFieldAccess when a user
	// writes `pkg.Name` for a known const.
	extConsts  map[string]map[string]ast.Expr // pkg → name → value expr
	// extMethods: cross-package method registry. Keyed by typeName,
	// then methodName, with a SLICE of entries because multiple
	// packages may legitimately declare a type with the same bare
	// name (e.g. bytes.Builder and strings.Builder both have
	// WriteByte). Lookups disambiguate via the receiver type's
	// Package qualifier when present (see lookupExtMethod). BUG.4.
	extMethods map[string]map[string][]*extMethodEntry
	// typeOwningPkg: typeName → pkgName that declared the struct.
	// Used to mangle method symbols when calling cross-package
	// methods. When multiple packages share a bare typeName, the
	// caller is expected to pass the receiver's Package qualifier
	// through the lookup paths instead of relying on this map.
	typeOwningPkg map[string]string
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
	// nextThunkID names per-call-site `run` thunks + pack structs when
	// the spawn path needs to heap-box oversized args.
	nextThunkID int
	// errorsStrerrorEmitted: gates one-time emission of the shared
	// %string @volt_errors_strerror(ptr) helper that errors.New points at.
	errorsStrerrorEmitted bool
	// Optional LLVM target triple. When empty, no `target triple` line
	// is emitted — clang `--target=` then governs.
	targetTriple string

	// Source file path used in DWARF !DIFile metadata. If empty, the
	// module emits no DI metadata. Set via SetSourceFile.
	sourceFile string

	// raceEnabled gates emission of `-race` instrumentation. When true,
	// main() gets a leading volt_race_enable() call and every channel /
	// mutex / atomic op gets paired volt_race_acquire/release calls.
	// Memory-access instrumentation around generic loads/stores is
	// future work; the sync-op instrumentation already catches the most
	// common races (unprotected access to data published through a
	// channel and read on the other side without synchronizing).
	raceEnabled bool

	// memProfilePath, when non-empty, makes main() inject a leading
	// volt_runtime_memprofile_set_path(path) call. The runtime's
	// _start epilogue (volt_runtime_at_program_exit) then dumps the
	// allocation profile to this path at process exit. Set by
	// `volt build --memprofile <path>`.
	memProfilePath string

	// Subprograms emitted alongside `define` lines for the DI metadata
	// block at module end. Each entry maps a metadata-id → DISubprogram
	// describing one volt function.
	subprograms []subprogramDI
	// Counter for per-statement DILocation ids (one per discovered
	// (function, source line) pair). Ids start at 300001.
	dbgLocNext int
	// Counter for !DILocalVariable ids. Starts at 500001 — well above
	// the subprogram (1000+) and DILocation (300000+) pools.
	dbgVarNext int
	// DI type metadata cache: LLVM type → metadata id (700000+ for
	// primitives, 800000+ for composite types).
	dbgTypes    map[string]int
	dbgTypeNext int
}

type subprogramDI struct {
	metaID    int // DISubprogram id
	locMetaID int // shared DILocation id (scope = this DISubprogram, line = decl line)
	name      string
	linkage   string
	line      int
	// lineLocs maps source line → DILocation metadata id, materialized
	// lazily by locForLine when the post-pass attaches !dbg to a call.
	lineLocs map[int]int
	// locals are the DILocalVariable entries we've allocated for this
	// function — both parameters (argNum > 0) and locals (argNum == 0).
	locals []dbgVar
}

// dbgVar records the bookkeeping for one !DILocalVariable in a
// function's DI block. The variable's DI type is resolved via
// `Emitter.dbgTypeFor(llvmType)` at metadata-emission time, so
// primitives get distinct DIBasicType nodes and `%string` becomes a
// proper DICompositeType (ptr + len) that gdb can pretty-print.
type dbgVar struct {
	metaID int
	name   string
	line   int
	argNum int    // 1+ for parameters in declaration order, 0 for locals
	llType string // LLVM type for resolving the DI type at tail-emit time
}

// nextDbgVarID hands out fresh !DILocalVariable metadata ids from a
// dedicated 500000+ pool, so we don't collide with subprograms (1000+),
// DILocations (300000+), or the fixed `!0`..`!2`/`!200`/`!201` slots.
func (e *Emitter) nextDbgVarID() int {
	e.dbgVarNext++
	return 500000 + e.dbgVarNext
}

// dbgTypeFor returns the metadata id for the DI type representing the
// given LLVM type. Reuses cached ids; allocates from a 700000+ pool
// for primitives (i1/i8/.../double/float/ptr) and a 800000+ pool for
// composite types (%string, %slice, etc.). The actual DI*Type literals
// are emitted in the DI metadata tail by `dbgTypeEmit`.
func (e *Emitter) dbgTypeFor(llT string) int {
	if e.dbgTypes == nil {
		e.dbgTypes = make(map[string]int)
	}
	if id, ok := e.dbgTypes[llT]; ok {
		return id
	}
	switch llT {
	case "%string":
		// Composite gets a member type allocated for the byte-pointer
		// (DIDerivedType pointer to i8). Reserve member-ids in 850000+.
		e.dbgTypeNext++
		id := 800000 + e.dbgTypeNext
		e.dbgTypes[llT] = id
		return id
	case "%slice":
		e.dbgTypeNext++
		id := 800000 + e.dbgTypeNext
		e.dbgTypes[llT] = id
		return id
	}
	e.dbgTypeNext++
	id := 700000 + e.dbgTypeNext
	e.dbgTypes[llT] = id
	return id
}

// dbgTypeEmit writes the DI type literal for a (llvmType, id) pair to
// the metadata tail. Called once per cached entry.
func (e *Emitter) dbgTypeEmit(out *strings.Builder, llT string, id int) {
	switch llT {
	case "i1":
		fmt.Fprintf(out, "!%d = !DIBasicType(name: \"bool\", size: 8, encoding: DW_ATE_boolean)\n", id)
	case "i8":
		fmt.Fprintf(out, "!%d = !DIBasicType(name: \"byte\", size: 8, encoding: DW_ATE_unsigned_char)\n", id)
	case "i16":
		fmt.Fprintf(out, "!%d = !DIBasicType(name: \"int16\", size: 16, encoding: DW_ATE_signed)\n", id)
	case "i32":
		fmt.Fprintf(out, "!%d = !DIBasicType(name: \"int32\", size: 32, encoding: DW_ATE_signed)\n", id)
	case "i64":
		fmt.Fprintf(out, "!%d = !DIBasicType(name: \"int\", size: 64, encoding: DW_ATE_signed)\n", id)
	case "double":
		fmt.Fprintf(out, "!%d = !DIBasicType(name: \"float64\", size: 64, encoding: DW_ATE_float)\n", id)
	case "float":
		fmt.Fprintf(out, "!%d = !DIBasicType(name: \"float32\", size: 32, encoding: DW_ATE_float)\n", id)
	case "ptr":
		fmt.Fprintf(out, "!%d = !DIBasicType(name: \"ptr\", size: 64, encoding: DW_ATE_address)\n", id)
	case "%string":
		// Backing: { ptr, i64 }. Pretty-print friendly: gdb shows the
		// struct fields; with a pretty-printer script the ptr+len pair
		// could render as the actual byte content.
		ptrID := id + 5000  // i8* member type id
		ptrMemID := id + 5100
		lenMemID := id + 5200
		fmt.Fprintf(out, "!%d = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: !%d, size: 64)\n",
			ptrID, e.dbgTypeFor("i8"))
		fmt.Fprintf(out, "!%d = !DIDerivedType(tag: DW_TAG_member, name: \"ptr\", baseType: !%d, size: 64, offset: 0)\n",
			ptrMemID, ptrID)
		fmt.Fprintf(out, "!%d = !DIDerivedType(tag: DW_TAG_member, name: \"len\", baseType: !%d, size: 64, offset: 64)\n",
			lenMemID, e.dbgTypeFor("i64"))
		fmt.Fprintf(out, "!%d = !DICompositeType(tag: DW_TAG_structure_type, name: \"string\", size: 128, elements: !{!%d, !%d})\n",
			id, ptrMemID, lenMemID)
	case "%slice":
		ptrID := id + 5000
		ptrMemID := id + 5100
		lenMemID := id + 5200
		capMemID := id + 5300
		fmt.Fprintf(out, "!%d = !DIDerivedType(tag: DW_TAG_pointer_type, baseType: !%d, size: 64)\n",
			ptrID, e.dbgTypeFor("i8"))
		fmt.Fprintf(out, "!%d = !DIDerivedType(tag: DW_TAG_member, name: \"ptr\", baseType: !%d, size: 64, offset: 0)\n",
			ptrMemID, ptrID)
		fmt.Fprintf(out, "!%d = !DIDerivedType(tag: DW_TAG_member, name: \"len\", baseType: !%d, size: 64, offset: 64)\n",
			lenMemID, e.dbgTypeFor("i64"))
		fmt.Fprintf(out, "!%d = !DIDerivedType(tag: DW_TAG_member, name: \"cap\", baseType: !%d, size: 64, offset: 128)\n",
			capMemID, e.dbgTypeFor("i64"))
		fmt.Fprintf(out, "!%d = !DICompositeType(tag: DW_TAG_structure_type, name: \"slice\", size: 192, elements: !{!%d, !%d, !%d})\n",
			id, ptrMemID, lenMemID, capMemID)
	default:
		// Fallback: treat as opaque 64-bit unsigned (likely a pointer or
		// boxed handle). User sees the raw integer in gdb.
		fmt.Fprintf(out, "!%d = !DIBasicType(name: %q, size: 64, encoding: DW_ATE_unsigned)\n",
			id, llT)
	}
}

// locForLine returns the metadata id for a !DILocation scoped to the
// given function's DISubprogram and at the given source line. Pulls
// from the per-function cache or allocates a fresh id from a separate
// pool (300000+); the actual DILocation literals are emitted in the
// module's DI metadata tail.
func (e *Emitter) locForLine(spIdx, line int) int {
	if spIdx < 0 || spIdx >= len(e.subprograms) {
		return e.subprograms[spIdx].locMetaID
	}
	sp := &e.subprograms[spIdx]
	if sp.lineLocs == nil {
		sp.lineLocs = make(map[int]int)
	}
	if id, ok := sp.lineLocs[line]; ok {
		return id
	}
	e.dbgLocNext++
	id := 300000 + e.dbgLocNext
	sp.lineLocs[line] = id
	return id
}

// SetTarget sets the LLVM target triple for the emitted module.
func (e *Emitter) SetTarget(triple string) { e.targetTriple = triple }

// SetSourceFile gives the emitter the original source path so it can
// emit DWARF !DIFile/!DISubprogram metadata. Empty path disables DI.
func (e *Emitter) SetSourceFile(path string) { e.sourceFile = path }

// SetRaceEnabled toggles `-race` instrumentation. When on, main() gets
// a leading volt_race_enable() and every channel send/recv, mutex
// Lock/Unlock, and atomic Read/Write/Add/CompSwap is bracketed with
// volt_race_acquire / volt_race_release calls so the runtime can build
// the happens-before graph.
func (e *Emitter) SetRaceEnabled(on bool) { e.raceEnabled = on }

// SetMemProfilePath enables memory-profile auto-dump. When set, main()
// injects a volt_runtime_memprofile_set_path(path) call so the runtime
// flushes the allocation profile to `path` at process exit.
func (e *Emitter) SetMemProfilePath(path string) { e.memProfilePath = path }

// structInfo carries field ordering + name→index for a struct type.
type structInfo struct {
	Fields   []*ast.Field
	Index    map[string]int
	External bool // imported from another package via AddExternal
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
		extPkgs:        make(map[string]map[string]*ast.FuncDecl),
		extConsts:      make(map[string]map[string]ast.Expr),
		extMethods:     make(map[string]map[string][]*extMethodEntry),
		typeOwningPkg:  make(map[string]string),
	}
}

// AddExternal registers another package's function + method
// signatures and struct types so codegen can resolve cross-package
// calls (free functions AND methods) without re-parsing.
func (e *Emitter) AddExternal(pkgName string, file *ast.File) {
	if e.extPkgs[pkgName] == nil {
		e.extPkgs[pkgName] = make(map[string]*ast.FuncDecl)
	}
	for _, d := range file.Decls {
		switch dd := d.(type) {
		case *ast.ConstDecl:
			if e.extConsts[pkgName] == nil {
				e.extConsts[pkgName] = make(map[string]ast.Expr)
			}
			e.extConsts[pkgName][dd.Name] = dd.Value
		case *ast.FuncDecl:
			if dd.Receiver == nil {
				// Free function.
				e.extPkgs[pkgName][dd.Name] = dd
				continue
			}
			// Method. Register under the receiver type name.
			recvType := dd.ReceiverTypeName()
			if recvType == "" {
				continue
			}
			if e.extMethods[recvType] == nil {
				e.extMethods[recvType] = make(map[string][]*extMethodEntry)
			}
			// Append rather than overwrite — multiple packages may
			// declare a same-named type with the same method name
			// (BUG.4). Lookups disambiguate via the receiver type's
			// Package qualifier.
			e.extMethods[recvType][dd.Name] = append(
				e.extMethods[recvType][dd.Name],
				&extMethodEntry{pkg: pkgName, decl: dd},
			)
		case *ast.TypeDecl:
			// Track which package owns each struct type, and merge the
			// type layout into our struct registry so llvmType can
			// resolve cross-package struct names (used in method
			// receivers, multi-return aggregates, etc.).
			if st, ok := dd.Type.(*ast.StructType); ok {
				e.typeOwningPkg[dd.Name] = pkgName
				if e.structs[dd.Name] == nil {
					idx := make(map[string]int, len(st.Fields))
					for i, f := range st.Fields {
						idx[f.Name] = i
					}
					e.structs[dd.Name] = &structInfo{Fields: st.Fields, Index: idx, External: true}
				}
			}
			// Cross-package interfaces: register the declaration so
			// `iface.RefName` resolves and dispatch finds method index +
			// signature.
			if it, ok := dd.Type.(*ast.InterfaceType); ok {
				e.interfaces[dd.Name] = true
				if e.interfaceDecls[dd.Name] == nil {
					e.interfaceDecls[dd.Name] = it
				}
			}
		}
	}
}

// methodSymbol mangles a method's LLVM symbol: <pkg>_<TypeName>_<MethodName>.
func methodSymbol(pkg, typeName, method string) string {
	return pkg + "_" + typeName + "_" + method
}

// vtableOwner returns the package that emits `tn`'s interface vtables (and
// owns its method symbols): the CURRENT package when tn is declared
// locally (it has local methods here), else the recorded owning package,
// else the current package. Using local methods rather than typeOwningPkg
// is robust against the global type-namespace clobbering that happens when
// two packages declare a same-named type (e.g. bytes.Builder vs
// strings.Builder) — each package then correctly owns its own vtable.
func (e *Emitter) vtableOwner(tn string) string {
	if e.isLocalType(tn) {
		return e.pkg
	}
	if o := e.typeOwningPkg[tn]; o != "" {
		return o
	}
	return e.pkg
}

// isLocalType reports whether `tn` is declared in the package currently
// being emitted — it has local methods OR a locally-registered (non-
// External) struct entry (the local Emit pass overwrites any external one).
// Robust against the global type-namespace clobbering of typeOwningPkg.
func (e *Emitter) isLocalType(tn string) bool {
	if len(e.methods[tn]) > 0 {
		return true
	}
	if si := e.structs[tn]; si != nil && !si.External {
		return true
	}
	return false
}

// lookupExtMethod resolves a cross-package method by (typeName,
// methodName, preferPkg). When preferPkg is non-empty, returns the
// entry whose pkg matches it (or nil if no such entry). When
// preferPkg is empty, returns the first registered entry — preserves
// legacy single-entry behavior for callers that don't carry a
// package qualifier. BUG.4: multiple packages can register methods
// on the same bare typeName; the receiver's AST Package qualifier
// is what disambiguates them.
func (e *Emitter) lookupExtMethod(typeName, methodName, preferPkg string) *extMethodEntry {
	ms, ok := e.extMethods[typeName]
	if !ok {
		return nil
	}
	entries, ok := ms[methodName]
	if !ok || len(entries) == 0 {
		return nil
	}
	if preferPkg != "" {
		for _, ent := range entries {
			if ent.pkg == preferPkg {
				return ent
			}
		}
		return nil
	}
	return entries[0]
}

// firstExtMethod returns the first (legacy) entry on a (typeName,
// methodName) slot, or nil. Use only when the caller has no package
// qualifier to disambiguate — equivalent to the pre-BUG.4 lookup.
func (e *Emitter) firstExtMethod(typeName, methodName string) *extMethodEntry {
	return e.lookupExtMethod(typeName, methodName, "")
}

// extMethodEntry records a method imported from another package along
// with the owning-package name so we can mangle its LLVM symbol via
// methodSymbol(owner, typeName, methodName).
type extMethodEntry struct {
	pkg  string
	decl *ast.FuncDecl
}

// methodMatchesIfaceSig reports whether `concrete`'s parameter list +
// return list structurally matches the interface method type `ift`.
// Used to enforce signature-strict interface satisfaction: a method
// with the right name but wrong signature doesn't count as
// implementing the interface.
func methodMatchesIfaceSig(concrete *ast.FuncDecl, ift *ast.FuncType) bool {
	if len(concrete.Params) != len(ift.Params) {
		return false
	}
	for i, p := range concrete.Params {
		if !typesStructurallyEqual(p.Type, ift.Params[i].Type) {
			return false
		}
	}
	if len(concrete.Results) != len(ift.Results) {
		return false
	}
	for i, r := range concrete.Results {
		if !typesStructurallyEqual(r, ift.Results[i]) {
			return false
		}
	}
	return true
}

// typesStructurallyEqual compares two AST types by shape — same kind,
// same named-type names, same element/key/value types recursively.
// Source positions are ignored. Returns false on any structural
// mismatch.
func typesStructurallyEqual(a, b ast.Type) bool {
	if a == nil || b == nil {
		return a == nil && b == nil
	}
	switch ta := a.(type) {
	case *ast.NamedType:
		tb, ok := b.(*ast.NamedType)
		return ok && ta.Name == tb.Name
	case *ast.PointerType:
		tb, ok := b.(*ast.PointerType)
		return ok && typesStructurallyEqual(ta.Elem, tb.Elem)
	case *ast.BorrowType:
		tb, ok := b.(*ast.BorrowType)
		return ok && typesStructurallyEqual(ta.Elem, tb.Elem)
	case *ast.SliceType:
		tb, ok := b.(*ast.SliceType)
		return ok && typesStructurallyEqual(ta.Elem, tb.Elem)
	case *ast.MapType:
		tb, ok := b.(*ast.MapType)
		return ok && typesStructurallyEqual(ta.Key, tb.Key) && typesStructurallyEqual(ta.Value, tb.Value)
	case *ast.ChanType:
		tb, ok := b.(*ast.ChanType)
		return ok && typesStructurallyEqual(ta.Elem, tb.Elem)
	}
	return false
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
		// Qualifier in user code is the path's last segment, not the
		// full path: `import "example.com/greeter"` exposes `greeter.X`.
		// Stdlib paths like "log" or "fmt" have no slash, so basename
		// equals the full path — backward compatible.
		name := im.Path
		if i := strings.LastIndex(im.Path, "/"); i >= 0 {
			name = im.Path[i+1:]
		}
		e.imported[name] = true
	}
	// Track per-file duplicate-decl detection. Each name lives in
	// exactly one of these namespaces per the volt model:
	//   - funcs / methods (top-level vs (T).Method)
	//   - consts
	//   - types (structs + interfaces share a namespace)
	// Duplicate names within a namespace previously silently
	// overwrote (consts) or surfaced as a cryptic clang IR
	// `invalid redefinition` error (funcs); now surface volt-level.
	seenFuncs := make(map[string]lex.Pos)
	seenMethods := make(map[string]map[string]lex.Pos)
	seenConsts := make(map[string]lex.Pos)
	seenTypes := make(map[string]lex.Pos)
	// crossNs maps every top-level identifier (fun / const / type
	// names share a flat namespace at file scope, because emitIdent
	// looks them up in a single sequence: consts → funcs → symbols)
	// to its first-sighting position. Catches function-vs-const
	// shadowing that otherwise resolves silently at use-site based on
	// lookup order.
	crossNs := make(map[string]lex.Pos)
	checkCrossNs := func(name string, pos lex.Pos, kind string) error {
		if prev, ok := crossNs[name]; ok {
			return fmt.Errorf("%s: %s %q collides with earlier top-level declaration (first at %s)",
				pos, kind, name, prev)
		}
		crossNs[name] = pos
		return nil
	}
	for _, d := range file.Decls {
		switch d := d.(type) {
		case *ast.FuncDecl:
			if d.Receiver != nil {
				tn := d.ReceiverTypeName()
				if seenMethods[tn] == nil {
					seenMethods[tn] = make(map[string]lex.Pos)
				}
				if prev, ok := seenMethods[tn][d.Name]; ok {
					return "", fmt.Errorf("%s: method (%s).%s redeclared (first at %s)",
						d.P, tn, d.Name, prev)
				}
				seenMethods[tn][d.Name] = d.P
				if e.methods[tn] == nil {
					e.methods[tn] = make(map[string]*ast.FuncDecl)
				}
				e.methods[tn][d.Name] = d
			} else {
				if prev, ok := seenFuncs[d.Name]; ok {
					return "", fmt.Errorf("%s: function %q redeclared (first at %s)",
						d.P, d.Name, prev)
				}
				if err := checkCrossNs(d.Name, d.P, "function"); err != nil {
					return "", err
				}
				seenFuncs[d.Name] = d.P
				e.funcs[d.Name] = d
			}
		case *ast.ConstDecl:
			if prev, ok := seenConsts[d.Name]; ok {
				return "", fmt.Errorf("%s: constant %q redeclared (first at %s)",
					d.P, d.Name, prev)
			}
			if err := checkCrossNs(d.Name, d.P, "constant"); err != nil {
				return "", err
			}
			seenConsts[d.Name] = d.P
			e.consts[d.Name] = d.Value
		case *ast.TypeDecl:
			if prev, ok := seenTypes[d.Name]; ok {
				return "", fmt.Errorf("%s: type %q redeclared (first at %s)",
					d.P, d.Name, prev)
			}
			if err := checkCrossNs(d.Name, d.P, "type"); err != nil {
				return "", err
			}
			seenTypes[d.Name] = d.P
			switch td := d.Type.(type) {
			case *ast.StructType:
				// Duplicate-field check: the user can write
				// `type T struct { x int; x int }` and the second `x`
				// silently overwrites the first in the field-index map.
				fieldPos := make(map[string]lex.Pos, len(td.Fields))
				for _, f := range td.Fields {
					if prev, ok := fieldPos[f.Name]; ok {
						return "", fmt.Errorf("%s: struct %q has duplicate field %q (first at %s)",
							f.P, d.Name, f.Name, prev)
					}
					fieldPos[f.Name] = f.P
				}
				idx := make(map[string]int, len(td.Fields))
				for i, f := range td.Fields {
					idx[f.Name] = i
				}
				e.structs[d.Name] = &structInfo{Fields: td.Fields, Index: idx}
			case *ast.InterfaceType:
				// Duplicate-method check: `interface { Foo() int; Foo() string }`
				// silently registered both, then the impl scan picked whichever
				// came last — a subtle source of "type does not implement" surprises.
				methodPos := make(map[string]lex.Pos, len(td.Methods))
				for _, m := range td.Methods {
					if prev, ok := methodPos[m.Name]; ok {
						return "", fmt.Errorf("%s: interface %q has duplicate method %q (first at %s)",
							m.P, d.Name, m.Name, prev)
					}
					methodPos[m.Name] = m.P
					// Duplicate-parameter check on the method signature.
					// Mirrors the FuncDecl check from Pass 154 but applied
					// inside interface method-type declarations.
					if mft, ok := m.Type.(*ast.FuncType); ok {
						paramPos := make(map[string]lex.Pos, len(mft.Params))
						for _, p := range mft.Params {
							if p.Name == "" {
								continue
							}
							if prev, ok := paramPos[p.Name]; ok {
								return "", fmt.Errorf("%s: interface %q method %q has duplicate parameter %q (first at %s)",
									p.P, d.Name, m.Name, p.Name, prev)
							}
							paramPos[p.Name] = p.P
						}
					}
				}
				e.interfaces[d.Name] = true
				e.interfaceDecls[d.Name] = td
			}
		}
	}

	// All structs / interfaces are registered now, so cross-references
	// from func signatures, struct fields, and method receivers can
	// be validated against the type universe. Catches unknown-type
	// references at the declaration site (e.g. `fun f(x Foo)`,
	// `type T struct { ref Pont }`) before they propagate.
	for _, d := range file.Decls {
		switch d := d.(type) {
		case *ast.FuncDecl:
			// Duplicate-parameter check: `fun f(a int, a int)` used to
			// lower to `define i64 @f(i64 %a, i64 %a)` which clang
			// rejects as `redefinition of argument '%a'`.
			paramPos := make(map[string]lex.Pos, len(d.Params))
			for _, p := range d.Params {
				if p.Name == "" {
					continue
				}
				if prev, ok := paramPos[p.Name]; ok {
					return "", fmt.Errorf("%s: function %q has duplicate parameter %q (first at %s)",
						p.P, d.Name, p.Name, prev)
				}
				paramPos[p.Name] = p.P
				if err := e.validateNamedType(p.Type); err != nil {
					return "", err
				}
			}
			for _, r := range d.Results {
				if err := e.validateNamedType(r); err != nil {
					return "", err
				}
			}
			if d.Receiver != nil {
				if err := e.validateNamedType(d.Receiver.Type); err != nil {
					return "", err
				}
			}
		case *ast.TypeDecl:
			if st, ok := d.Type.(*ast.StructType); ok {
				for _, f := range st.Fields {
					if err := e.validateNamedType(f.Type); err != nil {
						return "", err
					}
				}
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
	// Interface implementation check: a type implements an interface
	// iff every method declared on the interface exists on the type
	// with a matching signature (param types + result types). Both
	// local methods (e.methods) and cross-package methods
	// (e.extMethods) are eligible.
	for ifaceName, iface := range e.interfaceDecls {
		// Build the candidate type set: every declared struct, plus
		// every type that owns at least one method (local or
		// cross-package). Without including methodless structs, a
		// zero-method `interface {}` wouldn't recognize a methodless
		// type as satisfying it — even though every type trivially
		// implements an empty method set.
		typeNames := map[string]bool{}
		for tn := range e.structs {
			typeNames[tn] = true
		}
		for tn := range e.methods {
			typeNames[tn] = true
		}
		for tn := range e.extMethods {
			typeNames[tn] = true
		}
		for tn := range typeNames {
			// A type declared locally owns its FULL method set here; do NOT
			// fall back to a same-named external type's methods (volt's
			// global type namespace would otherwise let bytes.Builder's
			// Write make strings.Builder "implement" io.Writer, or let a
			// methodless local type borrow a stdlib type's methods —
			// emitting a vtable for a method it lacks).
			isLocalType := e.isLocalType(tn)
			ok := true
			for _, mDecl := range iface.Methods {
				ift, isFt := mDecl.Type.(*ast.FuncType)
				var concrete *ast.FuncDecl
				if m, exists := e.methods[tn]; exists {
					concrete = m[mDecl.Name]
				}
				if concrete == nil && !isLocalType {
					if ext := e.firstExtMethod(tn, mDecl.Name); ext != nil {
						concrete = ext.decl
					}
				}
				if concrete == nil {
					ok = false
					break
				}
				if isFt && !methodMatchesIfaceSig(concrete, ift) {
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

	// Cycle check: struct fields are inlined by value, so a struct
	// that directly contains itself (without `*T` or `&T`
	// indirection) is an infinite size. LLVM rejects this with a
	// cryptic `identified structure type 'X' is recursive` error from
	// the first define line. Surface it at the source position with a
	// friendly message before emission.
	if container, fieldType, pos := e.findStructValueCycle(file); container != "" {
		return "", fmt.Errorf("%s: struct %q contains a field of type %q by value — recursive structs need `*T` (pointer) or `&T` (borrow) indirection",
			pos, container, fieldType)
	}

	// Emit named struct types. The order from the source file is preserved.
	emittedStructs := make(map[string]bool)
	for _, d := range file.Decls {
		td, ok := d.(*ast.TypeDecl)
		if !ok {
			continue
		}
		st, ok := td.Type.(*ast.StructType)
		if !ok {
			continue
		}
		emittedStructs[td.Name] = true
		fmt.Fprintf(&e.header, "%%%s = type { ", td.Name)
		for i, f := range st.Fields {
			if i > 0 {
				e.header.WriteString(", ")
			}
			e.header.WriteString(e.llvmType(f.Type))
		}
		e.header.WriteString(" }\n")
	}
	// Also emit cross-package struct types registered via AddExternal so
	// the IR can mention `%T` in declares / calls / method receivers for
	// imported types (e.g. `%File` from package `os` referenced in main).
	for name, info := range e.structs {
		if !info.External || emittedStructs[name] {
			continue
		}
		fmt.Fprintf(&e.header, "%%%s = type { ", name)
		for i, f := range info.Fields {
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
	//
	// Cross-package: the vtable definition lives in the package that
	// owns the concrete type's methods (so the method symbols it
	// references actually `define` somewhere). Other packages that need
	// to reference the vtable will `declare external` it when they box.
	//
	// Value-receiver adapter: interface dispatch always passes the
	// boxed `ptr` as the receiver argument. Methods with a pointer
	// receiver consume that directly. Methods with a value receiver
	// (e.g. `fun (f File) Read()`) expect a `%File` value instead, so
	// we synthesize a `_$iface` trampoline that loads the value from
	// the ptr before forwarding. The vtable entry points at the
	// trampoline in that case.
	hasVtableDefined := false
	type ifaceTramp struct {
		typeName   string
		methodName string
		method     *ast.FuncDecl
	}
	var trampolines []ifaceTramp
	trampSeen := map[string]bool{}
	for tn, ifaces := range e.ifaceImpls {
		owner := e.vtableOwner(tn)
		if owner != e.pkg {
			continue
		}
		for ifaceName := range ifaces {
			iface := e.interfaceDecls[ifaceName]
			var entries []string
			for _, m := range iface.Methods {
				method := e.methods[tn][m.Name]
				if method == nil {
					if ent := e.firstExtMethod(tn, m.Name); ent != nil {
						method = ent.decl
					}
				}
				sym := methodSymbol(owner, tn, m.Name)
				if method != nil && method.Receiver != nil {
					if _, isPtr := method.Receiver.Type.(*ast.PointerType); !isPtr {
						if _, isBorrow := method.Receiver.Type.(*ast.BorrowType); !isBorrow {
							// Value receiver — needs trampoline.
							sym = sym + "_$iface"
							key := tn + "." + m.Name
							if !trampSeen[key] {
								trampSeen[key] = true
								trampolines = append(trampolines, ifaceTramp{tn, m.Name, method})
							}
						}
					}
				}
				entries = append(entries, "ptr @"+sym)
			}
			fmt.Fprintf(&e.header, "@%s_%s_%s_vtable = constant [%d x ptr] [%s]\n",
				owner, tn, ifaceName, len(entries), strings.Join(entries, ", "))
			hasVtableDefined = true
		}
	}
	if hasVtableDefined {
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

	// Emit value-receiver trampolines registered while building vtables.
	// Each trampoline takes (ptr recv, args...) — loads the receiver value
	// from the ptr, then forwards to the real method. Owner MUST match the
	// vtable-entry site (vtableOwner), not the clobber-prone typeOwningPkg —
	// trampolines are only registered while emitting a local type's vtable,
	// so this resolves to the current package.
	for _, t := range trampolines {
		owner := e.vtableOwner(t.typeName)
		sym := methodSymbol(owner, t.typeName, t.methodName)
		var retT string
		switch {
		case len(t.method.Results) == 0:
			retT = "void"
		case len(t.method.Results) == 1:
			retT = e.llvmType(t.method.Results[0])
		default:
			var sb strings.Builder
			sb.WriteByte('{')
			for i, r := range t.method.Results {
				if i > 0 {
					sb.WriteString(", ")
				}
				sb.WriteString(e.llvmType(r))
			}
			sb.WriteByte('}')
			retT = sb.String()
		}
		var paramSig []string
		var callArgs []string
		paramSig = append(paramSig, "ptr %recv")
		for i, p := range t.method.Params {
			pt := e.llvmType(p.Type)
			pname := fmt.Sprintf("%%a%d", i)
			paramSig = append(paramSig, pt+" "+pname)
			callArgs = append(callArgs, pt+" "+pname)
		}
		fmt.Fprintf(&body, "define %s @%s_$iface(%s) {\n", retT, sym, strings.Join(paramSig, ", "))
		body.WriteString("entry:\n")
		recvLL := "%" + t.typeName
		fmt.Fprintf(&body, "  %%v = load %s, ptr %%recv\n", recvLL)
		fullArgs := append([]string{recvLL + " %v"}, callArgs...)
		if retT == "void" {
			fmt.Fprintf(&body, "  call void @%s(%s)\n", sym, strings.Join(fullArgs, ", "))
			body.WriteString("  ret void\n")
		} else {
			fmt.Fprintf(&body, "  %%r = call %s @%s(%s)\n", retT, sym, strings.Join(fullArgs, ", "))
			fmt.Fprintf(&body, "  ret %s %%r\n", retT)
		}
		body.WriteString("}\n\n")
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
	// DWARF / debug-info metadata. Only emit when SetSourceFile gave us
	// a real path. Layout:
	//   !0  = DICompileUnit (lists subprograms via `retainedNodes`)
	//   !1  = DIFile
	//   !2  = DISubroutineType (shared — types: !{})
	//   !3  = retainedNodes tuple (all DISubprograms)
	//   !100..!100+N = DISubprogram per function
	//   !llvm.dbg.cu = !{!0}
	//   !llvm.module.flags = !{!200, !201}
	//   !200 = Dwarf Version 4
	//   !201 = Debug Info Version 3
	if e.sourceFile != "" {
		out.WriteString("\n; -- DWARF metadata --\n")
		absDir := "."
		// Strip any trailing slash first: a directory/package build path
		// like "./pkg/" would otherwise split to an EMPTY filename, which
		// LLVM rejects ("invalid filename" → it drops all debug info).
		src := strings.TrimRight(e.sourceFile, "/")
		base := src
		if i := strings.LastIndex(src, "/"); i >= 0 {
			absDir = src[:i]
			if absDir == "" {
				absDir = "/"
			}
			base = src[i+1:]
		}
		if base == "" {
			// Path was all slashes (or empty after trimming) — never emit
			// an empty DWARF filename.
			base = "main"
		}
		// Build retained-nodes tuple referencing every subprogram.
		var retained strings.Builder
		retained.WriteString("!{")
		for i, sp := range e.subprograms {
			if i > 0 {
				retained.WriteString(", ")
			}
			fmt.Fprintf(&retained, "!%d", sp.metaID)
		}
		retained.WriteString("}")

		fmt.Fprintf(&out, "!llvm.dbg.cu = !{!0}\n")
		fmt.Fprintf(&out, "!llvm.module.flags = !{!200, !201}\n")
		fmt.Fprintf(&out, "!0 = distinct !DICompileUnit(language: DW_LANG_C99, file: !1, producer: \"volt\", isOptimized: false, runtimeVersion: 0, emissionKind: FullDebug, retainedTypes: !{}, globals: !{})\n")
		fmt.Fprintf(&out, "!1 = !DIFile(filename: %q, directory: %q)\n", base, absDir)
		fmt.Fprintf(&out, "!2 = !DISubroutineType(types: !{})\n")
		fmt.Fprintf(&out, "!200 = !{i32 2, !\"Dwarf Version\", i32 4}\n")
		fmt.Fprintf(&out, "!201 = !{i32 2, !\"Debug Info Version\", i32 3}\n")
		for _, sp := range e.subprograms {
			line := sp.line
			if line <= 0 {
				line = 1
			}
			fmt.Fprintf(&out, "!%d = distinct !DISubprogram(name: %q, linkageName: %q, scope: !1, file: !1, line: %d, type: !2, scopeLine: %d, spFlags: DISPFlagDefinition, unit: !0)\n",
				sp.metaID, sp.name, sp.linkage, line, line)
			fmt.Fprintf(&out, "!%d = !DILocation(line: %d, column: 1, scope: !%d)\n",
				sp.locMetaID, line, sp.metaID)
			// Per-statement DILocations (one per source line touched
			// by a call inside this function).
			for srcLine, locID := range sp.lineLocs {
				fmt.Fprintf(&out, "!%d = !DILocation(line: %d, column: 1, scope: !%d)\n",
					locID, srcLine, sp.metaID)
			}
			// !DILocalVariable per parameter / local. Each variable's
			// `type:` resolves through `dbgTypeFor` for richer gdb
			// output (string shows as struct{ptr,len}, etc.).
			for _, v := range sp.locals {
				vline := v.line
				if vline <= 0 {
					vline = line
				}
				typeID := e.dbgTypeFor(v.llType)
				if v.argNum > 0 {
					fmt.Fprintf(&out, "!%d = !DILocalVariable(name: %q, arg: %d, scope: !%d, file: !1, line: %d, type: !%d)\n",
						v.metaID, v.name, v.argNum, sp.metaID, vline, typeID)
				} else {
					fmt.Fprintf(&out, "!%d = !DILocalVariable(name: %q, scope: !%d, file: !1, line: %d, type: !%d)\n",
						v.metaID, v.name, sp.metaID, vline, typeID)
				}
			}
		}
		// Emit all DI type metadata collected via dbgTypeFor. The
		// emission may itself reference more types (e.g. %string's
		// member-types `i8` and `i64`) via dbgTypeFor, which adds to
		// the map mid-iteration. Loop until stable.
		emittedTypes := make(map[string]bool)
		for {
			pending := []string{}
			for llT := range e.dbgTypes {
				if !emittedTypes[llT] {
					pending = append(pending, llT)
				}
			}
			if len(pending) == 0 {
				break
			}
			for _, llT := range pending {
				e.dbgTypeEmit(&out, llT, e.dbgTypes[llT])
				emittedTypes[llT] = true
			}
		}
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
		*ast.WaitgroupType, *ast.OnceType, *ast.CondvarType:
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

// scanMovedNames walks a function body and returns the set of local
// identifier names that appear in any context that potentially
// TRANSFERS OWNERSHIP. Used by A3 (slice/map auto-free) to decide
// which decls should register a free-at-scope-exit drop.
//
// Conservative includes (= "moved, skip auto-free"):
//   - argument to any CallExpr EXCEPT the built-in metadata helpers
//     (len/cap/chr/clone — they look at the value without consuming it)
//   - RHS of an AssignStmt or VarStmt (whole expression — i.e. the
//     target binding takes ownership)
//   - operand of a RetStmt
//   - argument to a RunStmt (parent → child handoff)
//
// Safe (NOT in the set):
//   - read-index s[i], assign-index s[i] = v
//   - range source `for k,v := range s`
//   - field access on s (slices/maps don't expose user-visible fields,
//     but be conservative anyway)
//
// False positives (over-including) just cost us auto-free for a var
// that's actually safe. False negatives (under-including) would cause
// double-free. Lean toward over-including.
func scanMovedNames(body *ast.Block) map[string]bool {
	moved := make(map[string]bool)
	if body == nil {
		return moved
	}
	var walkStmt func(ast.Stmt)
	var walkExpr func(ast.Expr)
	var walkMove func(ast.Expr) // marks the expr as moved if it's an ident

	walkMove = func(e ast.Expr) {
		if e == nil {
			return
		}
		if id, ok := e.(*ast.IdentExpr); ok {
			moved[id.Name] = true
		}
		walkExpr(e)
	}

	walkExpr = func(e ast.Expr) {
		if e == nil {
			return
		}
		switch x := e.(type) {
		case *ast.CallExpr:
			// Built-ins that don't transfer ownership: their first arg
			// is metadata-only. Recurse into their args normally.
			if id, ok := x.Fun.(*ast.IdentExpr); ok {
				switch id.Name {
				case "len", "cap", "chr", "clone":
					for _, a := range x.Args {
						walkExpr(a)
					}
					return
				}
			}
			walkExpr(x.Fun)
			for _, a := range x.Args {
				walkMove(a)
			}
		case *ast.IndexExpr:
			walkExpr(x.X)
			walkExpr(x.Index)
		case *ast.BinaryExpr:
			walkExpr(x.X)
			walkExpr(x.Y)
		case *ast.UnaryExpr:
			walkExpr(x.X)
		case *ast.NewExpr:
			// A composite literal TAKES OWNERSHIP of each value placed
			// into it (struct field, map key/value, slice element). When
			// the literal escapes (returned, stored in a heap struct), its
			// elements must outlive this function — so mark each contained
			// ident as moved and skip its auto-free. Without this, a local
			// slice/string/map stored into `new T { f: local }` and then
			// returned is freed at scope exit and its backing reused — a
			// use-after-free (e.g. `exec.Command` building `new Cmd{Args:argv}`).
			for _, a := range x.SizeArgs {
				walkExpr(a)
			}
			for _, p := range x.Pairs {
				if p != nil {
					walkMove(p.Value)
				}
			}
			for _, me := range x.MapEntries {
				if me != nil {
					walkMove(me.Key)
					walkMove(me.Value)
				}
			}
			for _, el := range x.SliceElems {
				walkMove(el)
			}
		case *ast.FuncLit:
			if x.Body != nil {
				for _, s := range x.Body.Stmts {
					walkStmt(s)
				}
			}
		}
	}

	walkStmt = func(s ast.Stmt) {
		if s == nil {
			return
		}
		switch x := s.(type) {
		case *ast.Block:
			for _, st := range x.Stmts {
				walkStmt(st)
			}
		case *ast.ExprStmt:
			walkExpr(x.Expr)
		case *ast.VarStmt:
			// Union the checker's precise end-of-scope move-state (set on
			// the decl during Check) with this static heuristic — only adds
			// marks, so it can only suppress more frees (never fewer).
			if x.MovedAtEnd {
				moved[x.Name] = true
			}
			walkMove(x.Value)
		case *ast.AssignStmt:
			walkExpr(x.LHS) // LHS = target; mostly safe (ident decl etc.)
			walkMove(x.RHS)
		case *ast.MultiAssignStmt:
			walkMove(x.RHS)
		case *ast.MultiVarStmt:
			walkMove(x.RHS)
		case *ast.RetStmt:
			for _, v := range x.Values {
				walkMove(v)
			}
		case *ast.IfStmt:
			walkStmt(x.Init)
			walkExpr(x.Cond)
			walkStmt(x.Then)
			walkStmt(x.Else)
		case *ast.ForStmt:
			walkStmt(x.Init)
			walkExpr(x.Cond)
			walkStmt(x.Post)
			walkExpr(x.RangeOver) // range source is NOT moved
			walkStmt(x.Body)
		case *ast.DeferStmt:
			walkExpr(x.Call)
		case *ast.RunStmt:
			if x.Call != nil {
				for _, a := range x.Call.Args {
					walkMove(a)
				}
			}
		case *ast.SwitchStmt:
			walkExpr(x.Tag)
			for _, cc := range x.Cases {
				for _, v := range cc.Vals {
					walkExpr(v)
				}
				for _, st := range cc.Stmts {
					walkStmt(st)
				}
			}
		}
	}

	for _, s := range body.Stmts {
		walkStmt(s)
	}
	return moved
}

// scanReleasableChannels returns the set of local channel variables
// (`c := new() chan T`) that this function solely owns and that never
// escape — safe to volt_chan_release at scope exit (#6).
//
// A channel is a heap handle carrying an atomic refcount; the creator
// holds the initial ref (volt_chan_new = 1) and releases it here at
// scope end. `run f(c)` retains a ref for the goroutine (released by the
// run thunk), so a captured channel is NOT an escape — the creator still
// releases its own ref. Channel ops (read/write/close, in ARG 0) are
// borrows, not escapes. EVERY other mention of the name PINS the channel
// (return, alias, composite-literal element, field/index, the VALUE
// position of write, any non-channel call, closure capture, send over
// another channel): skip the release (leak) rather than risk a
// double-free.
//
// Conservative by construction: a false pin only leaks; a missed pin
// would be a use-after-free. So the rule is "pin every identifier we
// reach, except the two whitelisted borrow positions."
func scanReleasableChannels(body *ast.Block) map[string]bool {
	cand := make(map[string]bool)   // chan-new locals
	pinned := make(map[string]bool) // escaped → unsafe to release
	if body == nil {
		return cand
	}
	var walkStmt func(ast.Stmt)
	var walkExpr func(ast.Expr) // pins every bare ident it reaches

	walkExpr = func(e ast.Expr) {
		if e == nil {
			return
		}
		switch x := e.(type) {
		case *ast.IdentExpr:
			pinned[x.Name] = true
		case *ast.CallExpr:
			if id, ok := x.Fun.(*ast.IdentExpr); ok {
				switch id.Name {
				case "read", "write", "close":
					// arg 0 is the channel (borrowed); leave it releasable
					// when it's a bare ident. Remaining args (the value in
					// write) are walked normally — a channel sent as a value
					// is a real escape.
					for i, a := range x.Args {
						if i == 0 {
							if _, isID := a.(*ast.IdentExpr); isID {
								continue
							}
						}
						walkExpr(a)
					}
					return
				}
			}
			walkExpr(x.Fun)
			for _, a := range x.Args {
				walkExpr(a)
			}
		case *ast.IndexExpr:
			walkExpr(x.X)
			walkExpr(x.Index)
		case *ast.BinaryExpr:
			walkExpr(x.X)
			walkExpr(x.Y)
		case *ast.UnaryExpr:
			walkExpr(x.X)
		case *ast.SelectorExpr:
			walkExpr(x.X)
		case *ast.NewExpr:
			for _, a := range x.SizeArgs {
				walkExpr(a)
			}
			for _, p := range x.Pairs {
				if p != nil {
					walkExpr(p.Value)
				}
			}
			for _, me := range x.MapEntries {
				if me != nil {
					walkExpr(me.Key)
					walkExpr(me.Value)
				}
			}
			for _, el := range x.SliceElems {
				walkExpr(el)
			}
		case *ast.FuncLit:
			// A channel captured by a closure escapes to the closure's
			// lifetime — pin it (walk the body normally).
			if x.Body != nil {
				for _, s := range x.Body.Stmts {
					walkStmt(s)
				}
			}
		}
	}

	walkStmt = func(s ast.Stmt) {
		if s == nil {
			return
		}
		switch x := s.(type) {
		case *ast.Block:
			for _, st := range x.Stmts {
				walkStmt(st)
			}
		case *ast.ExprStmt:
			walkExpr(x.Expr)
		case *ast.VarStmt:
			if ne, ok := x.Value.(*ast.NewExpr); ok {
				// The channel type may be on the NewExpr (`new() chan T`) or
				// on the var's declared type (`var c chan T = new(N)`).
				_, neChan := ne.Type.(*ast.ChanType)
				_, declChan := x.Type.(*ast.ChanType)
				if neChan || declChan {
					cand[x.Name] = true
					for _, a := range ne.SizeArgs {
						walkExpr(a)
					}
					return
				}
			}
			walkExpr(x.Value)
		case *ast.AssignStmt:
			walkExpr(x.LHS)
			walkExpr(x.RHS)
		case *ast.MultiAssignStmt:
			for _, l := range x.LHS {
				walkExpr(l)
			}
			walkExpr(x.RHS)
		case *ast.MultiVarStmt:
			walkExpr(x.RHS)
		case *ast.RetStmt:
			for _, v := range x.Values {
				walkExpr(v)
			}
		case *ast.IfStmt:
			walkStmt(x.Init)
			walkExpr(x.Cond)
			walkStmt(x.Then)
			walkStmt(x.Else)
		case *ast.ForStmt:
			walkStmt(x.Init)
			walkExpr(x.Cond)
			walkStmt(x.Post)
			walkExpr(x.RangeOver)
			walkStmt(x.Body)
		case *ast.DeferStmt:
			walkExpr(x.Call)
		case *ast.RunStmt:
			if x.Call != nil {
				for _, a := range x.Call.Args {
					// A bare channel ident captured by run is retained for
					// the goroutine — not an escape; leave it releasable.
					if _, isID := a.(*ast.IdentExpr); isID {
						continue
					}
					walkExpr(a)
				}
			}
		case *ast.SelectStmt:
			for _, cc := range x.Cases {
				if cc == nil {
					continue
				}
				// The case's channel is borrowed; the sent value and the
				// case body are real positions.
				if _, isID := cc.Channel.(*ast.IdentExpr); !isID {
					walkExpr(cc.Channel)
				}
				walkExpr(cc.SendValue)
				for _, st := range cc.Body {
					walkStmt(st)
				}
			}
		case *ast.SwitchStmt:
			walkExpr(x.Tag)
			for _, cc := range x.Cases {
				for _, v := range cc.Vals {
					walkExpr(v)
				}
				for _, st := range cc.Stmts {
					walkStmt(st)
				}
			}
		}
	}

	for _, s := range body.Stmts {
		walkStmt(s)
	}

	out := make(map[string]bool)
	for name := range cand {
		if !pinned[name] {
			out[name] = true
		}
	}
	return out
}

// hoistAllocas moves every `  %name = alloca ...` line in a function
// body to the front (the top of the entry block), preserving the order
// of all other lines. Allocas are stack slots that LLVM only frees at
// function return, so one emitted inside a loop body leaks a slot per
// iteration → stack overflow; hoisting allocates each slot once. Volt
// emits only static allocas (no `alloca T, iN %count` dynamic form), and
// an alloca has no SSA operands, so relocating it ahead of every use is
// always dominance-valid. The match is exact (`%… = alloca `) so it
// never catches a comment or string literal.
func hoistAllocas(body string) string {
	var allocas, rest strings.Builder
	for _, ln := range strings.SplitAfter(body, "\n") {
		trimmed := strings.TrimLeft(ln, " \t")
		if strings.HasPrefix(trimmed, "%") && strings.Contains(trimmed, " = alloca ") {
			allocas.WriteString(ln)
		} else {
			rest.WriteString(ln)
		}
	}
	if allocas.Len() == 0 {
		return body
	}
	return allocas.String() + rest.String()
}

// scanElemFreeableSlices returns the set of local `[]string` variables whose
// per-element PAYLOADS are safe to free at scope exit (S1b) — i.e. the slice
// is the SOLE owner of independent element strings. SAFE-BY-CONSTRUCTION
// whitelist: a candidate is freeable only if EVERY use of its name is one of
// the few positions that cannot alias an element payload OUT of the slice:
//   - the declaration itself
//   - a write-index LHS `s[i] = v` (stores INTO the slice; the RHS is moved in)
//   - an index-binding read `x := s[i]` / `x = s[i]` (the WHOLE rhs is `s[i]`;
//     S1a deep-copies these, so x is independent)
//   - `len(s)` / `cap(s)` (metadata only)
// ANY other occurrence (range over s, inline `s[i]` in ret/call/concat/
// composite, passing/returning/storing s, reassigning s, …) PINS the slice →
// elements are NOT freed (a leak, never a use-after-free). A missed case can
// therefore only under-free (leak), never double-free.
func (c *funcCtx) scanElemFreeableSlices(body *ast.Block) map[string]bool {
	cand := map[string]bool{}
	pinned := map[string]bool{}
	if body == nil {
		return cand
	}
	// ownedTransfer reports whether `v` placed into a slice element (an
	// initializer element or a write-index RHS `s[i] = v`) makes the slice the
	// SOLE owner of an independent payload — vs aliasing some other owner's
	// payload (which would make element-free a double-free / UAF). SAFE
	// whitelist: a string literal (rodata, free is a no-op), a known
	// heap-producer temp (concat/chr/etc., moved in), or a plain string
	// variable (`s[i] = v` MOVES v — verified — so v is consumed, not
	// aliased). Anything else (element read `xs[j]`, field read `o.f`, call
	// result, …) is conservatively NOT owned-transfer → pins the slice.
	ownedTransfer := func(v ast.Expr) bool {
		switch v.(type) {
		case *ast.StringLit, *ast.IdentExpr:
			return true
		}
		return isHeapStringProducer(v)
	}
	isStrSliceDecl := func(vs *ast.VarStmt) bool {
		if st, ok := vs.Type.(*ast.SliceType); ok {
			if nt, ok := st.Elem.(*ast.NamedType); ok && nt.Name == "string" {
				return true
			}
		}
		if ne, ok := vs.Value.(*ast.NewExpr); ok {
			if st, ok := ne.Type.(*ast.SliceType); ok {
				if nt, ok := st.Elem.(*ast.NamedType); ok && nt.Name == "string" {
					return true
				}
			}
		}
		return false
	}
	// isSliceIndexOf reports whether e is exactly `name[i]` for some name.
	sliceIndexName := func(e ast.Expr) string {
		idx, ok := e.(*ast.IndexExpr)
		if !ok {
			return ""
		}
		id, ok := idx.X.(*ast.IdentExpr)
		if !ok {
			return ""
		}
		return id.Name
	}

	var walkStmt func(ast.Stmt)
	var pin func(ast.Expr) // pins EVERY identifier reached (the conservative default)
	pin = func(e ast.Expr) {
		switch x := e.(type) {
		case nil:
			return
		case *ast.IdentExpr:
			pinned[x.Name] = true
		case *ast.CallExpr:
			// len(s)/cap(s) on a bare ident is metadata — does not pin the ident.
			if id, ok := x.Fun.(*ast.IdentExpr); ok && (id.Name == "len" || id.Name == "cap") {
				for _, a := range x.Args {
					if _, isID := a.(*ast.IdentExpr); isID {
						continue
					}
					pin(a)
				}
				return
			}
			pin(x.Fun)
			for _, a := range x.Args {
				pin(a)
			}
		case *ast.IndexExpr:
			pin(x.X)
			pin(x.Index)
		case *ast.BinaryExpr:
			pin(x.X)
			pin(x.Y)
		case *ast.UnaryExpr:
			pin(x.X)
		case *ast.SelectorExpr:
			pin(x.X)
		case *ast.NewExpr:
			for _, a := range x.SizeArgs {
				pin(a)
			}
			for _, p := range x.Pairs {
				if p != nil {
					pin(p.Value)
				}
			}
			for _, me := range x.MapEntries {
				if me != nil {
					pin(me.Key)
					pin(me.Value)
				}
			}
			for _, el := range x.SliceElems {
				pin(el)
			}
		case *ast.FuncLit:
			if x.Body != nil {
				for _, s := range x.Body.Stmts {
					walkStmt(s)
				}
			}
		}
	}

	walkStmt = func(s ast.Stmt) {
		switch x := s.(type) {
		case nil:
			return
		case *ast.Block:
			for _, st := range x.Stmts {
				walkStmt(st)
			}
		case *ast.ExprStmt:
			pin(x.Expr)
		case *ast.VarStmt:
			// Candidate only if the slice OWNS its initial elements: an empty
			// or sized init, or one whose every literal element is an
			// owned-transfer (literal/heap-temp/moved-ident). An initializer
			// that aliases another owner's payload (`new []string{xs[j]}`)
			// disqualifies the slice (it isn't the sole owner).
			if isStrSliceDecl(x) {
				initOwned := true
				if ne, ok := x.Value.(*ast.NewExpr); ok {
					for _, el := range ne.SliceElems {
						if !ownedTransfer(el) {
							initOwned = false
							break
						}
					}
				}
				if initOwned {
					cand[x.Name] = true
				}
			}
			// `x := s[i]` — whole RHS is an index read → S1a copies it; do NOT
			// pin the source slice (but still walk the index expr).
			if nm := sliceIndexName(x.Value); nm != "" {
				if idx, ok := x.Value.(*ast.IndexExpr); ok {
					pin(idx.Index)
				}
			} else if ne, ok := x.Value.(*ast.NewExpr); ok && isStrSliceDecl(x) {
				// the slice's own initializer elements are moved IN — fine.
				for _, el := range ne.SliceElems {
					pin(el)
				}
				for _, a := range ne.SizeArgs {
					pin(a)
				}
			} else {
				pin(x.Value)
			}
		case *ast.AssignStmt:
			_, lhsIsIdent := x.LHS.(*ast.IdentExpr)
			// write-index LHS `s[i] = v`: the slice stays a candidate ONLY if v
			// is an owned-transfer into the element. If v aliases another
			// owner's payload (`s[i] = xs[j]`, `s[i] = o.f`), s would
			// element-free a buffer it doesn't solely own → PIN s.
			if nm := sliceIndexName(x.LHS); nm != "" {
				if idx, ok := x.LHS.(*ast.IndexExpr); ok {
					pin(idx.Index)
				}
				if !ownedTransfer(x.RHS) {
					pinned[nm] = true
				}
			} else {
				pin(x.LHS)
			}
			// `x = s[i]` where x is a PLAIN IDENT — emitIdentAssign deep-copies
			// the element (S1a), so the source isn't aliased; don't pin it.
			// For ANY other LHS (notably a write-index `s[i] = xs[j]`, which is
			// NOT deep-copied → xs[j] aliases into s[i]) pin the RHS normally so
			// the source slice can't also be element-freed (would double-free).
			if lhsIsIdent && sliceIndexName(x.RHS) != "" {
				if idx, ok := x.RHS.(*ast.IndexExpr); ok {
					pin(idx.Index)
				}
			} else {
				pin(x.RHS)
			}
		case *ast.MultiAssignStmt:
			for _, l := range x.LHS {
				pin(l)
			}
			pin(x.RHS)
		case *ast.MultiVarStmt:
			pin(x.RHS)
		case *ast.RetStmt:
			for _, v := range x.Values {
				pin(v)
			}
		case *ast.IfStmt:
			walkStmt(x.Init)
			pin(x.Cond)
			walkStmt(x.Then)
			walkStmt(x.Else)
		case *ast.ForStmt:
			walkStmt(x.Init)
			pin(x.Cond)
			walkStmt(x.Post)
			pin(x.RangeOver) // range over a slice pins it (the value binding aliases)
			walkStmt(x.Body)
		case *ast.DeferStmt:
			pin(x.Call)
		case *ast.RunStmt:
			if x.Call != nil {
				pin(x.Call)
			}
		case *ast.SelectStmt:
			for _, cc := range x.Cases {
				if cc == nil {
					continue
				}
				pin(cc.Channel)
				pin(cc.SendValue)
				for _, st := range cc.Body {
					walkStmt(st)
				}
			}
		case *ast.SwitchStmt:
			pin(x.Tag)
			for _, cc := range x.Cases {
				for _, v := range cc.Vals {
					pin(v)
				}
				for _, st := range cc.Stmts {
					walkStmt(st)
				}
			}
		}
	}

	for _, s := range body.Stmts {
		walkStmt(s)
	}
	out := map[string]bool{}
	for name := range cand {
		if !pinned[name] {
			out[name] = true
		}
	}
	return out
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
	dbgSuffix := ""
	dbgLocID := 0
	if e.sourceFile != "" {
		// Reserve two metadata ids per function: DISubprogram and a
		// shared DILocation rooted in it. The DILocation is what we
		// attach to call instructions (LLVM requires it on
		// "inlinable" calls inside DI-bearing functions).
		dbgID := 1000 + 2*len(e.subprograms)
		dbgLocID = dbgID + 1
		e.subprograms = append(e.subprograms, subprogramDI{
			metaID:    dbgID,
			locMetaID: dbgLocID,
			name:      fd.Name,
			linkage:   symbolName,
			line:      fd.P.Line,
		})
		dbgSuffix = fmt.Sprintf(" !dbg !%d", dbgID)
	}
	out.WriteString(")" + dbgSuffix + " {\n")
	out.WriteString("entry:\n")

	c := &funcCtx{
		e:             e,
		symbols:       make(map[string]symbol),
		retType:       retType,
		retAstTypes:   fd.Results,
		isMain:        isMain,
		usedAddrs:     make(map[string]int),
		declaredAt:    make(map[string]int),
		declaredAtPos: make(map[string]lex.Pos),
		movedNames:      scanMovedNames(fd.Body),
		releasableChans: scanReleasableChannels(fd.Body),
	}
	// S1b element-freeable []string analysis runs as a method so it can
	// consult movedNames + the heap-producer classifier (it must verify each
	// element-WRITE is an owned-transfer, not an alias).
	c.elemFreeableSlices = c.scanElemFreeableSlices(fd.Body)

	for i, p := range allParams {
		pt := e.llvmType(p.Type)
		ptr := fmt.Sprintf("%%%s.addr", p.Name)
		c.usedAddrs[p.Name+".addr"] = 1
		fmt.Fprintf(&c.body, "  %s = alloca %s\n", ptr, pt)
		fmt.Fprintf(&c.body, "  store %s %%%s, ptr %s\n", pt, p.Name, ptr)
		if dbgLocID != 0 {
			varID := e.nextDbgVarID()
			e.subprograms[len(e.subprograms)-1].locals = append(
				e.subprograms[len(e.subprograms)-1].locals, dbgVar{
					metaID: varID,
					name:   p.Name,
					line:   fd.P.Line,
					argNum: i + 1,
					llType: pt,
				})
			c.e.ensureDeclare("declare void @llvm.dbg.declare(metadata, metadata, metadata)")
			fmt.Fprintf(&c.body,
				"  call void @llvm.dbg.declare(metadata ptr %s, metadata !%d, metadata !DIExpression())\n",
				ptr, varID)
		}
		c.symbols[p.Name] = symbol{
			Ptr:       ptr,
			Type:      pt,
			Elem:      e.elemType(p.Type),
			SliceElem: e.sliceElemLLVM(p.Type),
			IsMap:     isMapType(p.Type),
			AstType:   p.Type,
		}
		c.declaredAt[p.Name] = 0
		c.declaredAtPos[p.Name] = p.P
	}

	if isMain && e.raceEnabled {
		c.e.ensureDeclare("declare void @volt_race_enable()")
		c.body.WriteString("  call void @volt_race_enable()\n")
	}
	if isMain && e.memProfilePath != "" {
		gname, glen := e.internString(e.memProfilePath)
		c.e.ensureDeclare("declare void @volt_runtime_memprofile_set_path(ptr, i64)")
		fmt.Fprintf(&c.body, "  call void @volt_runtime_memprofile_set_path(ptr %s, i64 %d)\n", gname, glen)
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
	bodyStr := c.body.String()
	// Hoist every `alloca` to the top of the entry block. LLVM only
	// reclaims stack-allocated slots at function return, NOT at block exit
	// — so an alloca emitted inside a loop body allocates a FRESH slot on
	// every iteration and a long-running loop overflows the stack (SIGSEGV).
	// All of volt's allocas are static (no dynamic count operand) and have
	// no SSA dependencies, so moving them ahead of every use is always
	// valid; the slot is then allocated once and reused each iteration
	// (the variable is re-initialized by its in-body store regardless).
	bodyStr = hoistAllocas(bodyStr)
	if dbgLocID != 0 {
		// Walk the body. Track the current source line via the
		// `; .line N` markers emitStmt drops in. For each `call`,
		// append `, !dbg !<id>` where <id> resolves to a DILocation
		// for (current function, current line). Locations are
		// allocated on demand and recorded in e.subprograms[k].lineLocs
		// for emission at module end.
		spIdx := len(e.subprograms) - 1
		var rewritten strings.Builder
		curLoc := dbgLocID
		dbgTag := fmt.Sprintf(", !dbg !%d", curLoc)
		for _, ln := range strings.SplitAfter(bodyStr, "\n") {
			trimmed := strings.TrimLeft(ln, " \t")
			// Pick up per-statement line markers.
			if rest, ok := strings.CutPrefix(trimmed, "; .line "); ok {
				numStr := strings.TrimSpace(rest)
				if v, err := strconv.Atoi(numStr); err == nil && v > 0 {
					curLoc = e.locForLine(spIdx, v)
					dbgTag = fmt.Sprintf(", !dbg !%d", curLoc)
				}
				rewritten.WriteString(ln)
				continue
			}
			isCall := strings.HasPrefix(trimmed, "call ") ||
				strings.Contains(trimmed, " = call ")
			if isCall && !strings.Contains(ln, " !dbg ") {
				if strings.HasSuffix(ln, "\n") {
					rewritten.WriteString(ln[:len(ln)-1])
					rewritten.WriteString(dbgTag)
					rewritten.WriteByte('\n')
					continue
				}
			}
			rewritten.WriteString(ln)
		}
		bodyStr = rewritten.String()
	}
	out.WriteString(bodyStr)
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
	// C13 escape proof: true when this symbol holds a closure value
	// whose body captures one or more borrow/pointer variables. Escape
	// sites (ret, run) consult this to prevent the closure from
	// outliving its captured borrows.
	CapturesBorrow bool
	// ConcretePkg is the package owning this symbol's concrete `*T` type,
	// captured from its initializer (e.g. `bytes.NewBuilder()` → "bytes").
	// It survives the fact that a `*T` var's AST type drops the package
	// qualifier, so interface boxing of the variable can still reference
	// the right package-qualified vtable. Empty when unknown.
	ConcretePkg string
}

type funcCtx struct {
	e          *Emitter
	body       strings.Builder
	nextTmp    int
	nextLbl    int
	symbols    map[string]symbol
	retType    string
	retAstTypes []ast.Type // declared AST return types — used for friendly mismatch errors at ret
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
	// A3: names that the pre-scan flagged as POTENTIALLY MOVED somewhere
	// in this function body — passed as a non-borrow call arg, returned,
	// assigned to another var, sent through a channel, used in `run f(x)`,
	// or stored into a struct/composite literal. Conservative: any source
	// not in this set is considered owned-throughout and gets auto-free
	// at scope exit; vars in this set skip auto-free (and instead rely on
	// the move target taking ownership). The scan runs once in emitFunc
	// before the body is lowered.
	movedNames map[string]bool
	// releasableChans is the set of local channel vars (`c := new() chan T`)
	// this function solely owns and that never escape — released with
	// volt_chan_release at scope exit (#6). Computed once in emitFunc.
	releasableChans map[string]bool
	// elemFreeableSlices is the set of local []string vars whose per-element
	// payloads are safe to free at scope exit (S1b) — the slice is the sole
	// owner of independent element strings (scanElemFreeableSlices, a
	// safe-by-construction whitelist). Computed once in emitFunc.
	elemFreeableSlices map[string]bool
	// currentLine tracks the source line of the statement currently being
	// lowered. emitStmt updates it at entry; emitRaceMem reads it to
	// thread source-line info into the volt_race_read/write runtime
	// calls so race reports can cite "raced at file.volt:42" instead
	// of just thread+epoch. 0 means unknown.
	currentLine int
	// Top-level consts currently being expanded — used to detect
	// `const X = X + 1` self-references before they blow the Go stack.
	expandingConsts map[string]bool
	// declaredAt records the scope-depth at which each named local was
	// declared. emitVar consults this to reject `var x; var x` in the
	// same flat scope; popScope prunes entries at the leaving depth so
	// shadowing in nested scopes (and sequential for-loops at the same
	// parent depth) still works.
	declaredAt map[string]int
	// declaredAtPos parallels declaredAt; used to cite the position
	// of the first declaration in the redeclaration error.
	declaredAtPos map[string]lex.Pos
	// shadowed records the prior (name → symbol, declaredAt, pos)
	// state when emitVar overwrites an outer-scope binding inside an
	// inner scope. popScope walks this stack in reverse and restores
	// the outer binding so `var i = 100; for i := 0; ...` correctly
	// preserves the outer `i` after the loop ends.
	shadowed []shadowEntry
	// noDebugInfo skips llvm.dbg.declare / line-debug attachment for
	// this body. Set on closure children whose IR emits into a
	// trampoline buffer that has no DISubprogram of its own —
	// otherwise the dbg.declare calls reference the parent's
	// subprogram and LLVM rejects the resulting record.
	noDebugInfo bool
}

// shadowEntry captures the outer-scope state of a name being shadowed
// by an inner-scope declaration so popScope can restore it cleanly.
type shadowEntry struct {
	name     string
	depth    int // scopeDepth at which the shadow was created (the inner scope)
	prevSym  symbol
	prevDecl int
	prevPos  lex.Pos
	hadPrev  bool // true if an outer binding actually existed
}

// bindLocal records a new local binding (or shadowing of an outer
// one) and updates the symbol table, declaredAt tracking, and shadow
// stack uniformly. Used by everything that introduces a name at
// scope-depth > 0 (range bindings, multi-return splits, etc.).
// `pos` should be the source position of the declaration site;
// future redeclare errors will cite it. Returns an error when the
// name is already declared at this same scope.
func (c *funcCtx) bindLocal(name string, sym symbol, pos lex.Pos) error {
	if c.declaredAt == nil {
		c.declaredAt = make(map[string]int)
		c.declaredAtPos = make(map[string]lex.Pos)
	}
	if d, ok := c.declaredAt[name]; ok && d == c.scopeDepth {
		return fmt.Errorf("%s: local variable %q redeclared in the same scope (first at %s)",
			pos, name, c.declaredAtPos[name])
	}
	if prevDepth, hadPrev := c.declaredAt[name]; hadPrev && prevDepth < c.scopeDepth {
		c.shadowed = append(c.shadowed, shadowEntry{
			name:     name,
			depth:    c.scopeDepth,
			prevSym:  c.symbols[name],
			prevDecl: prevDepth,
			prevPos:  c.declaredAtPos[name],
			hadPrev:  true,
		})
	}
	c.symbols[name] = sym
	c.declaredAt[name] = c.scopeDepth
	c.declaredAtPos[name] = pos
	return nil
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
	// sliceElem, for dropKindSlice, is the LLVM element type when the slice's
	// per-element PAYLOADS must be freed too (S1b). "%string" → call
	// volt_slice_free_str_elems (free each element string then the buffer);
	// "" → free only the backing buffer (volt_slice_free). Set only when the
	// compiler proved the slice is sole owner of independent element payloads
	// (scanElemFreeableSlices).
	sliceElem string
}

type dropKind int

const (
	dropKindStruct dropKind = iota
	dropKindSyncGuard
	// A3: dropKindSlice frees the buffer pointer stored in the slice
	// header. The header is a {ptr, i64 len, i64 cap} alloca; we load
	// the leading ptr field and call volt_slice_free, which is a no-op
	// on null — so move-out sites can nullify the slot to suppress the
	// free.
	dropKindSlice
	// A3: dropKindMap frees the map_t handle stored at the alloca.
	// Same null-on-move suppression mechanic as dropKindSlice.
	dropKindMap
	// A3: dropKindString frees the buffer pointer stored in a %string
	// header. Registered only when codegen can prove the RHS produces
	// a HEAP-allocated string (binary `+` concat, `chr` builtin, etc.) —
	// never for string literals (whose ptr is in .rodata). volt_str_free
	// is null-safe.
	dropKindString
	// #6: dropKindChanRelease drops one refcount on a channel handle at
	// scope exit. Registered only for sole-owned, non-escaping `new()
	// chan` locals (scanReleasableChannels). The creator's ref drops here;
	// a `run` that captured the channel retained its own ref (released by
	// the run thunk), so the last release frees the struct + buffer.
	// volt_chan_release is null-safe.
	dropKindChanRelease
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

// emitRaceSync emits a volt_race_acquire or volt_race_release call on
// the given LLVM-level pointer variable. No-op when -race is off, so
// callers can wrap unconditionally. The pointer identifies the sync
// location (channel handle, mutex object, atomic cell); the runtime
// hashes it into its happens-before table.
func (c *funcCtx) emitRaceSync(kind string, ptrVar string) {
	if !c.e.raceEnabled {
		return
	}
	switch kind {
	case "acquire":
		c.e.ensureDeclare("declare void @volt_race_acquire(ptr)")
		fmt.Fprintf(&c.body, "  call void @volt_race_acquire(ptr %s)\n", ptrVar)
	case "release":
		c.e.ensureDeclare("declare void @volt_race_release(ptr)")
		fmt.Fprintf(&c.body, "  call void @volt_race_release(ptr %s)\n", ptrVar)
	}
}

// emitRaceMem emits a volt_race_read or volt_race_write call on the
// given LLVM-level pointer variable + size. No-op when -race is off.
// Used at user-visible memory access sites: struct field reads/writes,
// slice element reads/writes, map gets/sets. NOT used for stack locals
// (alloca slots) — those can't be shared between threads in volt
// (borrows don't cross thread boundaries), so they don't need
// instrumentation.
func (c *funcCtx) emitRaceMem(kind string, ptrVar string, size int) {
	if !c.e.raceEnabled {
		return
	}
	line := c.currentLine
	switch kind {
	case "read":
		c.e.ensureDeclare("declare void @volt_race_read(ptr, i64, i64)")
		fmt.Fprintf(&c.body, "  call void @volt_race_read(ptr %s, i64 %d, i64 %d)\n", ptrVar, size, line)
	case "write":
		c.e.ensureDeclare("declare void @volt_race_write(ptr, i64, i64)")
		fmt.Fprintf(&c.body, "  call void @volt_race_write(ptr %s, i64 %d, i64 %d)\n", ptrVar, size, line)
	}
}

// ---------------------------------------------------------------------
// Statements
// ---------------------------------------------------------------------

func (c *funcCtx) emitStmt(s ast.Stmt) error {
	// Drop a line marker into the IR so the post-pass DWARF rewriter
	// knows which source line subsequent call instructions belong to.
	// Plain LLVM-IR comment — clang accepts the line, harmless if we
	// strip DI at module-end (sourceFile == "").
	if s != nil {
		line := s.Pos().Line
		if line > 0 {
			// Track for runtime-side reporting (emitRaceMem reads this
			// to thread the source line into volt_race_read/write).
			c.currentLine = line
			if c.e.sourceFile != "" {
				fmt.Fprintf(&c.body, "  ; .line %d\n", line)
			}
			// Call-site memory profiling: when `--memprofile` is on,
			// stamp the per-thread "current line" so volt_alloc can
			// attribute allocations to this source line. Gated on the
			// build flag so non-profiling builds emit nothing.
			if c.e.memProfilePath != "" && !c.noDebugInfo {
				c.e.ensureDeclare("declare void @volt_memprofile_note_line(i64)")
				fmt.Fprintf(&c.body, "  call void @volt_memprofile_note_line(i64 %d)\n", line)
			}
		}
	}
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
	case *ast.Block:
		// Bare nested block — push a fresh scope, emit each inner stmt,
		// then pop the scope so drops registered inside (mutex guards,
		// owned slice/map/string locals, struct Drops) fire at the
		// closing `}`. Same machinery used for if/for bodies.
		c.pushScope()
		for _, stmt := range s.Stmts {
			if err := c.emitStmt(stmt); err != nil {
				return err
			}
			if c.terminated {
				break
			}
		}
		c.popScope()
		return nil
	}
	return fmt.Errorf("%s: unsupported statement %T", s.Pos(), s)
}

// tryRecv2 detects a channel receive used as a multi-value source —
// `read(ch)`. Builds an {elemLL, i64} aggregate SSA value (value, ok) by
// stack-alloca-ing a slot, calling volt_chan_recv which returns ok and
// memcpys the value into the slot, then loading the value and assembling
// the pair.
func (c *funcCtx) tryRecv2(rhs ast.Expr) (string, []string, bool) {
	var chExpr ast.Expr
	switch r := rhs.(type) {
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
	elemLL := c.chanArgElem(chExpr)
	slot := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = alloca %s\n", slot, elemLL)
	c.e.ensureDeclare("declare i64 @volt_chan_recv(ptr, ptr)")
	okTmp := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call i64 @volt_chan_recv(ptr %s, ptr %s)\n", okTmp, ch.Name, slot)
	c.emitRaceSync("acquire", ch.Name)
	val := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = load %s, ptr %s\n", val, elemLL, slot)
	// Assemble {elemLL, i64} aggregate so callers can extract.
	aggT := fmt.Sprintf("{%s, i64}", elemLL)
	t1 := c.newTemp()
	t2 := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = insertvalue %s undef, %s %s, 0\n", t1, aggT, elemLL, val)
	fmt.Fprintf(&c.body, "  %s = insertvalue %s %s, i64 %s, 1\n", t2, aggT, t1, okTmp)
	return t2, []string{elemLL, "i64"}, true
}

// tryIndex2 handles the comma-ok index form `v, ok := a[i]` for a SLICE or
// STRING — a bounds-checked read returning {element, in-bounds}. Branch-free
// and OOB-safe: the load pointer selects a zero-initialized scratch slot when
// the index is out of range, so nothing is ever read past the end (an empty
// slice reads the zero slot, not its null buffer). Mirrors tryRecv2's shape.
// Returns false for any other RHS (maps keep bare `m[k]` zero-on-missing).
func (c *funcCtx) tryIndex2(rhs ast.Expr) (string, []string, bool) {
	idx, ok := rhs.(*ast.IndexExpr)
	if !ok {
		return "", nil, false
	}
	xv, err := c.emitExpr(idx.X)
	if err != nil {
		return "", nil, false
	}
	var elemLL, bufP, lenV string
	switch {
	case xv.Type == "%string":
		elemLL = "i8"
		bufP, lenV = c.newTemp(), c.newTemp()
		fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 0\n", bufP, xv.Name)
		fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 1\n", lenV, xv.Name)
	case xv.Type == "%slice" && xv.SliceElem != "":
		elemLL = xv.SliceElem
		bufP, lenV = c.newTemp(), c.newTemp()
		fmt.Fprintf(&c.body, "  %s = extractvalue %%slice %s, 0\n", bufP, xv.Name)
		fmt.Fprintf(&c.body, "  %s = extractvalue %%slice %s, 1\n", lenV, xv.Name)
	default:
		return "", nil, false
	}
	iv, err := c.emitExpr(idx.Index)
	if err != nil {
		return "", nil, false
	}
	iv = c.convertInt(iv, "i64")
	// inbounds = (i >= 0) && (i < len)
	ge, lt, inb := c.newTemp(), c.newTemp(), c.newTemp()
	fmt.Fprintf(&c.body, "  %s = icmp sge i64 %s, 0\n", ge, iv.Name)
	fmt.Fprintf(&c.body, "  %s = icmp slt i64 %s, %s\n", lt, iv.Name, lenV)
	fmt.Fprintf(&c.body, "  %s = and i1 %s, %s\n", inb, ge, lt)
	// load pointer = inbounds ? &a[i] : &zeroSlot — never dereferences OOB.
	z := zeroValue(elemLL)
	zslot := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = alloca %s\n", zslot, elemLL)
	fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", elemLL, z.Name, zslot)
	realP, loadP, val := c.newTemp(), c.newTemp(), c.newTemp()
	fmt.Fprintf(&c.body, "  %s = getelementptr %s, ptr %s, i64 %s\n", realP, elemLL, bufP, iv.Name)
	fmt.Fprintf(&c.body, "  %s = select i1 %s, ptr %s, ptr %s\n", loadP, inb, realP, zslot)
	fmt.Fprintf(&c.body, "  %s = load %s, ptr %s\n", val, elemLL, loadP)
	okI64 := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = zext i1 %s to i64\n", okI64, inb)
	aggT := fmt.Sprintf("{%s, i64}", elemLL)
	t1, t2 := c.newTemp(), c.newTemp()
	fmt.Fprintf(&c.body, "  %s = insertvalue %s undef, %s %s, 0\n", t1, aggT, elemLL, val)
	fmt.Fprintf(&c.body, "  %s = insertvalue %s %s, i64 %s, 1\n", t2, aggT, t1, okI64)
	return t2, []string{elemLL, "i64"}, true
}

// emitMultiVar handles `a, b := foo()` where foo() returns multiple values.
// Also recognizes `v, ok := <-ch` and routes to volt_chan_recv2.
func (c *funcCtx) emitMultiVar(s *ast.MultiVarStmt) error {
	// Detect duplicate names on the LHS — `a, a := f()` would
	// silently overwrite the first symbol's table entry (and lower
	// to LLVM IR with two `%a.addr` allocas, which clang rejects
	// cryptically). Reject at the volt level before emission.
	for i, name := range s.Names {
		if name == "" || name == "_" {
			continue
		}
		for j := range i {
			if s.Names[j] == name {
				return fmt.Errorf("%s: multi-value decl lists name %q twice", s.Pos(), name)
			}
		}
		if d, ok := c.declaredAt[name]; ok && d == c.scopeDepth {
			return fmt.Errorf("%s: local variable %q redeclared in the same scope (first at %s)",
				s.Pos(), name, c.declaredAtPos[name])
		}
	}
	if agg, fieldTypes, ok := c.tryRecv2(s.RHS); ok {
		if len(s.Names) != 2 {
			return fmt.Errorf("%s: `<-ch` two-value form requires exactly two LHS names", s.Pos())
		}
		aggT := aggregateType(fieldTypes)
		for i, name := range s.Names {
			// `_` discards its field: the recv already ran (agg is bound),
			// so skip the alloca/store/bind. This also lets multiple `_`
			// coexist (`_, _ := <-ch`) without colliding on `%_.addr` or
			// tripping bindLocal's same-scope-redeclare guard.
			if name == "_" {
				continue
			}
			resultT := fieldTypes[i]
			ptr := fmt.Sprintf("%%%s.addr", name)
			fmt.Fprintf(&c.body, "  %s = alloca %s\n", ptr, resultT)
			ev := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = extractvalue %s %s, %d\n", ev, aggT, agg, i)
			fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", resultT, ev, ptr)
			if err := c.bindLocal(name, symbol{Ptr: ptr, Type: resultT}, s.P); err != nil {
				return err
			}
		}
		return nil
	}
	// `v, ok := a[i]` — bounds-checked slice/string index (comma-ok form).
	if agg, fieldTypes, ok := c.tryIndex2(s.RHS); ok {
		if len(s.Names) != 2 {
			return fmt.Errorf("%s: `v, ok := a[i]` requires exactly two names", s.Pos())
		}
		aggT := aggregateType(fieldTypes)
		for i, name := range s.Names {
			if name == "_" {
				continue
			}
			resultT := fieldTypes[i]
			ptr := fmt.Sprintf("%%%s.addr", name)
			fmt.Fprintf(&c.body, "  %s = alloca %s\n", ptr, resultT)
			ev := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = extractvalue %s %s, %d\n", ev, aggT, agg, i)
			fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", resultT, ev, ptr)
			if err := c.bindLocal(name, symbol{Ptr: ptr, Type: resultT}, s.P); err != nil {
				return err
			}
		}
		return nil
	}
	agg, fieldTypes, sig, err := c.emitMultiReturnCallWithSig(s.RHS)
	if err != nil {
		return err
	}
	if len(fieldTypes) != len(s.Names) {
		return fmt.Errorf("%s: call returns %d values but %d names declared",
			s.Pos(), len(fieldTypes), len(s.Names))
	}
	aggT := aggregateType(fieldTypes)
	for i, name := range s.Names {
		// `_` discards its field: the producing call already ran (agg is
		// bound), so skip the alloca/store/bind. This lets multiple `_`
		// coexist on one LHS (`a, _, _ := f()`) without colliding on
		// `%_.addr` or tripping bindLocal's same-scope-redeclare guard.
		if name == "_" {
			continue
		}
		resultT := fieldTypes[i]
		ptr := fmt.Sprintf("%%%s.addr", name)
		fmt.Fprintf(&c.body, "  %s = alloca %s\n", ptr, resultT)
		ev := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = extractvalue %s %s, %d\n", ev, aggT, agg, i)
		fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", resultT, ev, ptr)
		// Preserve AstType from the callee's signature so method
		// dispatch and other type-aware codegen paths work for
		// returned values (e.g., `err.Error()` on `(T, error)`).
		// Also propagate SliceElem when the result is a slice so
		// indexing/range on the returned slice works without the
		// "slice element type unknown" error.
		var astT ast.Type
		if sig != nil && i < len(sig.Results) {
			astT = sig.Results[i]
		}
		sliceElem := ""
		if astT != nil {
			if st, ok := astT.(*ast.SliceType); ok && st.Elem != nil {
				sliceElem = c.e.llvmType(st.Elem)
			}
		}
		isMap := isMapType(astT)
		if err := c.bindLocal(name, symbol{Ptr: ptr, Type: resultT, Elem: c.e.elemType(astT), SliceElem: sliceElem, IsMap: isMap, AstType: astT}, s.P); err != nil {
			return err
		}
	}
	return nil
}

// emitMultiReturnCallWithSig is emitMultiReturnCall but also returns
// the callee's FuncDecl so callers can preserve AST result types on the
// new symbols.
func (c *funcCtx) emitMultiReturnCallWithSig(expr ast.Expr) (string, []string, *ast.FuncDecl, error) {
	call, ok := expr.(*ast.CallExpr)
	if !ok {
		return "", nil, nil, fmt.Errorf("%s: multi-result RHS must be a call", expr.Pos())
	}
	var sig *ast.FuncDecl
	switch fn := call.Fun.(type) {
	case *ast.IdentExpr:
		sig = c.e.funcs[fn.Name]
	case *ast.SelectorExpr:
		if recvId, ok := fn.X.(*ast.IdentExpr); ok {
			// Try package-qualified free function first.
			if pkgFns, ok := c.e.extPkgs[recvId.Name]; ok {
				sig = pkgFns[fn.Sel]
			} else if _, isSym := c.symbols[recvId.Name]; isSym {
				// Method call on a local var.
				sig = c.resolveMethodOnSym(recvId.Name, fn.Sel)
			}
		}
	}
	agg, fieldTypes, err := c.emitMultiReturnCall(expr)
	return agg, fieldTypes, sig, err
}

// emitMultiAssign handles `a, b = foo()` into existing lvalues.
// Also handles `v, ok = read(ch)` / `v, ok = <-ch`.
func (c *funcCtx) emitMultiAssign(s *ast.MultiAssignStmt) error {
	agg, fieldTypes, ok := c.tryRecv2(s.RHS)
	if !ok {
		agg, fieldTypes, ok = c.tryIndex2(s.RHS)
	}
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
		// `_` discards its field — the producing call already ran, so there
		// is nothing to store. Matches the `:=` form (emitMultiVar).
		if id.Name == "_" {
			continue
		}
		sym, ok := c.symbols[id.Name]
		if !ok {
			return fmt.Errorf("%s: undefined variable %q", id.Pos(), id.Name)
		}
		ev := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = extractvalue %s %s, %d\n", ev, aggT, agg, i)
		// Convert int width if needed.
		v := c.convertInt(Value{Name: ev, Type: fieldTypes[i]}, sym.Type)
		// EXEC.caller-leaks: free the OLD heap value of this slot before
		// overwriting it, mirroring emitIdentAssign's A3 reassignment
		// cleanup (which the multi-assign path previously skipped → leak in
		// `a, b = f()` loops). Only slots with a registered slice/map/string
		// drop (= known heap-owned) are freed; the new value is a call/recv/
		// index result, conservatively NOT re-registered (same as the
		// var-decl path for function returns).
		c.freeReassignedSlot(sym)
		fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", sym.Type, v.Name, sym.Ptr)
	}
	return nil
}

// freeReassignedSlot frees a local's OLD heap value before it is
// overwritten and removes its stale drop registration. It fires only when
// the slot has a registered slice/map/string drop (the kinds keyed by
// alloca pointer) — i.e. a value this scope provably owns — so it can
// never double-free a borrowed/aliased value. Used by the multi-assign
// path; mirrors the inline cleanup in emitIdentAssign. The new value is
// not re-registered here (multi-assign RHS values are call/recv/index
// results, conservatively treated as non-owning, same as var-decl).
func (c *funcCtx) freeReassignedSlot(sym symbol) {
	idx := c.findDropForPtr(sym.Ptr)
	if idx < 0 {
		return
	}
	switch c.drops[idx].kind {
	case dropKindSlice:
		c.e.ensureDeclare("declare void @volt_slice_free(ptr)")
		bufP := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", bufP, sym.Ptr)
		fmt.Fprintf(&c.body, "  call void @volt_slice_free(ptr %s)\n", bufP)
	case dropKindMap:
		c.e.ensureDeclare("declare void @volt_map_free(ptr)")
		mh := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", mh, sym.Ptr)
		fmt.Fprintf(&c.body, "  call void @volt_map_free(ptr %s)\n", mh)
	case dropKindString:
		c.e.ensureDeclare("declare void @volt_str_free(ptr)")
		strV := c.newTemp()
		bufP := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = load %%string, ptr %s\n", strV, sym.Ptr)
		fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 0\n", bufP, strV)
		fmt.Fprintf(&c.body, "  call void @volt_str_free(ptr %s)\n", bufP)
	default:
		return // struct/sync-guard/chan drops aren't reassignment-managed
	}
	c.drops = append(c.drops[:idx], c.drops[idx+1:]...)
}

// resolveMethodOnSym returns the FuncDecl for sym.methodName, scanning
// the current-package method table first and falling back to the
// cross-package method registry. Used by emitMultiReturnCall to learn
// the method's result types after dispatching the call.
func (c *funcCtx) resolveMethodOnSym(symName, methodName string) *ast.FuncDecl {
	sym, ok := c.symbols[symName]
	if !ok {
		return nil
	}
	var typeName string
	if sym.AstType != nil {
		switch t := sym.AstType.(type) {
		case *ast.NamedType:
			typeName = t.Name
		case *ast.PointerType:
			if nt, ok := t.Elem.(*ast.NamedType); ok {
				typeName = nt.Name
			}
		case *ast.BorrowType:
			if nt, ok := t.Elem.(*ast.NamedType); ok {
				typeName = nt.Name
			}
		}
	}
	if typeName == "" {
		switch {
		case sym.Elem != "" && strings.HasPrefix(sym.Elem, "%"):
			typeName = strings.TrimPrefix(sym.Elem, "%")
		case strings.HasPrefix(sym.Type, "%") && sym.Type != "%string" && sym.Type != "%slice":
			typeName = strings.TrimPrefix(sym.Type, "%")
		}
	}
	if typeName == "" {
		return nil
	}
	if methods := c.e.methods[typeName]; methods != nil {
		if m := methods[methodName]; m != nil {
			return m
		}
	}
	if ent := c.e.firstExtMethod(typeName, methodName); ent != nil {
		return ent.decl
	}
	return nil
}

// emitMultiReturnCall lowers a function call that yields multiple values.
// Handles both bare-name calls (local package) and SelectorExpr calls
// (`pkg.Func()`) by consulting the cross-package signature registry
// (e.extPkgs) populated via Emitter.AddExternal.
func (c *funcCtx) emitMultiReturnCall(expr ast.Expr) (string, []string, error) {
	call, ok := expr.(*ast.CallExpr)
	if !ok {
		return "", nil, fmt.Errorf("%s: multi-result RHS must be a call", expr.Pos())
	}

	var sig *ast.FuncDecl
	var mangled string

	switch fn := call.Fun.(type) {
	case *ast.IdentExpr:
		s, ok := c.e.funcs[fn.Name]
		if !ok {
			if guess := c.suggestIdentifier(fn.Name); guess != "" {
				return "", nil, fmt.Errorf("%s: undefined function %q (did you mean %q?)", call.Pos(), fn.Name, guess)
			}
			return "", nil, fmt.Errorf("%s: undefined function %q", call.Pos(), fn.Name)
		}
		sig = s
		mangled = SymbolName(c.e.pkg, fn.Name)
	case *ast.SelectorExpr:
		// Three cases for `X.Y(...)`:
		//   (a) X is a package name → cross-package free-function call
		//   (b) X is a local var → method call (current or cross-package)
		//       — for multi-return we delegate to emitMethodCall, which
		//       returns an aggregate Value that we wrap as ("agg", types).
		recvId, ok := fn.X.(*ast.IdentExpr)
		if !ok {
			// COMPILER.multiret-recv: a non-ident receiver for a MULTI-return
			// method — `f().M()`, `s[i].M()`, `r.field.M()`. Spill it into a
			// fresh local (the same helpers the single-return path uses) and
			// recurse with a bare-name receiver, so the caller doesn't have to
			// pre-bind it. This only widens a case that previously hard-errored.
			var recvSym symbol
			var serr error
			switch rx := fn.X.(type) {
			case *ast.CallExpr:
				recvSym, serr = c.spillCallResultAsLocal(rx)
			case *ast.IndexExpr:
				recvSym, serr = c.spillIndexResultAsLocal(rx)
			case *ast.SelectorExpr:
				recvSym, serr = c.spillFieldAsLocal(rx)
			default:
				return "", nil, fmt.Errorf("%s: multi-return method receiver must be a bare variable, call result, index, or field — assign it to a local first", call.Pos())
			}
			if serr != nil {
				return "", nil, serr
			}
			name := fmt.Sprintf("$mrtmp%d", c.nextTmp)
			c.nextTmp++
			c.symbols[name] = recvSym
			return c.emitMultiReturnCall(&ast.CallExpr{
				P:    call.P,
				Fun:  &ast.SelectorExpr{P: fn.P, X: &ast.IdentExpr{P: fn.P, Name: name}, Sel: fn.Sel},
				Args: call.Args,
			})
		}
		if pkgFns, ok := c.e.extPkgs[recvId.Name]; ok {
			// Intercept multi-return intrinsics (fmt.Fprintf etc.) — they
			// don't have a real linked symbol, so we synthesize the call
			// and unpack the aggregate inline.
			full := recvId.Name + "." + fn.Sel
			if full == "fmt.Fprintf" {
				v, err := c.emitFmtFprintf(call)
				if err != nil {
					return "", nil, err
				}
				return v.Name, []string{"i64", "ptr"}, nil
			}
			s, ok := pkgFns[fn.Sel]
			if !ok {
				return "", nil, fmt.Errorf("%s: %s.%s not found", call.Pos(), recvId.Name, fn.Sel)
			}
			sig = s
			mangled = SymbolName(recvId.Name, fn.Sel)
		} else if recvSym, ok := c.symbols[recvId.Name]; ok {
			// Method call on a local. Delegate to emitMethodCall — it
			// already handles current + cross-package methods and
			// returns an aggregate Value when the method has multi-return.
			v, err := c.emitMethodCall(call, fn)
			if err != nil {
				return "", nil, err
			}
			// Interface receiver: pull the method signature out of the
			// interface declaration (the concrete impl table doesn't
			// hold the dispatched signature).
			if iname := c.userInterfaceName(recvSym.AstType); iname != "" {
				iface := c.e.interfaceDecls[iname]
				if iface != nil {
					for _, m := range iface.Methods {
						if m.Name != fn.Sel {
							continue
						}
						ft, _ := m.Type.(*ast.FuncType)
						if ft == nil {
							break
						}
						fieldTypes := make([]string, len(ft.Results))
						for i, r := range ft.Results {
							fieldTypes[i] = c.e.llvmType(r)
						}
						return v.Name, fieldTypes, nil
					}
				}
			}
			// Field-fn receiver: `b.write(...)` where `write` is a
			// struct field of `fun(...) R` type. Pull signature from
			// the field's declared FuncType.
			if tn := c.structTypeNameOfSym(recvSym); tn != "" {
				if info, ok := c.e.structs[tn]; ok {
					if idx, ok := info.Index[fn.Sel]; ok {
						if ft, ok := info.Fields[idx].Type.(*ast.FuncType); ok {
							fieldTypes := make([]string, len(ft.Results))
							for i, r := range ft.Results {
								fieldTypes[i] = c.e.llvmType(r)
							}
							return v.Name, fieldTypes, nil
						}
					}
				}
			}
			// Figure out the method's result types so the caller can
			// extract fields. Look it up the same way emitMethodCall does.
			method := c.resolveMethodOnSym(recvId.Name, fn.Sel)
			if method == nil {
				return "", nil, fmt.Errorf("%s: unable to resolve method %q after dispatch", call.Pos(), fn.Sel)
			}
			fieldTypes := make([]string, len(method.Results))
			for i, r := range method.Results {
				fieldTypes[i] = c.e.llvmType(r)
			}
			return v.Name, fieldTypes, nil
		} else {
			return "", nil, fmt.Errorf("%s: undefined identifier %q in call", call.Pos(), recvId.Name)
		}
	default:
		return "", nil, fmt.Errorf("%s: multi-return only via direct calls in v0.5", call.Pos())
	}

	if len(sig.Results) < 2 {
		return "", nil, fmt.Errorf("%s: %s does not return multiple values", call.Pos(), mangled)
	}
	if len(call.Args) != len(sig.Params) {
		return "", nil, fmt.Errorf("%s: %s takes %d arg(s), got %d",
			call.Pos(), mangled, len(sig.Params), len(call.Args))
	}

	fieldTypes := make([]string, len(sig.Results))
	for i, r := range sig.Results {
		fieldTypes[i] = c.e.llvmType(r)
	}
	aggT := aggregateType(fieldTypes)

	var argStrs []string
	paramTypeStrs := make([]string, len(sig.Params))
	for i, arg := range call.Args {
		v, err := c.emitCallArg(arg, sig.Params[i].Type)
		if err != nil {
			return "", nil, err
		}
		paramT := c.e.llvmType(sig.Params[i].Type)
		paramTypeStrs[i] = paramT
		argStrs = append(argStrs, paramT+" "+v.Name)
	}

	// Cross-package calls need a forward `declare`; in-package calls
	// don't (the function's own `define` is in this same module).
	if _, isSel := call.Fun.(*ast.SelectorExpr); isSel {
		c.e.ensureDeclare(fmt.Sprintf("declare %s @%s(%s)", aggT, mangled, strings.Join(paramTypeStrs, ", ")))
	}

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
// passes null for any unused tail slot.
//
// Two code paths:
//   (1) Fast path: every arg fits in 8 bytes (scalars, ptr) OR is
//       %fn_value (uses 2 slots, matches SysV's 16-byte-struct ABI).
//       Args are passed directly through spawn slots; the receiver
//       function's prologue reads them via its declared param types.
//   (2) Pack+thunk path: any arg is "oversized" (%string, %slice, or
//       a user struct that doesn't fit a register pair). We synthesize
//       a per-call-site thunk that takes a single ptr to a pack-struct,
//       loads each field, and calls the real function with the
//       unpacked args. The pack-struct is heap-allocated.
//
// For >6 args, pack into a struct and pass a single ptr (always uses
// the thunk path).
const spawnMaxArgs = 6

// isSpawnableInOneSlot reports whether an arg of this LLVM type fits
// directly in a single 8-byte spawn slot.
func isSpawnableInOneSlot(llT string) bool {
	switch llT {
	case "i1", "i8", "i16", "i32", "i64", "ptr", "double", "float":
		return true
	}
	return false
}

func (c *funcCtx) emitRun(s *ast.RunStmt) error {
	id, ok := s.Call.Fun.(*ast.IdentExpr)
	if !ok {
		return fmt.Errorf("%s: `run` requires a bare function name in v0.5", s.Pos())
	}
	sig, ok := c.e.funcs[id.Name]
	if !ok {
		if guess := c.suggestIdentifier(id.Name); guess != "" {
			return fmt.Errorf("%s: undefined function %q (did you mean %q?)", s.Pos(), id.Name, guess)
		}
		return fmt.Errorf("%s: undefined function %q", s.Pos(), id.Name)
	}
	if len(s.Call.Args) != len(sig.Params) {
		return fmt.Errorf("%s: %s takes %d arg(s), got %d",
			s.Pos(), id.Name, len(sig.Params), len(s.Call.Args))
	}
	// C13 escape proof: a closure that captures a borrow can't be
	// spawned on a fresh OS thread — the new thread's lifetime is
	// independent of the borrow's scope, so the captured pointer
	// becomes immediately dangling at the thread boundary.
	for _, arg := range s.Call.Args {
		if argId, ok := arg.(*ast.IdentExpr); ok {
			if sym, ok := c.symbols[argId.Name]; ok && sym.CapturesBorrow {
				return fmt.Errorf("%s: cannot pass closure %q to `run` — it captures a borrow whose scope is bound to the spawning thread (C13: borrows can't cross thread boundaries)",
					arg.Pos(), argId.Name)
			}
		}
		if fl, ok := arg.(*ast.FuncLit); ok && fl.CapturesBorrow {
			return fmt.Errorf("%s: cannot `run` a closure that captures a borrow (C13: borrows can't cross thread boundaries)",
				arg.Pos())
		}
	}

	// Decide which path: any oversized arg or >6 params → thunk.
	paramLL := make([]string, len(sig.Params))
	needsThunk := len(sig.Params) > spawnMaxArgs
	for i, p := range sig.Params {
		paramLL[i] = c.e.llvmType(p.Type)
		if !isSpawnableInOneSlot(paramLL[i]) && paramLL[i] != "%fn_value" {
			needsThunk = true
		}
		// #6: a captured channel must be retained for the goroutine and
		// released when it finishes. The release lives in the per-spawn
		// thunk (the bare user function `f` is also called synchronously,
		// so it can't release), so any channel capture forces the thunk
		// path.
		if _, isChan := p.Type.(*ast.ChanType); isChan {
			needsThunk = true
		}
	}

	if needsThunk {
		return c.emitRunViaThunk(s, sig, paramLL)
	}

	args := make([]string, spawnMaxArgs)
	for i := range args {
		args[i] = "null"
	}
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
	// #7: count the new thread BEFORE spawning it (parent-side), so the
	// deadlock backstop never sees a worker that exists but isn't yet in
	// g_live_threads. The worker calls volt_thread_exit when it returns.
	c.e.ensureDeclare("declare void @volt_thread_begin()")
	c.body.WriteString("  call void @volt_thread_begin()\n")
	c.e.ensureDeclare("declare void @volt_spawn(ptr, ptr, ptr, ptr, ptr, ptr, ptr)")
	fmt.Fprintf(&c.body, "  call void @volt_spawn(ptr @%s, ptr %s, ptr %s, ptr %s, ptr %s, ptr %s, ptr %s)\n",
		mangled, args[0], args[1], args[2], args[3], args[4], args[5])
	return nil
}

// emitRunViaThunk handles `run f(...)` when one or more args are
// oversized (won't fit a single 8-byte spawn slot). Approach:
//   1. Synthesize a per-call-site pack struct holding all args by type.
//   2. heap-alloc a pack, store each arg value into its field.
//   3. Synthesize a thunk function that takes (ptr pack), unpacks each
//      field with the right type, and tail-calls f.
//   4. Spawn the thunk with the pack ptr.
func (c *funcCtx) emitRunViaThunk(s *ast.RunStmt, sig *ast.FuncDecl, paramLL []string) error {
	id := s.Call.Fun.(*ast.IdentExpr)

	// Evaluate args into values FIRST (in caller scope).
	argVals := make([]Value, len(s.Call.Args))
	for i, expr := range s.Call.Args {
		v, err := c.emitCallArg(expr, sig.Params[i].Type)
		if err != nil {
			return err
		}
		argVals[i] = v
	}

	// #6: retain one ref per captured channel BEFORE the spawn, so the
	// goroutine's ref strictly happens-before it could run (and release).
	// The matching release runs at the end of the thunk below — balanced.
	hasChanParam := false
	for i, p := range sig.Params {
		if _, isChan := p.Type.(*ast.ChanType); isChan {
			hasChanParam = true
			c.e.ensureDeclare("declare void @volt_chan_retain(ptr)")
			fmt.Fprintf(&c.body, "  call void @volt_chan_retain(ptr %s)\n", argVals[i].Name)
		}
	}
	if hasChanParam {
		c.e.ensureDeclare("declare void @volt_chan_release(ptr)")
	}

	thunkID := c.e.nextThunkID
	c.e.nextThunkID++
	mangledF := SymbolName(c.e.pkg, id.Name)
	thunkSym := fmt.Sprintf("%s_$runthunk_%d", c.e.pkg, thunkID)
	packTy := fmt.Sprintf("%%%s_$runpack_%d", c.e.pkg, thunkID)

	// Declare pack struct type at module header.
	var fields strings.Builder
	for i, t := range paramLL {
		if i > 0 {
			fields.WriteString(", ")
		}
		fields.WriteString(t)
	}
	fmt.Fprintf(&c.e.header, "%s = type { %s }\n", packTy, fields.String())

	// Emit thunk body into the trampoline pool.
	var tb strings.Builder
	fmt.Fprintf(&tb, "define internal void @%s(ptr %%pack) {\n", thunkSym)
	tb.WriteString("entry:\n")
	loaded := make([]string, len(paramLL))
	for i, t := range paramLL {
		fieldP := fmt.Sprintf("%%f%d.ptr", i)
		fmt.Fprintf(&tb, "  %s = getelementptr %s, ptr %%pack, i32 0, i32 %d\n", fieldP, packTy, i)
		loadV := fmt.Sprintf("%%f%d", i)
		fmt.Fprintf(&tb, "  %s = load %s, ptr %s\n", loadV, t, fieldP)
		loaded[i] = loadV
	}
	fmt.Fprintf(&tb, "  call void @%s(", mangledF)
	for i, t := range paramLL {
		if i > 0 {
			tb.WriteString(", ")
		}
		fmt.Fprintf(&tb, "%s %s", t, loaded[i])
	}
	tb.WriteString(")\n")
	// #6: release this goroutine's retained ref on each captured channel
	// AFTER the call returns. The matching retain happened in the spawner.
	for i, p := range sig.Params {
		if _, isChan := p.Type.(*ast.ChanType); isChan {
			fmt.Fprintf(&tb, "  call void @volt_chan_release(ptr %s)\n", loaded[i])
		}
	}
	tb.WriteString("  ret void\n")
	tb.WriteString("}\n\n")
	c.e.trampolineDefs.WriteString(tb.String())

	// Allocate pack on heap; store each arg into its field.
	c.e.ensureDeclare("declare ptr @volt_alloc(i64)")
	sizeT := c.newTemp()
	sizeI := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = getelementptr %s, ptr null, i32 1\n", sizeT, packTy)
	fmt.Fprintf(&c.body, "  %s = ptrtoint ptr %s to i64\n", sizeI, sizeT)
	packPtr := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call ptr @volt_alloc(i64 %s)\n", packPtr, sizeI)
	for i, v := range argVals {
		conv := c.convertInt(v, paramLL[i])
		fieldP := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = getelementptr %s, ptr %s, i32 0, i32 %d\n", fieldP, packTy, packPtr, i)
		fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", paramLL[i], conv.Name, fieldP)
	}

	// #7: count the new thread parent-side before the spawn (see emitRun).
	c.e.ensureDeclare("declare void @volt_thread_begin()")
	c.body.WriteString("  call void @volt_thread_begin()\n")
	c.e.ensureDeclare("declare void @volt_spawn(ptr, ptr, ptr, ptr, ptr, ptr, ptr)")
	fmt.Fprintf(&c.body, "  call void @volt_spawn(ptr @%s, ptr %s, ptr null, ptr null, ptr null, ptr null, ptr null)\n",
		thunkSym, packPtr)
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

	// Pre-compute channel pointers, element types, and (for send) values
	// + their stack slots, OUTSIDE the loop so we don't re-eval
	// side-effecting exprs on every iteration.
	type compiledCase struct {
		chanV    Value
		elemLL   string
		sendSlot string // for send cases: ptr to value
		recvSlot string // for recv cases: ptr to value destination
	}
	compiled := make([]compiledCase, len(channelCases))
	for i, cs := range channelCases {
		chV, err := c.emitExpr(cs.Channel)
		if err != nil {
			return err
		}
		compiled[i].chanV = chV
		compiled[i].elemLL = c.chanArgElem(cs.Channel)
		if cs.SendValue != nil {
			sv, err := c.emitExpr(cs.SendValue)
			if err != nil {
				return err
			}
			sv = c.convertInt(sv, compiled[i].elemLL)
			slot := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = alloca %s\n", slot, compiled[i].elemLL)
			fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", compiled[i].elemLL, sv.Name, slot)
			compiled[i].sendSlot = slot
		} else {
			slot := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = alloca %s\n", slot, compiled[i].elemLL)
			compiled[i].recvSlot = slot
		}
	}

	fmt.Fprintf(&c.body, "  br label %%%s\n", loopLbl)
	c.terminated = true
	c.startBlock(loopLbl)

	c.e.ensureDeclare("declare i64 @volt_chan_try_send(ptr, ptr)")
	c.e.ensureDeclare("declare i64 @volt_chan_try_recv(ptr, ptr)")
	c.e.ensureDeclare("declare void @volt_yield()")

	for i, cs := range channelCases {
		nextLbl := c.newLabel("select.try")
		if cs.SendValue != nil {
			ok := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = call i64 @volt_chan_try_send(ptr %s, ptr %s)\n",
				ok, compiled[i].chanV.Name, compiled[i].sendSlot)
			cmp := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = icmp ne i64 %s, 0\n", cmp, ok)
			fmt.Fprintf(&c.body, "  br i1 %s, label %%%s, label %%%s\n", cmp, bodyLbls[i], nextLbl)
		} else {
			ok := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = call i64 @volt_chan_try_recv(ptr %s, ptr %s)\n",
				ok, compiled[i].chanV.Name, compiled[i].recvSlot)
			cmp := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = icmp ne i64 %s, 0\n", cmp, ok)
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
		// Bind recv names from the slot the loop populated.
		if cs.SendValue == nil && len(cs.RecvNames) > 0 {
			elemLL := compiled[i].elemLL
			vTmp := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = load %s, ptr %s\n", vTmp, elemLL, compiled[i].recvSlot)
			ptr := fmt.Sprintf("%%%s.case%d.addr", cs.RecvNames[0], i)
			fmt.Fprintf(&c.body, "  %s = alloca %s\n", ptr, elemLL)
			fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", elemLL, vTmp, ptr)
			if err := c.bindLocal(cs.RecvNames[0], symbol{Ptr: ptr, Type: elemLL}, cs.P); err != nil {
				return err
			}
			if len(cs.RecvNames) == 2 {
				// ok is always 1 in the body block (we only enter on success).
				okPtr := fmt.Sprintf("%%%s.case%d.addr", cs.RecvNames[1], i)
				fmt.Fprintf(&c.body, "  %s = alloca i64\n", okPtr)
				fmt.Fprintf(&c.body, "  store i64 1, ptr %s\n", okPtr)
				if err := c.bindLocal(cs.RecvNames[1], symbol{Ptr: okPtr, Type: "i64"}, cs.P); err != nil {
					return err
				}
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
	c.emitRaceSync("acquire", h)
	fmt.Fprintf(&c.body, "  store ptr %s, ptr %s\n", pl, addrPtr)

	if err := c.bindLocal(s.Name, symbol{
		Ptr:        addrPtr,
		Type:       "ptr",
		Elem:       elemT,
		IsGuard:    true,
		IsReadOnly: gc.readOnly,
		AstType:    gc.elem,
	}, s.P); err != nil {
		return err
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

// typeMismatchMessage returns a friendly volt-level error when a value
// of LLVM type `valLLVM` cannot be stored into a slot of LLVM type
// `targetLLVM`. Returns "" when the assignment is either already
// type-correct, numerically convertible, or covered by upstream
// boxing (error / any / interface / *T-Box / fn_value).
//
// The intent is to catch obvious cases like `var x int = "literal"`
// here, before the IR-level store produces a cryptic clang error.
func typeMismatchMessage(astType ast.Type, valLLVM, targetLLVM string) string {
	if valLLVM == targetLLVM {
		return ""
	}
	// Both numeric — convertInt / harmonize handles widening/narrowing.
	if isNumericLLVM(valLLVM) && isNumericLLVM(targetLLVM) {
		return ""
	}
	// Target is opaque ptr (error / any / interface / map / chan /
	// pointer / sync handle). All the implicit-conversion paths that
	// produce a ptr ran upstream; trust them and stay silent.
	if targetLLVM == "ptr" {
		return ""
	}
	// Source ptr → %fn_value is the closure-binding path; leave it.
	if valLLVM == "ptr" && targetLLVM == "%fn_value" {
		return ""
	}
	valName := llvmTypeFriendlyName(valLLVM)
	targetName := astTypeFriendlyName(astType, targetLLVM)
	if valName == "" || targetName == "" {
		return ""
	}
	return fmt.Sprintf("type mismatch: cannot use %s value where %s is expected", valName, targetName)
}

// isNumericLLVM reports whether t is an integer or float LLVM type.
func isNumericLLVM(t string) bool {
	return intBitSize(t) != 0 || isFloatLLVM(t)
}

// llvmTypeFriendlyName maps an LLVM type string back to a user-facing
// volt type name (best-effort; unknown types return "").
func llvmTypeFriendlyName(llvm string) string {
	switch llvm {
	case "i1":
		return "bool"
	case "i8":
		return "byte"
	case "i16":
		return "int16"
	case "i32":
		return "int32"
	case "i64":
		return "int"
	case "float":
		return "float32"
	case "double":
		return "float"
	case "%string":
		return "string"
	case "%slice":
		return "slice"
	case "%error_box":
		return "error"
	case "%fn_value":
		return "fun"
	case "ptr":
		return "pointer"
	}
	if rest, ok := strings.CutPrefix(llvm, "%"); ok {
		return rest
	}
	return ""
}

// astTypeFriendlyName prefers the AST-level declared name (so the user
// sees the name they wrote — `int`, `MyStruct`, etc.) and falls back
// to the LLVM-derived friendly name when the AST shape isn't a simple
// NamedType.
func astTypeFriendlyName(t ast.Type, fallbackLLVM string) string {
	if nt, ok := t.(*ast.NamedType); ok {
		return nt.Name
	}
	return llvmTypeFriendlyName(fallbackLLVM)
}

// suggestIdentifier scans c.symbols and c.e.funcs for the candidate
// closest to `name` by edit distance. Returns "" when no candidate is
// within a tight threshold (≤ 2 edits or ≤ 1/3 of the longer length).
// Used to turn `undefined identifier "cuonter"` into
// `undefined identifier "cuonter" (did you mean "counter"?)`.
func (c *funcCtx) suggestIdentifier(name string) string {
	cands := make([]string, 0, len(c.symbols)+len(c.e.funcs))
	for n := range c.symbols {
		cands = append(cands, n)
	}
	for n := range c.e.funcs {
		cands = append(cands, n)
	}
	return closestName(name, cands)
}

// validateNamedType ensures the named-type references in `t`
// resolve to either a built-in or a user-declared struct/interface.
// Recursively descends into pointer/borrow/slice/map/chan/sync
// wrappers so `var x *Foo = ...` catches an unknown `Foo` the same
// as `var x Foo = ...`. Returns a friendly error (with did-you-mean
// when close to a known type) on the first unknown NamedType.
func (e *Emitter) validateNamedType(t ast.Type) error {
	switch tt := t.(type) {
	case nil:
		return nil
	case *ast.NamedType:
		if isBuiltinTypeName(tt.Name) {
			return nil
		}
		if _, ok := e.structs[tt.Name]; ok {
			return nil
		}
		if e.interfaces[tt.Name] {
			return nil
		}
		cands := []string{}
		for n := range e.structs {
			cands = append(cands, n)
		}
		for n := range e.interfaces {
			cands = append(cands, n)
		}
		if guess := closestName(tt.Name, cands); guess != "" {
			return fmt.Errorf("%s: unknown type %q (did you mean %q?)", tt.P, tt.Name, guess)
		}
		return fmt.Errorf("%s: unknown type %q", tt.P, tt.Name)
	case *ast.PointerType:
		return e.validateNamedType(tt.Elem)
	case *ast.BorrowType:
		return e.validateNamedType(tt.Elem)
	case *ast.SliceType:
		return e.validateNamedType(tt.Elem)
	case *ast.MapType:
		if err := e.validateNamedType(tt.Key); err != nil {
			return err
		}
		return e.validateNamedType(tt.Value)
	case *ast.ChanType:
		return e.validateNamedType(tt.Elem)
	case *ast.AtomicType:
		return e.validateNamedType(tt.Elem)
	case *ast.MutexType:
		return e.validateNamedType(tt.Elem)
	case *ast.RwMutexType:
		return e.validateNamedType(tt.Elem)
	}
	return nil
}

// isBuiltinTypeName reports whether `name` is one of volt's built-in
// scalar / interface type names.
func isBuiltinTypeName(name string) bool {
	switch name {
	case "int", "int64", "uint", "uint64",
		"int32", "uint32", "int16", "uint16",
		"int8", "uint8", "byte", "bool",
		"float", "float64", "float32", "string",
		"error", "any":
		return true
	}
	return false
}

// findStructValueCycle walks every struct declared in `file` and
// reports the first by-value cycle it finds: a chain of struct
// fields (each a `NamedType`, not a pointer or borrow) that loops
// back on itself. Returns (container, fieldType, pos) when a cycle
// exists, all zero values otherwise. The position points at the
// container's TypeDecl (better than the field — the user can read
// the offending struct's body inline at that spot).
func (e *Emitter) findStructValueCycle(file *ast.File) (string, string, lex.Pos) {
	var visit func(name string, stack map[string]bool) (string, string)
	visit = func(name string, stack map[string]bool) (string, string) {
		info, ok := e.structs[name]
		if !ok {
			return "", ""
		}
		if stack[name] {
			return "", ""
		}
		stack[name] = true
		defer delete(stack, name)
		for _, f := range info.Fields {
			nt, ok := f.Type.(*ast.NamedType)
			if !ok {
				continue
			}
			if _, ok := e.structs[nt.Name]; !ok {
				continue
			}
			if stack[nt.Name] {
				return name, nt.Name
			}
			if c, fT := visit(nt.Name, stack); c != "" {
				return c, fT
			}
		}
		return "", ""
	}
	for _, d := range file.Decls {
		td, ok := d.(*ast.TypeDecl)
		if !ok {
			continue
		}
		if _, ok := td.Type.(*ast.StructType); !ok {
			continue
		}
		stack := make(map[string]bool)
		if c, fT := visit(td.Name, stack); c != "" {
			return c, fT, td.Pos()
		}
	}
	return "", "", lex.Pos{}
}

// suggestField returns the field of `typeName` closest to `name` by
// edit distance, or "" when no field is within the suggestion
// threshold. Used to turn `Point has no field "cuonter"` into
// `Point has no field "cuonter" (did you mean "counter"?)`.
func (e *Emitter) suggestField(typeName, name string) string {
	info, ok := e.structs[typeName]
	if !ok {
		return ""
	}
	cands := make([]string, 0, len(info.Fields))
	for _, f := range info.Fields {
		cands = append(cands, f.Name)
	}
	return closestName(name, cands)
}

// suggestMethod returns the method on `typeName` closest to `name`,
// scanning both local and cross-package method registries. Returns
// "" when nothing is within the threshold.
func (e *Emitter) suggestMethod(typeName, name string) string {
	cands := []string{}
	for n := range e.methods[typeName] {
		cands = append(cands, n)
	}
	for n := range e.extMethods[typeName] {
		cands = append(cands, n)
	}
	return closestName(name, cands)
}

// closestName picks the candidate with smallest edit distance to
// `name`, returning "" when nothing is within the suggestion
// threshold (≤ 2 edits unconditionally, or `dist*3 ≤ longest-length`
// for longer identifiers).
func closestName(name string, cands []string) string {
	best := ""
	bestDist := 1 << 30
	for _, cand := range cands {
		if cand == name || cand == "" {
			continue
		}
		d := levenshteinDistance(name, cand)
		if d < bestDist {
			bestDist = d
			best = cand
		}
	}
	longest := max(len(name), len(best))
	if best == "" || bestDist > 2 && bestDist*3 > longest {
		return ""
	}
	return best
}

// levenshteinDistance computes the edit distance between a and b
// (insertions, deletions, substitutions all cost 1). Mirrors the LSP
// package's helper; duplicated here so codegen can stay independent
// of cmd/volt.
func levenshteinDistance(a, b string) int {
	la, lb := len(a), len(b)
	if la == 0 {
		return lb
	}
	if lb == 0 {
		return la
	}
	prev := make([]int, lb+1)
	curr := make([]int, lb+1)
	for j := 0; j <= lb; j++ {
		prev[j] = j
	}
	for i := 1; i <= la; i++ {
		curr[0] = i
		for j := 1; j <= lb; j++ {
			cost := 1
			if a[i-1] == b[j-1] {
				cost = 0
			}
			del := prev[j] + 1
			ins := curr[j-1] + 1
			sub := prev[j-1] + cost
			curr[j] = min(del, ins, sub)
		}
		prev, curr = curr, prev
	}
	return prev[lb]
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

// structTypeNameOfSym returns the bare struct type name of a symbol —
// owned struct value, pointer-to-struct, or borrow-of-struct. Empty
// if the symbol isn't a struct (or known struct shape).
func (c *funcCtx) structTypeNameOfSym(sym symbol) string {
	if sym.AstType != nil {
		switch t := sym.AstType.(type) {
		case *ast.NamedType:
			return t.Name
		case *ast.PointerType:
			if nt, ok := t.Elem.(*ast.NamedType); ok {
				return nt.Name
			}
		case *ast.BorrowType:
			if nt, ok := t.Elem.(*ast.NamedType); ok {
				return nt.Name
			}
		}
	}
	if sym.Elem != "" && strings.HasPrefix(sym.Elem, "%") {
		return strings.TrimPrefix(sym.Elem, "%")
	}
	if strings.HasPrefix(sym.Type, "%") && sym.Type != "%string" && sym.Type != "%slice" {
		return strings.TrimPrefix(sym.Type, "%")
	}
	return ""
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
	// For a concrete `*T` (Type "ptr") the type name comes from
	// Value.Concrete; for a value (Type "%T") it's the LLVM type itself.
	isPtrVal := val.Type == "ptr"
	typeName := strings.TrimPrefix(val.Type, "%")
	if isPtrVal && val.Concrete != "" {
		typeName = val.Concrete
	}
	if !c.e.ifaceImpls[typeName][ifaceName] {
		// Diff iface methods against type methods to surface what's
		// missing (or mis-signed). Local + cross-package methods both
		// count as implemented when the signature matches.
		missing := []string{}
		mismatched := []string{}
		if iface := c.e.interfaceDecls[ifaceName]; iface != nil {
			for _, m := range iface.Methods {
				var concrete *ast.FuncDecl
				if md, ok := c.e.methods[typeName][m.Name]; ok {
					concrete = md
				} else if ext := c.e.firstExtMethod(typeName, m.Name); ext != nil {
					concrete = ext.decl
				}
				if concrete == nil {
					missing = append(missing, m.Name)
					continue
				}
				if ift, ok := m.Type.(*ast.FuncType); ok && !methodMatchesIfaceSig(concrete, ift) {
					mismatched = append(mismatched, m.Name)
				}
			}
		}
		switch {
		case len(missing) > 0 && len(mismatched) > 0:
			return Value{}, fmt.Errorf("%s: type %s does not implement interface %s (missing: %s; signature mismatch: %s)",
				pos, typeName, ifaceName, strings.Join(missing, ", "), strings.Join(mismatched, ", "))
		case len(mismatched) > 0:
			return Value{}, fmt.Errorf("%s: type %s does not implement interface %s (signature mismatch on method(s): %s)",
				pos, typeName, ifaceName, strings.Join(mismatched, ", "))
		case len(missing) > 0:
			return Value{}, fmt.Errorf("%s: type %s does not implement interface %s (missing method(s): %s)",
				pos, typeName, ifaceName, strings.Join(missing, ", "))
		}
		return Value{}, fmt.Errorf("%s: type %s does not implement interface %s (missing one of its methods)",
			pos, typeName, ifaceName)
	}
	// The vtable lives in the package that owns the concrete type. Prefer
	// the value's tracked owning package (disambiguates same-named types
	// across packages — volt's type namespace is global); fall back to
	// vtableOwner. Forward-declare it when it belongs to another package so
	// the linker resolves the reference.
	owner := val.ConcretePkg
	if owner == "" {
		owner = c.e.vtableOwner(typeName)
	}
	vtableSym := fmt.Sprintf("%s_%s_%s_vtable", owner, typeName, ifaceName)
	if owner != c.e.pkg {
		iface := c.e.interfaceDecls[ifaceName]
		nMethods := 0
		if iface != nil {
			nMethods = len(iface.Methods)
		}
		c.e.ensureDeclare(fmt.Sprintf("@%s = external constant [%d x ptr]", vtableSym, nMethods))
	}
	// Determine the data pointer for the box. For a concrete `*T` the
	// pointer IS the data slot — store it directly so dispatch passes the
	// real `*T` as the receiver (pointer-receiver methods consume it; the
	// value-receiver `_$iface` trampoline loads `T` from it). For a value,
	// heap-allocate a copy and point at it.
	c.e.ensureDeclare("declare ptr @volt_alloc(i64)")
	var dataPtr string
	if isPtrVal {
		dataPtr = val.Name
	} else {
		szPtr := c.newTemp()
		szInt := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = getelementptr %s, ptr null, i32 1\n", szPtr, val.Type)
		fmt.Fprintf(&c.body, "  %s = ptrtoint ptr %s to i64\n", szInt, szPtr)
		dataPtr = c.newTemp()
		fmt.Fprintf(&c.body, "  %s = call ptr @volt_alloc(i64 %s)\n", dataPtr, szInt)
		fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", val.Type, val.Name, dataPtr)
	}

	// Allocate the 16-byte fat pointer box {ptr data, ptr vtable}.
	// We reuse %error_box's layout (same shape — the second slot is
	// just opaque; error stores a fn ptr, user-iface stores a vtable
	// ptr; the dispatch path knows which kind it has).
	boxPtr := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call ptr @volt_alloc(i64 16)\n", boxPtr)
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
	switch {
	case len(methodFt.Results) == 0:
		retT = "void"
	case len(methodFt.Results) == 1:
		retT = c.e.llvmType(methodFt.Results[0])
	default:
		// Multi-return: aggregate "{T1, T2, ...}". Caller side
		// (emitMultiAssign / emitMultiVar) splits via extractvalue.
		var sb strings.Builder
		sb.WriteByte('{')
		for i, r := range methodFt.Results {
			if i > 0 {
				sb.WriteString(", ")
			}
			sb.WriteString(c.e.llvmType(r))
		}
		sb.WriteByte('}')
		retT = sb.String()
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

// pointeeStructName returns the bare struct type name `T` when
// expression `expr` has declared type `*T` (PointerType to
// NamedType) — used to drive auto-deref at field-access sites
// where the inner expression is a CallExpr, IndexExpr, or
// SelectorExpr returning/holding a pointer-to-struct. Returns ""
// when the type isn't recoverable or isn't a pointer-to-struct.
func (c *funcCtx) pointeeStructName(expr ast.Expr) string {
	var astT ast.Type
	switch e := expr.(type) {
	case *ast.IdentExpr:
		if sym, ok := c.symbols[e.Name]; ok {
			astT = sym.AstType
		}
	case *ast.CallExpr:
		switch fn := e.Fun.(type) {
		case *ast.IdentExpr:
			if fd, ok := c.e.funcs[fn.Name]; ok && len(fd.Results) == 1 {
				astT = fd.Results[0]
			}
		case *ast.SelectorExpr:
			if pkgId, ok := fn.X.(*ast.IdentExpr); ok {
				if pkgFns, ok := c.e.extPkgs[pkgId.Name]; ok {
					if sig, ok := pkgFns[fn.Sel]; ok && len(sig.Results) == 1 {
						astT = sig.Results[0]
					}
				}
			}
		}
	case *ast.IndexExpr:
		if id, ok := e.X.(*ast.IdentExpr); ok {
			if sym, ok := c.symbols[id.Name]; ok {
				switch t := sym.AstType.(type) {
				case *ast.SliceType:
					astT = t.Elem
				case *ast.MapType:
					astT = t.Value
				}
			}
		}
		// Field slice (`h.items[i]`) or nested index (`grid[r][c]`):
		// e.X isn't a bare ident, so recover the element type by walking
		// the selector/index chain. Lets field-access auto-deref a
		// pointer element reached through a struct field.
		if astT == nil {
			astT = c.indexedElemAst(e.X)
		}
	case *ast.SelectorExpr:
		// Determine the bare struct name that e.X represents. For
		// `w.o`-style chains where e.X is itself a SelectorExpr
		// returning *T, recurse to find the pointee struct first.
		var outerStructName string
		if id, ok := e.X.(*ast.IdentExpr); ok {
			if sym, ok := c.symbols[id.Name]; ok {
				outerStructName = c.structTypeNameOfSym(sym)
			}
		} else {
			outerStructName = c.pointeeStructName(e.X)
		}
		if outerStructName != "" {
			if info, ok := c.e.structs[outerStructName]; ok {
				if idx, ok := info.Index[e.Sel]; ok {
					astT = info.Fields[idx].Type
				}
			}
		}
	}
	if pt, ok := astT.(*ast.PointerType); ok {
		if nt, ok := pt.Elem.(*ast.NamedType); ok {
			if _, isStruct := c.e.structs[nt.Name]; isStruct {
				return nt.Name
			}
		}
	}
	return ""
}

// maybeBoxForPointer auto-boxes `val` (a struct value of type %T)
// when the target slot is declared as *T. Heap-allocates the struct
// and returns the ptr. Mirrors the implicit-Box pattern that
// emitVar uses for `var f *T = new T{...}`. Returns the value
// unchanged when no boxing applies.
func (c *funcCtx) maybeBoxForPointer(val Value, targetAst ast.Type) Value {
	pt, ok := targetAst.(*ast.PointerType)
	if !ok {
		return val
	}
	nt, ok := pt.Elem.(*ast.NamedType)
	if !ok {
		return val
	}
	if !strings.HasPrefix(val.Type, "%") || val.Type == "%string" || val.Type == "%slice" || val.Type == "%error_box" || val.Type == "%fn_value" {
		return val
	}
	if "%"+nt.Name != val.Type {
		return val
	}
	c.e.ensureDeclare("declare ptr @volt_alloc(i64)")
	sizeT := c.newTemp()
	sizeI := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = getelementptr %s, ptr null, i32 1\n", sizeT, val.Type)
	fmt.Fprintf(&c.body, "  %s = ptrtoint ptr %s to i64\n", sizeI, sizeT)
	heap := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call ptr @volt_alloc(i64 %s)\n", heap, sizeI)
	fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", val.Type, val.Name, heap)
	return Value{Name: heap, Type: "ptr"}
}

// ptrNamedTypeName returns (T, true) when `t` is `*T` for a NamedType T.
func ptrNamedTypeName(t ast.Type) (string, bool) {
	if pt, ok := t.(*ast.PointerType); ok {
		if nt, ok := pt.Elem.(*ast.NamedType); ok {
			return nt.Name, true
		}
	}
	return "", false
}

// namedBase returns the named type name of `S`, `*S`, or `&S` (the struct
// a variable of that type carries), or "" otherwise.
func namedBase(t ast.Type) string {
	switch tt := t.(type) {
	case *ast.NamedType:
		return tt.Name
	case *ast.PointerType:
		if nt, ok := tt.Elem.(*ast.NamedType); ok {
			return nt.Name
		}
	case *ast.BorrowType:
		if nt, ok := tt.Elem.(*ast.NamedType); ok {
			return nt.Name
		}
	}
	return ""
}

// methodDeclOn resolves method `name` on the named type `tn`, local
// methods first then cross-package, or nil.
func (c *funcCtx) methodDeclOn(tn, name string) *ast.FuncDecl {
	if m, ok := c.e.methods[tn]; ok {
		if md := m[name]; md != nil {
			return md
		}
	}
	if ext := c.e.lookupExtMethod(tn, name, ""); ext != nil {
		return ext.decl
	}
	return nil
}

// concretePtrType returns the named type T and the package that owns it
// when `expr` statically has type `*T` (a concrete pointer to a struct),
// or ("","") otherwise. It lets interface boxing distinguish a concrete
// `*T` (which must be wrapped in a {data,vtable} fat pointer) from an
// already-boxed interface value — both lower to LLVM "ptr" — and reference
// the right package-qualified vtable. Best-effort over the producers that
// yield a `*T`: `new T{}`, `*T`-typed identifiers, free/cross-package calls
// returning `*T`, method calls on a variable returning `*T`, and `*T`
// struct fields of a variable. Interface-typed results/fields correctly
// return "" (their element is a bare NamedType, not `*T`), so an already-
// boxed value passes through unboxed.
func (c *funcCtx) concretePtrType(expr ast.Expr) (string, string) {
	switch e := expr.(type) {
	case *ast.NewExpr:
		if nt, ok := e.Type.(*ast.NamedType); ok {
			return nt.Name, c.e.vtableOwner(nt.Name)
		}
	case *ast.IdentExpr:
		if sym, ok := c.symbols[e.Name]; ok && sym.AstType != nil {
			if n, ok := ptrNamedTypeName(sym.AstType); ok {
				return n, c.e.vtableOwner(n)
			}
		}
	case *ast.SelectorExpr:
		// Field access X.f where X is a variable of struct type S/*S and
		// the field f has type *T.
		if recvID, ok := e.X.(*ast.IdentExpr); ok {
			if sym, ok := c.symbols[recvID.Name]; ok {
				if sname := namedBase(sym.AstType); sname != "" {
					if si := c.e.structs[sname]; si != nil {
						if idx, ok := si.Index[e.Sel]; ok && idx < len(si.Fields) {
							if n, ok := ptrNamedTypeName(si.Fields[idx].Type); ok {
								return n, c.e.vtableOwner(n)
							}
						}
					}
				}
			}
		}
	case *ast.CallExpr:
		var fd *ast.FuncDecl
		pkg := ""
		switch fn := e.Fun.(type) {
		case *ast.IdentExpr:
			fd = c.e.funcs[fn.Name]
		case *ast.SelectorExpr:
			if recvID, ok := fn.X.(*ast.IdentExpr); ok {
				if pkgFns, ok := c.e.extPkgs[recvID.Name]; ok {
					// pkg.Func(...) — the returned *T is that package's type.
					fd = pkgFns[fn.Sel]
					pkg = recvID.Name
				} else if sym, ok := c.symbols[recvID.Name]; ok {
					// method call on a variable: X.M(...) where X : S/*S.
					if sname := namedBase(sym.AstType); sname != "" {
						fd = c.methodDeclOn(sname, fn.Sel)
					}
				}
			}
		}
		if fd != nil && len(fd.Results) == 1 {
			if n, ok := ptrNamedTypeName(fd.Results[0]); ok {
				if pkg == "" {
					pkg = c.e.vtableOwner(n)
				}
				return n, pkg
			}
		}
	}
	return "", ""
}

// emitMaybePtrForIface emits `expr` for assignment/passing into the slot
// typed `targetAst`. When the target is a USER INTERFACE and `expr` is an
// identifier bound to a concrete `*T` variable whose T implements that
// interface, it loads the POINTER (so the boxed interface shares the
// variable's pointee — pointer-receiver mutations through the box persist)
// instead of emitExpr's auto-deref'd value COPY. Every other case falls
// back to plain emitExpr. (Mirrors the borrow-var raw-ptr special-case in
// the var-decl path.)
func (c *funcCtx) emitMaybePtrForIface(expr ast.Expr, targetAst ast.Type) (Value, error) {
	if targetAst != nil {
		if iname := c.userInterfaceName(targetAst); iname != "" {
			if id, ok := expr.(*ast.IdentExpr); ok {
				if sym, ok := c.symbols[id.Name]; ok && sym.Ptr != "" {
					if tn, ok := ptrNamedTypeName(sym.AstType); ok && c.e.ifaceImpls[tn][iname] {
						pkg := sym.ConcretePkg
						if pkg == "" {
							pkg = c.e.vtableOwner(tn)
						}
						t := c.newTemp()
						fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", t, sym.Ptr)
						return Value{Name: t, Type: "ptr", Concrete: tn, ConcretePkg: pkg}, nil
					}
				}
			}
		}
	}
	return c.emitExpr(expr)
}

// maybeBoxForInterface auto-boxes `val` when the declared target
// type is an interface (`error`, `any`, or a user-declared
// interface). Returns the value unchanged when no boxing applies:
// target isn't an interface, value is already a `ptr` /
// `%error_box`, etc. Used by ret + multi-return so concrete values
// flow through interface-typed slots without a manual conversion.
func (c *funcCtx) maybeBoxForInterface(pos lex.Pos, val Value, targetAst ast.Type) (Value, error) {
	if targetAst == nil {
		return val, nil
	}
	// User interface: emitIfaceBox produces a vtable fat pointer.
	if iname := c.userInterfaceName(targetAst); iname != "" {
		if val.Type == "ptr" {
			// A concrete `*T` whose T implements the interface must be
			// boxed into a {data,vtable} fat pointer (the `*T` is the data
			// slot directly). A "ptr" with no known concrete type is an
			// already-boxed interface value (or untracked) — pass through.
			if val.Concrete != "" && c.e.ifaceImpls[val.Concrete][iname] {
				return c.emitIfaceBox(pos, val, iname)
			}
			return val, nil
		}
		return c.emitIfaceBox(pos, val, iname)
	}
	// Built-in `error`: same boxing predicate as the var-decl path.
	if isErrorType(targetAst) {
		if val.Type == "ptr" {
			return val, nil
		}
		if strings.HasPrefix(val.Type, "%") && val.Type != "%string" && val.Type != "%slice" && val.Type != "%error_box" {
			return c.emitErrorBox(pos, val)
		}
		return val, nil
	}
	// Built-in `any`: heap-copy concrete value, return ptr.
	if isAnyType(targetAst) {
		if val.Type == "ptr" {
			return val, nil
		}
		return c.emitAnyBox(pos, val)
	}
	return val, nil
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
	// Shadow guard: `emitIdent` consults top-level consts BEFORE the
	// local symbol table, so a local `var X = 10` declared with the
	// same name as a const `X = 5` would silently still resolve to 5
	// — a quiet correctness bug. Reject the collision at the var-decl
	// site instead of letting it slip through.
	if _, isConst := c.e.consts[s.Name]; isConst {
		return fmt.Errorf("%s: local variable %q collides with top-level constant of the same name — rename one of them",
			s.Pos(), s.Name)
	}
	// In-scope duplicate guard: `var x; var x` in the same flat scope
	// would silently overwrite the first symbol's entry. Track each
	// declaration's scope depth so shadowing across nested scopes (and
	// sequential for-loops at the same parent depth) still works, while
	// flat-scope dupes get caught here.
	// Same-scope-redeclare + shadow-save is all handled by bindLocal
	// at the end of this function. The check + save run there
	// alongside the actual symbols write.
	// Unknown-type detection: if the user wrote `var x Foo = ...` and
	// `Foo` isn't a known type, surface "unknown type" with a
	// did-you-mean hint rather than letting `llvmType` silently
	// return "void" and producing a misleading downstream message.
	if err := c.e.validateNamedType(s.Type); err != nil {
		return err
	}
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
	// C8 phase 6 (cross-statement alias): `var b2 = b1` where both are
	// borrow/pointer vars must copy the POINTER b1 holds, not auto-deref
	// it. emitIdent auto-derefs sym.Elem for ergonomic reads (`*b` is
	// implicit on most uses); here we want the raw ptr so b2 stores
	// the same underlying address. Covers `&T` (shared) and `*T` (write
	// borrow or owning heap pointer) alike.
	if isBorrowOrPointer(s.Type) && s.Value != nil {
		if id, ok := s.Value.(*ast.IdentExpr); ok {
			if srcSym, ok := c.symbols[id.Name]; ok && srcSym.Elem != "" {
				rawPtr := c.newTemp()
				fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", rawPtr, srcSym.Ptr)
				val = Value{Name: rawPtr, Type: "ptr"}
				goto skipNormalEmit
			}
		}
	}
	if s.Value != nil {
		val, err = c.emitMaybePtrForIface(s.Value, s.Type)
		if err != nil {
			return err
		}
	}
skipNormalEmit:
	typeStr := "i64"
	if s.Type != nil {
		typeStr = c.e.llvmType(s.Type)
	} else if s.Value != nil {
		typeStr = val.Type
	}

	// Implicit auto-boxing when the declared type is an interface:
	// `error` → emit_error_box, user interface → emit_iface_box,
	// `any` → emit_any_box. All three predicates + their boxing
	// helpers live behind `maybeBoxForInterface` so the var-decl,
	// call-arg, and ret paths share one implementation.
	if s.Value != nil {
		boxed, berr := c.maybeBoxForInterface(s.Pos(), val, s.Type)
		if berr != nil {
			return berr
		}
		val = boxed
	}
	var elem, sliceElem string
	// astType is the AST type recorded on the bound symbol. For an explicit
	// `var x T = ...` it's s.Type; for an inferred `x := ...` it's nil unless
	// we can reconstruct it from the RHS value (below).
	astType := s.Type
	if s.Type != nil {
		elem = c.e.elemType(s.Type)
		sliceElem = c.e.sliceElemLLVM(s.Type)
	} else if s.Value != nil {
		sliceElem = val.SliceElem
		// `:=` inference of a *T-returning RHS yields a bare "ptr" value with
		// no AstType/Elem, so a later `x.Method()` can't recover the pointee
		// type ("cannot call method on ptr") and the receiver-materialization
		// switch would mistake the pointer var for an owned value (passing
		// &x instead of the stored ptr). Reconstruct the *T AstType + Elem
		// from the value's concrete tag so the inferred local is shaped
		// exactly like an explicit `var x *T = ...`.
		if typeStr == "ptr" && val.Concrete != "" {
			astType = &ast.PointerType{Elem: &ast.NamedType{Name: val.Concrete, Package: val.ConcretePkg}}
			elem = c.e.elemType(astType)
		}
	}
	// Implicit boxing: `var f *T = new T{...}` heap-allocates the struct
	// value and stores its ptr. Same shape as Rust's `Box::new` /
	// Go's `&T{}`. Detected when:
	//   - LHS type is *T (PointerType to NamedType)
	//   - RHS produced a struct value (%T) matching the inner T
	if s.Value != nil && typeStr == "ptr" && strings.HasPrefix(val.Type, "%") &&
		val.Type != "%string" && val.Type != "%slice" && val.Type != "%error_box" && val.Type != "%fn_value" {
		if pt, ok := s.Type.(*ast.PointerType); ok {
			if nt, ok := pt.Elem.(*ast.NamedType); ok && "%"+nt.Name == val.Type {
				// Heap-allocate sizeof(T), store the struct value into it.
				c.e.ensureDeclare("declare ptr @volt_alloc(i64)")
				sizeT := c.newTemp()
				sizeI := c.newTemp()
				fmt.Fprintf(&c.body, "  %s = getelementptr %s, ptr null, i32 1\n", sizeT, val.Type)
				fmt.Fprintf(&c.body, "  %s = ptrtoint ptr %s to i64\n", sizeI, sizeT)
				heap := c.newTemp()
				fmt.Fprintf(&c.body, "  %s = call ptr @volt_alloc(i64 %s)\n", heap, sizeI)
				fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", val.Type, val.Name, heap)
				val = Value{Name: heap, Type: "ptr"}
			}
		}
	}

	// Friendly type-mismatch error BEFORE convertInt/store: catch
	// `var x int = "string-literal"` here rather than letting the
	// store-with-wrong-type bubble up through clang as a cryptic
	// LLVM IR error.
	if s.Value != nil {
		if mismatch := typeMismatchMessage(s.Type, val.Type, typeStr); mismatch != "" {
			return fmt.Errorf("%s: %s", s.Pos(), mismatch)
		}
	}
	ptr := "%" + c.allocaName(s.Name)
	fmt.Fprintf(&c.body, "  %s = alloca %s\n", ptr, typeStr)
	if s.Value != nil {
		// S1 (move model): a binding of an owned ELEMENT (`x := arr[i]` on a
		// []string) must own an INDEPENDENT copy, not alias the slice's
		// backing — deep-copy here so the slice stays sole owner and its
		// element payloads are safe to free. The drop is registered below
		// (same gate as map-string reads).
		if typeStr == "%string" && c.isStringSliceIndex(s.Value) {
			val = c.deepCopyString(val)
		}
		val = c.convertInt(val, typeStr)
		fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", typeStr, val.Name, ptr)
	}
	// Attach a !DILocalVariable so gdb's `print s.Name` works. Only
	// when the emitter has DI enabled (sourceFile != "") and we're
	// inside a tracked function (subprograms non-empty). Closure
	// bodies emit into a separate trampoline buffer without a
	// DISubprogram of their own — `noDebugInfo` skips the
	// dbg.declare attachment so LLVM doesn't reject the record.
	if c.e.sourceFile != "" && len(c.e.subprograms) > 0 && !c.noDebugInfo {
		varID := c.e.nextDbgVarID()
		spIdx := len(c.e.subprograms) - 1
		c.e.subprograms[spIdx].locals = append(c.e.subprograms[spIdx].locals, dbgVar{
			metaID: varID,
			name:   s.Name,
			line:   s.P.Line,
			llType: typeStr,
		})
		c.e.ensureDeclare("declare void @llvm.dbg.declare(metadata, metadata, metadata)")
		fmt.Fprintf(&c.body,
			"  call void @llvm.dbg.declare(metadata ptr %s, metadata !%d, metadata !DIExpression())\n",
			ptr, varID)
	}
	isMap := false
	if s.Type != nil {
		isMap = isMapType(s.Type)
	}
	// C13 escape proof: if the RHS is a closure literal that captures
	// borrows, propagate that flag onto the bound symbol so emitRet /
	// emitRun can reject the closure from escaping its borrow's scope.
	capturesBorrow := false
	if fl, ok := s.Value.(*ast.FuncLit); ok && fl.CapturesBorrow {
		capturesBorrow = true
	}
	if err := c.bindLocal(s.Name, symbol{Ptr: ptr, Type: typeStr, Elem: elem, SliceElem: sliceElem, IsMap: isMap, AstType: astType, CapturesBorrow: capturesBorrow, ConcretePkg: val.ConcretePkg}, s.P); err != nil {
		return err
	}

	// If the variable is an owned struct value AND its type (or any
	// transitively-owned struct field) has a Drop() method, register
	// the chain of drops at scope exit. Field drops run AFTER the
	// parent's own Drop, in reverse declaration order — matching
	// C++/Rust destruction semantics.
	if len(typeStr) > 1 && typeStr[0] == '%' && typeStr != "%string" && typeStr != "%slice" {
		typeName := strings.TrimPrefix(typeStr, "%")
		c.registerStructDrops(ptr, typeName, c.scopeDepth, make(map[string]bool))
		// #5 recursive reclaim: also free this value-struct's heap FIELD
		// payloads at scope exit — but ONLY when it wasn't moved out
		// (movedNames, the checker's precise move-state → no double-free)
		// AND it has no Drop method anywhere in its tree (→ no
		// Drop-reads-freed-field hazard). Drop-bearing structs keep
		// leaking their fields for now (safe).
		if !c.movedNames[s.Name] && !c.structHasDrop(typeName, make(map[string]bool)) {
			c.registerStructFieldDrops(ptr, typeName, c.scopeDepth, make(map[string]bool))
		}
	}
	// A3: auto-free for owned slice/map values at scope exit. Only
	// register a drop when the var's RHS is explicitly a `new (...)
	// []T{...}` or `new map[K]V`-style expression — i.e. this var
	// owns the storage outright. For any other RHS (field access like
	// `var arr = v.arr`, function returns that hand back a shared
	// header, sub-slicing, etc.) we treat the var as a NON-OWNING
	// alias and skip auto-free so we never double-free a buffer that
	// some other binding still references. We also skip when the
	// pre-scan flagged the name as POTENTIALLY MOVED somewhere in this
	// function — passing the slice/map to a call/return/run/send
	// hands ownership downstream, and the drop would race the caller.
	if ne, isNewExpr := s.Value.(*ast.NewExpr); isNewExpr {
		if typeStr == "%slice" && !c.movedNames[s.Name] {
			// S1b: also free per-element payloads when this is a []string the
			// compiler proved is sole owner of independent element strings
			// (scanElemFreeableSlices — safe-by-construction whitelist).
			selem := ""
			if sliceElem == "%string" && c.elemFreeableSlices[s.Name] {
				selem = "%string"
			}
			c.drops = append(c.drops, dropEntry{
				kind:      dropKindSlice,
				depth:     c.scopeDepth,
				ptr:       ptr,
				sliceElem: selem,
			})
		}
		if isMap && !c.movedNames[s.Name] {
			c.drops = append(c.drops, dropEntry{
				kind:  dropKindMap,
				depth: c.scopeDepth,
				ptr:   ptr,
			})
		}
		// #6: release the creator's refcount on a sole-owned, non-escaping
		// `new() chan` local at scope exit. scanReleasableChannels already
		// pinned (excluded) any channel that escapes; a `run` capture is
		// handled by retain+thunk-release, not a pin. The channel type may
		// sit on the NewExpr (`new() chan T`) or the declared type
		// (`var c chan T = new(N)`).
		_, neChan := ne.Type.(*ast.ChanType)
		_, declChan := s.Type.(*ast.ChanType)
		if (neChan || declChan) && c.releasableChans[s.Name] {
			c.drops = append(c.drops, dropEntry{
				kind:  dropKindChanRelease,
				depth: c.scopeDepth,
				ptr:   ptr,
			})
		}
	}
	// S3 first cut: a slice returned by an audited stdlib OWNED-RETURN call
	// (strings.Fields, maps.Keys, …) is a FRESH caller-owned slice — free its
	// backing at scope exit, exactly like a local `new []T{...}` and under the
	// SAME movedNames gate (suppressed if x is passed/returned/stored → no
	// use-after-free, only a possible leak). Frees the backing only; element
	// payloads of []string returns still leak (a documented follow-up).
	if typeStr == "%slice" && !c.movedNames[s.Name] && isOwnedSliceReturnCall(s.Value) {
		// BACKING ONLY — never element-free a function RETURN's elements: the
		// callee may have filled the returned slice with values that ALIAS its
		// inputs (e.g. maps.Keys copies the map's key headers), so element-free
		// here could double-free the caller's still-owned input. The backing
		// itself is always freshly new'd by the audited callee, so freeing it
		// is sound. (Full element reclamation of returns needs interprocedural
		// element-provenance — a documented follow-up.)
		c.drops = append(c.drops, dropEntry{
			kind:  dropKindSlice,
			depth: c.scopeDepth,
			ptr:   ptr,
		})
	}
	// A3 strings: register a string drop only when RHS is a KNOWN
	// heap-producer (string concat, `chr` builtin). Function-call
	// results conservatively skip auto-free because we can't tell
	// whether the callee returned a literal or a heap buffer. Same
	// move-skip discipline as slice/map.
	if typeStr == "%string" && !c.movedNames[s.Name] && (isHeapStringProducer(s.Value) || c.isStringMapIndex(s.Value) || c.isStringSliceIndex(s.Value)) {
		c.drops = append(c.drops, dropEntry{
			kind:  dropKindString,
			depth: c.scopeDepth,
			ptr:   ptr,
		})
	}
	return nil
}

// isStringMapIndex reports whether `e` is `m[k]` where m is a
// string-valued map. emitMapGet deep-copies such reads into a fresh
// heap %string (so the map stays sole owner of its backing), so the
// result must be A3-freed at scope exit like any heap string producer.
// Slice indexing (`s[i]`) is deliberately NOT matched — it returns an
// alias into the slice's backing, which the slice owns.
func (c *funcCtx) isStringMapIndex(e ast.Expr) bool {
	idx, ok := e.(*ast.IndexExpr)
	if !ok {
		return false
	}
	id, ok := idx.X.(*ast.IdentExpr)
	if !ok {
		return false
	}
	sym, ok := c.symbols[id.Name]
	if !ok {
		return false
	}
	return sym.IsMap && mapValueIsString(sym)
}

// isStringSliceIndex reports whether `e` is `arr[i]` where arr is a
// `[]string`. Under the move model (S1) a BINDING `x := arr[i]` of an owned
// element must produce an INDEPENDENT deep copy (not a silent alias into the
// slice's backing), so the slice stays the sole owner — which is what makes
// freeing the slice's element payloads safe. The caller deep-copies the
// value (deepCopyString) AND registers it for free at scope exit. Only the
// `arr[i]` (ident receiver, []string) shape; nested/struct elements are
// follow-ups.
func (c *funcCtx) isStringSliceIndex(e ast.Expr) bool {
	idx, ok := e.(*ast.IndexExpr)
	if !ok {
		return false
	}
	id, ok := idx.X.(*ast.IdentExpr)
	if !ok {
		return false
	}
	sym, ok := c.symbols[id.Name]
	if !ok {
		return false
	}
	return !sym.IsMap && sym.SliceElem == "%string"
}

// deepCopyString returns an independent heap copy of a `%string` value via
// volt_string_from_bytes — used so a binding that would otherwise alias
// another owner's backing (e.g. a []string element read) gets its own
// buffer. Caller must register the result for free at scope exit.
func (c *funcCtx) deepCopyString(val Value) Value {
	bptr := c.newTemp()
	blen := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 0\n", bptr, val.Name)
	fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 1\n", blen, val.Name)
	c.e.ensureDeclare("declare %string @volt_string_from_bytes(ptr, i64)")
	copied := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call %%string @volt_string_from_bytes(ptr %s, i64 %s)\n", copied, bptr, blen)
	return Value{Name: copied, Type: "%string"}
}

// rejectBorrowCaptureEscape returns a non-nil error if `e` is a closure
// (FuncLit or Ident bound to a FuncLit) that captures a borrow. Used
// at storage sites where the closure would outlive its captured
// borrow: struct field init, slice element init, map value set,
// indexed/field assignment. Closes the remaining C13 soundness gaps
// beyond `ret` and `run` which are handled separately.
func (c *funcCtx) rejectBorrowCaptureEscape(e ast.Expr, ctxLabel string) error {
	if fl, ok := e.(*ast.FuncLit); ok && fl.CapturesBorrow {
		return fmt.Errorf("%s: cannot store a closure that captures a borrow in %s (C13: borrow's scope ends before the storage outlives it)",
			e.Pos(), ctxLabel)
	}
	if id, ok := e.(*ast.IdentExpr); ok {
		if sym, ok := c.symbols[id.Name]; ok && sym.CapturesBorrow {
			return fmt.Errorf("%s: cannot store closure %q in %s — it captures a borrow whose scope ends before the storage outlives it (C13 storage escape)",
				e.Pos(), id.Name, ctxLabel)
		}
	}
	return nil
}

// funcLitCapturesBorrow reports whether a closure literal captures any
// borrow/pointer local. Computed on demand (the same test emitFuncLit uses
// to set FuncLit.CapturesBorrow) so it is correct even for a literal that
// has not been lowered yet — e.g. an inline closure passed as a call arg.
func (c *funcCtx) funcLitCapturesBorrow(fl *ast.FuncLit) bool {
	for _, name := range c.collectCaptures(fl) {
		if sym, ok := c.symbols[name]; ok && isBorrowOrPointerLLVM(sym) {
			return true
		}
	}
	return false
}

// isHeapStringProducer reports whether the RHS expression clearly
// produces a HEAP-allocated string (rather than a literal). Used by
// A3 to decide whether to register dropKindString at a var decl.
// Conservative: returns true only for expressions whose IR we
// directly control and KNOW lowers to volt_string_concat / volt_alloc,
// PLUS a hardcoded whitelist of stdlib functions whose contract is to
// always return a heap-allocated string (they call volt_alloc or
// volt_string_concat internally). User-defined functions returning
// string still skip auto-free — we can't tell whether they returned a
// literal or heap from the callsite.
func isHeapStringProducer(e ast.Expr) bool {
	switch x := e.(type) {
	case *ast.BinaryExpr:
		// String `+` lowers to volt_string_concat which heap-allocates.
		// Don't bother checking types — if it's a binary op on a string
		// var, the result is heap. (Numeric + on int args wouldn't
		// produce a %string-typed var anyway; emitVar wouldn't reach
		// this branch.)
		return x.Op == "+"
	case *ast.CallExpr:
		// `chr(b)` produces a single-byte heap string.
		if id, ok := x.Fun.(*ast.IdentExpr); ok && id.Name == "chr" {
			return true
		}
		// Stdlib functions with the contract "always returns heap".
		// pkg.Fn matches against the SelectorExpr form. The named set
		// covers the most-used string-producers; expand as needed.
		// Anything not on the list is conservatively NOT auto-freed.
		if sel, ok := x.Fun.(*ast.SelectorExpr); ok {
			if pkg, ok := sel.X.(*ast.IdentExpr); ok {
				if stdlibHeapStringProducers[pkg.Name+"."+sel.Sel] {
					return true
				}
			}
		}
	}
	return false
}

// stdlibHeapStringProducers is the whitelist of "pkg.Fn" callsites
// whose returned %string is registered for auto-free at the caller's
// var decl. Safe to over-include now that the runtime's volt_str_free
// guards against non-heap pointers via heap_range_contains — a literal
// return path no longer crashes; it just becomes a no-op.
//
// What this list buys: functions that USUALLY return heap (concat,
// transform, format) get auto-freed at scope exit. Edge-case literal
// returns inside these functions are harmlessly skipped by the
// runtime check. The dominant case (real heap data) frees correctly,
// recycling memory in tight loops.
// stdlibOwnedSliceReturns is the whitelist of "pkg.Fn" callsites that return
// a FRESHLY-allocated slice the caller solely owns — so `var x = pkg.Fn(...)`
// registers a backing free at scope exit, exactly like a local `new []T{...}`
// (and under the SAME movedNames gate: if x is passed/returned/stored, the
// free is suppressed → no use-after-free, only a possible leak). S3 first cut.
//
// SAFETY: unlike the string list above (volt_str_free is heap-range-safe so
// over-including is harmless), volt_slice_free frees the buffer pointer
// directly — so a function that returns its INPUT aliased (e.g. sort.IntsAsc
// does `ret s`, sorting in place) must NOT be listed, or the caller would
// double-free. Every entry here was AUDITED to `new(...)` a fresh slice and
// return THAT, never an aliased input/param. Frees the BACKING only; for
// []string returns the element strings still leak (a separate follow-up —
// element-payload free for non-`new` locals).
var stdlibOwnedSliceReturns = map[string]bool{
	"strings.Fields":         true, // new(count) []string{...}; ret out
	"strings.Split":          true, // new(parts) []string{...}; ret out
	"strings.SplitN":         true, // ret Split(...) / new(...) []string{}
	"maps.KeysStringInt":     true, // new(n) []string{}; ret out
	"maps.ValuesStringInt":   true, // new(n) []int{}; ret out
	"maps.KeysStringString":  true, // new(n) []string{}; ret out
	"maps.ValuesStringString": true, // new(n) []string{}; ret out
}

// isOwnedSliceReturnCall reports whether `e` is a call `pkg.Fn(...)` on the
// audited stdlibOwnedSliceReturns whitelist — i.e. its result is a fresh,
// caller-owned slice whose backing should be freed at the caller's scope
// exit. Checked purely at the call site by name (no cross-package plumbing).
func isOwnedSliceReturnCall(e ast.Expr) bool {
	call, ok := e.(*ast.CallExpr)
	if !ok {
		return false
	}
	sel, ok := call.Fun.(*ast.SelectorExpr)
	if !ok {
		return false
	}
	pkg, ok := sel.X.(*ast.IdentExpr)
	if !ok {
		return false
	}
	return stdlibOwnedSliceReturns[pkg.Name+"."+sel.Sel]
}

var stdlibHeapStringProducers = map[string]bool{
	"fmt.Sprintf":         true,
	"fmt.Sprintln":        true,
	"strings.Repeat":      true,
	"strings.RepeatByte":  true,
	"strings.RepeatRune":  true,
	"strings.RepeatTo":    true,
	"strings.Join":        true,
	"strings.JoinByte":    true,
	"strings.Concat":      true,
	"strings.ToUpper":     true,
	"strings.ToLower":     true,
	"strings.TrimSpace":   true,
	"strings.Trim":        true,
	"strings.Replace":     true,
	"strings.PadLeft":     true,
	"strings.PadRight":    true,
	"strings.Center":      true,
	"strings.Indent":      true,
	"strings.Dedent":      true,
	"strings.Truncate":    true,
	"strings.Reverse":     true,
	"strings.AsciiBar":    true,
	"strings.Banner":      true,
	"strings.Sparkline":   true,
	"strings.HumanBytes":  true,
	"strings.HumanCount":  true,
	"strings.AsciiHistogram":    true,
	"strings.AsciiHistogramRow": true,
	"strings.BulletList":   true,
	"strings.NumberedList": true,
	"strings.NormalizeNewlines":   true,
	"strings.NormalizeWhitespace": true,
	"strings.WordWrap":     true,
	"strings.QuoteString":  true,
	"strconv.Itoa":         true,
	"strconv.FormatBool":   true,
	"strconv.FormatInt":    true,
	"json.QuoteString":     true,
	"json.Encode":          true,
	"json.EncodePretty":    true,
	"strings.Slice":        true,
	"syscall.ReadSome":     true,
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

// registerStructFieldDrops registers scope-end frees for a value-struct's
// heap FIELD payloads — string/slice/map buffers — recursing into nested
// value-struct fields. It reuses the dropKindSlice/Map/String handlers with
// the field's GEP address as the drop ptr (the handler loads the live header
// from there and frees its buffer; null-safe, so a zero/uninitialized field
// is a no-op). The caller gates on movedNames (so a moved-out struct is
// skipped — no double-free) and on the type being Drop-free (so there's no
// "Drop reads a just-freed field" ordering hazard). Slice/map ELEMENT
// payloads aren't descended into yet (a follow-up); only the immediate
// buffer is freed, which fully reclaims flat structs and Copy-element slices.
func (c *funcCtx) registerStructFieldDrops(structPtr, typeName string, depth int, visiting map[string]bool) {
	if visiting[typeName] {
		return
	}
	visiting[typeName] = true
	info := c.e.structs[typeName]
	if info == nil {
		return
	}
	for i, f := range info.Fields {
		switch ft := f.Type.(type) {
		case *ast.SliceType:
			fp := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = getelementptr %%%s, ptr %s, i32 0, i32 %d\n", fp, typeName, structPtr, i)
			c.drops = append(c.drops, dropEntry{kind: dropKindSlice, depth: depth, ptr: fp})
		case *ast.MapType:
			fp := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = getelementptr %%%s, ptr %s, i32 0, i32 %d\n", fp, typeName, structPtr, i)
			c.drops = append(c.drops, dropEntry{kind: dropKindMap, depth: depth, ptr: fp})
		case *ast.NamedType:
			if ft.Name == "string" {
				fp := c.newTemp()
				fmt.Fprintf(&c.body, "  %s = getelementptr %%%s, ptr %s, i32 0, i32 %d\n", fp, typeName, structPtr, i)
				c.drops = append(c.drops, dropEntry{kind: dropKindString, depth: depth, ptr: fp})
			} else if _, ok := c.e.structs[ft.Name]; ok {
				fp := c.newTemp()
				fmt.Fprintf(&c.body, "  %s = getelementptr %%%s, ptr %s, i32 0, i32 %d\n", fp, typeName, structPtr, i)
				c.registerStructFieldDrops(fp, ft.Name, depth, visiting)
			}
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
	// Prune declaredAt entries for names introduced at the depth
	// being left, so sequential sibling scopes can reuse names (e.g.
	// two `for i := 0; ...` loops back-to-back).
	for name, d := range c.declaredAt {
		if d >= target {
			delete(c.declaredAt, name)
			delete(c.declaredAtPos, name)
			delete(c.symbols, name)
		}
	}
	// Restore outer-scope bindings that were shadowed at this depth.
	// Run in reverse-push order so each restore reflects the
	// outermost still-visible binding.
	for i := len(c.shadowed) - 1; i >= 0; i-- {
		s := c.shadowed[i]
		if s.depth != target {
			continue
		}
		if s.hadPrev {
			c.symbols[s.name] = s.prevSym
			c.declaredAt[s.name] = s.prevDecl
			c.declaredAtPos[s.name] = s.prevPos
		}
	}
	// Drop shadow entries created at this depth.
	keepShadow := c.shadowed[:0]
	for _, s := range c.shadowed {
		if s.depth != target {
			keepShadow = append(keepShadow, s)
		}
	}
	c.shadowed = keepShadow
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
// Also prunes declaredAt entries at depth > floor so the
// same-scope-redeclare guard works correctly for siblings.
func (c *funcCtx) discardDropsAbove(floor int) {
	for name, d := range c.declaredAt {
		if d > floor {
			delete(c.declaredAt, name)
			delete(c.declaredAtPos, name)
		}
	}
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
		c.emitRaceSync("release", h)
		fmt.Fprintf(&c.body, "  call void @%s(ptr %s)\n", d.unlockFn, h)
	case dropKindSlice:
		if d.sliceElem == "%string" {
			// S1b: free each element's string PAYLOAD, then the backing buffer.
			// Only set when the slice was proved sole owner of independent
			// element strings (scanElemFreeableSlices). Load buf (field 0) +
			// len (field 1) from the {ptr,len,cap} header; the runtime loops
			// freeing each element (heap-range-safe → literals no-op).
			c.e.ensureDeclare("declare void @volt_slice_free_str_elems(ptr, i64)")
			hdr := c.newTemp()
			bufP := c.newTemp()
			lenV := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = load %%slice, ptr %s\n", hdr, d.ptr)
			fmt.Fprintf(&c.body, "  %s = extractvalue %%slice %s, 0\n", bufP, hdr)
			fmt.Fprintf(&c.body, "  %s = extractvalue %%slice %s, 1\n", lenV, hdr)
			fmt.Fprintf(&c.body, "  call void @volt_slice_free_str_elems(ptr %s, i64 %s)\n", bufP, lenV)
			break
		}
		// Load the slice's buffer pointer (first field of {ptr, i64, i64})
		// and free it. volt_slice_free is null-safe so a moved-out var
		// (whose first field was nulled at the move site) is a no-op.
		c.e.ensureDeclare("declare void @volt_slice_free(ptr)")
		bufP := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", bufP, d.ptr)
		fmt.Fprintf(&c.body, "  call void @volt_slice_free(ptr %s)\n", bufP)
	case dropKindMap:
		// Load the map handle (a single ptr) and free its full graph
		// (entries + buckets + map_t header). Null-safe like slice free.
		c.e.ensureDeclare("declare void @volt_map_free(ptr)")
		mh := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", mh, d.ptr)
		fmt.Fprintf(&c.body, "  call void @volt_map_free(ptr %s)\n", mh)
	case dropKindString:
		// Load the %string header from the alloca, extract the buffer
		// pointer (first field), free it. The %string struct itself
		// is stack-resident (in the alloca) — only the bytes were heap.
		// volt_str_free is null-safe so move-out sites can nullify.
		c.e.ensureDeclare("declare void @volt_str_free(ptr)")
		strV := c.newTemp()
		bufP := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = load %%string, ptr %s\n", strV, d.ptr)
		fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 0\n", bufP, strV)
		fmt.Fprintf(&c.body, "  call void @volt_str_free(ptr %s)\n", bufP)
	case dropKindChanRelease:
		// Load the channel handle and drop the creator's refcount. The
		// runtime frees the struct + buffer when the count reaches 0;
		// volt_chan_release is null-safe.
		c.e.ensureDeclare("declare void @volt_chan_release(ptr)")
		ch := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", ch, d.ptr)
		fmt.Fprintf(&c.body, "  call void @volt_chan_release(ptr %s)\n", ch)
	}
}

// emitSliceIndexAssign handles `s[i] = v` where s is a slice variable.
// Extracts the backing pointer from the slice header, GEPs to the
// element slot at index i, stores the RHS value.
func (c *funcCtx) emitSliceIndexAssign(lhs *ast.IndexExpr, rhsExpr ast.Expr) error {
	if err := c.rejectBorrowCaptureEscape(rhsExpr, "slice element"); err != nil {
		return err
	}
	xv, err := c.emitExpr(lhs.X)
	if err != nil {
		return err
	}
	if xv.Type != "%slice" {
		return fmt.Errorf("%s: indexed assignment requires a slice or map, got %s", lhs.Pos(), xv.Type)
	}
	if xv.SliceElem == "" {
		return fmt.Errorf("%s: slice element type unknown — was it created via []T{...}?", lhs.Pos())
	}
	idx, err := c.emitExpr(lhs.Index)
	if err != nil {
		return err
	}
	// Pointer-aware: when the element type is a pointer (`[]*T`) and the
	// RHS is a pointer/borrow variable, store the RAW POINTER. Plain
	// emitExpr auto-derefs a pointer ident to its pointee (correct for
	// `tmp.field`, wrong here) — which would store a struct value into a
	// `ptr` slot. (`s[i] = s[j]` already worked: a slice-index yields the
	// raw element pointer, not a deref.) Mirrors emitBuiltinAppend.
	rhs, err := c.emitPointerAwareExpr(rhsExpr, xv.SliceElem)
	if err != nil {
		return err
	}
	// Friendly type-mismatch error BEFORE convertInt: surface
	// `s[i] = "string"` (where s is []int) at the source position.
	// Look up the slice variable's AST type to recover the declared
	// element type for the user-facing name; falls back to "" when the
	// source isn't a bare slice identifier (the LLVM-derived name
	// already gives a readable mismatch in that case).
	var elemAst ast.Type
	if id, ok := lhs.X.(*ast.IdentExpr); ok {
		if sym, ok := c.symbols[id.Name]; ok {
			if st, ok := sym.AstType.(*ast.SliceType); ok {
				elemAst = st.Elem
			}
		}
	}
	// Auto-box concrete values flowing into an interface-typed
	// slice element (`var s []error; s[0] = myErr`).
	if elemAst != nil {
		boxed, berr := c.maybeBoxForInterface(rhsExpr.Pos(), rhs, elemAst)
		if berr != nil {
			return berr
		}
		rhs = boxed
	}
	if mismatch := typeMismatchMessage(elemAst, rhs.Type, xv.SliceElem); mismatch != "" {
		return fmt.Errorf("%s: %s", lhs.Pos(), mismatch)
	}
	rhs = c.convertInt(rhs, xv.SliceElem)
	ptr := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = extractvalue %%slice %s, 0\n", ptr, xv.Name)
	fp := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = getelementptr %s, ptr %s, i64 %s\n", fp, xv.SliceElem, ptr, idx.Name)
	c.emitRaceMem("write", fp, 8)
	fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", xv.SliceElem, rhs.Name, fp)
	return nil
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
		// st.m[k] = v on a map FIELD — route to the same map setter via a
		// synthetic sym at the field's handle address.
		if sel, ok := lhs.X.(*ast.SelectorExpr); ok {
			if mt, addr, ok := c.mapFieldHandle(sel); ok {
				return c.emitMapSet(symbol{Ptr: addr, AstType: mt, IsMap: true}, lhs.Index, s.RHS, lhs.Pos())
			}
		}
		// s[i] = v on a slice variable: GEP into the backing, store v.
		return c.emitSliceIndexAssign(lhs, s.RHS)
	case *ast.UnaryExpr:
		// C8: `*p = v` — write through a held borrow/pointer. p must
		// resolve to a borrow-typed local; load its pointer and store
		// v at that address.
		if lhs.Op != "*" {
			return fmt.Errorf("%s: unsupported unary LHS %q", lhs.Pos(), lhs.Op)
		}
		id, ok := lhs.X.(*ast.IdentExpr)
		if !ok {
			return fmt.Errorf("%s: `*` LHS requires a pointer/borrow variable", lhs.Pos())
		}
		sym, ok := c.symbols[id.Name]
		if !ok {
			return fmt.Errorf("%s: undefined identifier %q", lhs.Pos(), id.Name)
		}
		if sym.Elem == "" {
			return fmt.Errorf("%s: %q is not a pointer/borrow (cannot deref-assign)", lhs.Pos(), id.Name)
		}
		val, err := c.emitExpr(s.RHS)
		if err != nil {
			return err
		}
		val = c.convertInt(val, sym.Elem)
		p := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", p, sym.Ptr)
		// Race instrumentation: a write THROUGH a pointer/borrow reaches
		// data that may live on the heap and be shared across threads
		// (e.g. a *T published via an atomic-ptr or chan). Instrument it.
		c.emitRaceMem("write", p, 8)
		fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", sym.Elem, val.Name, p)
		return nil
	}
	return fmt.Errorf("%s: assignment target must be a variable or field/index access", s.LHS.Pos())
}

func (c *funcCtx) emitIdentAssign(lhs *ast.IdentExpr, rhsExpr ast.Expr) error {
	sym, ok := c.symbols[lhs.Name]
	if !ok {
		if guess := c.suggestIdentifier(lhs.Name); guess != "" {
			return fmt.Errorf("%s: undefined variable %q (did you mean %q?)", lhs.Pos(), lhs.Name, guess)
		}
		return fmt.Errorf("%s: undefined variable %q", lhs.Pos(), lhs.Name)
	}
	if sym.IsReadOnly {
		return fmt.Errorf("%s: %s is a read-only guard — writes are not allowed (acquire with Lock() instead of LockRead() if you need to mutate)",
			lhs.Pos(), lhs.Name)
	}
	// emitMaybePtrForIface loads the raw pointer (not an auto-deref'd value
	// copy) when the LHS is an interface and the RHS is a concrete `*T`
	// ident — so the boxed interface shares the pointee. Falls back to plain
	// emitExpr for every other case (non-interface LHS, non-ident RHS).
	val, err := c.emitMaybePtrForIface(rhsExpr, sym.AstType)
	if err != nil {
		return err
	}
	// If the variable is itself a borrow/pointer (sym.Elem set), `x = v`
	// means "write v through x to the pointee" — deref then store.
	// Otherwise it's an ordinary store into the variable's own slot.
	if sym.Elem != "" {
		// COMPILER.reassign-call-ptr: when the RHS is itself a pointer
		// (e.g. `st = p.Wait()` where Wait returns `*T`) and the pointee is
		// not itself a pointer, this is a REBIND of the owning pointer, not
		// a write-through — store the new pointer into the variable's own
		// slot. (Write-through of a value keeps val typed as the pointee, so
		// this only fires for genuine pointer RHSs, which previously errored.)
		if val.Type == "ptr" && sym.Type == "ptr" && sym.Elem != "ptr" {
			c.emitRaceMem("write", sym.Ptr, 8)
			fmt.Fprintf(&c.body, "  store ptr %s, ptr %s\n", val.Name, sym.Ptr)
			return nil
		}
		val = c.convertInt(val, sym.Elem)
		ptr := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", ptr, sym.Ptr)
		c.emitRaceMem("write", ptr, 8)
		fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", sym.Elem, val.Name, ptr)
		return nil
	}
	// Implicit auto-boxing when the LHS is an interface (error / any / user
	// interface): a concrete `*T`/value RHS becomes the fat pointer the slot
	// expects. Mirrors the var-decl / call-arg / ret paths; without it,
	// `r = io.NewStringReader(s)` (an AssignStmt) stored a raw pointer and a
	// later `r.Read()` dispatched through a garbage vtable → SIGSEGV.
	if boxed, berr := c.maybeBoxForInterface(rhsExpr.Pos(), val, sym.AstType); berr != nil {
		return berr
	} else {
		val = boxed
	}
	// S1 (move model): `x = arr[i]` on a []string must own an INDEPENDENT
	// copy, not alias the slice's backing — so the slice stays sole owner and
	// its element payloads are safe to free. Deep-copy before the store; the
	// re-register gate below adds the drop. (Mirror of the emitVar path.)
	if sym.Type == "%string" && c.isStringSliceIndex(rhsExpr) {
		val = c.deepCopyString(val)
	}
	// Friendly type-mismatch error BEFORE store: surface
	// `x = "string"` (where x is int) at the source position rather
	// than as a cryptic clang LLVM IR store-type error.
	if mismatch := typeMismatchMessage(sym.AstType, val.Type, sym.Type); mismatch != "" {
		return fmt.Errorf("%s: %s", lhs.Pos(), mismatch)
	}
	val = c.convertInt(val, sym.Type)
	// A3 reassignment cleanup: if this slot has a registered slice/map/
	// string drop, the OLD value lived on the heap and is about to be
	// overwritten. Free it before the store so we don't leak. Then
	// remove the existing drop entry — we'll re-register only if the
	// new RHS is itself a heap producer (same gate as initial var-decl).
	// Critically, re-register at the ORIGINAL drop's depth, NOT
	// c.scopeDepth. If a reassignment happens inside a nested block
	// (e.g. a for-body), using c.scopeDepth would cause popScope at the
	// inner block's end to free the freshly-stored value EVERY iteration,
	// invalidating the var for the next iter. The var's lifetime is
	// bound to its declaration scope, not the rebind site's scope.
	// origDepth is the scope the re-registered drop binds to. It MUST be
	// the variable's DECLARATION scope, not the reassignment site
	// (c.scopeDepth). Otherwise, when a var is declared with a non-heap
	// initializer (e.g. `var pad string = ""`) and FIRST becomes heap
	// inside a loop (`pad = pad + "0"`), the drop would register at the
	// loop-body depth and fire every iteration — freeing the value we
	// just stored (the dangling-pad bug). Prefer the recorded declaration
	// depth; an existing drop's depth (below) is authoritative when present.
	origDepth := c.scopeDepth
	if d, ok := c.declaredAt[lhs.Name]; ok {
		origDepth = d
	}
	if idx := c.findDropForPtr(sym.Ptr); idx >= 0 {
		old := c.drops[idx]
		origDepth = old.depth
		switch old.kind {
		case dropKindSlice:
			c.e.ensureDeclare("declare void @volt_slice_free(ptr)")
			bufP := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", bufP, sym.Ptr)
			fmt.Fprintf(&c.body, "  call void @volt_slice_free(ptr %s)\n", bufP)
		case dropKindMap:
			c.e.ensureDeclare("declare void @volt_map_free(ptr)")
			mh := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", mh, sym.Ptr)
			fmt.Fprintf(&c.body, "  call void @volt_map_free(ptr %s)\n", mh)
		case dropKindString:
			c.e.ensureDeclare("declare void @volt_str_free(ptr)")
			strV := c.newTemp()
			bufP := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = load %%string, ptr %s\n", strV, sym.Ptr)
			fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 0\n", bufP, strV)
			fmt.Fprintf(&c.body, "  call void @volt_str_free(ptr %s)\n", bufP)
		}
		// Remove the old drop; we'll re-add below if applicable.
		c.drops = append(c.drops[:idx], c.drops[idx+1:]...)
	}
	fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", sym.Type, val.Name, sym.Ptr)
	// Re-register a drop for the new value when the RHS is a heap
	// producer (same gate as emitVar's initial registration). Skip if
	// the var name is in movedNames (downstream takes ownership).
	if !c.movedNames[lhs.Name] {
		if _, isNew := rhsExpr.(*ast.NewExpr); isNew {
			if sym.Type == "%slice" {
				c.drops = append(c.drops, dropEntry{kind: dropKindSlice, depth: origDepth, ptr: sym.Ptr})
			}
			if sym.IsMap {
				c.drops = append(c.drops, dropEntry{kind: dropKindMap, depth: origDepth, ptr: sym.Ptr})
			}
		}
		if sym.Type == "%string" && (isHeapStringProducer(rhsExpr) || c.isStringSliceIndex(rhsExpr)) {
			c.drops = append(c.drops, dropEntry{kind: dropKindString, depth: origDepth, ptr: sym.Ptr})
		}
	}
	return nil
}

// findDropForPtr returns the index of the FIRST drop in c.drops whose
// ptr matches `ptr` (the alloca address of a local), or -1 if none.
// Used by A3 reassignment cleanup: when overwriting an owned slot we
// need to free the old value AND remove the stale drop registration.
// Slice/map/string drops are the only kinds keyed by alloca pointer;
// struct/sync-guard drops use the same field but their lifecycle is
// different — we only act when the matched kind is one of the A3 kinds.
func (c *funcCtx) findDropForPtr(ptr string) int {
	for i, d := range c.drops {
		if d.ptr == ptr && (d.kind == dropKindSlice || d.kind == dropKindMap || d.kind == dropKindString) {
			return i
		}
	}
	return -1
}

// indexedElemStructName returns the bare struct name of a VALUE-element
// slice's element (`s` a `[]T` → "T"), or "" if the index isn't into a
// value-struct slice (`[]*T` pointer elements / maps fall through to the
// pointer-container path). Only handles a bare-ident slice receiver.
func (c *funcCtx) indexedElemStructName(idx *ast.IndexExpr) string {
	collId, ok := idx.X.(*ast.IdentExpr)
	if !ok {
		return ""
	}
	sym, ok := c.symbols[collId.Name]
	if !ok {
		return ""
	}
	st, ok := sym.AstType.(*ast.SliceType)
	if !ok {
		return ""
	}
	if nt, ok := st.Elem.(*ast.NamedType); ok {
		return nt.Name
	}
	return ""
}

func (c *funcCtx) emitFieldAssign(lhs *ast.SelectorExpr, rhsExpr ast.Expr) error {
	if err := c.rejectBorrowCaptureEscape(rhsExpr, fmt.Sprintf("field %q", lhs.Sel)); err != nil {
		return err
	}
	// Nested/computed-container LHS: `o.i.x = ...`, `s[i].x = ...`,
	// `f().x = ...`. Emit the inner value (which auto-derefs along
	// the way via FEAT.7/11) to get the container ptr, then GEP
	// into it for the final field store.
	switch lhs.X.(type) {
	case *ast.SelectorExpr, *ast.IndexExpr, *ast.CallExpr:
		var structName string
		var containerVal Value
		// Value-element slice index `s[i].field = v`: the element lives in
		// the backing array and is addressable, so take its address as the
		// container ptr. (`[]*T` elements are pointers and map values aren't
		// addressable — those fall through to the pointeeStructName path,
		// which handles a pointer-typed container like `o.ptrField.x`.)
		if idxExpr, ok := lhs.X.(*ast.IndexExpr); ok {
			if sn := c.indexedElemStructName(idxExpr); sn != "" {
				if addr, _, aerr := c.emitFieldOrIndexAddr(idxExpr); aerr == nil {
					structName = sn
					containerVal = Value{Name: addr, Type: "ptr"}
				}
			}
		}
		if structName == "" {
			structName = c.pointeeStructName(lhs.X)
			if structName == "" {
				return fmt.Errorf("%s: cannot resolve nested field-assignment target %q — declare an intermediate local if the chain involves non-pointer fields",
					lhs.Pos(), lhs.Sel)
			}
			cv, err := c.emitExpr(lhs.X)
			if err != nil {
				return err
			}
			if cv.Type != "ptr" {
				return fmt.Errorf("%s: nested field-assignment requires the container to be pointer-typed (got %s)",
					lhs.Pos(), cv.Type)
			}
			containerVal = cv
		}
		info := c.e.structs[structName]
		if info == nil {
			return fmt.Errorf("%s: %s is not a struct", lhs.Pos(), structName)
		}
		idx, ok := info.Index[lhs.Sel]
		if !ok {
			if guess := c.e.suggestField(structName, lhs.Sel); guess != "" {
				return fmt.Errorf("%s: %s has no field %q (did you mean %q?)", lhs.Pos(), structName, lhs.Sel, guess)
			}
			return fmt.Errorf("%s: %s has no field %q", lhs.Pos(), structName, lhs.Sel)
		}
		fieldT := c.e.llvmType(info.Fields[idx].Type)
		val, err := c.emitExpr(rhsExpr)
		if err != nil {
			return err
		}
		boxed, berr := c.maybeBoxForInterface(rhsExpr.Pos(), val, info.Fields[idx].Type)
		if berr != nil {
			return berr
		}
		val = boxed
		val = c.maybeBoxForPointer(val, info.Fields[idx].Type)
		if mismatch := typeMismatchMessage(info.Fields[idx].Type, val.Type, fieldT); mismatch != "" {
			return fmt.Errorf("%s: %s", lhs.Pos(), mismatch)
		}
		fp := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = getelementptr %%%s, ptr %s, i32 0, i32 %d\n",
			fp, structName, containerVal.Name, idx)
		c.emitRaceMem("write", fp, 8)
		fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", fieldT, val.Name, fp)
		return nil
	}
	recvIdent, ok := lhs.X.(*ast.IdentExpr)
	if !ok {
		return fmt.Errorf("%s: field assignment target must be `var.field` or `var.f1.f2...` for nested chains", lhs.Pos())
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
		return fmt.Errorf("%s: cannot assign field %q on %q — it has type %s, not a struct",
			lhs.Pos(), lhs.Sel, recvIdent.Name, llvmTypeFriendlyName(sym.Type))
	}

	info := c.e.structs[typeName]
	if info == nil {
		return fmt.Errorf("%s: %s is not a struct", lhs.Pos(), typeName)
	}
	idx, ok := info.Index[lhs.Sel]
	if !ok {
		if guess := c.e.suggestField(typeName, lhs.Sel); guess != "" {
			return fmt.Errorf("%s: %s has no field %q (did you mean %q?)", lhs.Pos(), typeName, lhs.Sel, guess)
		}
		return fmt.Errorf("%s: %s has no field %q", lhs.Pos(), typeName, lhs.Sel)
	}
	fieldT := c.e.llvmType(info.Fields[idx].Type)

	// Short-form `new {}` on the RHS infers its type from the field
	// (`st.m = new {}` → the field's declared map/slice/struct type),
	// matching the var-decl path (`var x T = new {}`, emitVar ~L3862).
	if ne, ok := rhsExpr.(*ast.NewExpr); ok && ne.Type == nil {
		ne.Type = info.Fields[idx].Type
	}

	val, err := c.emitExpr(rhsExpr)
	if err != nil {
		return err
	}
	// Auto-box concrete values flowing into an interface field
	// (`r.err = myErr`, etc.). Matches the struct-literal path.
	boxed, berr := c.maybeBoxForInterface(rhsExpr.Pos(), val, info.Fields[idx].Type)
	if berr != nil {
		return berr
	}
	val = boxed
	// Friendly type-mismatch error BEFORE store: surface field-level
	// `p.X = "string"` (where X is int) at the source position.
	if mismatch := typeMismatchMessage(info.Fields[idx].Type, val.Type, fieldT); mismatch != "" {
		return fmt.Errorf("%s: %s", lhs.Pos(), mismatch)
	}
	fp := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = getelementptr %%%s, ptr %s, i32 0, i32 %d\n",
		fp, typeName, baseAddr, idx)
	// Only instrument writes to heap-resident struct fields. Stack-local
	// struct fields can't be shared between threads in volt (borrows
	// don't cross thread boundaries), so they don't need instrumentation.
	// Detect: if baseAddr is the borrow-load result (sym.Elem path) the
	// struct lives on the heap; if baseAddr is sym.Ptr the struct is the
	// local alloca and we skip.
	if baseAddr != sym.Ptr {
		c.emitRaceMem("write", fp, 8)
	}
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
			// C13 escape proof: a closure that captures a borrow can't
			// outlive its borrowed value. Reject returning such a
			// closure — the caller-side scope would dangle.
			if sym, ok := c.symbols[id.Name]; ok && sym.CapturesBorrow {
				return fmt.Errorf("%s: cannot return closure %q — it captures a borrow whose scope ends here (C13: capture-by-borrow can't escape the borrowed value's lifetime)",
					e.Pos(), id.Name)
			}
		}
		// Inline `ret fun() { ... }` — same check on the literal directly.
		if fl, ok := e.(*ast.FuncLit); ok && fl.CapturesBorrow {
			return fmt.Errorf("%s: cannot return a closure that captures a borrow (C13: borrow's scope ends here)",
				e.Pos())
		}
	}
	// Evaluate return values BEFORE running defers, so the result isn't
	// affected by deferred operations.
	//
	// For each slot whose declared return type is `ptr` (a pointer /
	// interface value), suppress emitIdent's auto-deref so we return
	// the raw pointer — not a dereferenced struct. This matches the
	// single-return bypass below but applies to multi-return too.
	fieldRetTypes := parseAggregateFields(c.retType)
	values := make([]Value, 0, len(s.Values))
	for i, e := range s.Values {
		wantT := c.retType
		if i < len(fieldRetTypes) {
			wantT = fieldRetTypes[i]
		}
		v, err := c.emitPointerAwareExpr(e, wantT)
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
						fmt.Fprintf(&c.body, "  ret ptr %s\n", t)
						c.terminated = true
						return nil
					}
				}
			}
		}
		// Auto-box a concrete value when the declared return is an
		// interface (`error`, `any`, or a user-declared interface).
		// Without this, `fun makeErr() error { ret myErr }` would
		// fail clang as `defined with type %MyErr but expected ptr`.
		if len(c.retAstTypes) == 1 {
			boxed, berr := c.maybeBoxForInterface(s.Values[0].Pos(), values[0], c.retAstTypes[0])
			if berr != nil {
				return berr
			}
			values[0] = boxed
			// Pointer-receiver auto-box: `fun f() *T { ret new T{...} }`
			// heap-allocates the struct and returns the ptr.
			values[0] = c.maybeBoxForPointer(values[0], c.retAstTypes[0])
		}
		// Friendly type-mismatch error BEFORE ret: surface
		// `ret "string"` from a fun returning int at the source position.
		if len(c.retAstTypes) == 1 {
			if mismatch := typeMismatchMessage(c.retAstTypes[0], values[0].Type, c.retType); mismatch != "" {
				return fmt.Errorf("%s: %s", s.Values[0].Pos(), mismatch)
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
			// Auto-box concrete values flowing into interface slots
			// (same shape as the single-return case above).
			if i < len(c.retAstTypes) {
				boxed, berr := c.maybeBoxForInterface(s.Values[i].Pos(), v, c.retAstTypes[i])
				if berr != nil {
					return berr
				}
				v = boxed
				v = c.maybeBoxForPointer(v, c.retAstTypes[i])
				values[i] = v
			}
			// Friendly per-slot type-mismatch error before insertvalue.
			if i < len(c.retAstTypes) {
				if mismatch := typeMismatchMessage(c.retAstTypes[i], v.Type, fieldTypes[i]); mismatch != "" {
					return fmt.Errorf("%s: %s", s.Values[i].Pos(), mismatch)
				}
			}
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
	// The range bindings (`i`, `v`) are scoped to the for-loop itself.
	// Open a scope around the whole loop so subsequent statements at
	// the outer scope can reuse those names — and so a loop binding
	// that collides with an outer-scope name surfaces a same-scope
	// redeclare diagnostic only when the collision is at the same
	// scope, not when it's plain shadowing across scope levels.
	c.pushScope()
	defer c.popScope()
	switch src.Type {
	case "%slice":
		return c.emitRangeOverSlice(s, src)
	case "%string":
		return c.emitRangeOverString(s, src)
	case "i64":
		return c.emitRangeOverInt(s, src)
	case "ptr":
		if id, ok := s.RangeOver.(*ast.IdentExpr); ok {
			if sym, ok := c.symbols[id.Name]; ok && sym.IsMap {
				return c.emitRangeOverMap(s, src, sym)
			}
		}
		return fmt.Errorf("%s: cannot range over value of type %s", s.Pos(), src.Type)
	}
	return fmt.Errorf("%s: cannot range over value of type %s — supported: slice, string, int, map", s.Pos(), src.Type)
}

// emitRangeOverInt lowers `for i := range N` to the equivalent
// `for i := 0; i < N; i++ { body }`. No value binding is allowed —
// integer range is index-only (matches Go 1.22's surface).
func (c *funcCtx) emitRangeOverInt(s *ast.ForStmt, src Value) error {
	if s.RangeV != "" && s.RangeV != "_" {
		return fmt.Errorf("%s: range over int takes only one binding (the index)", s.Pos())
	}
	// Stash the upper bound in a stable slot — src is SSA-only.
	limPtr := "%" + c.uniqueLocal("_range_lim") + ".addr"
	fmt.Fprintf(&c.body, "  %s = alloca i64\n", limPtr)
	fmt.Fprintf(&c.body, "  store i64 %s, ptr %s\n", src.Name, limPtr)

	iName := s.RangeI
	if iName == "" || iName == "_" {
		iName = c.uniqueLocal("_range_i")
	}
	iPtr := "%" + c.uniqueLocal(iName) + ".addr"
	fmt.Fprintf(&c.body, "  %s = alloca i64\n", iPtr)
	fmt.Fprintf(&c.body, "  store i64 0, ptr %s\n", iPtr)
	if err := c.bindLocal(iName, symbol{Ptr: iPtr, Type: "i64", AstType: &ast.NamedType{Name: "int"}}, s.P); err != nil {
		return err
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
	lim := c.newTemp()
	cmp := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = load i64, ptr %s\n", iCur, iPtr)
	fmt.Fprintf(&c.body, "  %s = load i64, ptr %s\n", lim, limPtr)
	fmt.Fprintf(&c.body, "  %s = icmp slt i64 %s, %s\n", cmp, iCur, lim)
	fmt.Fprintf(&c.body, "  br i1 %s, label %%%s, label %%%s\n", cmp, bodyLbl, endLbl)
	c.terminated = true

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
	if err := c.bindLocal(iName, symbol{Ptr: iPtr, Type: "i64", AstType: &ast.NamedType{Name: "int"}}, s.P); err != nil {
		return err
	}

	// Value binding `v` (optional) — typed to the slice element.
	if s.RangeV != "" && s.RangeV != "_" {
		vPtr := "%" + c.uniqueLocal(s.RangeV) + ".addr"
		fmt.Fprintf(&c.body, "  %s = alloca %s\n", vPtr, elemLL)
		// Recover the slice element's AST type so method dispatch
		// on `v` works for interface elements (`v.Error()` on a
		// `[]error`, etc.). Without an AstType, codegen sees the
		// LLVM ptr but doesn't know the interface vtable shape.
		var elemAst ast.Type
		if id, ok := s.RangeOver.(*ast.IdentExpr); ok {
			if sym, ok := c.symbols[id.Name]; ok {
				if st, ok := sym.AstType.(*ast.SliceType); ok {
					elemAst = st.Elem
				}
			}
		}
		if err := c.bindLocal(s.RangeV, symbol{Ptr: vPtr, Type: elemLL, Elem: c.e.elemType(elemAst), AstType: elemAst}, s.P); err != nil {
			return err
		}
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
	if err := c.bindLocal(iName, symbol{Ptr: iPtr, Type: "i64", AstType: &ast.NamedType{Name: "int"}}, s.P); err != nil {
		return err
	}

	if s.RangeV != "" && s.RangeV != "_" {
		vPtr := "%" + c.uniqueLocal(s.RangeV) + ".addr"
		fmt.Fprintf(&c.body, "  %s = alloca i8\n", vPtr)
		if err := c.bindLocal(s.RangeV, symbol{Ptr: vPtr, Type: "i8", AstType: &ast.NamedType{Name: "byte"}}, s.P); err != nil {
			return err
		}
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

// emitRangeOverMap lowers `for k, v := range m` over a map[K]V.
// Uses volt_map_iter_new + volt_map_iter_next runtime helpers. Each
// iteration: call iter_next; if it returns 0, exit; else load k/v and
// run the body. Keys are %string (today maps only key by string); the
// value is i64 today (matching the existing map runtime).
//
// Concurrent mutation during iteration is UB (documented). The iter
// state is heap-allocated; we leak it on exit until A.3 wires Drop
// auto-free for all heap-backed locals.
func (c *funcCtx) emitRangeOverMap(s *ast.ForStmt, src Value, sym symbol) error {
	// Allocate iterator.
	c.e.ensureDeclare("declare ptr @volt_map_iter_new(ptr)")
	c.e.ensureDeclare("declare i64 @volt_map_iter_next(ptr, ptr, ptr, ptr)")
	iter := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call ptr @volt_map_iter_new(ptr %s)\n", iter, src.Name)

	valIsString := mapValueIsString(sym)
	valIsSlice := mapValueIsSlice(sym)
	// Interface-valued or pointer-valued maps store the boxed ptr
	// in the i64 slot; the range binding for `v` should expose it
	// as a ptr (typed to the declared AST type), not as a raw i64.
	var valIfaceAst ast.Type
	if mt, ok := sym.AstType.(*ast.MapType); ok {
		if isErrorType(mt.Value) || isAnyType(mt.Value) || c.userInterfaceName(mt.Value) != "" {
			valIfaceAst = mt.Value
		} else if _, isPtr := mt.Value.(*ast.PointerType); isPtr {
			valIfaceAst = mt.Value
		}
	}

	// Stack slots for key (ptr + len = %string-shaped) and value (i64).
	keyPtrSlot := c.newTemp()
	keyLenSlot := c.newTemp()
	valSlot := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = alloca ptr\n", keyPtrSlot)
	fmt.Fprintf(&c.body, "  %s = alloca i64\n", keyLenSlot)
	fmt.Fprintf(&c.body, "  %s = alloca i64\n", valSlot)

	// Bindings k (string) and v (i64 or %string per map's V type) —
	// registered before body emit so user code can reference them.
	var kPtr, vPtr string
	if s.RangeI != "" && s.RangeI != "_" {
		kPtr = "%" + c.uniqueLocal(s.RangeI) + ".addr"
		fmt.Fprintf(&c.body, "  %s = alloca %%string\n", kPtr)
		if err := c.bindLocal(s.RangeI, symbol{Ptr: kPtr, Type: "%string", AstType: &ast.NamedType{Name: "string"}}, s.P); err != nil {
			return err
		}
	}
	if s.RangeV != "" && s.RangeV != "_" {
		vPtr = "%" + c.uniqueLocal(s.RangeV) + ".addr"
		switch {
		case valIsString:
			fmt.Fprintf(&c.body, "  %s = alloca %%string\n", vPtr)
			if err := c.bindLocal(s.RangeV, symbol{Ptr: vPtr, Type: "%string", AstType: &ast.NamedType{Name: "string"}}, s.P); err != nil {
				return err
			}
		case valIsSlice:
			mt := sym.AstType.(*ast.MapType)
			st := mt.Value.(*ast.SliceType)
			fmt.Fprintf(&c.body, "  %s = alloca %%slice\n", vPtr)
			if err := c.bindLocal(s.RangeV, symbol{Ptr: vPtr, Type: "%slice", AstType: mt.Value, SliceElem: c.e.llvmType(st.Elem)}, s.P); err != nil {
				return err
			}
		case valIfaceAst != nil:
			fmt.Fprintf(&c.body, "  %s = alloca ptr\n", vPtr)
			if err := c.bindLocal(s.RangeV, symbol{Ptr: vPtr, Type: "ptr", Elem: c.e.elemType(valIfaceAst), AstType: valIfaceAst}, s.P); err != nil {
				return err
			}
		default:
			fmt.Fprintf(&c.body, "  %s = alloca i64\n", vPtr)
			if err := c.bindLocal(s.RangeV, symbol{Ptr: vPtr, Type: "i64", AstType: &ast.NamedType{Name: "int"}}, s.P); err != nil {
				return err
			}
		}
	}

	condLbl := c.newLabel("range.cond")
	bodyLbl := c.newLabel("range.body")
	endLbl := c.newLabel("range.end")
	c.loops = append(c.loops, loopFrame{breakLbl: endLbl, continueLbl: condLbl, scopeDepth: c.scopeDepth})
	defer func() { c.loops = c.loops[:len(c.loops)-1] }()

	fmt.Fprintf(&c.body, "  br label %%%s\n", condLbl)
	c.terminated = true

	c.startBlock(condLbl)
	okTmp := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call i64 @volt_map_iter_next(ptr %s, ptr %s, ptr %s, ptr %s)\n",
		okTmp, iter, keyPtrSlot, keyLenSlot, valSlot)
	cmp := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = icmp ne i64 %s, 0\n", cmp, okTmp)
	fmt.Fprintf(&c.body, "  br i1 %s, label %%%s, label %%%s\n", cmp, bodyLbl, endLbl)
	c.terminated = true

	c.startBlock(bodyLbl)
	c.pushScope()
	// Load k = {keyPtr, keyLen} into a %string, store at kPtr.
	if kPtr != "" {
		kp := c.newTemp()
		kl := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", kp, keyPtrSlot)
		fmt.Fprintf(&c.body, "  %s = load i64, ptr %s\n", kl, keyLenSlot)
		t1 := c.newTemp()
		t2 := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = insertvalue %%string zeroinitializer, ptr %s, 0\n", t1, kp)
		fmt.Fprintf(&c.body, "  %s = insertvalue %%string %s, i64 %s, 1\n", t2, t1, kl)
		fmt.Fprintf(&c.body, "  store %%string %s, ptr %s\n", t2, kPtr)
	}
	if vPtr != "" {
		switch {
		case valIsString:
			// Value stored is `ptr-to-%string` boxed in the i64 slot
			// (see emitMapSet). Load the i64, treat as ptr, deref.
			rawI := c.newTemp()
			ptrV := c.newTemp()
			strV := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = load i64, ptr %s\n", rawI, valSlot)
			fmt.Fprintf(&c.body, "  %s = inttoptr i64 %s to ptr\n", ptrV, rawI)
			fmt.Fprintf(&c.body, "  %s = load %%string, ptr %s\n", strV, ptrV)
			fmt.Fprintf(&c.body, "  store %%string %s, ptr %s\n", strV, vPtr)
		case valIsSlice:
			// Same boxing shape as valIsString but the payload is
			// %slice (24 bytes) — see emitMapSet's slice branch.
			rawI := c.newTemp()
			ptrV := c.newTemp()
			sliceV := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = load i64, ptr %s\n", rawI, valSlot)
			fmt.Fprintf(&c.body, "  %s = inttoptr i64 %s to ptr\n", ptrV, rawI)
			fmt.Fprintf(&c.body, "  %s = load %%slice, ptr %s\n", sliceV, ptrV)
			fmt.Fprintf(&c.body, "  store %%slice %s, ptr %s\n", sliceV, vPtr)
		case valIfaceAst != nil:
			// Interface-valued map: i64 slot holds the boxed ptr.
			// inttoptr it back into the ptr-typed v binding.
			rawI := c.newTemp()
			ptrV := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = load i64, ptr %s\n", rawI, valSlot)
			fmt.Fprintf(&c.body, "  %s = inttoptr i64 %s to ptr\n", ptrV, rawI)
			fmt.Fprintf(&c.body, "  store ptr %s, ptr %s\n", ptrV, vPtr)
		default:
			v := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = load i64, ptr %s\n", v, valSlot)
			fmt.Fprintf(&c.body, "  store i64 %s, ptr %s\n", v, vPtr)
		}
	}
	for _, stmt := range s.Body.Stmts {
		if err := c.emitStmt(stmt); err != nil {
			return err
		}
	}
	if !c.terminated {
		c.popScope()
		fmt.Fprintf(&c.body, "  br label %%%s\n", condLbl)
		c.terminated = true
	} else {
		c.scopeDepth--
		c.discardDropsAbove(c.scopeDepth)
	}

	c.startBlock(endLbl)
	return nil
}

func (c *funcCtx) emitFor(s *ast.ForStmt) error {
	if s.RangeOver != nil {
		return c.emitRangeFor(s)
	}
	// The for-init binds a variable (`for i := 0; ...`) that's scoped
	// to the loop itself. Open a scope around the whole loop so two
	// sequential `for i := 0` siblings don't trip the
	// same-scope-redeclare guard.
	if s.Init != nil {
		c.pushScope()
		defer c.popScope()
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

// emitExpr lowers an expression to a Value. It wraps emitExprInner to
// tag concrete `*T` pointer results with their named type (Value.Concrete)
// so interface boxing can distinguish them from already-boxed interfaces.
func (c *funcCtx) emitExpr(e ast.Expr) (Value, error) {
	v, err := c.emitExprInner(e)
	if err == nil && v.Type == "ptr" && v.Concrete == "" {
		if ct, cp := c.concretePtrType(e); ct != "" {
			v.Concrete = ct
			v.ConcretePkg = cp
		}
	}
	return v, err
}

func (c *funcCtx) emitExprInner(e ast.Expr) (Value, error) {
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
	// st.m[k] read on a map FIELD — synthetic sym at the field handle.
	if sel, ok := ex.X.(*ast.SelectorExpr); ok {
		if mt, addr, ok := c.mapFieldHandle(sel); ok {
			return c.emitMapGet(symbol{Ptr: addr, AstType: mt, IsMap: true}, ex.Index, ex.Pos())
		}
	}

	xv, err := c.emitExpr(ex.X)
	if err != nil {
		return Value{}, err
	}
	idx, err := c.emitExpr(ex.Index)
	if err != nil {
		return Value{}, err
	}
	// String indexing: extract ptr+len from %string, GEP+load one byte.
	// Returns an i8 (volt's `byte` type).
	if xv.Type == "%string" {
		ptr := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 0\n", ptr, xv.Name)
		fp := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = getelementptr i8, ptr %s, i64 %s\n", fp, ptr, idx.Name)
		v := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = load i8, ptr %s\n", v, fp)
		return Value{Name: v, Type: "i8"}, nil
	}
	if xv.Type != "%slice" {
		return Value{}, fmt.Errorf("%s: indexing requires a slice or string, got %s", ex.Pos(), xv.Type)
	}
	if xv.SliceElem == "" {
		return Value{}, fmt.Errorf("%s: slice element type unknown — was it created via []T{...}?", ex.Pos())
	}
	ptr := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = extractvalue %%slice %s, 0\n", ptr, xv.Name)
	fp := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = getelementptr %s, ptr %s, i64 %s\n", fp, xv.SliceElem, ptr, idx.Name)
	c.emitRaceMem("read", fp, 8)
	v := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = load %s, ptr %s\n", v, xv.SliceElem, fp)
	// If the element type is itself a slice (e.g. `[][]T`'s inner
	// `[]T`), propagate the inner element's LLVM type onto the
	// result so further indexing works without losing track of T.
	innerSE := ""
	if xv.SliceElem == "%slice" {
		if inner := c.indexedElemAst(ex.X); inner != nil {
			if st, ok := inner.(*ast.SliceType); ok && st.Elem != nil {
				innerSE = c.e.llvmType(st.Elem)
			}
		}
	}
	return Value{Name: v, Type: xv.SliceElem, SliceElem: innerSE}, nil
}

// indexedElemAst returns the element AST type of `x` when x is a
// slice — i.e., what `x[i]` would evaluate to type-wise. Walks
// through chained IdentExpr / IndexExpr / SelectorExpr so nested
// indexing like `s[0][1]` (where s is [][]T) can recover T at each
// step. Returns nil if x's slice-element type can't be recovered.
func (c *funcCtx) indexedElemAst(x ast.Expr) ast.Type {
	switch ex := x.(type) {
	case *ast.IdentExpr:
		if sym, ok := c.symbols[ex.Name]; ok {
			if st, ok := sym.AstType.(*ast.SliceType); ok {
				return st.Elem
			}
		}
	case *ast.IndexExpr:
		// Result of inner indexing — its own element AST is one
		// SliceType peel from this level's indexedElemAst.
		inner := c.indexedElemAst(ex.X)
		if st, ok := inner.(*ast.SliceType); ok {
			return st.Elem
		}
	case *ast.SelectorExpr:
		// Struct field of slice type.
		if id, ok := ex.X.(*ast.IdentExpr); ok {
			if sym, ok := c.symbols[id.Name]; ok {
				tn := c.structTypeNameOfSym(sym)
				if tn != "" {
					if info, ok := c.e.structs[tn]; ok {
						for _, f := range info.Fields {
							if f.Name == ex.Sel {
								if st, ok := f.Type.(*ast.SliceType); ok {
									return st.Elem
								}
							}
						}
					}
				}
			}
		}
	}
	return nil
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
			case "Minute":
				lit = 60000000000
			case "Hour":
				lit = 3600000000000
			default:
				return Value{}, fmt.Errorf("%s: time.%s not supported as a value", ex.Pos(), ex.Sel)
			}
			t := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = add i64 0, %d\n", t, lit)
			return Value{Name: t, Type: "i64"}, nil
		}
		// Cross-package top-level const: substitute its value expr at
		// the use site (mirrors how same-package consts work in
		// emitIdent). Tracks under the import's last-path-segment
		// name to match how user code references `pkg.Name`.
		if pkgConsts, ok := c.e.extConsts[id.Name]; ok {
			if cv, ok := pkgConsts[ex.Sel]; ok {
				return c.emitExpr(cv)
			}
		}
		return Value{}, fmt.Errorf("%s: %s.%s referenced as a value (only call form supported)",
			ex.Pos(), id.Name, ex.Sel)
	}

	xv, err := c.emitExpr(ex.X)
	if err != nil {
		return Value{}, err
	}
	// Auto-deref: if the value is a ptr and we can recover the
	// pointed-to struct type from the source expression, load the
	// struct so field-access proceeds the same way as on a bare
	// struct value. Covers `make().x` (make returns *Box), `s[0].x`
	// when slice element is *Box, etc.
	if xv.Type == "ptr" {
		if structName := c.pointeeStructName(ex.X); structName != "" {
			c.emitRaceMem("read", xv.Name, 8)
			loaded := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = load %%%s, ptr %s\n", loaded, structName, xv.Name)
			xv = Value{Name: loaded, Type: "%" + structName}
		}
	}
	// xv.Type is something like "%Counter". Strip the leading '%' to look up.
	typeName := strings.TrimPrefix(xv.Type, "%")
	info, ok := c.e.structs[typeName]
	if !ok {
		// Misleading-error fix: the receiver isn't a struct, so the
		// field access can't resolve. Name the receiver expression and
		// its actual type for a readable diagnostic.
		recv := "value"
		if id, ok := ex.X.(*ast.IdentExpr); ok {
			recv = fmt.Sprintf("%q", id.Name)
		}
		return Value{}, fmt.Errorf("%s: cannot read field %q on %s — it has type %s, not a struct",
			ex.Pos(), ex.Sel, recv, llvmTypeFriendlyName(xv.Type))
	}
	idx, ok := info.Index[ex.Sel]
	if !ok {
		if guess := c.e.suggestField(typeName, ex.Sel); guess != "" {
			return Value{}, fmt.Errorf("%s: %s has no field %q (did you mean %q?)", ex.Pos(), typeName, ex.Sel, guess)
		}
		return Value{}, fmt.Errorf("%s: %s has no field %q", ex.Pos(), typeName, ex.Sel)
	}
	fieldT := c.e.llvmType(info.Fields[idx].Type)
	t := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = extractvalue %s %s, %d\n", t, xv.Type, xv.Name, idx)
	// Propagate slice element type so an immediate `obj.field[i]` index
	// works without losing the element type.
	sliceElem := ""
	if fieldT == "%slice" {
		sliceElem = c.e.sliceElemLLVM(info.Fields[idx].Type)
	}
	return Value{Name: t, Type: fieldT, SliceElem: sliceElem}, nil
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
		if _, known := info.Index[kv.Key]; !known {
			if guess := c.e.suggestField(typeName, kv.Key); guess != "" {
				return Value{}, fmt.Errorf("%s: %s has no field %q (did you mean %q?)",
					kv.Value.Pos(), typeName, kv.Key, guess)
			}
			return Value{}, fmt.Errorf("%s: %s has no field %q",
				kv.Value.Pos(), typeName, kv.Key)
		}
		if _, dup := provided[kv.Key]; dup {
			return Value{}, fmt.Errorf("%s: field %q listed twice in %s composite literal",
				kv.Value.Pos(), kv.Key, typeName)
		}
		if err := c.rejectBorrowCaptureEscape(kv.Value, fmt.Sprintf("struct field %s.%s", typeName, kv.Key)); err != nil {
			return Value{}, err
		}
		provided[kv.Key] = kv.Value
	}
	prev := "zeroinitializer"
	for i, f := range info.Fields {
		fieldT := c.e.llvmType(f.Type)
		var v Value
		if expr, ok := provided[f.Name]; ok {
			val, err := c.emitMaybePtrForIface(expr, f.Type)
			if err != nil {
				return Value{}, err
			}
			// Auto-box concrete values flowing into an interface field
			// (error / any / user-iface). emitMaybePtrForIface keeps a
			// concrete *T's POINTER (not an auto-deref'd copy) when the
			// field is an interface it implements, so writes through the
			// boxed field reach the original pointee (e.g. an io.Writer
			// stored on a Process). Without this the field-store would
			// also fail clang with a struct-vs-ptr mismatch.
			boxed, berr := c.maybeBoxForInterface(expr.Pos(), val, f.Type)
			if berr != nil {
				return Value{}, berr
			}
			val = boxed
			// Same shape for pointer-to-struct fields: a struct
			// value flowing into a `*T` field heap-allocates
			// (matches `var f *T = new T{...}` in emitVar).
			val = c.maybeBoxForPointer(val, f.Type)
			// Friendly type-mismatch error BEFORE convertInt: surface
			// `T{x: "string"}` (where x is int) at the field site.
			if mismatch := typeMismatchMessage(f.Type, val.Type, fieldT); mismatch != "" {
				return Value{}, fmt.Errorf("%s: %s", expr.Pos(), mismatch)
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
	case *ast.CondvarType:
		return c.emitNewCondvar(ex)
	}
	return Value{}, fmt.Errorf("%s: `new` does not support type %T", ex.Pos(), ex.Type)
}

// emitNewCondvar lowers `new condvar` (or bare `new()` when the LHS
// type is condvar) into a call to volt_cond_new. No size, no init.
func (c *funcCtx) emitNewCondvar(ex *ast.NewExpr) (Value, error) {
	if len(ex.Pairs) > 0 || len(ex.SliceElems) > 0 {
		return Value{}, fmt.Errorf("%s: condvar takes only `new()`, not `{...}`", ex.Pos())
	}
	if len(ex.SizeArgs) > 0 {
		return Value{}, fmt.Errorf("%s: condvar has no size — use bare `new()`", ex.Pos())
	}
	c.e.ensureDeclare("declare ptr @volt_cond_new()")
	t := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call ptr @volt_cond_new()\n", t)
	return Value{Name: t, Type: "ptr"}, nil
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

// emitNewMap lowers `new map[K]V`, `new map[K]V{}`, `new map[K]V(cap)`,
// `new map[K]V{k:v}`, `new map[K]V(cap){k:v}`. The `(cap)` arg is
// currently advisory — the runtime map ignores it (always allocates
// the default bucket count). Bare `new map[K]V` produces an empty map
// (matches `new chan T` and `new []T`'s no-parens, no-braces form).
func (c *funcCtx) emitNewMap(ex *ast.NewExpr, t *ast.MapType) (Value, error) {
	if len(ex.Pairs) > 0 || len(ex.SliceElems) > 0 {
		return Value{}, fmt.Errorf("%s: map composite literal uses `key: value` entries (not field names or bare expressions)", ex.Pos())
	}
	// String-valued maps box their values via heap-allocated %string;
	// see emitMapSet / emitMapGet. Mirror that here at literal-time.
	vIsString := false
	if nt, ok := t.Value.(*ast.NamedType); ok && nt.Name == "string" {
		vIsString = true
	}
	// value_kind tells the runtime how to OWN its values: 1 = boxed
	// %string (free the box + backing on delete/free, deep-copy on
	// clone). 0 = plain i64 slot (int/bool/ptr) or a boxed slice value
	// (slice value ownership is deferred — still leaks, documented).
	valueKind := 0
	if vIsString {
		valueKind = 1
	}
	c.e.ensureDeclare("declare ptr @volt_map_new(i64)")
	mapTmp := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call ptr @volt_map_new(i64 %d)\n", mapTmp, valueKind)

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
		// Auto-box concrete values flowing into interface-typed map
		// entries (`new map[string]error{"a": myErr}`).
		boxed, berr := c.maybeBoxForInterface(ent.Pos(), v, t.Value)
		if berr != nil {
			return Value{}, berr
		}
		v = boxed
		// Same for pointer-typed map values
		// (`new map[string]*Box{"a": new Box{...}}`).
		v = c.maybeBoxForPointer(v, t.Value)
		var valI64 string
		if vIsString {
			c.e.ensureDeclare("declare ptr @volt_alloc(i64)")
			boxPtr := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = call ptr @volt_alloc(i64 16)\n", boxPtr)
			fmt.Fprintf(&c.body, "  store %%string %s, ptr %s\n", v.Name, boxPtr)
			ival := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = ptrtoint ptr %s to i64\n", ival, boxPtr)
			valI64 = ival
		} else if v.Type == "ptr" {
			ival := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = ptrtoint ptr %s to i64\n", ival, v.Name)
			valI64 = ival
		} else {
			v = c.convertInt(v, "i64")
			valI64 = v.Name
		}
		kp := c.newTemp()
		kl := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 0\n", kp, k.Name)
		fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 1\n", kl, k.Name)
		c.e.ensureDeclare("declare void @volt_map_set(ptr, ptr, i64, i64)")
		fmt.Fprintf(&c.body, "  call void @volt_map_set(ptr %s, ptr %s, i64 %s, i64 %s)\n",
			mapTmp, kp, kl, valI64)
	}
	return Value{Name: mapTmp, Type: "ptr"}, nil
}

// emitNewChan lowers `new chan T` and `new chan T(capacity)`. The
// element type's size is computed via the standard LLVM
// `getelementptr null,1; ptrtoint` trick so any user struct/primitive
// works; the runtime allocates `cap * elem_size` bytes for the buffer.
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
	// Compute element size from the channel's declared T.
	elemLL := "i64"
	if ct, ok := ex.Type.(*ast.ChanType); ok && ct.Elem != nil {
		elemLL = c.e.llvmType(ct.Elem)
	}
	sizeT := c.newTemp()
	sizeI := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = getelementptr %s, ptr null, i32 1\n", sizeT, elemLL)
	fmt.Fprintf(&c.body, "  %s = ptrtoint ptr %s to i64\n", sizeI, sizeT)

	c.e.ensureDeclare("declare ptr @volt_chan_new(i64, i64)")
	t := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call ptr @volt_chan_new(i64 %s, i64 %s)\n", t, capVal.Name, sizeI)
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
	elemSize := c.e.llvmTypeBytes(elemLL)
	bytesTmp := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = mul i64 %s, %d\n", bytesTmp, lenVal.Name, elemSize)

	c.e.ensureDeclare("declare ptr @volt_alloc(i64)")
	dataTmp := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call ptr @volt_alloc(i64 %s)\n", dataTmp, bytesTmp)

	// Initialize each provided element.
	for i, el := range ex.SliceElems {
		if err := c.rejectBorrowCaptureEscape(el, "slice element"); err != nil {
			return Value{}, err
		}
		v, err := c.emitExpr(el)
		if err != nil {
			return Value{}, err
		}
		// Auto-box concrete values flowing into interface-typed
		// slice elements (`new(2) []error{e1, e2}`).
		boxed, berr := c.maybeBoxForInterface(el.Pos(), v, st.Elem)
		if berr != nil {
			return Value{}, berr
		}
		v = boxed
		// Auto-box concrete struct values flowing into `*T` slice
		// elements (`new(2) []*Box{new Box{...}, ...}`).
		v = c.maybeBoxForPointer(v, st.Elem)
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
		if _, known := info.Index[kv.Key]; !known {
			if guess := c.e.suggestField(nt.Name, kv.Key); guess != "" {
				return Value{}, fmt.Errorf("%s: %s has no field %q (did you mean %q?)",
					kv.Value.Pos(), nt.Name, kv.Key, guess)
			}
			return Value{}, fmt.Errorf("%s: %s has no field %q",
				kv.Value.Pos(), nt.Name, kv.Key)
		}
		if _, dup := provided[kv.Key]; dup {
			return Value{}, fmt.Errorf("%s: field %q listed twice in %s composite literal",
				kv.Value.Pos(), kv.Key, nt.Name)
		}
		if err := c.rejectBorrowCaptureEscape(kv.Value, fmt.Sprintf("struct field %s.%s", nt.Name, kv.Key)); err != nil {
			return Value{}, err
		}
		provided[kv.Key] = kv.Value
	}

	prev := "zeroinitializer"
	for i, f := range info.Fields {
		fieldT := c.e.llvmType(f.Type)
		var v Value
		if expr, ok := provided[f.Name]; ok {
			val, err := c.emitMaybePtrForIface(expr, f.Type)
			if err != nil {
				return Value{}, err
			}
			// Auto-box concrete values flowing into an interface field
			// (error / any / user-iface). emitMaybePtrForIface keeps a
			// concrete *T's POINTER (not an auto-deref'd copy) when the
			// field is an interface it implements, so writes through the
			// boxed field reach the original pointee (e.g. an io.Writer
			// stored on a Process). Without this the field-store would
			// also fail clang with a struct-vs-ptr mismatch.
			boxed, berr := c.maybeBoxForInterface(expr.Pos(), val, f.Type)
			if berr != nil {
				return Value{}, berr
			}
			val = boxed
			// Same shape for pointer-to-struct fields: a struct
			// value flowing into a `*T` field heap-allocates
			// (matches `var f *T = new T{...}` in emitVar).
			val = c.maybeBoxForPointer(val, f.Type)
			// Friendly type-mismatch error BEFORE convertInt: surface
			// `T{x: "string"}` (where x is int) at the field site.
			if mismatch := typeMismatchMessage(f.Type, val.Type, fieldT); mismatch != "" {
				return Value{}, fmt.Errorf("%s: %s", expr.Pos(), mismatch)
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
// Aggregates: %string / %fn_value / %error_box = 16; %slice = 24.
// Named struct types (e.g. "%File") fall through to 8 here; use
// Emitter.llvmTypeBytes for slice-element sizing that needs to look
// them up.
func llvmTypeBytes(llT string) int {
	switch llT {
	case "i1", "i8":
		return 1
	case "i16":
		return 2
	case "i32", "float":
		return 4
	case "%string", "%fn_value", "%error_box":
		return 16
	case "%slice":
		return 24
	default:
		// i64, double, ptr — 8 bytes.
		return 8
	}
}

// llvmTypeBytes is the Emitter-aware variant: handles user-defined
// struct types ("%TypeName") by summing their field sizes via the
// struct registry. Falls back to the package-level function for
// primitives and built-in aggregates.
func (e *Emitter) llvmTypeBytes(llT string) int {
	if len(llT) > 1 && llT[0] == '%' {
		switch llT {
		case "%string", "%fn_value", "%error_box", "%slice":
			return llvmTypeBytes(llT)
		}
		name := llT[1:]
		if info, ok := e.structs[name]; ok {
			total := 0
			for _, f := range info.Fields {
				total += e.llvmTypeBytes(e.llvmType(f.Type))
			}
			return total
		}
	}
	return llvmTypeBytes(llT)
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
	// Duplicate-parameter check on the closure's parameter list.
	// Mirrors the FuncDecl check from Pass 154: a closure that
	// binds the same name twice would lower to LLVM IR with
	// duplicate `%name` registers — caught here at the source level
	// for a friendlier diagnostic.
	paramPos := make(map[string]lex.Pos, len(ex.Params))
	for _, p := range ex.Params {
		if p.Name == "" {
			continue
		}
		if prev, ok := paramPos[p.Name]; ok {
			return Value{}, fmt.Errorf("%s: closure has duplicate parameter %q (first at %s)",
				p.P, p.Name, prev)
		}
		paramPos[p.Name] = p.P
	}
	captures := c.collectCaptures(ex)
	ex.Captures = captures

	id := c.e.closureLitID
	c.e.closureLitID++
	bodySym := fmt.Sprintf("%s_$lit_%d", c.e.pkg, id)
	envTy := ""
	if len(captures) > 0 {
		envTy = fmt.Sprintf("%%env_$%d", id)
	}

	// C13 capture-by-borrow lands in Pass 752. Borrows captured in
	// closures are stored as plain ptr in the heap-allocated env; the
	// closure body's load/store paths already handle this correctly
	// because the closure inherits the captured symbol's Elem field.
	//
	// SAFETY: the closure's env is heap-allocated and may outlive the
	// borrowed value's scope. A closure that captures a borrow and then
	// ESCAPES (gets returned, passed to `run`, or stored long-term) is
	// unsound — the borrow becomes dangling. The minimal escape gate:
	// reject `run f(closure_with_borrow_capture)` so multi-threaded
	// outliving is impossible. Other escape paths (returning the
	// closure, storing in a struct/slice/map) are rejected by the
	// existing escape-borrow check at the FuncDecl return type level
	// when the user's return type is `fun()` — that path doesn't yet
	// see through the closure body, so a soundness gap remains for
	// returns. Full C8 phase 3 lifetime tracking would close that gap.
	closureHasBorrow := false
	for _, name := range captures {
		sym := c.symbols[name]
		if isBorrowOrPointerLLVM(sym) {
			closureHasBorrow = true
			break
		}
	}
	ex.CapturesBorrow = closureHasBorrow

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
		e:             c.e,
		symbols:       make(map[string]symbol),
		retType:       "void",
		isMain:        false,
		usedAddrs:     make(map[string]int),
		declaredAt:    make(map[string]int),
		declaredAtPos: make(map[string]lex.Pos),
		noDebugInfo:   true,
	}
	if len(ex.Results) > 0 {
		child.retType = c.e.llvmType(ex.Results[0])
		// Closure body's `ret` site needs the AST result type so the
		// emitRet → maybeBoxForInterface chain auto-boxes concrete
		// values flowing out of an interface-returning closure.
		child.retAstTypes = ex.Results
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
	// Cycle guard: refuse to recurse through a const that's already
	// being expanded — catches `const X = X + 1` and mutual cycles
	// before they blow the Go stack.
	if cv, ok := c.e.consts[ex.Name]; ok {
		if c.expandingConsts == nil {
			c.expandingConsts = make(map[string]bool)
		}
		if c.expandingConsts[ex.Name] {
			return Value{}, fmt.Errorf("%s: constant %q is self-referential (depends on its own value)",
				ex.Pos(), ex.Name)
		}
		c.expandingConsts[ex.Name] = true
		defer delete(c.expandingConsts, ex.Name)
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
		if guess := c.suggestIdentifier(ex.Name); guess != "" {
			return Value{}, fmt.Errorf("%s: undefined identifier %q (did you mean %q?)", ex.Pos(), ex.Name, guess)
		}
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

// emitFieldOrIndexAddr computes the ADDRESS (not value) of a struct
// field (`s.field`) or slice element (`a[i]`), returning the ptr temp
// and the element's LLVM type. Backs partial borrows `&s.f` /
// `&a[i]`. Handles the common shapes: ident-receiver struct
// (value or borrow/pointer) and a slice indexed by any expression.
func (c *funcCtx) emitFieldOrIndexAddr(ex ast.Expr) (string, string, error) {
	switch e := ex.(type) {
	case *ast.SelectorExpr:
		recvIdent, ok := e.X.(*ast.IdentExpr)
		if !ok {
			return "", "", fmt.Errorf("%s: `&` of a field requires a simple `var.field` target", e.Pos())
		}
		sym, ok := c.symbols[recvIdent.Name]
		if !ok {
			return "", "", fmt.Errorf("%s: undefined identifier %q", e.Pos(), recvIdent.Name)
		}
		var typeName, baseAddr string
		switch {
		case sym.Elem != "" && strings.HasPrefix(sym.Elem, "%") && sym.Elem != "%string":
			ptr := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", ptr, sym.Ptr)
			baseAddr = ptr
			typeName = strings.TrimPrefix(sym.Elem, "%")
		case strings.HasPrefix(sym.Type, "%") && sym.Type != "%string":
			baseAddr = sym.Ptr
			typeName = strings.TrimPrefix(sym.Type, "%")
		default:
			return "", "", fmt.Errorf("%s: cannot take `&` of field %q on %q — it has type %s, not a struct",
				e.Pos(), e.Sel, recvIdent.Name, llvmTypeFriendlyName(sym.Type))
		}
		info := c.e.structs[typeName]
		if info == nil {
			return "", "", fmt.Errorf("%s: %s is not a struct", e.Pos(), typeName)
		}
		idx, ok := info.Index[e.Sel]
		if !ok {
			if guess := c.e.suggestField(typeName, e.Sel); guess != "" {
				return "", "", fmt.Errorf("%s: %s has no field %q (did you mean %q?)", e.Pos(), typeName, e.Sel, guess)
			}
			return "", "", fmt.Errorf("%s: %s has no field %q", e.Pos(), typeName, e.Sel)
		}
		fieldT := c.e.llvmType(info.Fields[idx].Type)
		fp := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = getelementptr %%%s, ptr %s, i32 0, i32 %d\n",
			fp, typeName, baseAddr, idx)
		return fp, fieldT, nil
	case *ast.IndexExpr:
		xv, err := c.emitExpr(e.X)
		if err != nil {
			return "", "", err
		}
		if xv.Type != "%slice" {
			return "", "", fmt.Errorf("%s: `&` of an indexed element requires a slice, got %s", e.Pos(), xv.Type)
		}
		if xv.SliceElem == "" {
			return "", "", fmt.Errorf("%s: slice element type unknown — was it created via []T{...}?", e.Pos())
		}
		idx, err := c.emitExpr(e.Index)
		if err != nil {
			return "", "", err
		}
		idx = c.convertInt(idx, "i64")
		ptr := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = extractvalue %%slice %s, 0\n", ptr, xv.Name)
		fp := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = getelementptr %s, ptr %s, i64 %s\n", fp, xv.SliceElem, ptr, idx.Name)
		return fp, xv.SliceElem, nil
	}
	return "", "", fmt.Errorf("%s: cannot take address of this expression", ex.Pos())
}

func (c *funcCtx) emitUnary(ex *ast.UnaryExpr) (Value, error) {
	// C8 held-borrow: `&x` returns the alloca address of a local. Whether
	// it's a shared read borrow (`&T`) or the exclusive write borrow (`*T`)
	// is decided by the binding type and enforced by the checker — both
	// lower to the same Value{Type: "ptr"} here.
	if ex.Op == "&" {
		// Reborrow: `&*b` where b is itself a borrow/pointer. The deref
		// `*b` names the pointee; taking its address yields the pointer b
		// already holds. Lower to a load of that pointer — the reborrow
		// shares the same underlying storage. The checker enforces
		// exclusivity (a write reborrow of a `&T` source is rejected
		// upstream).
		if inner, ok := ex.X.(*ast.UnaryExpr); ok && inner.Op == "*" {
			if iid, ok := inner.X.(*ast.IdentExpr); ok {
				if sym, ok := c.symbols[iid.Name]; ok && sym.Elem != "" {
					p := c.newTemp()
					fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", p, sym.Ptr)
					return Value{Name: p, Type: "ptr"}, nil
				}
			}
			return Value{}, fmt.Errorf("%s: reborrow `&*x` requires x to be a borrow/pointer variable", ex.Pos())
		}
		// Partial borrow: `&s.field` / `&a[i]`. Borrow the address of a
		// struct field or slice element rather than the whole aggregate.
		// The checker ties the borrow's lifetime to the root container.
		switch ex.X.(type) {
		case *ast.SelectorExpr, *ast.IndexExpr:
			addr, _, err := c.emitFieldOrIndexAddr(ex.X)
			if err != nil {
				return Value{}, err
			}
			return Value{Name: addr, Type: "ptr"}, nil
		}
		id, ok := ex.X.(*ast.IdentExpr)
		if !ok {
			return Value{}, fmt.Errorf("%s: `&` can only take the address of a local variable, struct field, or slice element", ex.Pos())
		}
		sym, ok := c.symbols[id.Name]
		if !ok {
			return Value{}, fmt.Errorf("%s: undefined identifier %q", ex.Pos(), id.Name)
		}
		if sym.Elem != "" {
			// Already a borrow/pointer. A bare `&b` (without a deref) is
			// still rejected — use `&*b` to reborrow, or pass b directly.
			return Value{}, fmt.Errorf("%s: cannot take address of %q — it's already a borrow/pointer (reborrow via `&*%s`, or pass it directly)", ex.Pos(), id.Name, id.Name)
		}
		return Value{Name: sym.Ptr, Type: "ptr"}, nil
	}
	// C8 held-borrow: `*p` loads through the pointer/borrow. The result
	// type is sym.Elem (the deref type).
	if ex.Op == "*" {
		id, ok := ex.X.(*ast.IdentExpr)
		if !ok {
			return Value{}, fmt.Errorf("%s: `*` requires a pointer/borrow variable", ex.Pos())
		}
		sym, ok := c.symbols[id.Name]
		if !ok {
			return Value{}, fmt.Errorf("%s: undefined identifier %q", ex.Pos(), id.Name)
		}
		if sym.Elem == "" {
			return Value{}, fmt.Errorf("%s: %q is not a pointer/borrow (deref `*%s` requires &T or *T type)", ex.Pos(), id.Name, id.Name)
		}
		// Load the pointer from the alloca, then load the pointee.
		p := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", p, sym.Ptr)
		// Race instrumentation: a read THROUGH a pointer/borrow may touch
		// heap data shared across threads. Pairs with the *p = v write
		// instrumentation so unsynchronized pointer sharing is caught.
		c.emitRaceMem("read", p, 8)
		v := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = load %s, ptr %s\n", v, sym.Elem, p)
		return Value{Name: v, Type: sym.Elem}, nil
	}
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
	}
	return Value{}, fmt.Errorf("%s: unsupported unary op %q", ex.Pos(), ex.Op)
}

// isNilLit reports whether e is the literal `nil`.
func isNilLit(e ast.Expr) bool {
	_, ok := e.(*ast.NilLit)
	return ok
}

// emitPointerAwareExpr emits `e` but suppresses emitIdent's
// auto-deref when the consumer wants the raw pointer ("ptr"). This
// matters for places like `append(slice, item)` where item is a
// pointer-typed local — the slice element type is `ptr`, not the
// dereferenced struct.
func (c *funcCtx) emitPointerAwareExpr(e ast.Expr, wantT string) (Value, error) {
	if wantT == "ptr" {
		if id, ok := e.(*ast.IdentExpr); ok {
			if sym, ok := c.symbols[id.Name]; ok && sym.Elem != "" {
				t := c.newTemp()
				fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", t, sym.Ptr)
				return Value{Name: t, Type: "ptr"}, nil
			}
		}
	}
	return c.emitExpr(e)
}

func (c *funcCtx) emitBinary(ex *ast.BinaryExpr) (Value, error) {
	// Nil comparison: for `v == nil` / `v != nil` where v is a
	// pointer/borrow-typed local, we want to compare the raw pointer
	// — not auto-deref to the pointee value (that would compare a
	// struct against null, which LLVM rejects).
	if ex.Op == "==" || ex.Op == "!=" {
		if isNilLit(ex.Y) || isNilLit(ex.X) {
			id, nilSide := ex.X, ex.Y
			if isNilLit(ex.X) {
				id, nilSide = ex.Y, ex.X
			}
			if ident, ok := id.(*ast.IdentExpr); ok {
				if sym, ok := c.symbols[ident.Name]; ok && sym.Elem != "" {
					_ = nilSide
					raw := c.newTemp()
					fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", raw, sym.Ptr)
					cmpOp := "eq"
					if ex.Op == "!=" {
						cmpOp = "ne"
					}
					r := c.newTemp()
					fmt.Fprintf(&c.body, "  %s = icmp %s ptr %s, null\n", r, cmpOp, raw)
					return Value{Name: r, Type: "i1"}, nil
				}
			}
		}
	}
	// Short-circuit logical operators. `a && b` evaluates b only when a
	// is true; `a || b` only when a is false. This matches Go/C and is
	// essential for the nil-guard idiom `p != nil && p.field` — without
	// it, the RHS runs even when the guard already decided the result
	// (a nil-deref crash). Lowered with a slot + conditional branch
	// (same no-phi style as the rest of codegen).
	if ex.Op == "&&" || ex.Op == "||" {
		slot := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = alloca i1\n", slot)
		xv, xerr := c.emitExpr(ex.X)
		if xerr != nil {
			return Value{}, xerr
		}
		xb := c.toBool(xv)
		fmt.Fprintf(&c.body, "  store i1 %s, ptr %s\n", xb.Name, slot)
		rhsLbl := c.newLabel("sc.rhs")
		joinLbl := c.newLabel("sc.join")
		// && : evaluate RHS only if x is true. || : only if x is false.
		if ex.Op == "&&" {
			fmt.Fprintf(&c.body, "  br i1 %s, label %%%s, label %%%s\n", xb.Name, rhsLbl, joinLbl)
		} else {
			fmt.Fprintf(&c.body, "  br i1 %s, label %%%s, label %%%s\n", xb.Name, joinLbl, rhsLbl)
		}
		c.terminated = true

		c.startBlock(rhsLbl)
		yv, yerr := c.emitExpr(ex.Y)
		if yerr != nil {
			return Value{}, yerr
		}
		yb := c.toBool(yv)
		fmt.Fprintf(&c.body, "  store i1 %s, ptr %s\n", yb.Name, slot)
		fmt.Fprintf(&c.body, "  br label %%%s\n", joinLbl)
		c.terminated = true

		c.startBlock(joinLbl)
		r := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = load i1, ptr %s\n", r, slot)
		return Value{Name: r, Type: "i1"}, nil
	}

	x, err := c.emitExpr(ex.X)
	if err != nil {
		return Value{}, err
	}
	y, err := c.emitExpr(ex.Y)
	if err != nil {
		return Value{}, err
	}
	// String equality: `==` / `!=` on two %string values lowers to a
	// runtime byte-compare. Returns i1.
	if (ex.Op == "==" || ex.Op == "!=") && x.Type == "%string" && y.Type == "%string" {
		ap := c.newTemp()
		al := c.newTemp()
		bp := c.newTemp()
		bl := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 0\n", ap, x.Name)
		fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 1\n", al, x.Name)
		fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 0\n", bp, y.Name)
		fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 1\n", bl, y.Name)
		c.e.ensureDeclare("declare i64 @volt_string_eq(ptr, i64, ptr, i64)")
		rEq := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = call i64 @volt_string_eq(ptr %s, i64 %s, ptr %s, i64 %s)\n",
			rEq, ap, al, bp, bl)
		cmpOp := "ne"
		if ex.Op == "!=" {
			cmpOp = "eq"
		}
		r := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = icmp %s i64 %s, 0\n", r, cmpOp, rEq)
		return Value{Name: r, Type: "i1"}, nil
	}
	// String concat: `+` on two %string values lowers to a runtime call
	// that heap-allocates the joined bytes and returns a fresh %string.
	if ex.Op == "+" && x.Type == "%string" && y.Type == "%string" {
		ap := c.newTemp()
		al := c.newTemp()
		bp := c.newTemp()
		bl := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 0\n", ap, x.Name)
		fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 1\n", al, x.Name)
		fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 0\n", bp, y.Name)
		fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 1\n", bl, y.Name)
		c.e.ensureDeclare("declare %string @volt_string_concat(ptr, i64, ptr, i64)")
		r := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = call %%string @volt_string_concat(ptr %s, i64 %s, ptr %s, i64 %s)\n",
			r, ap, al, bp, bl)
		return Value{Name: r, Type: "%string"}, nil
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
	// Friendly binary-op type-mismatch error: catch operands that no
	// harmonization branch above could reconcile (e.g. int + string).
	// Without this, LLVM produces a cryptic `defined with type X but
	// expected Y` from the arithmetic / compare instruction.
	if x.Type != y.Type {
		xName := llvmTypeFriendlyName(x.Type)
		yName := llvmTypeFriendlyName(y.Type)
		if xName == "" {
			xName = x.Type
		}
		if yName == "" {
			yName = y.Type
		}
		return Value{}, fmt.Errorf("%s: type mismatch in binary %q: %s and %s",
			ex.Pos(), ex.Op, xName, yName)
	}
	// Friendly error for struct equality / comparison: volt's
	// LLVM compare-int op rejects struct operands ("icmp requires
	// integer operands"). Surface this at the volt source position
	// with an actionable message instead of letting clang error.
	if (ex.Op == "==" || ex.Op == "!=") && len(opT) > 1 && opT[0] == '%' &&
		opT != "%string" && opT != "%slice" && opT != "%error_box" && opT != "%fn_value" {
		return Value{}, fmt.Errorf("%s: struct equality (%s) is not supported in v0.7 — compare field-by-field instead",
			ex.Pos(), ex.Op)
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
	case "&":
		fmt.Fprintf(&c.body, "  %s = and %s %s, %s\n", t, opT, x.Name, y.Name)
		return Value{Name: t, Type: opT}, nil
	case "|":
		fmt.Fprintf(&c.body, "  %s = or %s %s, %s\n", t, opT, x.Name, y.Name)
		return Value{Name: t, Type: opT}, nil
	case "^":
		fmt.Fprintf(&c.body, "  %s = xor %s %s, %s\n", t, opT, x.Name, y.Name)
		return Value{Name: t, Type: opT}, nil
	case "<<":
		fmt.Fprintf(&c.body, "  %s = shl %s %s, %s\n", t, opT, x.Name, y.Name)
		return Value{Name: t, Type: opT}, nil
	case ">>":
		// Arithmetic right shift — signed semantics for int.
		fmt.Fprintf(&c.body, "  %s = ashr %s %s, %s\n", t, opT, x.Name, y.Name)
		return Value{Name: t, Type: opT}, nil
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
		case "chr":
			return c.emitBuiltinChr(call)
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
		case "delete":
			return c.emitBuiltinDelete(call)
		}
		// Inside the `runtime` stdlib package, the low-level `syscall*`
		// helpers are the FFI bridge to the C runtime. Externally,
		// callers use `runtime.X` (a selector) which the qualified-call
		// path intercepts directly; but the public functions' OWN bodies
		// (and composite helpers like HeapSnapshot) call these bare
		// `syscall*` names, which must resolve to the real C symbols
		// rather than the zero-returning volt stubs. Gated on pkg so user
		// code can't accidentally hijack an identically-named function.
		if c.e.pkg == "runtime" {
			if v, handled, err := c.emitRuntimeSyscallBridge(call, fn.Name); handled {
				return v, err
			}
		}
		// Same stub-and-intercept hazard for the `os` package: Argc /
		// ArgAt / Getenv are codegen intrinsics intercepted at `os.X`
		// selector sites, but os.Args() / os.GetenvOr() call them BARE
		// intra-package, which would hit the zero-returning stub bodies
		// (os.Args silently returned an empty slice; GetenvOr never saw
		// the real env). Route bare intrinsic calls to the real lowering.
		if c.e.pkg == "os" {
			switch fn.Name {
			case "Argc":
				return c.emitOsArgc(call)
			case "ArgAt":
				return c.emitOsArgAt(call)
			case "Getenv":
				return c.emitOsGetenv(call)
			}
		}
		return c.emitUnqualifiedCall(call, fn)
	}
	return Value{}, fmt.Errorf("%s: unsupported call form", call.Pos())
}

// emitRuntimeSyscallBridge lowers the `runtime` package's internal
// `syscall*` FFI helpers to their C runtime symbols. Returns
// (value, true, err) when `name` is a recognized bridge; (zero,
// false, nil) otherwise so the caller falls through to the normal
// volt-function path.
func (c *funcCtx) emitRuntimeSyscallBridge(call *ast.CallExpr, name string) (Value, bool, error) {
	// void-returning, no-arg bridges.
	voidNoArg := map[string]string{
		"syscallCompact":             "volt_compact",
		"syscallResetRaceViolations": "volt_race_reset_violations",
		"syscallMemProfileReset":     "volt_runtime_memprofile_reset",
	}
	// i64-returning, no-arg bridges.
	i64NoArg := map[string]string{
		"syscallThreadCount":    "volt_runtime_thread_count",
		"syscallRaceViolations": "volt_race_violations",
		"syscallHeapBytes":      "volt_runtime_heap_bytes",
		"syscallNumSizeClasses": "volt_runtime_num_size_classes",
		"syscallAllocCount":     "volt_runtime_alloc_count",
		"syscallFreeCount":      "volt_runtime_free_count",
		"syscallLiveBytes":      "volt_runtime_live_bytes",
		"syscallLiveCountHuge":  "volt_runtime_live_count_huge",
	}
	// i64-returning, single-i64-arg bridges.
	i64OneArg := map[string]string{
		"syscallFreelistCount":   "volt_runtime_freelist_count",
		"syscallLiveCountClass":  "volt_runtime_live_count_class",
		"syscallAllocCountClass": "volt_runtime_alloc_count_class",
		"syscallAllocBytesClass": "volt_runtime_alloc_bytes_class",
		"syscallSizeClassBytes":  "volt_runtime_size_class_bytes",
	}
	if sym, ok := voidNoArg[name]; ok {
		c.e.ensureDeclare(fmt.Sprintf("declare void @%s()", sym))
		fmt.Fprintf(&c.body, "  call void @%s()\n", sym)
		return Value{Name: "", Type: "void"}, true, nil
	}
	if sym, ok := i64NoArg[name]; ok {
		c.e.ensureDeclare(fmt.Sprintf("declare i64 @%s()", sym))
		t := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = call i64 @%s()\n", t, sym)
		return Value{Name: t, Type: "i64"}, true, nil
	}
	if sym, ok := i64OneArg[name]; ok {
		v, err := c.emitRuntimeI64FromI64(call, sym, name)
		return v, true, err
	}
	switch name {
	case "syscallSetArenaChunkSize":
		if len(call.Args) != 1 {
			return Value{}, true, fmt.Errorf("%s: %s takes 1 argument", call.Pos(), name)
		}
		v, err := c.emitExpr(call.Args[0])
		if err != nil {
			return Value{}, true, err
		}
		v = c.convertInt(v, "i64")
		c.e.ensureDeclare("declare void @volt_runtime_set_arena_chunk_size(i64)")
		fmt.Fprintf(&c.body, "  call void @volt_runtime_set_arena_chunk_size(i64 %s)\n", v.Name)
		return Value{Name: "", Type: "void"}, true, nil
	case "syscallMemProfileDump":
		if len(call.Args) != 1 {
			return Value{}, true, fmt.Errorf("%s: %s takes 1 argument", call.Pos(), name)
		}
		pv, err := c.emitExpr(call.Args[0])
		if err != nil {
			return Value{}, true, err
		}
		ptr := c.newTemp()
		ln := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 0\n", ptr, pv.Name)
		fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 1\n", ln, pv.Name)
		c.e.ensureDeclare("declare i64 @volt_runtime_memprofile_dump(ptr, i64)")
		t := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = call i64 @volt_runtime_memprofile_dump(ptr %s, i64 %s)\n", t, ptr, ln)
		return Value{Name: t, Type: "i64"}, true, nil
	}
	return Value{}, false, nil
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

// checkChanDirCompat verifies that the channel handle `arg` is
// direction-compatible with the channel parameter `paramType`. Returns
// an error message (empty if OK or if either side isn't a channel).
//
// Rule table (arg dir × param dir):
//
//	bidi → bidi/read/write : OK (narrowing or no-op)
//	read → read           : OK
//	write → write         : OK
//	read → bidi           : REJECT (can't widen)
//	write → bidi          : REJECT (can't widen)
//	read → write          : REJECT (incompatible)
//	write → read          : REJECT (incompatible)
//
// Only fires when both arg and param are channel-typed and at least one
// side has a non-bidi direction. Bare expressions (not idents) default
// to ChanBoth and trigger the widen check against narrowed params.
func (c *funcCtx) checkChanDirCompat(arg ast.Expr, paramType ast.Type) string {
	pc, ok := paramType.(*ast.ChanType)
	if !ok {
		return ""
	}
	var argDir ast.ChanDir = ast.ChanBoth
	argIsChan := false
	if id, ok := arg.(*ast.IdentExpr); ok {
		if sym, ok := c.symbols[id.Name]; ok {
			if ct, ok := sym.AstType.(*ast.ChanType); ok {
				argDir = ct.Dir
				argIsChan = true
			}
		}
	}
	if !argIsChan {
		return ""
	}
	if argDir == pc.Dir {
		return ""
	}
	if argDir == ast.ChanBoth {
		return "" // bidi → narrowed: established narrowing case
	}
	argName := chanDirName(argDir)
	paramName := chanDirName(pc.Dir)
	if pc.Dir == ast.ChanBoth {
		return fmt.Sprintf("cannot pass `%s` to a `chan` (bidirectional) parameter — narrowing is one-way", argName)
	}
	return fmt.Sprintf("cannot pass `%s` to a `%s` parameter — directions are incompatible", argName, paramName)
}

// chanDirName returns the surface-syntax form of a channel direction.
func chanDirName(d ast.ChanDir) string {
	switch d {
	case ast.ChanRead:
		return "chan read T"
	case ast.ChanWrite:
		return "chan write T"
	}
	return "chan T"
}

// chanArgElem returns the LLVM element type for a channel argument
// (consulting the symbol table). Falls back to i64 when the type info
// isn't available (e.g., a return value used directly).
func (c *funcCtx) chanArgElem(arg ast.Expr) string {
	if id, ok := arg.(*ast.IdentExpr); ok {
		if sym, ok := c.symbols[id.Name]; ok {
			if ct, ok := sym.AstType.(*ast.ChanType); ok && ct.Elem != nil {
				return c.e.llvmType(ct.Elem)
			}
		}
	}
	return "i64"
}

// chanArgAstElem returns the AST element type of a channel argument
// (e.g. `*ast.NamedType{Name:"error"}` for a `chan error`). Used by
// the send path to drive interface auto-boxing via
// `maybeBoxForInterface`. Returns nil when the type isn't recoverable
// (non-ident channel expressions; the boxing path falls back to
// pass-through behavior).
func (c *funcCtx) chanArgAstElem(arg ast.Expr) ast.Type {
	if id, ok := arg.(*ast.IdentExpr); ok {
		if sym, ok := c.symbols[id.Name]; ok {
			if ct, ok := sym.AstType.(*ast.ChanType); ok {
				return ct.Elem
			}
		}
	}
	return nil
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
	elemLL := c.chanArgElem(call.Args[0])
	slot := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = alloca %s\n", slot, elemLL)
	c.e.ensureDeclare("declare i64 @volt_chan_recv(ptr, ptr)")
	okTmp := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call i64 @volt_chan_recv(ptr %s, ptr %s)\n", okTmp, ch.Name, slot)
	c.emitRaceSync("acquire", ch.Name)
	v := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = load %s, ptr %s\n", v, elemLL, slot)
	return Value{Name: v, Type: elemLL}, nil
}

// emitBuiltinWrite lowers `write(ch, v)` to volt_chan_send(ch, &v).
// Stack-allocates a slot, stores v, passes the pointer; runtime memcpys.
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
	// Auto-box concrete values flowing into interface-typed channels.
	if elemAst := c.chanArgAstElem(call.Args[0]); elemAst != nil {
		boxed, berr := c.maybeBoxForInterface(call.Args[1].Pos(), val, elemAst)
		if berr != nil {
			return Value{}, berr
		}
		val = boxed
		// Same shape for pointer-typed channels (chan *T).
		val = c.maybeBoxForPointer(val, elemAst)
	}
	elemLL := c.chanArgElem(call.Args[0])
	val = c.convertInt(val, elemLL)
	slot := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = alloca %s\n", slot, elemLL)
	fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", elemLL, val.Name, slot)
	c.emitRaceSync("release", ch.Name)
	c.e.ensureDeclare("declare void @volt_chan_send(ptr, ptr)")
	fmt.Fprintf(&c.body, "  call void @volt_chan_send(ptr %s, ptr %s)\n", ch.Name, slot)
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
		c.emitRaceSync("acquire", handle)
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
		c.emitRaceSync("release", handle)
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
		c.emitRaceSync("release", handle)
		t := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = call %s @%s(ptr %s, %s %s)\n", t, llT, fn, handle, llT, v.Name)
		c.emitRaceSync("acquire", handle)
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
		c.emitRaceSync("release", handle)
		raw := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = call i64 @%s(ptr %s, %s %s, %s %s)\n",
			raw, fn, handle, llT, oldV.Name, llT, newV.Name)
		c.emitRaceSync("acquire", handle)
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

// emitCondvarMethod dispatches Wait(m) / Signal() / Broadcast() on a
// condvar receiver. Wait expects a mutex T argument — the caller MUST
// already hold the lock via that mutex's guard pattern; the runtime
// atomically unlocks, sleeps until signaled, and reacquires before
// returning. Spurious wakeups are possible so callers should re-check
// the predicate in a loop.
func (c *funcCtx) emitCondvarMethod(call *ast.CallExpr, recvSym symbol, method string) (Value, error) {
	handle := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", handle, recvSym.Ptr)

	switch method {
	case "Wait":
		if len(call.Args) != 1 {
			return Value{}, fmt.Errorf("%s: condvar.Wait takes exactly 1 argument (the paired mutex)", call.Pos())
		}
		// Resolve the mutex argument: must be a mutex T handle. We load
		// its ptr and pass to volt_cond_wait alongside the cond handle.
		mArg := call.Args[0]
		mId, ok := mArg.(*ast.IdentExpr)
		if !ok {
			return Value{}, fmt.Errorf("%s: condvar.Wait argument must be a mutex variable", call.Pos())
		}
		mSym, ok := c.symbols[mId.Name]
		if !ok {
			return Value{}, fmt.Errorf("%s: undefined identifier %q", mArg.Pos(), mId.Name)
		}
		if _, ok := mSym.AstType.(*ast.MutexType); !ok {
			return Value{}, fmt.Errorf("%s: condvar.Wait argument must be a mutex T, got %s", mArg.Pos(), llvmTypeFriendlyName(mSym.Type))
		}
		mPtr := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", mPtr, mSym.Ptr)
		c.e.ensureDeclare("declare void @volt_cond_wait(ptr, ptr)")
		fmt.Fprintf(&c.body, "  call void @volt_cond_wait(ptr %s, ptr %s)\n", handle, mPtr)
		return Value{Name: "", Type: "void"}, nil

	case "Signal":
		if len(call.Args) != 0 {
			return Value{}, fmt.Errorf("%s: condvar.Signal takes no arguments", call.Pos())
		}
		c.e.ensureDeclare("declare void @volt_cond_signal(ptr)")
		fmt.Fprintf(&c.body, "  call void @volt_cond_signal(ptr %s)\n", handle)
		return Value{Name: "", Type: "void"}, nil

	case "Broadcast":
		if len(call.Args) != 0 {
			return Value{}, fmt.Errorf("%s: condvar.Broadcast takes no arguments", call.Pos())
		}
		c.e.ensureDeclare("declare void @volt_cond_broadcast(ptr)")
		fmt.Fprintf(&c.body, "  call void @volt_cond_broadcast(ptr %s)\n", handle)
		return Value{Name: "", Type: "void"}, nil
	}
	return Value{}, fmt.Errorf("%s: condvar has no method %q (expected Wait, Signal, Broadcast)",
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
		return c.cloneSlice(pos, val, tt.Elem, c.e.llvmType(tt.Elem))
	case *ast.MapType:
		return c.cloneMap(val)
	}
	return Value{}, fmt.Errorf("%s: clone: unsupported type %T", pos, t)
}

// typeIsPodForClone reports whether a value of type t can be cloned by a
// pure byte-copy of its bits — no inner heap data to follow. Primitives
// (int, bool, float, byte) qualify; user structs qualify iff every field
// recursively qualifies. Strings / slices / maps / pointers / channels
// do not (they carry heap-bound state that the byte-copy would alias).
func (c *funcCtx) typeIsPodForClone(t ast.Type) bool {
	switch tt := t.(type) {
	case *ast.NamedType:
		switch tt.Name {
		case "int", "int8", "int16", "int32", "int64",
			"uint", "uint8", "uint16", "uint32", "uint64",
			"byte", "bool", "float", "float32", "float64":
			return true
		case "string", "error", "any":
			return false
		}
		info, ok := c.e.structs[tt.Name]
		if !ok {
			return false
		}
		for _, f := range info.Fields {
			if !c.typeIsPodForClone(f.Type) {
				return false
			}
		}
		return true
	}
	return false
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
// fresh header, then (when the element type carries inner heap data)
// walks the new buffer and replaces each element with a deep clone.
// For POD element types (int, bool, struct of POD fields) the byte
// copy alone is sufficient — no per-element work needed.
func (c *funcCtx) cloneSlice(pos lex.Pos, val Value, elemAst ast.Type, elemLL string) (Value, error) {
	if val.Type != "%slice" {
		return Value{}, fmt.Errorf("clone: expected %%slice, got %s", val.Type)
	}
	ptr := c.newTemp()
	lenVal := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = extractvalue %%slice %s, 0\n", ptr, val.Name)
	fmt.Fprintf(&c.body, "  %s = extractvalue %%slice %s, 1\n", lenVal, val.Name)
	bytesTmp := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = mul i64 %s, %d\n", bytesTmp, lenVal, c.e.llvmTypeBytes(elemLL))
	c.e.ensureDeclare("declare ptr @volt_buf_clone(ptr, i64)")
	nptr := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call ptr @volt_buf_clone(ptr %s, i64 %s)\n", nptr, ptr, bytesTmp)
	if !c.typeIsPodForClone(elemAst) {
		if err := c.emitSliceDeepCloneLoop(pos, nptr, lenVal, elemAst, elemLL); err != nil {
			return Value{}, err
		}
	}
	s1 := c.newTemp()
	s2 := c.newTemp()
	s3 := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = insertvalue %%slice zeroinitializer, ptr %s, 0\n", s1, nptr)
	fmt.Fprintf(&c.body, "  %s = insertvalue %%slice %s, i64 %s, 1\n", s2, s1, lenVal)
	// cap == len for the clone: we copied exactly `len` bytes.
	fmt.Fprintf(&c.body, "  %s = insertvalue %%slice %s, i64 %s, 2\n", s3, s2, lenVal)
	return Value{Name: s3, Type: "%slice", SliceElem: elemLL}, nil
}

// emitSliceDeepCloneLoop walks the freshly byte-copied buffer at `nptr`
// (count = `lenVal` elements of LLVM type `elemLL`, AST type `elemAst`)
// and replaces each element with a deep clone via cloneValue. The byte
// copy already populated the new buffer with the original element bits;
// this loop overwrites each slot with an independent owned copy so the
// two slices share no inner heap data.
func (c *funcCtx) emitSliceDeepCloneLoop(pos lex.Pos, nptr, lenVal string, elemAst ast.Type, elemLL string) error {
	iAddr := c.newTemp()
	condLbl := c.newLabel("clone.cond")
	bodyLbl := c.newLabel("clone.body")
	endLbl := c.newLabel("clone.end")
	fmt.Fprintf(&c.body, "  %s = alloca i64\n", iAddr)
	fmt.Fprintf(&c.body, "  store i64 0, ptr %s\n", iAddr)
	fmt.Fprintf(&c.body, "  br label %%%s\n", condLbl)
	fmt.Fprintf(&c.body, "%s:\n", condLbl)
	iVal := c.newTemp()
	cmp := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = load i64, ptr %s\n", iVal, iAddr)
	fmt.Fprintf(&c.body, "  %s = icmp slt i64 %s, %s\n", cmp, iVal, lenVal)
	fmt.Fprintf(&c.body, "  br i1 %s, label %%%s, label %%%s\n", cmp, bodyLbl, endLbl)
	fmt.Fprintf(&c.body, "%s:\n", bodyLbl)
	elemP := c.newTemp()
	elemV := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = getelementptr %s, ptr %s, i64 %s\n", elemP, elemLL, nptr, iVal)
	fmt.Fprintf(&c.body, "  %s = load %s, ptr %s\n", elemV, elemLL, elemP)
	cloned, err := c.cloneValue(pos, Value{Name: elemV, Type: elemLL}, elemAst)
	if err != nil {
		return err
	}
	fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", elemLL, cloned.Name, elemP)
	iNext := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = add i64 %s, 1\n", iNext, iVal)
	fmt.Fprintf(&c.body, "  store i64 %s, ptr %s\n", iNext, iAddr)
	fmt.Fprintf(&c.body, "  br label %%%s\n", condLbl)
	fmt.Fprintf(&c.body, "%s:\n", endLbl)
	return nil
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
// emitBuiltinDelete lowers `delete(m, key)` to volt_map_delete.
// `m` must be a map; `key` is the obvious %string key. Silently
// succeeds if the key is absent.
func (c *funcCtx) emitBuiltinDelete(call *ast.CallExpr) (Value, error) {
	if len(call.Args) != 2 {
		return Value{}, fmt.Errorf("%s: delete takes (map, key)", call.Pos())
	}
	id, ok := call.Args[0].(*ast.IdentExpr)
	if !ok {
		return Value{}, fmt.Errorf("%s: delete first argument must be a map variable", call.Pos())
	}
	sym, ok := c.symbols[id.Name]
	if !ok {
		return Value{}, fmt.Errorf("%s: undefined identifier %q", id.Pos(), id.Name)
	}
	if !sym.IsMap {
		return Value{}, fmt.Errorf("%s: delete first argument must be a map (got %T)", call.Pos(), sym.AstType)
	}
	mapPtr := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", mapPtr, sym.Ptr)

	k, err := c.emitExpr(call.Args[1])
	if err != nil {
		return Value{}, err
	}
	if k.Type != "%string" {
		return Value{}, fmt.Errorf("%s: delete key must be string in v0.5, got %s", call.Pos(), k.Type)
	}
	kp := c.newTemp()
	kl := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 0\n", kp, k.Name)
	fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 1\n", kl, k.Name)
	c.e.ensureDeclare("declare void @volt_map_delete(ptr, ptr, i64)")
	fmt.Fprintf(&c.body, "  call void @volt_map_delete(ptr %s, ptr %s, i64 %s)\n",
		mapPtr, kp, kl)
	return Value{Name: "", Type: "void"}, nil
}

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
	elem, err := c.emitPointerAwareExpr(call.Args[1], elemT)
	if err != nil {
		return Value{}, err
	}
	// Heap-box a struct VALUE element when the slice holds pointers:
	// `append(xs, new T{...})` where xs is `[]*T`. emitPointerAwareExpr
	// only un-derefs pointer IDENTS; a `new T{...}` literal arrives as a
	// `%T` value, which must be boxed to a `ptr` before it's stored into
	// the slice's `ptr` element slot (otherwise: clang "store %T into
	// ptr"). Already-pointer elements pass through unchanged.
	if elemT == "ptr" {
		if elemAst := c.indexedElemAst(call.Args[0]); elemAst != nil {
			elem = c.maybeBoxForPointer(elem, elemAst)
		}
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
// emitBuiltinChr lowers chr(b) to volt_chr_string(b) → %string —
// a 1-byte heap string holding b.
func (c *funcCtx) emitBuiltinChr(call *ast.CallExpr) (Value, error) {
	if len(call.Args) != 1 {
		return Value{}, fmt.Errorf("%s: chr takes exactly 1 argument (byte)", call.Pos())
	}
	b, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	b = c.convertInt(b, "i64")
	c.e.ensureDeclare("declare %string @volt_chr_string(i64)")
	r := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call %%string @volt_chr_string(i64 %s)\n", r, b.Name)
	return Value{Name: r, Type: "%string"}, nil
}

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

// mapValueIsString reports whether the symbol's map value type is
// `string`. Used to dispatch the box-via-heap-ptr path for
// `map[string]string` (the runtime stores values as i64, so a 16-byte
// string is stashed behind a pointer).
func mapValueIsString(sym symbol) bool {
	mt, ok := sym.AstType.(*ast.MapType)
	if !ok {
		return false
	}
	nt, ok := mt.Value.(*ast.NamedType)
	return ok && nt.Name == "string"
}

// mapValueIsSlice reports whether the symbol's map value type is a
// `[]T` slice. Same boxing motivation as mapValueIsString but the
// payload is 24 bytes (`%slice = {ptr, len, cap}`) instead of 16.
func mapValueIsSlice(sym symbol) bool {
	mt, ok := sym.AstType.(*ast.MapType)
	if !ok {
		return false
	}
	_, ok = mt.Value.(*ast.SliceType)
	return ok
}

// emitMapGet lowers `m[key]` to volt_map_get(m, key_ptr, key_len).
// For string-valued maps the i64 return is interpreted as ptr-to-
// %string (the value was heap-allocated at set-time).
// mapFieldHandle resolves `s.f` to a MAP field: returns the field's MapType
// and the address where its handle is stored, so a map FIELD can route to the
// same get/set path as a map variable. ok=false if `s.f` isn't a map field.
func (c *funcCtx) mapFieldHandle(sel *ast.SelectorExpr) (*ast.MapType, string, bool) {
	var structName string
	if id, ok := sel.X.(*ast.IdentExpr); ok {
		if sym, ok := c.symbols[id.Name]; ok {
			structName = c.structTypeNameOfSym(sym)
		}
	} else {
		structName = c.pointeeStructName(sel.X)
	}
	if structName == "" {
		return nil, "", false
	}
	info := c.e.structs[structName]
	if info == nil {
		return nil, "", false
	}
	idx, ok := info.Index[sel.Sel]
	if !ok {
		return nil, "", false
	}
	mt, ok := info.Fields[idx].Type.(*ast.MapType)
	if !ok {
		return nil, "", false
	}
	addr, _, err := c.emitFieldOrIndexAddr(sel)
	if err != nil {
		return nil, "", false
	}
	return mt, addr, true
}

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
	// Interface-valued maps store the boxed ptr cast to i64; unbox
	// here by casting back via inttoptr. Missing key → i64 0, which
	// inttoptr's to null — comparable against `nil`. Same shape
	// applies to pointer-typed map values (`map[K]*T`) — the
	// stored ptr was cast to i64 on set, restore via inttoptr here.
	if mt, ok := sym.AstType.(*ast.MapType); ok {
		if isErrorType(mt.Value) || isAnyType(mt.Value) || c.userInterfaceName(mt.Value) != "" {
			pv := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = inttoptr i64 %s to ptr\n", pv, t)
			return Value{Name: pv, Type: "ptr"}, nil
		}
		if _, isPtr := mt.Value.(*ast.PointerType); isPtr {
			pv := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = inttoptr i64 %s to ptr\n", pv, t)
			return Value{Name: pv, Type: "ptr"}, nil
		}
	}
	if mapValueIsString(sym) {
		// Treat the i64 as a pointer to a heap-allocated %string.
		// Zero (missing key) → return an empty %string. Use a stack
		// slot + branches instead of phi to keep with the rest of
		// the codegen's style.
		slot := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = alloca %%string\n", slot)
		fmt.Fprintf(&c.body, "  store %%string zeroinitializer, ptr %s\n", slot)
		zeroLbl := c.newLabel("mapget.zero")
		loadLbl := c.newLabel("mapget.load")
		joinLbl := c.newLabel("mapget.join")
		cmp := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = icmp eq i64 %s, 0\n", cmp, t)
		fmt.Fprintf(&c.body, "  br i1 %s, label %%%s, label %%%s\n", cmp, zeroLbl, loadLbl)
		c.terminated = true

		c.startBlock(loadLbl)
		ptrVal := c.newTemp()
		strVal := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = inttoptr i64 %s to ptr\n", ptrVal, t)
		fmt.Fprintf(&c.body, "  %s = load %%string, ptr %s\n", strVal, ptrVal)
		// DEEP-COPY the value out of the map's box. The box's %string
		// aliases the map-owned backing; returning it directly would let
		// the value escape (into a var, another map, a slice) while the
		// map still owns + frees that backing — a double-free / UAF once
		// the map is dropped or the key overwritten. volt_string_from_bytes
		// makes an independent heap copy so the map stays the sole owner
		// of its backing (mirrors map_clone_value on the runtime side).
		bptr := c.newTemp()
		blen := c.newTemp()
		copied := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 0\n", bptr, strVal)
		fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 1\n", blen, strVal)
		c.e.ensureDeclare("declare {ptr, i64} @volt_string_from_bytes(ptr, i64)")
		fmt.Fprintf(&c.body, "  %s = call %%string @volt_string_from_bytes(ptr %s, i64 %s)\n", copied, bptr, blen)
		fmt.Fprintf(&c.body, "  store %%string %s, ptr %s\n", copied, slot)
		fmt.Fprintf(&c.body, "  br label %%%s\n", joinLbl)
		c.terminated = true

		c.startBlock(zeroLbl)
		fmt.Fprintf(&c.body, "  br label %%%s\n", joinLbl)
		c.terminated = true

		c.startBlock(joinLbl)
		out := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = load %%string, ptr %s\n", out, slot)
		return Value{Name: out, Type: "%string"}, nil
	}
	if mapValueIsSlice(sym) {
		// Same shape as the string-valued path but with %slice
		// (24 bytes) — missing key returns a zero-initialized slice
		// (ptr=null, len=0, cap=0).
		mt := sym.AstType.(*ast.MapType)
		elemLL := c.e.llvmType(mt.Value.(*ast.SliceType).Elem)
		slot := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = alloca %%slice\n", slot)
		fmt.Fprintf(&c.body, "  store %%slice zeroinitializer, ptr %s\n", slot)
		zeroLbl := c.newLabel("mapget.zero")
		loadLbl := c.newLabel("mapget.load")
		joinLbl := c.newLabel("mapget.join")
		cmp := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = icmp eq i64 %s, 0\n", cmp, t)
		fmt.Fprintf(&c.body, "  br i1 %s, label %%%s, label %%%s\n", cmp, zeroLbl, loadLbl)
		c.terminated = true

		c.startBlock(loadLbl)
		ptrVal := c.newTemp()
		sliceVal := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = inttoptr i64 %s to ptr\n", ptrVal, t)
		fmt.Fprintf(&c.body, "  %s = load %%slice, ptr %s\n", sliceVal, ptrVal)
		fmt.Fprintf(&c.body, "  store %%slice %s, ptr %s\n", sliceVal, slot)
		fmt.Fprintf(&c.body, "  br label %%%s\n", joinLbl)
		c.terminated = true

		c.startBlock(zeroLbl)
		fmt.Fprintf(&c.body, "  br label %%%s\n", joinLbl)
		c.terminated = true

		c.startBlock(joinLbl)
		out := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = load %%slice, ptr %s\n", out, slot)
		return Value{Name: out, Type: "%slice", SliceElem: elemLL}, nil
	}
	return Value{Name: t, Type: "i64"}, nil
}

// emitMapSet lowers `m[key] = v` to volt_map_set(m, key_ptr, key_len, v).
func (c *funcCtx) emitMapSet(sym symbol, keyExpr ast.Expr, valExpr ast.Expr, pos lex.Pos) error {
	if err := c.rejectBorrowCaptureEscape(valExpr, "map value"); err != nil {
		return err
	}
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
	// Auto-box a concrete value flowing into an interface-typed
	// map value (`var m map[string]error; m["k"] = myErr`).
	if mt, ok := sym.AstType.(*ast.MapType); ok {
		boxed, berr := c.maybeBoxForInterface(valExpr.Pos(), v, mt.Value)
		if berr != nil {
			return berr
		}
		v = boxed
		// Same for pointer-typed map values.
		v = c.maybeBoxForPointer(v, mt.Value)
	}
	// Friendly type-mismatch error BEFORE the runtime call: surface
	// `m["k"] = "wrong"` (where m is map[string]int) at the source.
	if mt, ok := sym.AstType.(*ast.MapType); ok {
		targetT := c.e.llvmType(mt.Value)
		if mismatch := typeMismatchMessage(mt.Value, v.Type, targetT); mismatch != "" {
			return fmt.Errorf("%s: %s", pos, mismatch)
		}
	}
	var valI64 string
	if mapValueIsString(sym) {
		// Heap-allocate 16 bytes (a %string struct), store v into it,
		// pass the pointer-as-i64 so the runtime's i64-only value slot
		// can carry a 16-byte string indirectly.
		c.e.ensureDeclare("declare ptr @volt_alloc(i64)")
		boxPtr := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = call ptr @volt_alloc(i64 16)\n", boxPtr)
		fmt.Fprintf(&c.body, "  store %%string %s, ptr %s\n", v.Name, boxPtr)
		ival := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = ptrtoint ptr %s to i64\n", ival, boxPtr)
		valI64 = ival
	} else if mapValueIsSlice(sym) {
		// Heap-allocate 24 bytes (%slice = {ptr, len, cap}), store v,
		// pass the pointer-as-i64.
		c.e.ensureDeclare("declare ptr @volt_alloc(i64)")
		boxPtr := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = call ptr @volt_alloc(i64 24)\n", boxPtr)
		fmt.Fprintf(&c.body, "  store %%slice %s, ptr %s\n", v.Name, boxPtr)
		ival := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = ptrtoint ptr %s to i64\n", ival, boxPtr)
		valI64 = ival
	} else if v.Type == "ptr" {
		// Ptr-valued map entry (interface/struct-ptr/map/chan/etc.).
		// Cast the ptr to i64 so it fits the runtime's i64 value slot.
		ival := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = ptrtoint ptr %s to i64\n", ival, v.Name)
		valI64 = ival
	} else {
		v = c.convertInt(v, "i64")
		valI64 = v.Name
	}
	c.e.ensureDeclare("declare void @volt_map_set(ptr, ptr, i64, i64)")
	fmt.Fprintf(&c.body, "  call void @volt_map_set(ptr %s, ptr %s, i64 %s, i64 %s)\n",
		mapPtr, kp, kl, valI64)
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
	case "syscall.GetRandom":
		return c.emitSyscallGetRandom(call)
	case "syscall.Mkdir":
		return c.emitSyscallMkdir(call)
	case "syscall.PathExists":
		return c.emitSyscallPathExists(call)
	case "syscall.Remove":
		return c.emitSyscallRemove(call)
	case "syscall.BytesToString":
		return c.emitSyscallBytesToString(call)
	case "syscall.ProcSpawnFds":
		return c.emitSyscallProcSpawnFds(call)
	case "syscall.ProcWait":
		return c.emitSyscallProcWait(call)
	case "syscall.Kill":
		return c.emitSyscallTcp2(call, "volt_kill")
	case "syscall.Getpid":
		if len(call.Args) != 0 {
			return Value{}, fmt.Errorf("%s: syscall.Getpid takes no arguments", call.Pos())
		}
		c.e.ensureDeclare("declare i64 @volt_getpid()")
		r := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = call i64 @volt_getpid()\n", r)
		return Value{Name: r, Type: "i64"}, nil
	case "syscall.Gettid":
		if len(call.Args) != 0 {
			return Value{}, fmt.Errorf("%s: syscall.Gettid takes no arguments", call.Pos())
		}
		c.e.ensureDeclare("declare i64 @volt_gettid()")
		r := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = call i64 @volt_gettid()\n", r)
		return Value{Name: r, Type: "i64"}, nil
	case "syscall.ReadSome":
		return c.emitSyscallReadSome(call)
	case "log.Println":
		return c.emitLogFormatCall(call, true)
	case "log.Print":
		return c.emitLogFormatCall(call, false)
	case "fmt.Println":
		return c.emitFmtFormatCall(call, true)
	case "fmt.Print", "fmt.Printf":
		return c.emitFmtFormatCall(call, false)
	case "fmt.Sprintf":
		return c.emitFmtSprintf(call)
	case "fmt.Errorf":
		return c.emitFmtErrorf(call)
	case "fmt.Fprintf":
		return c.emitFmtFprintf(call)
	case "errors.New":
		return c.emitErrorsNew(call)
	case "syscall.Open":
		return c.emitSyscallOpen(call)
	case "syscall.Close":
		return c.emitSyscallClose(call)
	case "syscall.ReadAll":
		return c.emitSyscallReadAll(call)
	case "syscall.ReadLine":
		return c.emitSyscallReadLine(call)
	case "syscall.WriteAll":
		return c.emitSyscallWriteAll(call)
	case "syscall.TcpListen":
		return c.emitSyscallTcp3(call, "volt_tcp_listen")
	case "syscall.TcpAccept":
		return c.emitSyscallTcp1(call, "volt_tcp_accept")
	case "syscall.TcpDial":
		return c.emitSyscallTcp2(call, "volt_tcp_dial")
	// Terminal control (back the `term` stdlib package). All are plain
	// (i64)->i64 / (i64,i64)->i64 runtime calls, so the generic Tcp1/Tcp2
	// lowerings fit exactly — no dedicated emitter needed.
	case "syscall.TermSize":
		return c.emitSyscallTcp1(call, "volt_term_size")
	case "syscall.TermMakeRaw":
		return c.emitSyscallTcp1(call, "volt_term_makeraw")
	case "syscall.TermRestore":
		return c.emitSyscallTcp1(call, "volt_term_restore")
	case "syscall.ReadByte":
		return c.emitSyscallTcp1(call, "volt_read_byte")
	case "syscall.PollIn":
		return c.emitSyscallTcp2(call, "volt_poll_in")
	case "runtime.Compact":
		if len(call.Args) != 0 {
			return Value{}, fmt.Errorf("%s: runtime.Compact takes no arguments", call.Pos())
		}
		c.e.ensureDeclare("declare void @volt_compact()")
		fmt.Fprintf(&c.body, "  call void @volt_compact()\n")
		return Value{Name: "", Type: "void"}, nil
	case "runtime.ThreadCount":
		if len(call.Args) != 0 {
			return Value{}, fmt.Errorf("%s: runtime.ThreadCount takes no arguments", call.Pos())
		}
		c.e.ensureDeclare("declare i64 @volt_runtime_thread_count()")
		t := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = call i64 @volt_runtime_thread_count()\n", t)
		return Value{Name: t, Type: "i64"}, nil
	case "runtime.RaceViolations":
		if len(call.Args) != 0 {
			return Value{}, fmt.Errorf("%s: runtime.RaceViolations takes no arguments", call.Pos())
		}
		c.e.ensureDeclare("declare i64 @volt_race_violations()")
		t := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = call i64 @volt_race_violations()\n", t)
		return Value{Name: t, Type: "i64"}, nil
	case "runtime.ResetRaceViolations":
		if len(call.Args) != 0 {
			return Value{}, fmt.Errorf("%s: runtime.ResetRaceViolations takes no arguments", call.Pos())
		}
		c.e.ensureDeclare("declare void @volt_race_reset_violations()")
		fmt.Fprintf(&c.body, "  call void @volt_race_reset_violations()\n")
		return Value{Name: "", Type: "void"}, nil
	case "runtime.HeapBytes":
		if len(call.Args) != 0 {
			return Value{}, fmt.Errorf("%s: runtime.HeapBytes takes no arguments", call.Pos())
		}
		c.e.ensureDeclare("declare i64 @volt_runtime_heap_bytes()")
		t := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = call i64 @volt_runtime_heap_bytes()\n", t)
		return Value{Name: t, Type: "i64"}, nil
	case "runtime.NumSizeClasses":
		if len(call.Args) != 0 {
			return Value{}, fmt.Errorf("%s: runtime.NumSizeClasses takes no arguments", call.Pos())
		}
		c.e.ensureDeclare("declare i64 @volt_runtime_num_size_classes()")
		t := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = call i64 @volt_runtime_num_size_classes()\n", t)
		return Value{Name: t, Type: "i64"}, nil
	case "runtime.FreelistCount":
		if len(call.Args) != 1 {
			return Value{}, fmt.Errorf("%s: runtime.FreelistCount takes 1 argument (size-class index)", call.Pos())
		}
		v, err := c.emitExpr(call.Args[0])
		if err != nil {
			return Value{}, err
		}
		v = c.convertInt(v, "i64")
		c.e.ensureDeclare("declare i64 @volt_runtime_freelist_count(i64)")
		t := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = call i64 @volt_runtime_freelist_count(i64 %s)\n", t, v.Name)
		return Value{Name: t, Type: "i64"}, nil
	case "runtime.SetArenaChunkSize":
		if len(call.Args) != 1 {
			return Value{}, fmt.Errorf("%s: runtime.SetArenaChunkSize takes 1 argument", call.Pos())
		}
		v, err := c.emitExpr(call.Args[0])
		if err != nil {
			return Value{}, err
		}
		v = c.convertInt(v, "i64")
		c.e.ensureDeclare("declare void @volt_runtime_set_arena_chunk_size(i64)")
		fmt.Fprintf(&c.body, "  call void @volt_runtime_set_arena_chunk_size(i64 %s)\n", v.Name)
		return Value{Name: "", Type: "void"}, nil
	case "runtime.AllocCount":
		if len(call.Args) != 0 {
			return Value{}, fmt.Errorf("%s: runtime.AllocCount takes no arguments", call.Pos())
		}
		c.e.ensureDeclare("declare i64 @volt_runtime_alloc_count()")
		t := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = call i64 @volt_runtime_alloc_count()\n", t)
		return Value{Name: t, Type: "i64"}, nil
	case "runtime.FreeCount":
		if len(call.Args) != 0 {
			return Value{}, fmt.Errorf("%s: runtime.FreeCount takes no arguments", call.Pos())
		}
		c.e.ensureDeclare("declare i64 @volt_runtime_free_count()")
		t := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = call i64 @volt_runtime_free_count()\n", t)
		return Value{Name: t, Type: "i64"}, nil
	case "runtime.LiveBytes":
		if len(call.Args) != 0 {
			return Value{}, fmt.Errorf("%s: runtime.LiveBytes takes no arguments", call.Pos())
		}
		c.e.ensureDeclare("declare i64 @volt_runtime_live_bytes()")
		t := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = call i64 @volt_runtime_live_bytes()\n", t)
		return Value{Name: t, Type: "i64"}, nil
	case "runtime.LiveCountClass":
		return c.emitRuntimeI64FromI64(call, "volt_runtime_live_count_class", "runtime.LiveCountClass")
	case "runtime.AllocCountClass":
		return c.emitRuntimeI64FromI64(call, "volt_runtime_alloc_count_class", "runtime.AllocCountClass")
	case "runtime.AllocBytesClass":
		return c.emitRuntimeI64FromI64(call, "volt_runtime_alloc_bytes_class", "runtime.AllocBytesClass")
	case "runtime.SizeClassBytes":
		return c.emitRuntimeI64FromI64(call, "volt_runtime_size_class_bytes", "runtime.SizeClassBytes")
	case "runtime.LiveCountHuge":
		if len(call.Args) != 0 {
			return Value{}, fmt.Errorf("%s: runtime.LiveCountHuge takes no arguments", call.Pos())
		}
		c.e.ensureDeclare("declare i64 @volt_runtime_live_count_huge()")
		t := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = call i64 @volt_runtime_live_count_huge()\n", t)
		return Value{Name: t, Type: "i64"}, nil
	case "runtime.MemProfileReset":
		if len(call.Args) != 0 {
			return Value{}, fmt.Errorf("%s: runtime.MemProfileReset takes no arguments", call.Pos())
		}
		c.e.ensureDeclare("declare void @volt_runtime_memprofile_reset()")
		fmt.Fprintf(&c.body, "  call void @volt_runtime_memprofile_reset()\n")
		return Value{Name: "", Type: "void"}, nil
	case "runtime.MemProfileDump":
		if len(call.Args) != 1 {
			return Value{}, fmt.Errorf("%s: runtime.MemProfileDump takes 1 argument (path)", call.Pos())
		}
		pv, err := c.emitExpr(call.Args[0])
		if err != nil {
			return Value{}, err
		}
		if pv.Type != "%string" {
			return Value{}, fmt.Errorf("%s: runtime.MemProfileDump path must be a string", call.Pos())
		}
		ptr := c.newTemp()
		ln := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 0\n", ptr, pv.Name)
		fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 1\n", ln, pv.Name)
		c.e.ensureDeclare("declare i64 @volt_runtime_memprofile_dump(ptr, i64)")
		t := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = call i64 @volt_runtime_memprofile_dump(ptr %s, i64 %s)\n", t, ptr, ln)
		return Value{Name: t, Type: "i64"}, nil
	case "time.Now":
		return c.emitTimeNow(call, "volt_now_ns")
	case "time.Mono":
		return c.emitTimeNow(call, "volt_mono_ns")
	case "time.Since":
		return c.emitTimeSinceUntil(call, true)
	case "time.Until":
		return c.emitTimeSinceUntil(call, false)
	case "os.Argc":
		return c.emitOsArgc(call)
	case "os.ArgAt":
		return c.emitOsArgAt(call)
	case "os.Getenv":
		return c.emitOsGetenv(call)
	}

	// Otherwise: call into the imported package's mangled symbol.
	symbol := SymbolName(pkgName, sel.Sel)
	return c.emitForeignCall(call, symbol)
}

// emitMethodCall handles `obj.method(args)` where obj is a value (or a
// borrow). Looks up the method on obj's type and dispatches.
func (c *funcCtx) emitMethodCall(call *ast.CallExpr, sel *ast.SelectorExpr) (Value, error) {
	// Bare-variable receiver (`r.Method()`) — the typical path.
	if recvIdent, ok := sel.X.(*ast.IdentExpr); ok {
		recvSym, ok := c.symbols[recvIdent.Name]
		if !ok {
			return Value{}, fmt.Errorf("%s: undefined identifier %q", call.Pos(), recvIdent.Name)
		}
		return c.emitMethodCallWithRecv(call, sel, recvSym)
	}
	// Field-access receiver (`r.field.Method()`) — spill the field
	// value into a temp local and recurse. Computes the field's
	// declared AST type from the struct registry so method dispatch
	// + interface auto-handling still work.
	if fieldSel, ok := sel.X.(*ast.SelectorExpr); ok {
		recvSym, err := c.spillFieldAsLocal(fieldSel)
		if err != nil {
			return Value{}, err
		}
		return c.emitMethodCallWithRecv(call, sel, recvSym)
	}
	// Call-result receiver (`makeBox(...).Method()`) — same spill
	// pattern, recover the AST return type from the callee's
	// FuncDecl.
	if innerCall, ok := sel.X.(*ast.CallExpr); ok {
		recvSym, err := c.spillCallResultAsLocal(innerCall)
		if err != nil {
			return Value{}, err
		}
		return c.emitMethodCallWithRecv(call, sel, recvSym)
	}
	// Index-result receiver (`s[i].Method()` or `m[k].Method()`) —
	// spill the element/value and recover the AST type from the
	// collection's symbol.
	if idx, ok := sel.X.(*ast.IndexExpr); ok {
		recvSym, err := c.spillIndexResultAsLocal(idx)
		if err != nil {
			return Value{}, err
		}
		return c.emitMethodCallWithRecv(call, sel, recvSym)
	}
	return Value{}, fmt.Errorf("%s: method-call receiver must be a bare variable, struct field, call result, or index expression — assign more complex receivers to a local first (e.g. `var r T = expr; r.Method()`)",
		call.Pos())
}

// spillFieldAsLocal emits the field-access value into a fresh
// stack slot and returns a synthetic symbol that the method-call
// path can dispatch on. Used to widen the chained-method-call
// restriction so `r.err.Error()` works without forcing the user to
// pre-bind `r.err` into a local.
func (c *funcCtx) spillFieldAsLocal(sel *ast.SelectorExpr) (symbol, error) {
	val, err := c.emitFieldAccess(sel)
	if err != nil {
		return symbol{}, err
	}
	// Recover the AST type of the field so method resolution +
	// interface boxing still work. Walks the receiver chain to find
	// the struct, then looks up sel.Sel's declared type. Uses the
	// same recursion as FEAT.11 — sel.X may itself be a
	// SelectorExpr (nested chain).
	var astT ast.Type
	var outerStructName string
	if id, ok := sel.X.(*ast.IdentExpr); ok {
		if sym, ok := c.symbols[id.Name]; ok {
			outerStructName = c.structTypeNameOfSym(sym)
		}
	} else {
		outerStructName = c.pointeeStructName(sel.X)
	}
	if outerStructName != "" {
		if info, ok := c.e.structs[outerStructName]; ok {
			if idx, ok := info.Index[sel.Sel]; ok {
				astT = info.Fields[idx].Type
			}
		}
	}
	ptr := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = alloca %s\n", ptr, val.Type)
	fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", val.Type, val.Name, ptr)
	return symbol{Ptr: ptr, Type: val.Type, Elem: c.e.elemType(astT), AstType: astT}, nil
}

// lookupMethodReturn returns the single declared result AST type
// of method `(T).M`, searching both local (`e.methods`) and
// cross-package (`e.extMethods`) registries. Returns nil if the
// method doesn't exist, has zero or multiple returns, or the type
// isn't a known struct. Used by spillCallResultAsLocal to recover
// the AST type for chained method calls.
func (c *funcCtx) lookupMethodReturn(typeName, methodName string) ast.Type {
	if typeName == "" {
		return nil
	}
	if methods, ok := c.e.methods[typeName]; ok {
		if md, ok := methods[methodName]; ok && len(md.Results) == 1 {
			return md.Results[0]
		}
	}
	if ext := c.e.firstExtMethod(typeName, methodName); ext != nil && ext.decl != nil && len(ext.decl.Results) == 1 {
		return ext.decl.Results[0]
	}
	return nil
}

// spillCallResultAsLocal emits a call's return value into a fresh
// stack slot and returns a synthetic symbol carrying its declared
// AST result type. Used so `makeBox(...).Method()` dispatches via
// the same method-call machinery as a bare-variable receiver.
// Only single-return calls are supported here — multi-return
// results aren't useful as method receivers anyway.
func (c *funcCtx) spillCallResultAsLocal(call *ast.CallExpr) (symbol, error) {
	val, err := c.emitCall(call)
	if err != nil {
		return symbol{}, err
	}
	// Recover the AST return type from the callee's FuncDecl. The
	// usual shapes: bare ident → local function, pkg.Func → foreign
	// function (extPkgs).
	var astT ast.Type
	switch fn := call.Fun.(type) {
	case *ast.IdentExpr:
		if fd, ok := c.e.funcs[fn.Name]; ok && len(fd.Results) == 1 {
			astT = fd.Results[0]
		}
	case *ast.SelectorExpr:
		if pkgId, ok := fn.X.(*ast.IdentExpr); ok {
			// pkg.Func() — cross-package function.
			if pkgFns, ok := c.e.extPkgs[pkgId.Name]; ok {
				if sig, ok := pkgFns[fn.Sel]; ok && len(sig.Results) == 1 {
					astT = sig.Results[0]
				}
			}
			// recv.Method() — method on a local var.
			if astT == nil {
				if sym, ok := c.symbols[pkgId.Name]; ok {
					tn := c.structTypeNameOfSym(sym)
					astT = c.lookupMethodReturn(tn, fn.Sel)
				}
			}
		} else {
			// recv.Method() where recv is a non-Ident expression
			// (e.g. `s[0].Method()`, `f().Method()`, `r.f.Method()`).
			// Find the struct name via pointeeStructName, then
			// resolve the method in its registry.
			tn := c.pointeeStructName(fn.X)
			if tn != "" {
				astT = c.lookupMethodReturn(tn, fn.Sel)
			}
		}
	}
	ptr := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = alloca %s\n", ptr, val.Type)
	fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", val.Type, val.Name, ptr)
	return symbol{Ptr: ptr, Type: val.Type, Elem: c.e.elemType(astT), AstType: astT}, nil
}

// spillIndexResultAsLocal emits a `s[i]` / `m[k]` access value
// into a fresh stack slot and returns a synthetic symbol whose
// AstType is recovered from the source collection's declared
// element/value type. Used so `s[0].Method()` and `m["k"].Method()`
// dispatch via the standard method-call machinery.
func (c *funcCtx) spillIndexResultAsLocal(idx *ast.IndexExpr) (symbol, error) {
	var astT ast.Type
	isSlice := false
	if collectionId, ok := idx.X.(*ast.IdentExpr); ok {
		if sym, ok := c.symbols[collectionId.Name]; ok {
			switch t := sym.AstType.(type) {
			case *ast.SliceType:
				astT = t.Elem
				isSlice = true
			case *ast.MapType:
				astT = t.Value
			}
		}
	}
	// Fallback for slices reached through a non-ident expression — a
	// struct FIELD (`h.items[i]`) or a nested index (`grid[r][c]`).
	// indexedElemAst walks selectors/index chains to recover the element
	// type, so `h.items[i].Method()` (items a []*T field) can dispatch.
	if astT == nil {
		astT = c.indexedElemAst(idx.X)
	}
	// For a VALUE-element slice (`[]T`, not `[]*T`), bind the receiver to
	// the element's REAL address so a pointer-receiver method
	// (`s[i].Mutate()`) changes the element in place — not a throwaway
	// copy. Value-receiver methods still see the right value (loaded from
	// the same address). Map values aren't stably addressable, and a
	// `[]*T` element is already a pointer whose copy aliases the real
	// object, so both keep the copy-spill below.
	if isSlice {
		if _, isPtr := astT.(*ast.PointerType); !isPtr {
			if addr, _, err := c.emitFieldOrIndexAddr(idx); err == nil {
				return symbol{Ptr: addr, Type: c.e.llvmType(astT), Elem: c.e.elemType(astT), AstType: astT}, nil
			}
		}
	}
	val, err := c.emitExpr(idx)
	if err != nil {
		return symbol{}, err
	}
	ptr := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = alloca %s\n", ptr, val.Type)
	fmt.Fprintf(&c.body, "  store %s %s, ptr %s\n", val.Type, val.Name, ptr)
	return symbol{Ptr: ptr, Type: val.Type, Elem: c.e.elemType(astT), AstType: astT}, nil
}

// emitMethodCallWithRecv is the original emitMethodCall body,
// factored out so both the bare-variable and field-access entry
// points share the same dispatch logic.
func (c *funcCtx) emitMethodCallWithRecv(call *ast.CallExpr, sel *ast.SelectorExpr, recvSym symbol) (Value, error) {

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
		case *ast.CondvarType:
			return c.emitCondvarMethod(call, recvSym, sel.Sel)
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

	// Determine the bare struct type name AND its package qualifier
	// (if the AST carries one). The qualifier disambiguates types
	// that share a bare name across packages (bytes.Builder vs
	// strings.Builder — BUG.4). Try (in order):
	//   1. AstType's NamedType / *NamedType — most reliable
	//   2. Symbol's Elem field (set for borrows/pointers)
	//   3. Symbol's Type field (set for inline struct values)
	var typeName string
	var recvPkg string
	if recvSym.AstType != nil {
		switch t := recvSym.AstType.(type) {
		case *ast.NamedType:
			typeName = t.Name
			recvPkg = t.Package
		case *ast.PointerType:
			if nt, ok := t.Elem.(*ast.NamedType); ok {
				typeName = nt.Name
				recvPkg = nt.Package
			}
		case *ast.BorrowType:
			if nt, ok := t.Elem.(*ast.NamedType); ok {
				typeName = nt.Name
				recvPkg = nt.Package
			}
		}
	}
	if typeName == "" {
		switch {
		case recvSym.Elem != "" && strings.HasPrefix(recvSym.Elem, "%"):
			typeName = strings.TrimPrefix(recvSym.Elem, "%")
		case strings.HasPrefix(recvSym.Type, "%") && recvSym.Type != "%string" && recvSym.Type != "%slice":
			typeName = strings.TrimPrefix(recvSym.Type, "%")
		}
	}
	if typeName == "" {
		return Value{}, fmt.Errorf("%s: cannot call method on %s", call.Pos(), recvSym.Type)
	}

	// Resolve the method. If the receiver carries a package
	// qualifier that differs from the current package, dispatch
	// must use the cross-package registry filtered to that pkg —
	// the local `methods` map may have a same-bare-name type with
	// different identity (BUG.4).
	var method *ast.FuncDecl
	methodOwnerPkg := c.e.pkg
	if recvPkg != "" && recvPkg != c.e.pkg {
		if ent := c.e.lookupExtMethod(typeName, sel.Sel, recvPkg); ent != nil {
			method = ent.decl
			methodOwnerPkg = ent.pkg
		}
	} else {
		if methods := c.e.methods[typeName]; methods != nil {
			method = methods[sel.Sel]
		}
		if method == nil {
			if ent := c.e.lookupExtMethod(typeName, sel.Sel, ""); ent != nil {
				method = ent.decl
				methodOwnerPkg = ent.pkg
			}
		}
	}
	if method == nil {
		// Fallback: maybe sel.Sel names a STRUCT FIELD of function type
		// (`fun(...) R`). Lower as an indirect call through the field.
		if info, ok := c.e.structs[typeName]; ok {
			if idx, ok := info.Index[sel.Sel]; ok {
				if ft, ok := info.Fields[idx].Type.(*ast.FuncType); ok {
					return c.emitFieldFuncCall(call, recvSym, typeName, sel.Sel, idx, ft)
				}
			}
		}
		if guess := c.e.suggestMethod(typeName, sel.Sel); guess != "" {
			return Value{}, fmt.Errorf("%s: type %s has no method %q (did you mean %q?)", call.Pos(), typeName, sel.Sel, guess)
		}
		return Value{}, fmt.Errorf("%s: type %s has no method %q", call.Pos(), typeName, sel.Sel)
	}

	// Build the return-type string. Multi-return methods produce an
	// aggregate { ... }; the caller path (emitMultiVar) extracts fields.
	var retT string
	switch len(method.Results) {
	case 0:
		retT = "void"
	case 1:
		retT = c.e.llvmType(method.Results[0])
	default:
		ft := make([]string, len(method.Results))
		for i, r := range method.Results {
			ft[i] = c.e.llvmType(r)
		}
		retT = aggregateType(ft)
	}

	// Receiver argument. Mirrors emitCallArg's bare-name inference
	// but works for synthesized recvSyms (chained-method-call path)
	// where we don't have an IdentExpr to feed into emitCallArg.
	//
	//   - Pointer/borrow receiver type + symbol IS a pointer/borrow:
	//     load the stored ptr (extra deref).
	//   - Pointer/borrow receiver type + owned symbol: pass
	//     recvSym.Ptr as-is (the alloca address IS the receiver).
	//   - Value receiver: load the value from recvSym.Ptr.
	recvT := c.e.llvmType(method.Receiver.Type)
	var recvArgName string
	switch {
	case isBorrowOrPointer(method.Receiver.Type) && recvSym.Elem != "":
		loaded := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", loaded, recvSym.Ptr)
		recvArgName = loaded
	case isBorrowOrPointer(method.Receiver.Type):
		recvArgName = recvSym.Ptr
	default:
		loaded := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = load %s, ptr %s\n", loaded, recvSym.Type, recvSym.Ptr)
		recvArgName = loaded
	}
	argStrs := []string{recvT + " " + recvArgName}
	paramTypeStrs := []string{recvT}

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
		paramTypeStrs = append(paramTypeStrs, paramT)
	}

	mangled := methodSymbol(methodOwnerPkg, typeName, sel.Sel)
	// For cross-package methods, emit a forward `declare`.
	if methodOwnerPkg != c.e.pkg {
		c.e.ensureDeclare(fmt.Sprintf("declare %s @%s(%s)", retT, mangled, strings.Join(paramTypeStrs, ", ")))
	}
	if retT == "void" {
		fmt.Fprintf(&c.body, "  call void @%s(%s)\n", mangled, strings.Join(argStrs, ", "))
		return Value{Name: "", Type: "void"}, nil
	}
	t := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call %s @%s(%s)\n", t, retT, mangled, strings.Join(argStrs, ", "))
	return Value{Name: t, Type: retT}, nil
}

// emitForeignCall handles calls to functions in other packages. If we
// know the signature (registered via Emitter.AddExternal), we use it
// to mangle the right ABI. Falls back to a 1-arg-void legacy path
// when the signature isn't visible (covers very old intrinsics that
// predate AddExternal).
// emitRuntimeI64FromI64 lowers a runtime intrinsic of the shape
// `fun X(arg int) int` to a direct call to the named C symbol that
// takes one i64 and returns one i64. Used by the per-size-class
// accessors (LiveCountClass, AllocCountClass, ...).
func (c *funcCtx) emitRuntimeI64FromI64(call *ast.CallExpr, symbol, label string) (Value, error) {
	if len(call.Args) != 1 {
		return Value{}, fmt.Errorf("%s: %s takes 1 argument (size-class index)", call.Pos(), label)
	}
	v, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	v = c.convertInt(v, "i64")
	c.e.ensureDeclare(fmt.Sprintf("declare i64 @%s(i64)", symbol))
	t := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call i64 @%s(i64 %s)\n", t, symbol, v.Name)
	return Value{Name: t, Type: "i64"}, nil
}

func (c *funcCtx) emitForeignCall(call *ast.CallExpr, symbol string) (Value, error) {
	// Try to find the signature via the registered cross-package map.
	sel, _ := call.Fun.(*ast.SelectorExpr)
	if sel != nil {
		if pkgId, ok := sel.X.(*ast.IdentExpr); ok {
			if pkgFns, ok := c.e.extPkgs[pkgId.Name]; ok {
				if sig, ok := pkgFns[sel.Sel]; ok {
					return c.emitForeignCallWithSig(call, symbol, sig)
				}
				// Package is known but the symbol isn't — surface a
				// friendly error with a did-you-mean suggestion so the
				// user doesn't see a cryptic clang IR error later (the
				// legacy fall-through below silently emits a void call,
				// which then fails at LLVM lowering time).
				cands := make([]string, 0, len(pkgFns))
				for n := range pkgFns {
					cands = append(cands, n)
				}
				if guess := closestName(sel.Sel, cands); guess != "" {
					return Value{}, fmt.Errorf("%s: package %s has no function %q (did you mean %q?)",
						call.Pos(), pkgId.Name, sel.Sel, guess)
				}
				return Value{}, fmt.Errorf("%s: package %s has no function %q",
					call.Pos(), pkgId.Name, sel.Sel)
			}
		}
	}
	// Legacy 1-arg-void path (older intrinsics).
	if len(call.Args) != 1 {
		return Value{}, fmt.Errorf("%s: cross-package calls require a known signature; %q has none registered", call.Pos(), symbol)
	}
	arg, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	c.e.ensureDeclare(fmt.Sprintf("declare void @%s(%s)", symbol, arg.Type))
	fmt.Fprintf(&c.body, "  call void @%s(%s %s)\n", symbol, arg.Type, arg.Name)
	return Value{Name: "", Type: "void"}, nil
}

// emitForeignCallWithSig emits a cross-package call with a known signature.
// Routes multi-return to emitMultiReturnCall (used here as an expression
// would not, but for single-return: emit a direct call with the right types).
func (c *funcCtx) emitForeignCallWithSig(call *ast.CallExpr, symbol string, sig *ast.FuncDecl) (Value, error) {
	if len(call.Args) != len(sig.Params) {
		// Prefer the user-facing `pkg.Func` form over the mangled
		// `pkg_Func` symbol when reporting arity mismatches.
		display := symbol
		if sel, ok := call.Fun.(*ast.SelectorExpr); ok {
			if pkg, ok := sel.X.(*ast.IdentExpr); ok {
				display = pkg.Name + "." + sel.Sel
			}
		}
		return Value{}, fmt.Errorf("%s: %s takes %d arg(s), got %d",
			call.Pos(), display, len(sig.Params), len(call.Args))
	}
	paramTypeStrs := make([]string, len(sig.Params))
	argStrs := make([]string, len(sig.Params))
	for i, arg := range call.Args {
		v, err := c.emitCallArg(arg, sig.Params[i].Type)
		if err != nil {
			return Value{}, err
		}
		paramT := c.e.llvmType(sig.Params[i].Type)
		paramTypeStrs[i] = paramT
		argStrs[i] = paramT + " " + v.Name
	}
	var retT string
	switch len(sig.Results) {
	case 0:
		retT = "void"
	case 1:
		retT = c.e.llvmType(sig.Results[0])
	default:
		ft := make([]string, len(sig.Results))
		for i, r := range sig.Results {
			ft[i] = c.e.llvmType(r)
		}
		retT = aggregateType(ft)
	}
	c.e.ensureDeclare(fmt.Sprintf("declare %s @%s(%s)", retT, symbol, strings.Join(paramTypeStrs, ", ")))
	if retT == "void" {
		fmt.Fprintf(&c.body, "  call void @%s(%s)\n", symbol, strings.Join(argStrs, ", "))
		return Value{Name: "", Type: "void"}, nil
	}
	r := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call %s @%s(%s)\n", r, retT, symbol, strings.Join(argStrs, ", "))
	return Value{Name: r, Type: retT}, nil
}

// emitFieldFuncCall lowers `recv.field(args...)` when `field` is a
// struct field of `fun(...) R` type — i.e. a function-value held in a
// field. Loads %fn_value from the field slot, extracts fn+env, calls
// fn(env, args...). Multi-return is supported via aggregate type.
func (c *funcCtx) emitFieldFuncCall(call *ast.CallExpr, recvSym symbol, typeName, fieldName string, fieldIdx int, ft *ast.FuncType) (Value, error) {
	if len(call.Args) != len(ft.Params) {
		return Value{}, fmt.Errorf("%s: field-fn %s.%s takes %d arg(s), got %d",
			call.Pos(), typeName, fieldName, len(ft.Params), len(call.Args))
	}
	// Get a pointer to the struct value. For owned values (recvSym.Type
	// == "%T"), the alloca itself is the ptr. For pointer/borrow
	// receivers (recvSym.Type == "ptr"), load the stored ptr.
	var structPtr string
	if recvSym.Type == "ptr" {
		structPtr = c.newTemp()
		fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", structPtr, recvSym.Ptr)
	} else {
		structPtr = recvSym.Ptr
	}
	fieldPtr := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = getelementptr %%%s, ptr %s, i32 0, i32 %d\n",
		fieldPtr, typeName, structPtr, fieldIdx)
	fv := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = load %%fn_value, ptr %s\n", fv, fieldPtr)
	fnP := c.newTemp()
	envP := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = extractvalue %%fn_value %s, 0\n", fnP, fv)
	fmt.Fprintf(&c.body, "  %s = extractvalue %%fn_value %s, 1\n", envP, fv)

	var retT string
	switch len(ft.Results) {
	case 0:
		retT = "void"
	case 1:
		retT = c.e.llvmType(ft.Results[0])
	default:
		fts := make([]string, len(ft.Results))
		for i, r := range ft.Results {
			fts[i] = c.e.llvmType(r)
		}
		retT = aggregateType(fts)
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
	// Same-package intrinsic dispatch: a few stdlib packages (os,
	// time, etc.) declare stub bodies for codegen-intrinsic
	// functions so cross-package `os.Getenv(...)` calls type-check.
	// If those packages' own .volt source calls the function
	// unqualified (e.g. `Getenv("HOME")` from inside `os.UserHomeDir`),
	// the stub body would run instead of the intrinsic. Route the
	// known stub names through the intrinsic emitter here.
	switch c.e.pkg + "." + fn.Name {
	case "os.Getenv":
		return c.emitOsGetenv(call)
	case "time.Now":
		return c.emitTimeNow(call, "volt_now_ns")
	case "time.Mono":
		return c.emitTimeNow(call, "volt_mono_ns")
	case "time.Since":
		return c.emitTimeSinceUntil(call, true)
	case "time.Until":
		return c.emitTimeSinceUntil(call, false)
	}
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
		// If the name is a known local of non-function type, point at
		// the actual type rather than claiming the function is undefined.
		if sym, ok := c.symbols[fn.Name]; ok {
			return Value{}, fmt.Errorf("%s: cannot call %q — it has type %s, not a function",
				call.Pos(), fn.Name, llvmTypeFriendlyName(sym.Type))
		}
		if guess := c.suggestIdentifier(fn.Name); guess != "" {
			return Value{}, fmt.Errorf("%s: undefined function %q (did you mean %q?)", call.Pos(), fn.Name, guess)
		}
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
	// "Values own, borrows visit": a closure that captures a borrow may only
	// be CALLED where it's made. Passing it as an argument lets the callee
	// store it or run it after the borrow's scope ends → dangling. Reject it
	// (closures that capture by value/copy, the common case, pass fine).
	if fl, ok := arg.(*ast.FuncLit); ok && (fl.CapturesBorrow || c.funcLitCapturesBorrow(fl)) {
		return Value{}, fmt.Errorf("%s: cannot pass a closure that captures a borrow as an argument — it could outlive the borrow; capture by value/copy, or call it where it's made",
			arg.Pos())
	}
	if id, ok := arg.(*ast.IdentExpr); ok {
		if sym, ok := c.symbols[id.Name]; ok && sym.CapturesBorrow {
			return Value{}, fmt.Errorf("%s: cannot pass closure %q (it captures a borrow) as an argument — it could outlive the borrow; capture by value/copy, or call it where it's made",
				arg.Pos(), id.Name)
		}
	}
	// Strict channel-direction compatibility at the call site. A bidi
	// arg can narrow to any param direction, but a narrowed arg cannot
	// widen back to bidi and read/write are mutually incompatible.
	if msg := c.checkChanDirCompat(arg, paramType); msg != "" {
		return Value{}, fmt.Errorf("%s: %s", arg.Pos(), msg)
	}
	// Interface-typed parameter (user iface, error, or any): all
	// three flow through `maybeBoxForInterface` which picks the
	// right boxing helper (vtable / error_box / any-box) based on
	// the AST kind.
	if c.userInterfaceName(paramType) != "" || isErrorType(paramType) || isAnyType(paramType) {
		val, err := c.emitMaybePtrForIface(arg, paramType)
		if err != nil {
			return Value{}, err
		}
		return c.maybeBoxForInterface(arg.Pos(), val, paramType)
	}
	if !isBorrowOrPointer(paramType) {
		val, err := c.emitExpr(arg)
		if err != nil {
			return Value{}, err
		}
		// Friendly type-mismatch error BEFORE the call: surface
		// `f("string")` (where f expects int) at the source position
		// rather than a cryptic clang IR call-type error.
		targetT := c.e.llvmType(paramType)
		if mismatch := typeMismatchMessage(paramType, val.Type, targetT); mismatch != "" {
			return Value{}, fmt.Errorf("%s: %s", arg.Pos(), mismatch)
		}
		return val, nil
	}
	id, ok := arg.(*ast.IdentExpr)
	if !ok {
		// Non-ident pointer/borrow arg — e.g. a call that already
		// returns a `ptr`, or a struct-literal that needs implicit
		// boxing into `*T` (matches the var-decl implicit-Box rule).
		val, err := c.emitExpr(arg)
		if err != nil {
			return Value{}, err
		}
		if val.Type == "ptr" {
			return val, nil
		}
		boxed := c.maybeBoxForPointer(val, paramType)
		if boxed.Type == "ptr" {
			return boxed, nil
		}
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

// emitSyscallMkdir lowers syscall.Mkdir(path, mode) → runtime
// volt_mkdir(ptr, len, mode). Returns 0 or -errno.
func (c *funcCtx) emitSyscallMkdir(call *ast.CallExpr) (Value, error) {
	if len(call.Args) != 2 {
		return Value{}, fmt.Errorf("%s: syscall.Mkdir takes (path string, mode int)", call.Pos())
	}
	p, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	if p.Type != "%string" {
		return Value{}, fmt.Errorf("%s: syscall.Mkdir path must be a string", call.Pos())
	}
	m, err := c.emitExpr(call.Args[1])
	if err != nil {
		return Value{}, err
	}
	pp := c.newTemp()
	pl := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 0\n", pp, p.Name)
	fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 1\n", pl, p.Name)
	c.e.ensureDeclare("declare i64 @volt_mkdir(ptr, i64, i64)")
	rc := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call i64 @volt_mkdir(ptr %s, i64 %s, i64 %s)\n", rc, pp, pl, m.Name)
	return Value{Name: rc, Type: "i64"}, nil
}

// emitSyscallPathExists lowers syscall.PathExists(path) → runtime
// volt_path_exists(ptr, len). Returns 1/0; we widen to i1 for bool.
func (c *funcCtx) emitSyscallPathExists(call *ast.CallExpr) (Value, error) {
	if len(call.Args) != 1 {
		return Value{}, fmt.Errorf("%s: syscall.PathExists takes (path string)", call.Pos())
	}
	p, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	if p.Type != "%string" {
		return Value{}, fmt.Errorf("%s: syscall.PathExists path must be a string", call.Pos())
	}
	pp := c.newTemp()
	pl := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 0\n", pp, p.Name)
	fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 1\n", pl, p.Name)
	c.e.ensureDeclare("declare i64 @volt_path_exists(ptr, i64)")
	rc := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call i64 @volt_path_exists(ptr %s, i64 %s)\n", rc, pp, pl)
	b := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = icmp ne i64 %s, 0\n", b, rc)
	return Value{Name: b, Type: "i1"}, nil
}

// emitSyscallBytesToString lowers syscall.BytesToString(buf []byte, n int)
// to runtime volt_string_from_bytes(ptr, n). Materializes a fresh
// %string from the first n bytes of buf.
func (c *funcCtx) emitSyscallBytesToString(call *ast.CallExpr) (Value, error) {
	if len(call.Args) != 2 {
		return Value{}, fmt.Errorf("%s: syscall.BytesToString takes (buf []byte, n int)", call.Pos())
	}
	buf, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	if buf.Type != "%slice" {
		return Value{}, fmt.Errorf("%s: syscall.BytesToString buf must be []byte", call.Pos())
	}
	n, err := c.emitExpr(call.Args[1])
	if err != nil {
		return Value{}, err
	}
	dataPtr := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = extractvalue %%slice %s, 0\n", dataPtr, buf.Name)
	c.e.ensureDeclare("declare {ptr, i64} @volt_string_from_bytes(ptr, i64)")
	t := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call %%string @volt_string_from_bytes(ptr %s, i64 %s)\n",
		t, dataPtr, n.Name)
	return Value{Name: t, Type: "%string"}, nil
}

// emitSyscallRemove lowers syscall.Remove(path) → runtime
// volt_remove(ptr, len). Returns 0 or -errno.
func (c *funcCtx) emitSyscallRemove(call *ast.CallExpr) (Value, error) {
	if len(call.Args) != 1 {
		return Value{}, fmt.Errorf("%s: syscall.Remove takes (path string)", call.Pos())
	}
	p, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	if p.Type != "%string" {
		return Value{}, fmt.Errorf("%s: syscall.Remove path must be a string", call.Pos())
	}
	pp := c.newTemp()
	pl := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 0\n", pp, p.Name)
	fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 1\n", pl, p.Name)
	c.e.ensureDeclare("declare i64 @volt_remove(ptr, i64)")
	rc := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call i64 @volt_remove(ptr %s, i64 %s)\n", rc, pp, pl)
	return Value{Name: rc, Type: "i64"}, nil
}

// emitSyscallProcSpawnFds lowers
//   syscall.ProcSpawnFds(path string, argv []string, env []string,
//                        dir string, inFd int, outFd int, errFd int) int
// → runtime volt_proc_spawn_fds, which forks+execs dup3'ing the child's
// 0/1/2 to the given fds (-1 = inherit), and returns the child pid (-1 on
// fail).
func (c *funcCtx) emitSyscallProcSpawnFds(call *ast.CallExpr) (Value, error) {
	if len(call.Args) != 7 {
		return Value{}, fmt.Errorf("%s: syscall.ProcSpawnFds takes (path, argv, env, dir, inFd, outFd, errFd)", call.Pos())
	}
	path, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	argv, err := c.emitExpr(call.Args[1])
	if err != nil {
		return Value{}, err
	}
	env, err := c.emitExpr(call.Args[2])
	if err != nil {
		return Value{}, err
	}
	dir, err := c.emitExpr(call.Args[3])
	if err != nil {
		return Value{}, err
	}
	if path.Type != "%string" || dir.Type != "%string" {
		return Value{}, fmt.Errorf("%s: syscall.ProcSpawnFds path/dir must be strings", call.Pos())
	}
	if argv.Type != "%slice" || env.Type != "%slice" {
		return Value{}, fmt.Errorf("%s: syscall.ProcSpawnFds argv/env must be []string", call.Pos())
	}
	inFd, err := c.emitExpr(call.Args[4])
	if err != nil {
		return Value{}, err
	}
	inFd = c.convertInt(inFd, "i64")
	outFd, err := c.emitExpr(call.Args[5])
	if err != nil {
		return Value{}, err
	}
	outFd = c.convertInt(outFd, "i64")
	errFd, err := c.emitExpr(call.Args[6])
	if err != nil {
		return Value{}, err
	}
	errFd = c.convertInt(errFd, "i64")
	pp := c.newTemp()
	pl := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 0\n", pp, path.Name)
	fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 1\n", pl, path.Name)
	ap := c.newTemp()
	al := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = extractvalue %%slice %s, 0\n", ap, argv.Name)
	fmt.Fprintf(&c.body, "  %s = extractvalue %%slice %s, 1\n", al, argv.Name)
	ep := c.newTemp()
	el := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = extractvalue %%slice %s, 0\n", ep, env.Name)
	fmt.Fprintf(&c.body, "  %s = extractvalue %%slice %s, 1\n", el, env.Name)
	dp := c.newTemp()
	dl := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 0\n", dp, dir.Name)
	fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 1\n", dl, dir.Name)
	c.e.ensureDeclare("declare i64 @volt_proc_spawn_fds(ptr, i64, ptr, i64, ptr, i64, ptr, i64, i64, i64, i64)")
	r := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call i64 @volt_proc_spawn_fds(ptr %s, i64 %s, ptr %s, i64 %s, ptr %s, i64 %s, ptr %s, i64 %s, i64 %s, i64 %s, i64 %s)\n",
		r, pp, pl, ap, al, ep, el, dp, dl, inFd.Name, outFd.Name, errFd.Name)
	return Value{Name: r, Type: "i64"}, nil
}

// emitSyscallProcWait lowers syscall.ProcWait(pid int) int → runtime
// volt_exec_wait. Blocking reap; returns the child's exit code.
func (c *funcCtx) emitSyscallProcWait(call *ast.CallExpr) (Value, error) {
	if len(call.Args) != 1 {
		return Value{}, fmt.Errorf("%s: syscall.ProcWait takes (pid int)", call.Pos())
	}
	pid, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	pid = c.convertInt(pid, "i64")
	c.e.ensureDeclare("declare i64 @volt_exec_wait(i64)")
	r := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call i64 @volt_exec_wait(i64 %s)\n", r, pid.Name)
	return Value{Name: r, Type: "i64"}, nil
}

// emitSyscallReadSome lowers syscall.ReadSome(fd int, max int) string →
// runtime volt_read_some: a single read of up to `max` bytes ("" on EOF).
func (c *funcCtx) emitSyscallReadSome(call *ast.CallExpr) (Value, error) {
	if len(call.Args) != 2 {
		return Value{}, fmt.Errorf("%s: syscall.ReadSome takes (fd int, max int)", call.Pos())
	}
	fd, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	mx, err := c.emitExpr(call.Args[1])
	if err != nil {
		return Value{}, err
	}
	fd = c.convertInt(fd, "i64")
	mx = c.convertInt(mx, "i64")
	c.e.ensureDeclare("declare %string @volt_read_some(i64, i64)")
	r := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call %%string @volt_read_some(i64 %s, i64 %s)\n", r, fd.Name, mx.Name)
	return Value{Name: r, Type: "%string"}, nil
}

// emitSyscallGetRandom lowers syscall.GetRandom(n int) → runtime
// volt_getrandom into a heap-allocated %string. Short reads honor the
// kernel's actual return value (always <= n). Negative returns
// (errors) collapse to an empty string.
func (c *funcCtx) emitSyscallGetRandom(call *ast.CallExpr) (Value, error) {
	if len(call.Args) != 1 {
		return Value{}, fmt.Errorf("%s: syscall.GetRandom takes (n int)", call.Pos())
	}
	n, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	c.e.ensureDeclare("declare ptr @volt_alloc(i64)")
	c.e.ensureDeclare("declare i64 @volt_getrandom(ptr, i64)")
	buf := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call ptr @volt_alloc(i64 %s)\n", buf, n.Name)
	got := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call i64 @volt_getrandom(ptr %s, i64 %s)\n", got, buf, n.Name)
	// Clamp negative (error) length to 0.
	clamped := c.newTemp()
	isNeg := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = icmp slt i64 %s, 0\n", isNeg, got)
	fmt.Fprintf(&c.body, "  %s = select i1 %s, i64 0, i64 %s\n", clamped, isNeg, got)
	// Pack into %string {ptr, len}.
	t1 := c.newTemp()
	t2 := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = insertvalue %%string zeroinitializer, ptr %s, 0\n", t1, buf)
	fmt.Fprintf(&c.body, "  %s = insertvalue %%string %s, i64 %s, 1\n", t2, t1, clamped)
	return Value{Name: t2, Type: "%string"}, nil
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

// emitFmtFormatCall is the fmt.* family (stdout, fd 1). Same shape
// as log.* but writes to fd 1. Backs fmt.Print / fmt.Println / fmt.Printf.
func (c *funcCtx) emitFmtFormatCall(call *ast.CallExpr, addNewline bool) (Value, error) {
	return c.emitFormatCallToFd(call, addNewline, 1, "fmt")
}

// emitFmtSprintf lowers fmt.Sprintf(format, args...) to a chain of
// volt_string_concat calls that build the final string from the format
// chunks and each arg converted to its string form (%d → int_to_string,
// %s → arg, %t → bool_to_string, %v → dispatch). The result is a
// freshly-allocated heap %string.
//
// O(n²) for chained concats (each one copies). For short format strings
// this is fine; if it becomes a hotspot, swap in a single-allocation
// accumulator (precompute total length, alloca once, fill).
func (c *funcCtx) emitFmtSprintf(call *ast.CallExpr) (Value, error) {
	if len(call.Args) == 0 {
		return Value{}, fmt.Errorf("%s: fmt.Sprintf requires at least a format string", call.Pos())
	}
	fmtLit, ok := call.Args[0].(*ast.StringLit)
	if !ok {
		return Value{}, fmt.Errorf("%s: fmt.Sprintf requires a string literal as the format", call.Pos())
	}
	chunks, verbs, err := parseLogFormat(fmtLit.Text)
	if err != nil {
		return Value{}, fmt.Errorf("%s: %v", call.Pos(), err)
	}
	if len(verbs) != len(call.Args)-1 {
		return Value{}, fmt.Errorf("%s: fmt.Sprintf: format has %d verbs but %d args provided",
			call.Pos(), len(verbs), len(call.Args)-1)
	}

	// Collect each piece (as a %string Value). Walk chunks + verbs in
	// lockstep; emit literal-as-string for non-empty chunks and
	// arg-conversion for each verb.
	var pieces []Value
	argIdx := 0
	for i, chunk := range chunks {
		if chunk != "" {
			pieces = append(pieces, c.stringLiteralValue(chunk))
		}
		if i < len(verbs) {
			argExpr := call.Args[1+argIdx]
			argVal, err := c.emitExpr(argExpr)
			if err != nil {
				return Value{}, err
			}
			piece, err := c.formatArgToString(argExpr, argVal, verbs[i])
			if err != nil {
				return Value{}, err
			}
			pieces = append(pieces, piece)
			argIdx++
		}
	}

	if len(pieces) == 0 {
		return c.stringLiteralValue(""), nil
	}
	result := pieces[0]
	c.e.ensureDeclare("declare %string @volt_string_concat(ptr, i64, ptr, i64)")
	for j := 1; j < len(pieces); j++ {
		ap := c.newTemp()
		al := c.newTemp()
		bp := c.newTemp()
		bl := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 0\n", ap, result.Name)
		fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 1\n", al, result.Name)
		fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 0\n", bp, pieces[j].Name)
		fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 1\n", bl, pieces[j].Name)
		r := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = call %%string @volt_string_concat(ptr %s, i64 %s, ptr %s, i64 %s)\n",
			r, ap, al, bp, bl)
		result = Value{Name: r, Type: "%string"}
	}
	return result, nil
}

// emitFmtFprintf lowers `fmt.Fprintf(w, format, args...)` to:
//   1. Build the formatted %string the same way Sprintf does.
//   2. Dispatch `w.Write(s)` through w's Writer vtable (method 0).
// Returns the (int, error) aggregate the Write method produces.
//
// w may be:
//   - already an interface box (ptr) — used directly
//   - a concrete struct value — boxed against the io.Writer vtable
func (c *funcCtx) emitFmtFprintf(call *ast.CallExpr) (Value, error) {
	if len(call.Args) < 2 {
		return Value{}, fmt.Errorf("%s: fmt.Fprintf requires (writer, format, args...)", call.Pos())
	}
	// Evaluate writer arg.
	wExpr := call.Args[0]
	wVal, err := c.emitExpr(wExpr)
	if err != nil {
		return Value{}, err
	}
	if wVal.Type != "ptr" {
		// Concrete struct value — auto-box into Writer.
		boxed, berr := c.emitIfaceBox(call.Pos(), wVal, "Writer")
		if berr != nil {
			return Value{}, berr
		}
		wVal = boxed
	}
	// Build formatted message — Sprintf with args[1:] as a fresh call shape.
	innerCall := &ast.CallExpr{
		P:    call.P,
		Fun:  call.Fun,
		Args: call.Args[1:],
	}
	msg, err := c.emitFmtSprintf(innerCall)
	if err != nil {
		return Value{}, err
	}

	// Dispatch w.Write(msg) — vtable index 0 of Writer.
	dataGep := c.newTemp()
	dataPtr := c.newTemp()
	vtGep := c.newTemp()
	vtPtr := c.newTemp()
	fnGep := c.newTemp()
	fnPtr := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = getelementptr %%error_box, ptr %s, i32 0, i32 0\n", dataGep, wVal.Name)
	fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", dataPtr, dataGep)
	fmt.Fprintf(&c.body, "  %s = getelementptr %%error_box, ptr %s, i32 0, i32 1\n", vtGep, wVal.Name)
	fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", vtPtr, vtGep)
	fmt.Fprintf(&c.body, "  %s = getelementptr ptr, ptr %s, i32 0\n", fnGep, vtPtr)
	fmt.Fprintf(&c.body, "  %s = load ptr, ptr %s\n", fnPtr, fnGep)
	result := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call {i64, ptr} %s(ptr %s, %%string %s)\n",
		result, fnPtr, dataPtr, msg.Name)
	return Value{Name: result, Type: "{i64, ptr}"}, nil
}

// emitFmtErrorf is fmt.Sprintf + errors.New: build the formatted
// message, then wrap it into an error_box.
func (c *funcCtx) emitFmtErrorf(call *ast.CallExpr) (Value, error) {
	msg, err := c.emitFmtSprintf(call)
	if err != nil {
		return Value{}, err
	}
	// Reuse the errors.New box machinery: stash msg in a heap holder
	// and point an %error_box at it.
	c.e.ensureErrorsRuntimeHelper()
	c.e.ensureDeclare("declare ptr @volt_alloc(i64)")
	holder := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call ptr @volt_alloc(i64 16)\n", holder)
	fmt.Fprintf(&c.body, "  store %%string %s, ptr %s\n", msg.Name, holder)
	box := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call ptr @volt_alloc(i64 16)\n", box)
	dataP := c.newTemp()
	fnP := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = getelementptr %%error_box, ptr %s, i32 0, i32 0\n", dataP, box)
	fmt.Fprintf(&c.body, "  store ptr %s, ptr %s\n", holder, dataP)
	fmt.Fprintf(&c.body, "  %s = getelementptr %%error_box, ptr %s, i32 0, i32 1\n", fnP, box)
	fmt.Fprintf(&c.body, "  store ptr @volt_errors_strerror, ptr %s\n", fnP)
	return Value{Name: box, Type: "ptr"}, nil
}

// stringLiteralValue produces a %string Value containing `s`. Used
// when format chunks need to appear as a %string Value (rather than
// being written directly).
func (c *funcCtx) stringLiteralValue(s string) Value {
	gname, glen := c.e.internString(s)
	t1 := c.newTemp()
	t2 := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = insertvalue %%string zeroinitializer, ptr %s, 0\n", t1, gname)
	fmt.Fprintf(&c.body, "  %s = insertvalue %%string %s, i64 %d, 1\n", t2, t1, glen)
	return Value{Name: t2, Type: "%string"}
}

// formatArgToString converts an arg value to a %string for the given
// verb (%d / %s / %t / %v). Mirrors emitFormattedArgFd but produces a
// %string Value instead of writing to fd.
func (c *funcCtx) formatArgToString(argExpr ast.Expr, v Value, verb byte) (Value, error) {
	switch verb {
	case 'd':
		if !isIntLLVM(v.Type) {
			return Value{}, fmt.Errorf("%s: %%d expects an integer, got %s", argExpr.Pos(), v.Type)
		}
		v = c.convertInt(v, "i64")
		c.e.ensureDeclare("declare %string @volt_int_to_string(i64)")
		r := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = call %%string @volt_int_to_string(i64 %s)\n", r, v.Name)
		return Value{Name: r, Type: "%string"}, nil
	case 's':
		if v.Type != "%string" {
			return Value{}, fmt.Errorf("%s: %%s expects a string, got %s", argExpr.Pos(), v.Type)
		}
		return v, nil
	case 't':
		if v.Type != "i1" {
			return Value{}, fmt.Errorf("%s: %%t expects a bool, got %s", argExpr.Pos(), v.Type)
		}
		ext := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = zext i1 %s to i64\n", ext, v.Name)
		c.e.ensureDeclare("declare %string @volt_bool_to_string(i64)")
		r := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = call %%string @volt_bool_to_string(i64 %s)\n", r, ext)
		return Value{Name: r, Type: "%string"}, nil
	case 'v':
		switch {
		case v.Type == "%string":
			return v, nil
		case v.Type == "i1":
			ext := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = zext i1 %s to i64\n", ext, v.Name)
			c.e.ensureDeclare("declare %string @volt_bool_to_string(i64)")
			r := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = call %%string @volt_bool_to_string(i64 %s)\n", r, ext)
			return Value{Name: r, Type: "%string"}, nil
		case isIntLLVM(v.Type):
			v = c.convertInt(v, "i64")
			c.e.ensureDeclare("declare %string @volt_int_to_string(i64)")
			r := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = call %%string @volt_int_to_string(i64 %s)\n", r, v.Name)
			return Value{Name: r, Type: "%string"}, nil
		default:
			return Value{}, fmt.Errorf("%s: %%v: unsupported value type %s", argExpr.Pos(), v.Type)
		}
	default:
		return Value{}, fmt.Errorf("%s: unsupported format verb %%%c", argExpr.Pos(), verb)
	}
}

// emitLogFormatCall is the shared compiler intrinsic for log.Println and
// log.Print. They write to fd 2 (stderr). They differ only by whether
// a trailing "\n" is appended.
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
	return c.emitFormatCallToFd(call, addNewline, 2, "log")
}

// emitFormatCallToFd is the shared engine for both `log.*` (fd=2,
// stderr) and `fmt.*` (fd=1, stdout). pkgName is used only for error
// messages. The format-walk is identical; only the write target differs.
func (c *funcCtx) emitFormatCallToFd(call *ast.CallExpr, addNewline bool, fd int64, pkgName string) (Value, error) {
	name := pkgName + ".Print"
	if addNewline {
		name = pkgName + ".Println"
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
		c.emitWriteStringFd(s, fd)
		if addNewline {
			c.emitWriteCStringLiteralFd("\n", fd)
		}
		return Value{Name: "", Type: "void"}, nil
	}

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

	argIdx := 0
	for i, lit := range chunks {
		if lit != "" {
			c.emitWriteCStringLiteralFd(lit, fd)
		}
		if i < len(verbs) {
			argExpr := call.Args[1+argIdx]
			argVal, err := c.emitExpr(argExpr)
			if err != nil {
				return Value{}, err
			}
			if err := c.emitFormattedArgFd(argExpr, argVal, verbs[i], fd); err != nil {
				return Value{}, err
			}
			argIdx++
		}
	}
	if addNewline {
		c.emitWriteCStringLiteralFd("\n", fd)
	}
	return Value{Name: "", Type: "void"}, nil
}

// emitWriteStringFd writes a %string value (ptr + len) to the given fd.
func (c *funcCtx) emitWriteStringFd(s Value, fd int64) {
	pTmp := c.newTemp()
	lTmp := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 0\n", pTmp, s.Name)
	fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 1\n", lTmp, s.Name)
	c.e.ensureDeclare("declare void @volt_write(i64, ptr, i64)")
	fmt.Fprintf(&c.body, "  call void @volt_write(i64 %d, ptr %s, i64 %s)\n", fd, pTmp, lTmp)
}

// emitWriteCStringLiteralFd interns a literal and writes it to fd.
func (c *funcCtx) emitWriteCStringLiteralFd(s string, fd int64) {
	if s == "" {
		return
	}
	gname, glen := c.e.internString(s)
	c.e.ensureDeclare("declare void @volt_write(i64, ptr, i64)")
	fmt.Fprintf(&c.body, "  call void @volt_write(i64 %d, ptr %s, i64 %d)\n", fd, gname, glen)
}

// emitFormattedArgFd writes one argument according to a format verb,
// targeting the given fd.
func (c *funcCtx) emitFormattedArgFd(argExpr ast.Expr, v Value, verb byte, fd int64) error {
	switch verb {
	case 'd':
		if !isIntLLVM(v.Type) {
			return fmt.Errorf("%s: %%d expects an integer, got %s", argExpr.Pos(), v.Type)
		}
		v = c.convertInt(v, "i64")
		c.e.ensureDeclare("declare void @volt_write_int(i64, i64)")
		fmt.Fprintf(&c.body, "  call void @volt_write_int(i64 %d, i64 %s)\n", fd, v.Name)
	case 's':
		if v.Type != "%string" {
			return fmt.Errorf("%s: %%s expects a string, got %s", argExpr.Pos(), v.Type)
		}
		c.emitWriteStringFd(v, fd)
	case 't':
		if v.Type != "i1" {
			return fmt.Errorf("%s: %%t expects a bool, got %s", argExpr.Pos(), v.Type)
		}
		ext := c.newTemp()
		fmt.Fprintf(&c.body, "  %s = zext i1 %s to i64\n", ext, v.Name)
		c.e.ensureDeclare("declare void @volt_write_bool(i64, i64)")
		fmt.Fprintf(&c.body, "  call void @volt_write_bool(i64 %d, i64 %s)\n", fd, ext)
	case 'v':
		switch {
		case v.Type == "%string":
			c.emitWriteStringFd(v, fd)
		case v.Type == "i1":
			ext := c.newTemp()
			fmt.Fprintf(&c.body, "  %s = zext i1 %s to i64\n", ext, v.Name)
			c.e.ensureDeclare("declare void @volt_write_bool(i64, i64)")
			fmt.Fprintf(&c.body, "  call void @volt_write_bool(i64 %d, i64 %s)\n", fd, ext)
		case isIntLLVM(v.Type):
			v = c.convertInt(v, "i64")
			c.e.ensureDeclare("declare void @volt_write_int(i64, i64)")
			fmt.Fprintf(&c.body, "  call void @volt_write_int(i64 %d, i64 %s)\n", fd, v.Name)
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

// emitErrorsNew lowers errors.New(msg) to an %error_box pointing at a
// heap-allocated string holder + a shared Error() implementation that
// just returns the held string. The result is an opaque `ptr` value
// that the call site stores into an `error`-typed binding.
func (c *funcCtx) emitErrorsNew(call *ast.CallExpr) (Value, error) {
	if len(call.Args) != 1 {
		return Value{}, fmt.Errorf("%s: errors.New takes (msg string)", call.Pos())
	}
	msg, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	if msg.Type != "%string" {
		return Value{}, fmt.Errorf("%s: errors.New requires a string argument, got %s", call.Pos(), msg.Type)
	}
	c.e.ensureErrorsRuntimeHelper()

	c.e.ensureDeclare("declare ptr @volt_alloc(i64)")
	// Heap-allocate a %string holder (16 bytes), store msg into it.
	holder := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call ptr @volt_alloc(i64 16)\n", holder)
	fmt.Fprintf(&c.body, "  store %%string %s, ptr %s\n", msg.Name, holder)
	// Heap-allocate the error_box (16 bytes: data ptr + fn ptr), populate.
	box := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call ptr @volt_alloc(i64 16)\n", box)
	dataP := c.newTemp()
	fnP := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = getelementptr %%error_box, ptr %s, i32 0, i32 0\n", dataP, box)
	fmt.Fprintf(&c.body, "  store ptr %s, ptr %s\n", holder, dataP)
	fmt.Fprintf(&c.body, "  %s = getelementptr %%error_box, ptr %s, i32 0, i32 1\n", fnP, box)
	fmt.Fprintf(&c.body, "  store ptr @volt_errors_strerror, ptr %s\n", fnP)
	return Value{Name: box, Type: "ptr"}, nil
}

// emitSyscallOpen lowers syscall.Open(path string, flags int, mode int) int
// to volt_open(ptr, len, flags, mode). Returns fd on success, -errno on error.
func (c *funcCtx) emitSyscallOpen(call *ast.CallExpr) (Value, error) {
	if len(call.Args) != 3 {
		return Value{}, fmt.Errorf("%s: syscall.Open takes (path string, flags int, mode int)", call.Pos())
	}
	path, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	if path.Type != "%string" {
		return Value{}, fmt.Errorf("%s: syscall.Open: path must be a string, got %s", call.Pos(), path.Type)
	}
	flags, err := c.emitExpr(call.Args[1])
	if err != nil {
		return Value{}, err
	}
	flags = c.convertInt(flags, "i64")
	mode, err := c.emitExpr(call.Args[2])
	if err != nil {
		return Value{}, err
	}
	mode = c.convertInt(mode, "i64")
	pp := c.newTemp()
	pl := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 0\n", pp, path.Name)
	fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 1\n", pl, path.Name)
	c.e.ensureDeclare("declare i64 @volt_open(ptr, i64, i64, i64)")
	r := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call i64 @volt_open(ptr %s, i64 %s, i64 %s, i64 %s)\n",
		r, pp, pl, flags.Name, mode.Name)
	return Value{Name: r, Type: "i64"}, nil
}

// emitSyscallClose lowers syscall.Close(fd int) int → volt_close.
func (c *funcCtx) emitSyscallClose(call *ast.CallExpr) (Value, error) {
	if len(call.Args) != 1 {
		return Value{}, fmt.Errorf("%s: syscall.Close takes (fd int)", call.Pos())
	}
	fd, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	fd = c.convertInt(fd, "i64")
	c.e.ensureDeclare("declare i64 @volt_close(i64)")
	r := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call i64 @volt_close(i64 %s)\n", r, fd.Name)
	return Value{Name: r, Type: "i64"}, nil
}

// emitSyscallReadAll lowers syscall.ReadAll(fd int) string. Reads all
// available bytes from fd; returns empty string on error (ptr=NULL).
// The runtime returns a 16-byte {ptr, i64 len} aggregate that matches
// volt's %string layout directly.
func (c *funcCtx) emitSyscallReadAll(call *ast.CallExpr) (Value, error) {
	if len(call.Args) != 1 {
		return Value{}, fmt.Errorf("%s: syscall.ReadAll takes (fd int)", call.Pos())
	}
	fd, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	fd = c.convertInt(fd, "i64")
	c.e.ensureDeclare("declare %string @volt_read_all(i64)")
	r := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call %%string @volt_read_all(i64 %s)\n", r, fd.Name)
	return Value{Name: r, Type: "%string"}, nil
}

// emitSyscallReadLine lowers syscall.ReadLine(fd int) string. Reads one
// line (up to but not including the trailing newline) from fd via
// volt_read_line. On a terminal a single line is returned when the user
// presses Enter; on a pipe/EOF the remaining bytes (or "") come back.
// Returns a heap %string (auto-freed at scope exit).
func (c *funcCtx) emitSyscallReadLine(call *ast.CallExpr) (Value, error) {
	if len(call.Args) != 1 {
		return Value{}, fmt.Errorf("%s: syscall.ReadLine takes (fd int)", call.Pos())
	}
	fd, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	fd = c.convertInt(fd, "i64")
	c.e.ensureDeclare("declare %string @volt_read_line(i64)")
	r := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call %%string @volt_read_line(i64 %s)\n", r, fd.Name)
	return Value{Name: r, Type: "%string"}, nil
}

// emitSyscallWriteAll lowers syscall.WriteAll(fd int, s string) int →
// volt_write_n. Returns bytes written or -errno.
func (c *funcCtx) emitSyscallWriteAll(call *ast.CallExpr) (Value, error) {
	if len(call.Args) != 2 {
		return Value{}, fmt.Errorf("%s: syscall.WriteAll takes (fd int, s string)", call.Pos())
	}
	fd, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	fd = c.convertInt(fd, "i64")
	s, err := c.emitExpr(call.Args[1])
	if err != nil {
		return Value{}, err
	}
	if s.Type != "%string" {
		return Value{}, fmt.Errorf("%s: syscall.WriteAll: second arg must be string, got %s", call.Pos(), s.Type)
	}
	sp := c.newTemp()
	sl := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 0\n", sp, s.Name)
	fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 1\n", sl, s.Name)
	c.e.ensureDeclare("declare i64 @volt_write_n(i64, ptr, i64)")
	r := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call i64 @volt_write_n(i64 %s, ptr %s, i64 %s)\n", r, fd.Name, sp, sl)
	return Value{Name: r, Type: "i64"}, nil
}

// emitSyscallTcp1 lowers a (i64) -> i64 runtime TCP helper:
// volt_tcp_accept(lfd).
func (c *funcCtx) emitSyscallTcp1(call *ast.CallExpr, helper string) (Value, error) {
	if len(call.Args) != 1 {
		return Value{}, fmt.Errorf("%s: %s takes 1 arg", call.Pos(), helper)
	}
	a, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	a = c.convertInt(a, "i64")
	c.e.ensureDeclare(fmt.Sprintf("declare i64 @%s(i64)", helper))
	r := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call i64 @%s(i64 %s)\n", r, helper, a.Name)
	return Value{Name: r, Type: "i64"}, nil
}

// emitSyscallTcp2 lowers (i64, i64) -> i64 — volt_tcp_dial(ip, port).
func (c *funcCtx) emitSyscallTcp2(call *ast.CallExpr, helper string) (Value, error) {
	if len(call.Args) != 2 {
		return Value{}, fmt.Errorf("%s: %s takes 2 args", call.Pos(), helper)
	}
	a, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	a = c.convertInt(a, "i64")
	b, err := c.emitExpr(call.Args[1])
	if err != nil {
		return Value{}, err
	}
	b = c.convertInt(b, "i64")
	c.e.ensureDeclare(fmt.Sprintf("declare i64 @%s(i64, i64)", helper))
	r := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call i64 @%s(i64 %s, i64 %s)\n", r, helper, a.Name, b.Name)
	return Value{Name: r, Type: "i64"}, nil
}

// emitSyscallTcp3 lowers (i64, i64, i64) -> i64 — volt_tcp_listen(ip, port, backlog).
func (c *funcCtx) emitSyscallTcp3(call *ast.CallExpr, helper string) (Value, error) {
	if len(call.Args) != 3 {
		return Value{}, fmt.Errorf("%s: %s takes 3 args", call.Pos(), helper)
	}
	a, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	a = c.convertInt(a, "i64")
	b, err := c.emitExpr(call.Args[1])
	if err != nil {
		return Value{}, err
	}
	b = c.convertInt(b, "i64")
	cv, err := c.emitExpr(call.Args[2])
	if err != nil {
		return Value{}, err
	}
	cv = c.convertInt(cv, "i64")
	c.e.ensureDeclare(fmt.Sprintf("declare i64 @%s(i64, i64, i64)", helper))
	r := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call i64 @%s(i64 %s, i64 %s, i64 %s)\n",
		r, helper, a.Name, b.Name, cv.Name)
	return Value{Name: r, Type: "i64"}, nil
}

// emitOsArgc lowers os.Argc() to volt_arg_count() → i64.
func (c *funcCtx) emitOsArgc(call *ast.CallExpr) (Value, error) {
	if len(call.Args) != 0 {
		return Value{}, fmt.Errorf("%s: os.Argc takes no arguments", call.Pos())
	}
	c.e.ensureDeclare("declare i64 @volt_arg_count()")
	r := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call i64 @volt_arg_count()\n", r)
	return Value{Name: r, Type: "i64"}, nil
}

// emitOsArgAt lowers os.ArgAt(i) to volt_arg_at(i) → %string.
// Out-of-range indices return the empty string ({NULL, 0}).
func (c *funcCtx) emitOsArgAt(call *ast.CallExpr) (Value, error) {
	if len(call.Args) != 1 {
		return Value{}, fmt.Errorf("%s: os.ArgAt takes (i int)", call.Pos())
	}
	i, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	i = c.convertInt(i, "i64")
	c.e.ensureDeclare("declare %string @volt_arg_at(i64)")
	r := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call %%string @volt_arg_at(i64 %s)\n", r, i.Name)
	return Value{Name: r, Type: "%string"}, nil
}

// emitOsGetenv lowers os.Getenv(name) to volt_env_get(ptr, len) → %string.
// Returns empty string if not found.
func (c *funcCtx) emitOsGetenv(call *ast.CallExpr) (Value, error) {
	if len(call.Args) != 1 {
		return Value{}, fmt.Errorf("%s: os.Getenv takes (name string)", call.Pos())
	}
	name, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	if name.Type != "%string" {
		return Value{}, fmt.Errorf("%s: os.Getenv requires a string, got %s", call.Pos(), name.Type)
	}
	np := c.newTemp()
	nl := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 0\n", np, name.Name)
	fmt.Fprintf(&c.body, "  %s = extractvalue %%string %s, 1\n", nl, name.Name)
	c.e.ensureDeclare("declare %string @volt_env_get(ptr, i64)")
	r := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call %%string @volt_env_get(ptr %s, i64 %s)\n", r, np, nl)
	return Value{Name: r, Type: "%string"}, nil
}

// emitTimeSinceUntil lowers time.Since(t)/Until(t) to a volt_mono_ns
// call plus the matching subtraction. since=true → Mono() - t (elapsed
// nanoseconds since t); since=false → t - Mono() (nanoseconds remaining
// until t). Both take and return i64.
func (c *funcCtx) emitTimeSinceUntil(call *ast.CallExpr, since bool) (Value, error) {
	name := "Since"
	if !since {
		name = "Until"
	}
	if len(call.Args) != 1 {
		return Value{}, fmt.Errorf("%s: time.%s takes exactly 1 argument (an int nanosecond timestamp from time.Mono())", call.Pos(), name)
	}
	t, err := c.emitExpr(call.Args[0])
	if err != nil {
		return Value{}, err
	}
	tWidened := c.convertInt(t, "i64")
	c.e.ensureDeclare("declare i64 @volt_mono_ns()")
	now := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call i64 @volt_mono_ns()\n", now)
	r := c.newTemp()
	if since {
		fmt.Fprintf(&c.body, "  %s = sub i64 %s, %s\n", r, now, tWidened.Name)
	} else {
		fmt.Fprintf(&c.body, "  %s = sub i64 %s, %s\n", r, tWidened.Name, now)
	}
	return Value{Name: r, Type: "i64"}, nil
}

// emitTimeNow lowers time.Now() / time.Mono() to the runtime clock
// helpers. Both return i64 nanoseconds (since Unix epoch for Now,
// since process start for Mono).
func (c *funcCtx) emitTimeNow(call *ast.CallExpr, rtFn string) (Value, error) {
	if len(call.Args) != 0 {
		return Value{}, fmt.Errorf("%s: %s takes no arguments", call.Pos(), rtFn)
	}
	c.e.ensureDeclare(fmt.Sprintf("declare i64 @%s()", rtFn))
	r := c.newTemp()
	fmt.Fprintf(&c.body, "  %s = call i64 @%s()\n", r, rtFn)
	return Value{Name: r, Type: "i64"}, nil
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

// ensureErrorsRuntimeHelper emits the shared Error() implementation
// that errors.New points at: load the held %string from the box's data
// pointer and return it. Emitted once per module.
func (e *Emitter) ensureErrorsRuntimeHelper() {
	if e.errorsStrerrorEmitted {
		return
	}
	e.errorsStrerrorEmitted = true
	e.trampolineDefs.WriteString("define internal %string @volt_errors_strerror(ptr %self) {\n")
	e.trampolineDefs.WriteString("entry:\n")
	e.trampolineDefs.WriteString("  %r = load %string, ptr %self\n")
	e.trampolineDefs.WriteString("  ret %string %r\n")
	e.trampolineDefs.WriteString("}\n\n")
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
