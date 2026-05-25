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
	errs       []string
	funcs      map[string]*ast.FuncDecl
	extPkgs    map[string]map[string]*ast.FuncDecl // pkg → func name → decl
	curResults []ast.Type                          // declared return types of the function being checked
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
		return fmt.Errorf("ownership check failed:\n  %s", strings.Join(c.errs, "\n  "))
	}
	return nil
}

// ---------------------------------------------------------------------
// Per-function analysis
// ---------------------------------------------------------------------

type state struct {
	movable bool
	moved   ast.Node // nil if alive; otherwise the statement that moved it
	isParam bool     // true if this symbol is a function parameter
	used    bool     // any read (including field/index receiver) sets this
	decl    ast.Node // declaration site, for the "declared but not used" diagnostic
	typ     ast.Type // declared type of this symbol (when known)
}

// cloneSyms returns an independent copy of the ownership state.
func cloneSyms(in map[string]*state) map[string]*state {
	out := make(map[string]*state, len(in))
	for k, v := range in {
		nv := *v // copy struct value
		out[k] = &nv
	}
	return out
}

// mergeSyms unions branch states back into `dst`. A variable is considered
// moved post-branches if it was moved in any branch — conservative,
// catches "moved in some path" use-after-move bugs. Used-flag propagates
// the same way: a read in either branch counts as a read.
func mergeSyms(dst, a, b map[string]*state) {
	for k, ds := range dst {
		as, aOK := a[k]
		bs, bOK := b[k]
		if aOK && as.used {
			ds.used = true
		}
		if bOK && bs.used {
			ds.used = true
		}
		if aOK && as.moved != nil {
			ds.moved = as.moved
			continue
		}
		if bOK && bs.moved != nil {
			ds.moved = bs.moved
		}
	}
	// Variables newly declared inside a branch don't escape — drop them.
}

func (c *Checker) checkFunc(fd *ast.FuncDecl) {
	syms := make(map[string]*state)
	for _, p := range fd.Params {
		syms[p.Name] = &state{movable: isMovableType(p.Type), isParam: true, typ: p.Type}
	}
	if fd.Receiver != nil {
		syms[fd.Receiver.Name] = &state{movable: isMovableType(fd.Receiver.Type), isParam: true, typ: fd.Receiver.Type}
	}
	if fd.Body == nil {
		return
	}
	// Stash the function's declared results so RetStmt checks can validate
	// borrow-of-local escapes.
	c.curResults = fd.Results
	defer func() { c.curResults = nil }()
	// checkBlock walks the body and reports any newly-declared
	// unused locals — covers both top-level and branch scopes.
	c.checkBlock(fd.Body, syms)
	// Channel multiplicity contracts (chanOROW / chanORMW / chanMROW /
	// chanMRMW) — counted at the declaring scope by walking endpoints.
	c.checkChanContracts(fd)
}

// reportUnusedSince flags every variable that was declared inside the
// current block (i.e., added to `syms` since `entry` was snapshotted)
// but never read. Mirrors Go's "declared and not used" rule. Skips
// function parameters and `_`-prefixed names.
func (c *Checker) reportUnusedSince(syms map[string]*state, entry map[string]bool) {
	for name, st := range syms {
		if entry[name] {
			continue // existed before the block — not its responsibility
		}
		if st == nil || st.isParam || st.used || st.decl == nil {
			continue
		}
		if strings.HasPrefix(name, "_") {
			continue
		}
		c.errs = append(c.errs, fmt.Sprintf("%s: %q declared but not used", st.decl.Pos(), name))
	}
}

// snapshotNames returns the set of names currently in syms — used to
// distinguish "declared in this block" from "inherited from outside."
func snapshotNames(syms map[string]*state) map[string]bool {
	out := make(map[string]bool, len(syms))
	for name := range syms {
		out[name] = true
	}
	return out
}

// checkBlock walks every statement, then reports any newly-declared
// local that was never read. Works for both top-level function bodies
// and branch bodies (if/else/for/select case) — `entry` distinguishes
// what was already in scope.
func (c *Checker) checkBlock(b *ast.Block, syms map[string]*state) {
	entry := snapshotNames(syms)
	for _, s := range b.Stmts {
		c.checkStmt(s, syms)
	}
	c.reportUnusedSince(syms, entry)
}

func (c *Checker) checkStmt(s ast.Stmt, syms map[string]*state) {
	switch s := s.(type) {
	case *ast.VarStmt:
		c.checkExprUse(s.Value, syms)
		c.maybeMoveBareIdent(s.Value, s, syms)
		syms[s.Name] = &state{movable: isMovableType(s.Type), typ: s.Type, decl: s}
	case *ast.AssignStmt:
		c.checkExprUse(s.RHS, syms)
		c.maybeMoveBareIdent(s.RHS, s, syms)
		// Reject writes through a shared borrow (&T).
		c.checkBorrowWrite(s.LHS, syms)
		// Field/index writes (x.f = ..., m[k] = ...) read x — count as a use.
		switch lhs := s.LHS.(type) {
		case *ast.SelectorExpr:
			c.checkExprUse(lhs.X, syms)
		case *ast.IndexExpr:
			c.checkExprUse(lhs.X, syms)
			c.checkExprUse(lhs.Index, syms)
		}
		if id, ok := s.LHS.(*ast.IdentExpr); ok {
			if st, ok := syms[id.Name]; ok {
				st.moved = nil // reassigned, revived
			}
		}
	case *ast.RetStmt:
		for _, v := range s.Values {
			c.checkExprUse(v, syms)
		}
		// Lifetime check: if the declared return type is a borrow/pointer
		// and the corresponding return expression is a local (non-param)
		// identifier, reject — the borrow would outlive its storage.
		for i, v := range s.Values {
			if i >= len(c.curResults) {
				break
			}
			if !isBorrowOrPointer(c.curResults[i]) {
				continue
			}
			id, ok := v.(*ast.IdentExpr)
			if !ok {
				continue
			}
			st, ok := syms[id.Name]
			if !ok || st.isParam {
				continue // unknown or a parameter — assume OK
			}
			c.errs = append(c.errs, fmt.Sprintf(
				"%s: cannot return read/write access to local %q — it would outlive the value it points at",
				v.Pos(), id.Name))
		}
		// Returning a value can be a move; but our return values are i64
		// for now (no string returns), so not actionable yet.
	case *ast.ExprStmt:
		c.checkExprUse(s.Expr, syms)
		if call, ok := s.Expr.(*ast.CallExpr); ok {
			c.checkCallMoves(call, syms)
		}
	case *ast.IfStmt:
		// Init clause runs once, before Cond. Its bindings are scoped to
		// the entire if/else chain — visible in Cond, Then, and Else
		// (and any else-if Cond). Snapshot pre-init state so we can drop
		// the bindings when leaving the if.
		preInit := snapshotNames(syms)
		if s.Init != nil {
			c.checkStmt(s.Init, syms)
		}
		c.checkExprUse(s.Cond, syms)
		// Branch-join: each branch sees a clone of the post-init state;
		// after the if, a variable is considered moved if it was moved
		// in *any* branch we could have taken (conservative — over-rejects
		// rather than miss bugs).
		thenSyms := cloneSyms(syms)
		if s.Then != nil {
			c.checkBlock(s.Then, thenSyms)
		}
		elseSyms := cloneSyms(syms)
		if s.Else != nil {
			c.checkStmt(s.Else, elseSyms)
		}
		mergeSyms(syms, thenSyms, elseSyms)
		// Init-bound names go out of scope at the end of the if/else.
		if s.Init != nil {
			for name := range syms {
				if !preInit[name] {
					delete(syms, name)
				}
			}
		}
	case *ast.ForStmt:
		// Loop body executes 0+ times. Treat as a branch: clone state,
		// check the body, then merge back. A move inside the loop must
		// taint the post-loop state. (We also run the body once for the
		// "ran at least once" path — that's what the merge captures.)
		if s.RangeOver != nil {
			// Range form: the source is read (marks it used in outer
			// syms), and the bindings enter scope inside the loop.
			c.checkExprUse(s.RangeOver, syms)
		}
		if s.Init != nil {
			c.checkStmt(s.Init, syms)
		}
		c.checkExprUse(s.Cond, syms)
		loopSyms := cloneSyms(syms)
		if s.RangeOver != nil {
			if s.RangeI != "" && s.RangeI != "_" {
				loopSyms[s.RangeI] = &state{movable: false, decl: s}
			}
			if s.RangeV != "" && s.RangeV != "_" {
				loopSyms[s.RangeV] = &state{movable: false, decl: s}
			}
		}
		if s.Body != nil {
			c.checkBlock(s.Body, loopSyms)
		}
		if s.Post != nil {
			c.checkStmt(s.Post, loopSyms)
		}
		// Skip-the-body state = syms; loop state = loopSyms.
		mergeSyms(syms, cloneSyms(syms), loopSyms)
	case *ast.Block:
		c.checkBlock(s, syms)
	case *ast.RunStmt:
		// `run f(args)` — walk args so identifiers count as used and
		// move tracking sees them. Borrow-arg rejection lives in checkRun.
		if s.Call != nil {
			c.checkExprUse(s.Call, syms)
			c.checkRun(s, syms)
		}
	case *ast.SendStmt:
		c.checkExprUse(s.Channel, syms)
		c.checkExprUse(s.Value, syms)
		c.maybeMoveBareIdent(s.Value, s, syms)
	case *ast.SelectStmt:
		for _, cs := range s.Cases {
			if cs == nil {
				continue
			}
			if cs.IsDefault {
				for _, st := range cs.Body {
					c.checkStmt(st, syms)
				}
				continue
			}
			c.checkExprUse(cs.Channel, syms)
			c.checkExprUse(cs.SendValue, syms)
			// recv-bound names enter scope for the case body
			caseSyms := cloneSyms(syms)
			for _, n := range cs.RecvNames {
				caseSyms[n] = &state{movable: false, decl: cs}
			}
			for _, st := range cs.Body {
				c.checkStmt(st, caseSyms)
			}
		}
	case *ast.MultiVarStmt:
		c.checkExprUse(s.RHS, syms)
		for _, n := range s.Names {
			syms[n] = &state{movable: false, decl: s}
		}
	case *ast.MultiAssignStmt:
		c.checkExprUse(s.RHS, syms)
		for _, lhs := range s.LHS {
			switch l := lhs.(type) {
			case *ast.SelectorExpr:
				c.checkExprUse(l.X, syms)
			case *ast.IndexExpr:
				c.checkExprUse(l.X, syms)
				c.checkExprUse(l.Index, syms)
			case *ast.IdentExpr:
				if st, ok := syms[l.Name]; ok {
					st.moved = nil
				}
			}
		}
	case *ast.DeferStmt:
		if s.Call != nil {
			c.checkExprUse(s.Call, syms)
		}
	}
}

// checkRun rejects borrow / pointer arguments to a spawned function.
// Borrows are scope-bound (their lifetime is tied to the storage they
// point at), and the spawned thread outlives the caller's scope, so a
// borrow would dangle. The only safe way to share data with a spawned
// thread is a reference-typed handle (chan / mutex / atomic / etc).
func (c *Checker) checkRun(s *ast.RunStmt, _ map[string]*state) {
	if s.Call == nil {
		return
	}
	id, ok := s.Call.Fun.(*ast.IdentExpr)
	if !ok {
		return
	}
	sig := c.funcs[id.Name]
	if sig == nil {
		return
	}
	for i, arg := range s.Call.Args {
		if i >= len(sig.Params) {
			break
		}
		pt := sig.Params[i].Type
		if !isBorrowOrPointer(pt) {
			continue
		}
		// Borrow-typed param — the bare-name inference rule would
		// materialize a borrow at the call site. Reject explicitly.
		c.errs = append(c.errs, fmt.Sprintf(
			"%s: cannot pass borrow / pointer argument to `run` — borrows can't cross thread boundaries (use a chan / mutex / atomic handle instead)",
			arg.Pos()))
	}
}

// checkExprUse: walks an expression, flagging use of moved variables.
func (c *Checker) checkExprUse(e ast.Expr, syms map[string]*state) {
	if e == nil {
		return
	}
	switch ex := e.(type) {
	case *ast.IdentExpr:
		if st, ok := syms[ex.Name]; ok {
			st.used = true
			if st.moved != nil {
				c.errs = append(c.errs, fmt.Sprintf(
					"%s: use of moved value %q (moved at %s)",
					ex.Pos(), ex.Name, st.moved.Pos()))
			}
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
	case *ast.IndexExpr:
		c.checkExprUse(ex.X, syms)
		c.checkExprUse(ex.Index, syms)
	case *ast.NewExpr:
		for _, a := range ex.SizeArgs {
			c.checkExprUse(a, syms)
		}
		for _, p := range ex.Pairs {
			c.checkExprUse(p.Value, syms)
		}
		for _, m := range ex.MapEntries {
			c.checkExprUse(m.Key, syms)
			c.checkExprUse(m.Value, syms)
		}
		for _, e := range ex.SliceElems {
			c.checkExprUse(e, syms)
		}
	case *ast.FuncLit:
		// Closure literal: walk the body in a child scope so that
		// identifiers it references which resolve to OUR locals
		// (captures) get marked as used in our syms. The literal's
		// own params shadow outer names — we add them to a child syms
		// so refs to them don't hit our outer entries.
		child := cloneSyms(syms)
		for _, p := range ex.Params {
			child[p.Name] = &state{movable: isMovableType(p.Type), isParam: true, typ: p.Type}
		}
		if ex.Body != nil {
			c.checkBlock(ex.Body, child)
		}
		// Propagate "used" marks from child back to syms for names that
		// existed in syms (captures). Don't import new declarations.
		for name, ds := range syms {
			if cs, ok := child[name]; ok && cs.used {
				ds.used = true
			}
		}
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
		case isMovableType(paramType):
			// Field/index access argument: consume(p.a) / consume(s[i]).
			// Mark the root container as moved (conservative).
			if root, ok := rootIdent(arg); ok {
				if st, ok := syms[root]; ok && st.movable && st.moved == nil {
					st.moved = call
				}
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
				"%s: variable %q used with multiple read/write accesses in the same call; at least one asks for write access (*T) — that's not allowed alongside any other access",
				bs[0].node.Pos(), name))
		}
	}
}

// checkBorrowWrite reports an error if `lhs` writes through a shared
// borrow (`&T`). Two shapes are checked:
//
//   x = ...        — direct assignment to a `&T`-typed variable
//   x.field = ...  — field-assign whose receiver is a `&T`-typed variable
//
// A `*T` (unique mutable borrow) is allowed; only `&T` is rejected.
func (c *Checker) checkBorrowWrite(lhs ast.Expr, syms map[string]*state) {
	switch e := lhs.(type) {
	case *ast.IdentExpr:
		st, ok := syms[e.Name]
		if !ok {
			return
		}
		if _, ok := st.typ.(*ast.BorrowType); ok {
			c.errs = append(c.errs, fmt.Sprintf(
				"%s: cannot write to %q — you only have read access (`&T`). Ask for write access (`*T`) to modify.",
				e.Pos(), e.Name))
		}
	case *ast.SelectorExpr:
		recv, ok := e.X.(*ast.IdentExpr)
		if !ok {
			return
		}
		st, ok := syms[recv.Name]
		if !ok {
			return
		}
		if _, ok := st.typ.(*ast.BorrowType); ok {
			c.errs = append(c.errs, fmt.Sprintf(
				"%s: cannot write to field %q through %q — the receiver only has read access (`&T`). Ask for write access (`*T`) to modify.",
				e.Pos(), e.Sel, recv.Name))
		}
	}
}

// maybeMoveBareIdent: for `var x = y`, `x = y`, `var x = p.a`,
// `x = p.a[i]` etc., mark the source (root variable) as moved if it
// is movable. Field/index chains conservatively move the whole root
// container — volt doesn't track partial moves at field granularity
// today, so any structural-field read consumes the parent.
func (c *Checker) maybeMoveBareIdent(rhs ast.Expr, at ast.Node, syms map[string]*state) {
	switch rhs.(type) {
	case *ast.IdentExpr, *ast.SelectorExpr, *ast.IndexExpr:
		if root, ok := rootIdent(rhs); ok {
			if st, ok := syms[root]; ok && st.movable && st.moved == nil {
				st.moved = at
			}
		}
	}
}

// rootIdent walks a chain of selector/index expressions back to the
// leftmost identifier — e.g. `p.a.b` → "p", `arr[i].x` → "arr".
// Returns ok=false if the chain doesn't bottom out in an identifier.
func rootIdent(e ast.Expr) (string, bool) {
	switch x := e.(type) {
	case *ast.IdentExpr:
		return x.Name, true
	case *ast.SelectorExpr:
		return rootIdent(x.X)
	case *ast.IndexExpr:
		return rootIdent(x.X)
	}
	return "", false
}

// ---------------------------------------------------------------------
// Type predicates
// ---------------------------------------------------------------------

// isMovableType reports whether a value of this type is consumed when
// passed by value (or copied into a new variable).
//
// Movable:
//   - string (owns its backing bytes)
//   - any named type other than a Copy primitive (i.e. user-defined struct
//     types — they may own heap memory through their fields)
//   - slice and map (own their backing storage)
//   - anonymous struct types
//
// Not movable:
//   - numeric primitives + bool (Copy semantics)
//   - chan T (reference-typed by design — copying yields another handle)
//   - borrows &T / *T (not owned values)
//   - interface-shaped types `error`, `any` (reference-typed, nilable)
func isMovableType(t ast.Type) bool {
	if t == nil {
		return false
	}
	switch tt := t.(type) {
	case *ast.NamedType:
		return !isCopyPrimitive(tt.Name)
	case *ast.SliceType, *ast.MapType, *ast.StructType:
		return true
	}
	return false
}

// isCopyPrimitive lists the named types that have value-copy semantics.
// Anything else with a name is treated as a (movable) user-defined type.
func isCopyPrimitive(name string) bool {
	switch name {
	case "int", "int8", "int16", "int32", "int64",
		"uint", "uint8", "uint16", "uint32", "uint64",
		"byte", "bool", "float", "float32", "float64",
		"error", "any":
		return true
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
