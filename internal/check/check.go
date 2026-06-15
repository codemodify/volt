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
	// structs indexes every struct type by name (local + external) so
	// the move-tracker can ask "is this field a Copy primitive?" at
	// SelectorExpr reads — that's the difference between `r.idx`
	// (i64 field, no parent move) and `r.hash` (string field, moves).
	structs    map[string]*ast.StructType
	// methods indexes every method (local + external) by its receiver
	// type name → method name. Lets the call-site borrow checker find
	// a method's receiver mutability for `obj.Method()` calls — the
	// cross-package method-borrow check (item 9).
	methods    map[string]map[string]*ast.FuncDecl
	curResults []ast.Type // declared return types of the function being checked
}

func New() *Checker {
	return &Checker{
		funcs:   make(map[string]*ast.FuncDecl),
		extPkgs: make(map[string]map[string]*ast.FuncDecl),
		structs: make(map[string]*ast.StructType),
		methods: make(map[string]map[string]*ast.FuncDecl),
	}
}

// registerMethod indexes a method decl under its receiver type name.
func (c *Checker) registerMethod(d *ast.FuncDecl) {
	recv := d.ReceiverTypeName()
	if recv == "" {
		return
	}
	if c.methods[recv] == nil {
		c.methods[recv] = make(map[string]*ast.FuncDecl)
	}
	// Don't clobber a local method with a same-named external one.
	if _, present := c.methods[recv][d.Name]; !present {
		c.methods[recv][d.Name] = d
	}
}

// AddExternal registers the function signatures of another package so the
// checker can reason about cross-package calls.
func (c *Checker) AddExternal(pkgName string, file *ast.File) {
	if c.extPkgs[pkgName] == nil {
		c.extPkgs[pkgName] = make(map[string]*ast.FuncDecl)
	}
	for _, d := range file.Decls {
		switch dd := d.(type) {
		case *ast.FuncDecl:
			if dd.Receiver != nil {
				// External method: index it so cross-package method-call
				// borrow checks can find its receiver mutability.
				c.registerMethod(dd)
				continue
			}
			c.extPkgs[pkgName][dd.Name] = dd
		case *ast.TypeDecl:
			if st, ok := dd.Type.(*ast.StructType); ok {
				if _, present := c.structs[dd.Name]; !present {
					c.structs[dd.Name] = st
				}
			}
		}
	}
}

// Check runs ownership analysis on the file. Returns a non-nil error
// listing all violations, if any.
func (c *Checker) Check(file *ast.File) error {
	for _, d := range file.Decls {
		switch dd := d.(type) {
		case *ast.FuncDecl:
			if dd.Receiver != nil {
				c.registerMethod(dd)
			} else {
				c.funcs[dd.Name] = dd
			}
		case *ast.TypeDecl:
			if st, ok := dd.Type.(*ast.StructType); ok {
				c.structs[dd.Name] = st
			}
		}
	}
	for _, d := range file.Decls {
		if fd, ok := d.(*ast.FuncDecl); ok {
			c.checkFunc(fd)
		}
	}
	if len(c.errs) > 0 {
		// Diagnostics polish: when there are many errors, prefix a
		// count summary so users see the total before scrolling.
		header := "ownership check failed:"
		if len(c.errs) > 3 {
			header = fmt.Sprintf("ownership check failed (%d errors):", len(c.errs))
		}
		return fmt.Errorf("%s\n  %s", header, strings.Join(c.errs, "\n  "))
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
	heap    bool     // true if value came from `new` — pointer is safe to return
	// C8 phase 3: when a held mutable borrow currently aliases this var,
	// record its declaration site. Nil means "no active mut borrow".
	// Cleared at the borrow var's block-scope end.
	borrowedBy ast.Node
	// C8 phase 4: count of active shared `&T` borrows of this var.
	// Many shared borrows OK; one mut borrow OK alone. The two are
	// mutually exclusive.
	sharedBorrowCount int
	// C8 phase 3: when this symbol IS a held borrow, this records the
	// SOURCE var's name so the source's borrowedBy / sharedBorrowCount
	// can be updated if the borrow var goes out of scope.
	borrowSource string
	// C8 phase 4: true if this symbol is itself a write borrow (`*T`, vs
	// a shared `&T`). Used by checkBlock to know which side of the borrow
	// accounting to decrement at block end.
	borrowIsMut bool
	// C8 phase 6 (cross-statement alias): true if this borrow inherited
	// its source from another borrow variable via `var b2 = b1`. The
	// source's borrowedBy / sharedBorrowCount were NOT bumped by this
	// alias (the original `b1` already owns the slot), so end-of-block
	// must NOT decrement either.
	borrowIsAlias bool
	// C8 phase 7 (disjoint field borrows): per-field borrow accounting on
	// the SOURCE var. `&s.x` and `&s.y` (into `*T`) are allowed simultaneously
	// (distinct fields don't alias); a conflict only arises on the SAME
	// field, or against a whole-`s` borrow. Keyed by field name.
	mutBorrowedFields    map[string]ast.Node
	sharedBorrowedFields map[string]int
	// borrowField records WHICH field-path this borrow var holds on its
	// source ("" = whole var or an index borrow, which stay conservative).
	// Used at end-of-block to release the right per-field slot.
	borrowField string
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
		syms[p.Name] = &state{movable: c.isMovableType(p.Type), isParam: true, typ: p.Type}
	}
	if fd.Receiver != nil {
		syms[fd.Receiver.Name] = &state{movable: c.isMovableType(fd.Receiver.Type), isParam: true, typ: fd.Receiver.Type}
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
	// #7 stage 1: reject provable single-threaded unbuffered-channel
	// deadlocks at compile time (the sound, no-false-reject half of the
	// hybrid model; the runtime all-blocked backstop is stage 2).
	c.checkChanDeadlocks(fd)
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
	// Record end-of-scope move-state on each block-local's declaration, so
	// codegen can precisely suppress its scope-end free (the foundation for
	// safe recursive reclamation — this is the checker's type-aware move
	// state, which knows movable-vs-Copy field extracts). Runs before the
	// borrow-release loop below clears block-local entries.
	for name, st := range syms {
		if entry[name] {
			continue
		}
		if st.moved != nil {
			if vs, ok := st.decl.(*ast.VarStmt); ok {
				vs.MovedAtEnd = true
			}
		}
	}
	c.reportUnusedSince(syms, entry)
	// C8 phase 3 block-scoped borrow release: any held-borrow declared
	// inside this block goes out of scope at `}`. Clear the borrowedBy
	// flag on its source so a subsequent `&source` after the block
	// closes is allowed again. We DON'T delete the borrow's symbol
	// entry — that's `reportUnusedSince`'s job — but the source's
	// borrowedBy needs to be cleared regardless of usage.
	for name, st := range syms {
		if entry[name] {
			continue
		}
		if st.borrowSource == "" {
			continue
		}
		// Aliases (inherited from another borrow var) don't own the
		// source's borrow slot — skip the decrement; the original
		// owner will clear it when ITS scope ends.
		if st.borrowIsAlias {
			delete(syms, name)
			continue
		}
		if src, ok := syms[st.borrowSource]; ok {
			if st.borrowField != "" {
				// C8 phase 7: release the per-field slot, not the whole var.
				if st.borrowIsMut {
					if src.mutBorrowedFields != nil && src.mutBorrowedFields[st.borrowField] == st.decl {
						delete(src.mutBorrowedFields, st.borrowField)
					}
				} else {
					if src.sharedBorrowedFields != nil && src.sharedBorrowedFields[st.borrowField] > 0 {
						src.sharedBorrowedFields[st.borrowField]--
					}
				}
			} else if st.borrowIsMut {
				// Clear the mutable borrow flag if THIS borrow was the
				// active one (defensive against re-assignment).
				if src.borrowedBy == st.decl {
					src.borrowedBy = nil
				}
			} else {
				// Decrement the shared-borrow counter.
				if src.sharedBorrowCount > 0 {
					src.sharedBorrowCount--
				}
			}
		}
		// Also delete the borrow symbol from syms so subsequent
		// shadowing or re-decl in an outer block doesn't see it.
		delete(syms, name)
	}
}

func (c *Checker) checkStmt(s ast.Stmt, syms map[string]*state) {
	switch s := s.(type) {
	case *ast.VarStmt:
		c.checkExprUse(s.Value, syms)
		c.maybeMoveBareIdent(s.Value, s, syms)
		isHeap := false
		if _, ok := s.Value.(*ast.NewExpr); ok {
			isHeap = true
		}
		// A pointer bound from a CALL result is an OWNED value, never a
		// borrow into THIS function's frame: if the callee returned a
		// dangling `&local`, the callee itself would have been rejected by
		// this same check. So returning it later is safe — mark heap so the
		// return-lifetime check doesn't false-positive on e.g.
		// `var st *ExitStatus = c.Start(...); ret …, st`.
		if _, ok := s.Value.(*ast.CallExpr); ok {
			isHeap = true
		}
		// C8 phase 3+4: when the RHS is `&x`, the declared var is a held
		// borrow. The binding type decides which: `&T` is a shared read
		// borrow, `*T` the exclusive write borrow. Apply the alias rules:
		//   - into `&T`: allowed if NO write borrow active (sharedBorrowCount can be > 0)
		//   - into `*T`: allowed only if sharedBorrowCount == 0 AND no write borrow active
		borrowSource := ""
		borrowIsMut := false
		borrowIsAlias := false
		borrowField := "" // C8 phase 7: field-path for `&s.field` (write borrow)
		// C8 phase 6 (cross-statement borrow alias): when the RHS is a
		// plain identifier that names ANOTHER borrow variable, propagate
		// the source-tracking metadata so end-of-block cleanup still
		// fires correctly. We mark the alias to avoid double-counting
		// the source's borrow slot.
		if id, ok := s.Value.(*ast.IdentExpr); ok {
			if src, ok := syms[id.Name]; ok && src.borrowSource != "" {
				borrowSource = src.borrowSource
				borrowIsMut = src.borrowIsMut
				borrowIsAlias = true
			}
		}
		// C8 reborrow: `var b2 *T = &*b1` / `var b2 &T = &*b1`. Taking the
		// address of a deref of an existing borrow produces a new borrow
		// that shares b1's underlying storage. Rules:
		//   - a `*T` (write) reborrow requires b1 to be a write borrow
		//     (can't get exclusive access through a shared borrow).
		//   - `&*b1` is always allowed (a shared reborrow; downgrade OK).
		// The reborrow inherits b1's ultimate source and is marked as an
		// alias so end-of-block cleanup doesn't double-count the source's
		// borrow slot.
		if un, ok := s.Value.(*ast.UnaryExpr); ok && un.Op == "&" {
			if deref, ok := un.X.(*ast.UnaryExpr); ok && deref.Op == "*" {
				wantMut := isPointerType(s.Type)
				if bid, ok := deref.X.(*ast.IdentExpr); ok {
					if bsym, ok := syms[bid.Name]; ok && bsym.borrowSource != "" {
						if wantMut && !bsym.borrowIsMut {
							c.errs = append(c.errs, fmt.Sprintf(
								"%s: cannot reborrow `*%s` as a write borrow — %q is a shared borrow (`&T`); exclusive access can't be obtained through it",
								s.Pos(), bid.Name, bid.Name))
						}
						borrowSource = bsym.borrowSource
						borrowIsMut = wantMut
						borrowIsAlias = true
					}
				}
				syms[s.Name] = &state{
					movable:       c.isMovableType(s.Type),
					typ:           s.Type,
					decl:          s,
					heap:          isHeap,
					borrowSource:  borrowSource,
					borrowIsMut:   borrowIsMut,
					borrowIsAlias: borrowIsAlias,
				}
				return
			}
		}
		if un, ok := s.Value.(*ast.UnaryExpr); ok && un.Op == "&" {
			isMut := isPointerType(s.Type)
			// Source can be a bare ident (`&x`), a DIRECT struct-field
			// partial borrow (`&s.field` — tracked per field so
			// disjoint fields can be borrowed at once), or another partial
			// shape (`&a[i]`, nested `s.a.b`) which stays conservative
			// (ties to the whole root container).
			srcName := ""
			fieldPath := "" // non-empty only for `&s.field` (direct field)
			if id, ok := un.X.(*ast.IdentExpr); ok {
				srcName = id.Name
			} else if sel, ok := un.X.(*ast.SelectorExpr); ok {
				if rid, ok := sel.X.(*ast.IdentExpr); ok {
					srcName = rid.Name
					fieldPath = sel.Sel // direct field → disjoint-eligible
				} else if root, ok := rootIdent(un.X); ok {
					srcName = root // nested chain → conservative whole-var
				}
			} else if _, ok := un.X.(*ast.IndexExpr); ok {
				if root, ok := rootIdent(un.X); ok {
					srcName = root // index → conservative whole-var
				}
			}
			if srcName != "" {
				if src, ok := syms[srcName]; ok {
					if fieldPath != "" {
						// Disjoint field borrow path.
						if src.mutBorrowedFields == nil {
							src.mutBorrowedFields = map[string]ast.Node{}
							src.sharedBorrowedFields = map[string]int{}
						}
						conflict := ""
						if src.borrowedBy != nil {
							conflict = fmt.Sprintf("the whole of %q is mutably borrowed (first at %s)", srcName, src.borrowedBy.Pos())
						} else if src.sharedBorrowCount > 0 {
							conflict = fmt.Sprintf("the whole of %q has %d shared borrow(s) active", srcName, src.sharedBorrowCount)
						} else if prev := src.mutBorrowedFields[fieldPath]; prev != nil {
							conflict = fmt.Sprintf("field %q is already mutably borrowed (first at %s)", srcName+"."+fieldPath, prev.Pos())
						} else if isMut && src.sharedBorrowedFields[fieldPath] > 0 {
							conflict = fmt.Sprintf("field %q has a shared borrow active", srcName+"."+fieldPath)
						} else if !isMut && src.mutBorrowedFields[fieldPath] != nil {
							conflict = fmt.Sprintf("field %q is mutably borrowed", srcName+"."+fieldPath)
						}
						if conflict != "" {
							c.errs = append(c.errs, fmt.Sprintf(
								"%s: cannot take `&%s.%s` — %s",
								s.Pos(), srcName, fieldPath, conflict))
						} else {
							if isMut {
								src.mutBorrowedFields[fieldPath] = s
							} else {
								src.sharedBorrowedFields[fieldPath]++
							}
							borrowSource = srcName
							borrowIsMut = isMut
							borrowField = fieldPath
						}
					} else if isMut {
						// Whole-var mutable borrow: conflicts with ANY
						// existing borrow, including individual field borrows.
						if src.borrowedBy != nil {
							c.errs = append(c.errs, fmt.Sprintf(
								"%s: cannot take `&%s` as a write borrow — another write borrow is still active (first at %s)",
								s.Pos(), srcName, src.borrowedBy.Pos()))
						} else if src.sharedBorrowCount > 0 {
							c.errs = append(c.errs, fmt.Sprintf(
								"%s: cannot take `&%s` as a write borrow — %d shared borrow(s) are still active (write + shared borrows are mutually exclusive)",
								s.Pos(), srcName, src.sharedBorrowCount))
						} else if n := len(src.mutBorrowedFields) + nonzeroCount(src.sharedBorrowedFields); n > 0 {
							c.errs = append(c.errs, fmt.Sprintf(
								"%s: cannot take `&%s` as a write borrow — %d of its field(s) are still borrowed",
								s.Pos(), srcName, n))
						} else {
							src.borrowedBy = s
							borrowSource = srcName
							borrowIsMut = true
						}
					} else {
						// Whole-var shared borrow.
						if src.borrowedBy != nil {
							c.errs = append(c.errs, fmt.Sprintf(
								"%s: cannot take `&%s` — a write borrow (`*T`) is still active (first at %s); shared and write borrows are mutually exclusive",
								s.Pos(), srcName, src.borrowedBy.Pos()))
						} else if len(src.mutBorrowedFields) > 0 {
							c.errs = append(c.errs, fmt.Sprintf(
								"%s: cannot take `&%s` — %d of its field(s) are mutably borrowed",
								s.Pos(), srcName, len(src.mutBorrowedFields)))
						} else {
							src.sharedBorrowCount++
							borrowSource = srcName
							borrowIsMut = false
						}
					}
				}
			}
		}
		syms[s.Name] = &state{
			movable:       c.isMovableType(s.Type),
			typ:           s.Type,
			decl:          s,
			heap:          isHeap,
			borrowSource:  borrowSource,
			borrowIsMut:   borrowIsMut,
			borrowIsAlias: borrowIsAlias,
			borrowField:   borrowField,
		}
	case *ast.AssignStmt:
		// LHS reads happen BEFORE the RHS evaluation's side effects
		// (the most common case is `hashes[r.idx] = r.hash`: r.idx is
		// a Copy read that shouldn't be blocked by the r.hash move
		// that the RHS triggers). Reject writes through a shared
		// borrow (&T) first; that check inspects the LHS shape.
		c.checkBorrowWrite(s.LHS, syms)
		switch lhs := s.LHS.(type) {
		case *ast.SelectorExpr:
			c.checkExprUse(lhs.X, syms)
		case *ast.IndexExpr:
			c.checkExprUse(lhs.X, syms)
			c.checkExprUse(lhs.Index, syms)
		case *ast.UnaryExpr:
			// C8: `*p = v` — the borrow `p` is being USED to direct the
			// store, so count it. Without this the unused-var check
			// flags `p` even though it's clearly load-bearing.
			c.checkExprUse(lhs.X, syms)
		}
		c.checkExprUse(s.RHS, syms)
		c.maybeMoveBareIdent(s.RHS, s, syms)
		// move-on-insert: `s = append(s, v)` consumes the element values.
		// Scoped to append — general by-value consumption of an assignment-
		// RHS call arg is intentionally NOT done, so a string passed to a
		// read-only stdlib call (`n = strings.Count(s, sub)`) stays reusable
		// (strings are immutable: passing one shares, it doesn't hand over).
		if call, ok := s.RHS.(*ast.CallExpr); ok {
			c.moveOnInsert(call, syms)
		}
		if id, ok := s.LHS.(*ast.IdentExpr); ok {
			if st, ok := syms[id.Name]; ok {
				// Reassigning `x` gives it a fresh value, so it's valid again
				// even if the RHS just consumed it — the `s = f(s)` /
				// `s = append(s, …)` transform-and-reassign idiom. (Any
				// use-after-move WITHIN the RHS was already caught above.)
				st.moved = nil
				// C8 phase 5: reject `x = v` when x has an active
				// borrow. Mutating the borrow source while a borrow is
				// held would invalidate the borrow's view (or, with
				// a `*T` write borrow, alias the unique reference). Strict
				// rule: source becomes effectively frozen for the
				// borrow's lifetime.
				if st.borrowedBy != nil {
					c.errs = append(c.errs, fmt.Sprintf(
						"%s: cannot mutate %q — a write borrow (`*T`) is still active (first at %s); the source is frozen until the borrow ends",
						s.Pos(), id.Name, st.borrowedBy.Pos()))
				} else if st.sharedBorrowCount > 0 {
					c.errs = append(c.errs, fmt.Sprintf(
						"%s: cannot mutate %q — %d shared `&` borrow(s) are still active; the source is read-only until they end",
						s.Pos(), id.Name, st.sharedBorrowCount))
				}
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
			// `ret &x` / `ret &s.field` / `ret &a[i]` — returning the address
			// of anything in THIS frame escapes a borrow; always rejected (a
			// value you keep comes from `new`, never from `&`).
			if un, ok := v.(*ast.UnaryExpr); ok && un.Op == "&" {
				c.errs = append(c.errs, fmt.Sprintf(
					"%s: cannot return a borrow (`&…`) — it points into this call and would dangle; return a value (move) or a copy (`.Clone()`)",
					v.Pos()))
				continue
			}
			id, ok := v.(*ast.IdentExpr)
			if !ok {
				continue
			}
			st, ok := syms[id.Name]
			if !ok {
				continue // unknown — assume OK
			}
			if st.heap {
				continue // came from `new`/a call — an owned value, safe to return
			}
			// A borrow (peek/loan) may not leave the call that holds it
			// ("values own, borrows visit"). This includes a borrow PARAMETER:
			// the caller's value might die before the returned borrow is used,
			// so the safe, lifetime-free rule is simply "borrows don't escape".
			who := "local"
			if st.isParam {
				who = "borrowed parameter"
			}
			c.errs = append(c.errs, fmt.Sprintf(
				"%s: cannot return %s %q — a borrow (`&T`/`*T`) can't outlive its call; return a value, or a copy (`.Clone()`)",
				v.Pos(), who, id.Name))
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
	case *ast.SwitchStmt:
		// A switch is an if/else chain over Tag: the tag is evaluated
		// once, then exactly one case body (or default) runs. Mirror the
		// IfStmt branch-join — every case sees a clone of the pre-switch
		// state, and a variable is considered moved after the switch if
		// it was moved in *any* case (conservative). Walking the bodies
		// is also what makes a use inside a case count toward both move
		// tracking and the "declared but not used" diagnostic; before
		// this case existed, switch statements were skipped entirely.
		if s.Tag != nil {
			c.checkExprUse(s.Tag, syms)
		}
		acc := cloneSyms(syms) // the implicit "no case matched" path
		for _, cc := range s.Cases {
			if cc == nil {
				continue
			}
			// Case match expressions are evaluated in the outer scope.
			for _, v := range cc.Vals {
				c.checkExprUse(v, syms)
			}
			caseSyms := cloneSyms(syms)
			for _, st := range cc.Stmts {
				c.checkStmt(st, caseSyms)
			}
			mergeSyms(acc, acc, caseSyms)
		}
		mergeSyms(syms, syms, acc)
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
		// If the RHS is a function call returning pointer/borrow values,
		// trust the callee to give us heap-backed pointers (we can't see
		// inside it from here). Mark the corresponding LHS slots as
		// heap-safe so `ret v` after this assignment isn't rejected.
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
					if isBorrowOrPointer(st.typ) {
						st.heap = true
					}
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
			child[p.Name] = &state{movable: c.isMovableType(p.Type), isParam: true, typ: p.Type}
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
// moveOnInsert handles `append(s, v…)`: each ELEMENT value (args after the
// slice at index 0) is handed INTO the slice, so a movable element passed by
// value is consumed — using it after it lives in the slice would alias the
// slice's storage. Only bare movable idents are consumed; a Copy element
// (int/bool/…) duplicates, and a field/index element stays conservative.
// No-op for any call that isn't `append`.
func (c *Checker) moveOnInsert(call *ast.CallExpr, syms map[string]*state) {
	id, ok := call.Fun.(*ast.IdentExpr)
	if !ok || id.Name != "append" {
		return
	}
	for i := 1; i < len(call.Args); i++ {
		if a, ok := call.Args[i].(*ast.IdentExpr); ok {
			if st, ok := syms[a.Name]; ok && st.movable && st.moved == nil {
				st.moved = call
			}
		}
	}
}

func (c *Checker) checkCallMoves(call *ast.CallExpr, syms map[string]*state) {
	switch fn := call.Fun.(type) {
	case *ast.IdentExpr:
		if fn.Name == "append" {
			c.moveOnInsert(call, syms)
			return
		}
		if sig := c.funcs[fn.Name]; sig != nil {
			c.checkCallArgs(call, sig, syms, true)
		}
	case *ast.SelectorExpr:
		if pkgId, ok := fn.X.(*ast.IdentExpr); ok {
			// Distinguish `pkg.Func(...)` (X names an imported package)
			// from `obj.Method(...)` (X names a local variable). A
			// variable takes precedence: if the receiver is in syms it's
			// a method call, so run the receiver-borrow check.
			if recv, ok := syms[pkgId.Name]; ok {
				c.checkMethodReceiverBorrow(call, fn, pkgId.Name, recv)
				// Item 4: also borrow-check the method's PARAMETERS. A
				// method's receiver lives in m.Receiver (not Params), and
				// call.Args are the explicit args, so Params[i] aligns
				// with Args[i]. Pass trackMoves=false: a method call must
				// NOT move-mark a field/index arg's root container (e.g.
				// `buf.WriteString(rec[i].Name)` does not consume `rec`).
				if m := c.lookupMethod(recv.typ, fn.Sel); m != nil {
					c.checkCallArgs(call, m, syms, false)
				}
			} else if pkg, ok := c.extPkgs[pkgId.Name]; ok {
				if sig := pkg[fn.Sel]; sig != nil {
					c.checkCallArgs(call, sig, syms, true)
				}
			}
		}
	}
}

// checkCallArgs runs the per-argument ownership checks for a call whose
// callee signature is `sig`. When trackMoves is true, movable-typed
// by-value args mark their source (or root container) as moved; methods
// pass false since a method argument doesn't transfer ownership of the
// caller's aggregate. The `&` borrow-lifetime check and the
// intra-call aliasing-XOR-mutation check run regardless.
func (c *Checker) checkCallArgs(call *ast.CallExpr, sig *ast.FuncDecl, syms map[string]*state, trackMoves bool) {
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

		// C8 phase 4+5: cross-function borrow tracking. When the arg is
		// `&x` (UnaryExpr), check the source's existing borrow state —
		// passing a write borrow into a function that already has a
		// borrow elsewhere conflicts the same as `var b *T = &x` would.
		// The borrow is "live for the duration of the call" so any
		// pre-existing borrow on the source rejects the call.
		if un, ok := arg.(*ast.UnaryExpr); ok && un.Op == "&" {
			isMut := isPointerType(paramType)
			if srcId, ok := un.X.(*ast.IdentExpr); ok {
				if src, ok := syms[srcId.Name]; ok {
					if isMut {
						if src.borrowedBy != nil {
							c.errs = append(c.errs, fmt.Sprintf(
								"%s: cannot pass `&%s` as a write borrow to %s — another write borrow is still active (first at %s)",
								arg.Pos(), srcId.Name, fnLabel(call.Fun), src.borrowedBy.Pos()))
						} else if src.sharedBorrowCount > 0 {
							c.errs = append(c.errs, fmt.Sprintf(
								"%s: cannot pass `&%s` as a write borrow to %s — %d shared borrow(s) are still active",
								arg.Pos(), srcId.Name, fnLabel(call.Fun), src.sharedBorrowCount))
						}
					} else {
						if src.borrowedBy != nil {
							c.errs = append(c.errs, fmt.Sprintf(
								"%s: cannot pass `&%s` to %s — a write borrow (`*T`) is still active (first at %s)",
								arg.Pos(), srcId.Name, fnLabel(call.Fun), src.borrowedBy.Pos()))
						}
					}
				}
				// Record for intra-call alias check (the loop body below).
				borrows[srcId.Name] = append(borrows[srcId.Name], borrowInfo{mutable: isMut, node: arg})
			}
			continue
		}

		switch {
		case isBorrowType(paramType):
			// `&T` params are always shared, read-only borrows.
			if isIdent {
				borrows[argId.Name] = append(borrows[argId.Name], borrowInfo{mutable: false, node: arg})
			}
		case isPointerType(paramType):
			if isIdent {
				borrows[argId.Name] = append(borrows[argId.Name], borrowInfo{mutable: true, node: arg})
			}
		case c.isMovableType(paramType) && isIdent:
			if trackMoves {
				if st, ok := syms[argId.Name]; ok && st.movable && st.moved == nil {
					st.moved = call
				}
			}
		case c.isMovableType(paramType):
			// Field/index access argument: consume(p.a) / consume(s[i]).
			// Mark the root container as moved (conservative). Methods
			// skip this — a method arg doesn't consume the caller's
			// aggregate. EXCEPTION: a field read THROUGH A POINTER
			// (`ptr.field` or `sliceOfPtrs[i].field`) only borrows the
			// field — the container owns pointers, not the pointed-to
			// values, so the read doesn't consume it. (codegen's
			// extractvalue copies the field header; it isn't freed here.)
			if trackMoves && !c.argReadsThroughPointer(arg, syms) {
				if root, ok := rootIdent(arg); ok {
					if st, ok := syms[root]; ok && st.movable && st.moved == nil {
						st.moved = call
					}
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

// checkMethodReceiverBorrow validates `obj.Method(...)` against obj's
// active-borrow state. Calling a method borrows the receiver for the
// call's duration — the same lifetime rule as passing `&obj` to a free
// function. Works for both local and cross-package methods (item 9: the
// method registry is populated from AddExternal).
//
// Rules, given obj's declared type T and the method's receiver:
//   - write receiver (`*T`): reject if ANY borrow of obj is active
//     (a held write borrow or one-or-more shared `&`).
//   - shared receiver (`&T`): reject only if a write borrow is active.
// A receiver-less value type (`T`, by-copy) borrows nothing → no check.
// lookupMethod resolves method `name` on the type of `recvType`
// (a NamedType or pointer/borrow to one). Returns nil if unknown.
func (c *Checker) lookupMethod(recvType ast.Type, name string) *ast.FuncDecl {
	typeName := namedTypeName(recvType)
	if typeName == "" {
		return nil
	}
	mset, ok := c.methods[typeName]
	if !ok {
		return nil
	}
	return mset[name]
}

func (c *Checker) checkMethodReceiverBorrow(call *ast.CallExpr, sel *ast.SelectorExpr, recvName string, recv *state) {
	m := c.lookupMethod(recv.typ, sel.Sel)
	if m == nil || m.Receiver == nil {
		return
	}
	mutating := false
	shared := false
	switch m.Receiver.Type.(type) {
	case *ast.PointerType:
		mutating = true
	case *ast.BorrowType:
		shared = true
	default:
		// Value receiver (`fun (r T)`) — by-copy, borrows nothing.
		return
	}
	if mutating {
		if recv.borrowedBy != nil {
			c.errs = append(c.errs, fmt.Sprintf(
				"%s: cannot call %s.%s — it needs write access to %q but a write borrow (`*T`) is still active (first at %s)",
				call.Pos(), recvName, sel.Sel, recvName, recv.borrowedBy.Pos()))
		} else if recv.sharedBorrowCount > 0 {
			c.errs = append(c.errs, fmt.Sprintf(
				"%s: cannot call %s.%s — it needs write access to %q but %d shared borrow(s) are still active",
				call.Pos(), recvName, sel.Sel, recvName, recv.sharedBorrowCount))
		}
	} else if shared {
		if recv.borrowedBy != nil {
			c.errs = append(c.errs, fmt.Sprintf(
				"%s: cannot call %s.%s — a write borrow (`*T`) of %q is still active (first at %s); shared and write access are mutually exclusive",
				call.Pos(), recvName, sel.Sel, recvName, recv.borrowedBy.Pos()))
		}
	}
}

// namedTypeName extracts the bare type name from a NamedType or a
// pointer/borrow to one (`T`, `*T`, `&T` → "T"). Empty otherwise.
// nonzeroCount returns how many entries in `m` have a value > 0.
// Used to count active per-field shared borrows.
func nonzeroCount(m map[string]int) int {
	n := 0
	for _, v := range m {
		if v > 0 {
			n++
		}
	}
	return n
}

func namedTypeName(t ast.Type) string {
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
				"%s: cannot write to %q — you only have shared read access (`&T`). Declare it as `*T` to mutate.",
				e.Pos(), e.Name))
		}
	case *ast.UnaryExpr:
		// `*p = v` — write through a held borrow. Allowed only if p is
		// `*T` (the write borrow). Shared `&T` rejected.
		if e.Op != "*" {
			return
		}
		id, ok := e.X.(*ast.IdentExpr)
		if !ok {
			return
		}
		st, ok := syms[id.Name]
		if !ok {
			return
		}
		if _, ok := st.typ.(*ast.BorrowType); ok {
			c.errs = append(c.errs, fmt.Sprintf(
				"%s: cannot write through `*%s` — %q is a shared borrow (`&T`). Declare it as `*T` to allow writes.",
				e.Pos(), id.Name, id.Name))
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
//
// Exception: indexing a string returns a `byte` (a Copy primitive),
// so `var c byte = s[i]` doesn't actually consume any string bytes —
// don't move s. This matters for any code that does byte-by-byte
// scanning + binding to a local (JSON decoder, parsers, etc.).
func (c *Checker) maybeMoveBareIdent(rhs ast.Expr, at ast.Node, syms map[string]*state) {
	switch r := rhs.(type) {
	case *ast.IndexExpr:
		// Reading `s[i]` from a string or slice yields the element
		// value WITHOUT consuming the container's header:
		//   - `string[i]` → byte (Copy)
		//   - `[]T[i]` → T (Copy or Movable — but the slice handle
		//     is unchanged; the local binding gets its own copy of
		//     the element header. Volt doesn't track element-level
		//     moves, so this is conservative-safe.)
		//   - `map[K]V[i]` → V; if V is a Copy primitive (int, bool,
		//     byte, ...) the read returns by-value and doesn't
		//     disturb the map. Movable-V map reads still move the
		//     map handle conservatively (the read could expose a
		//     movable value the caller mutates outside the map's
		//     view).
		if root, ok := rootIdent(rhs); ok {
			if st, ok := syms[root]; ok && st.movable && st.moved == nil {
				if isPureIndex(r) {
					if isStringType(st.typ) || isSliceType(st.typ) {
						return
					}
					if isMapWithCopyValue(st.typ) {
						return
					}
				}
				// `s.field[k]` where field is a map-with-Copy-value or a
				// slice-of-Copy-element — the read copies a scalar out and
				// doesn't consume the struct (`v := st.m["k"]`, `st.xs[i]`).
				if c.indexedFieldYieldsCopy(r, st.typ) {
					return
				}
				st.moved = at
			}
		}
	case *ast.SelectorExpr:
		// Field read `r.field`: if r is a struct and the field's type
		// is a Copy primitive (int, bool, byte, ...), the read copies
		// the value out without disturbing r. The full `r.movable`
		// case still moves to preserve the existing semantics (the
		// movable field's storage is logically gone after the read).
		if root, ok := rootIdent(rhs); ok {
			if st, ok := syms[root]; ok && st.movable && st.moved == nil {
				if c.fieldIsCopy(st.typ, r) {
					return
				}
				// `slice[i].copyField` — reading a Copy scalar out of a
				// value-element slice copies it without consuming the slice
				// (the linked-list-via-ids walk: `cur = nodes[cur].next`).
				if c.sliceElemFieldIsCopy(st.typ, r) {
					return
				}
				st.moved = at
			}
		}
	case *ast.IdentExpr:
		if root, ok := rootIdent(rhs); ok {
			if st, ok := syms[root]; ok && st.movable && st.moved == nil {
				st.moved = at
			}
		}
	}
}

// argReadsThroughPointer reports whether a call argument is a field read
// whose receiver is reached via a pointer indirection — `ptr.field` or
// `sliceOfPtrs[i].field`. Reading a field through a pointer BORROWS that
// field; it doesn't consume the container (which owns the pointers, not the
// pointed-to values), so the root must not be marked moved. Without this,
// e.g. `print(hits[k].name)` would spuriously consume the whole `hits`
// slice on the first read.
func (c *Checker) argReadsThroughPointer(arg ast.Expr, syms map[string]*state) bool {
	sel, ok := arg.(*ast.SelectorExpr)
	if !ok {
		return false
	}
	switch x := sel.X.(type) {
	case *ast.IdentExpr:
		// `ptr.field` — ptr is a `*T` variable.
		if st, ok := syms[x.Name]; ok {
			return isPointerType(st.typ)
		}
	case *ast.IndexExpr:
		// `sliceOfPtrs[i].field` — the slice element type is `*T`.
		if root, ok := rootIdent(x.X); ok {
			if st, ok := syms[root]; ok {
				if sl, ok := st.typ.(*ast.SliceType); ok {
					return isPointerType(sl.Elem)
				}
			}
		}
	}
	return false
}

// fieldIsCopy returns true iff the SelectorExpr reads a field of a
// known struct type and that field is declared as a Copy primitive.
// Multi-step selectors (`r.f1.f2`) are treated conservatively
// (returns false) — the move tracker doesn't yet understand
// transitive field reads.
func (c *Checker) fieldIsCopy(rootType ast.Type, sel *ast.SelectorExpr) bool {
	if rootType == nil {
		return false
	}
	// Only handle the shape `<ident>.<field>` — multi-step or pointer
	// receivers (`(*r).field`) skip the optimization.
	if _, ok := sel.X.(*ast.IdentExpr); !ok {
		return false
	}
	typeName := bareStructName(rootType)
	if typeName == "" {
		return false
	}
	st, ok := c.structs[typeName]
	if !ok {
		return false
	}
	for _, f := range st.Fields {
		if f.Name != sel.Sel {
			continue
		}
		nt, ok := f.Type.(*ast.NamedType)
		return ok && isCopyPrimitive(nt.Name)
	}
	return false
}

// sliceElemFieldIsCopy reports whether `sel` is `s[i].field` where `s` is a
// slice of VALUE structs (`[]T`, not `[]*T`) and `field` is a Copy primitive.
// Reading such a field copies a scalar out and consumes nothing, so the slice
// root must not be marked moved. rootType is the slice's declared type.
func (c *Checker) sliceElemFieldIsCopy(rootType ast.Type, sel *ast.SelectorExpr) bool {
	if _, ok := sel.X.(*ast.IndexExpr); !ok {
		return false
	}
	slt, ok := rootType.(*ast.SliceType)
	if !ok {
		return false
	}
	nt, ok := slt.Elem.(*ast.NamedType)
	if !ok {
		return false
	}
	st, ok := c.structs[nt.Name]
	if !ok {
		return false
	}
	for _, f := range st.Fields {
		if f.Name == sel.Sel {
			ft, ok := f.Type.(*ast.NamedType)
			return ok && isCopyPrimitive(ft.Name)
		}
	}
	return false
}

// indexedFieldYieldsCopy reports whether `idx` is `root.field[k]` where the
// struct field is a map with a Copy-primitive VALUE or a slice with a Copy
// ELEMENT — reading it copies a scalar out and consumes nothing, so the root
// struct must not be marked moved. rootType is the root ident's type; only the
// direct `root.field[k]` shape is handled (nested chains stay conservative).
func (c *Checker) indexedFieldYieldsCopy(idx *ast.IndexExpr, rootType ast.Type) bool {
	sel, ok := idx.X.(*ast.SelectorExpr)
	if !ok {
		return false
	}
	if _, ok := sel.X.(*ast.IdentExpr); !ok {
		return false
	}
	structName := bareStructName(rootType)
	if structName == "" {
		return false
	}
	st, ok := c.structs[structName]
	if !ok {
		return false
	}
	for _, f := range st.Fields {
		if f.Name != sel.Sel {
			continue
		}
		switch ft := f.Type.(type) {
		case *ast.MapType:
			nt, ok := ft.Value.(*ast.NamedType)
			return ok && isCopyPrimitive(nt.Name)
		case *ast.SliceType:
			nt, ok := ft.Elem.(*ast.NamedType)
			return ok && isCopyPrimitive(nt.Name)
		}
		return false
	}
	return false
}

// bareStructName extracts the underlying named type from a borrow or
// pointer wrapper. `Counter` / `&Counter` / `*Counter` → "Counter".
func bareStructName(t ast.Type) string {
	switch t := t.(type) {
	case *ast.NamedType:
		return t.Name
	case *ast.BorrowType:
		return bareStructName(t.Elem)
	case *ast.PointerType:
		return bareStructName(t.Elem)
	}
	return ""
}

// isPureIndex reports whether e is exactly `ident[expr]` — a single
// index step on a bare identifier (no further selector/index chain
// above it). That's the shape `s[i]` takes; `s.field[i]` and
// `mat[i][j]` don't qualify (they could touch wider state).
func isPureIndex(e *ast.IndexExpr) bool {
	_, ok := e.X.(*ast.IdentExpr)
	return ok
}

// isStringType reports whether t is the named `string` type.
func isStringType(t ast.Type) bool {
	nt, ok := t.(*ast.NamedType)
	return ok && nt.Name == "string"
}

// isMapWithCopyValue reports whether t is a `map[K]V` where V is a
// Copy primitive (int, bool, byte, etc.). Reading such a map yields
// a by-value copy, so it doesn't move the map handle.
func isMapWithCopyValue(t ast.Type) bool {
	mt, ok := t.(*ast.MapType)
	if !ok {
		return false
	}
	nt, ok := mt.Value.(*ast.NamedType)
	if !ok {
		return false
	}
	return isCopyPrimitive(nt.Name)
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
// isMovableType reports whether a value of type t has MOVE semantics
// (passing it by value transfers ownership). Movable: string, slices,
// maps, and named structs that own a movable field. NOT movable (Copy):
// the primitives in isCopyPrimitive AND — new in this pass — a struct
// ALL of whose fields are themselves Copy. Such a struct owns no heap
// backing, so copying it bit-for-bit is sound and reuse-after-pass is
// safe; the old blanket "every named struct moves" was false
// conservatism (it forced value-like structs such as Style/Rect to be
// single-use after being handed to a function). Consulting c.structs
// makes this a method.
func (c *Checker) isMovableType(t ast.Type) bool {
	if t == nil {
		return false
	}
	switch tt := t.(type) {
	case *ast.NamedType:
		if isCopyPrimitive(tt.Name) {
			return false
		}
		// A struct whose fields are all Copy is itself Copy.
		if c.structIsCopy(tt.Name, map[string]bool{}) {
			return false
		}
		return true
	case *ast.SliceType, *ast.MapType, *ast.StructType:
		return true
	}
	return false
}

// structIsCopy reports whether typeName is a known struct whose fields
// are ALL Copy (recursively). Unknown names / non-struct types are not
// Copy. Recursive-by-value structs are rejected upstream, so the visited
// set is only a guard against pathological input.
func (c *Checker) structIsCopy(typeName string, visited map[string]bool) bool {
	if visited[typeName] {
		return true
	}
	st, ok := c.structs[typeName]
	if !ok {
		return false
	}
	// Copy and Drop are mutually exclusive (as in Rust): a type with a
	// Drop method has resource-cleanup semantics, so bit-copying it and
	// then dropping each copy would double-free / use-after-drop. The
	// canonical case is os.File — all-Copy fields {fd, closed, pinned}
	// but a Drop that closes the fd; it must keep MOVE semantics so the
	// auto-close fires exactly once. c.methods carries both local and
	// external (AddExternal) methods, so this catches imported types too.
	if m := c.methods[typeName]; m != nil {
		if _, hasDrop := m["Drop"]; hasDrop {
			return false
		}
	}
	visited[typeName] = true
	for _, f := range st.Fields {
		if !c.typeIsCopy(f.Type, visited) {
			visited[typeName] = false
			return false
		}
	}
	visited[typeName] = false
	return true
}

// typeIsCopy is the field-level Copy predicate used by structIsCopy: a
// field is Copy iff it's a Copy primitive or another all-Copy struct.
// Pointers, borrows, slices, maps, channels, and strings are NOT Copy
// (a pointer/borrow owns or aliases heap storage — copying it would
// double-own — so a struct containing one stays movable).
func (c *Checker) typeIsCopy(t ast.Type, visited map[string]bool) bool {
	nt, ok := t.(*ast.NamedType)
	if !ok {
		return false
	}
	if isCopyPrimitive(nt.Name) {
		return true
	}
	return c.structIsCopy(nt.Name, visited)
}

// isSliceType reports whether t is a `[]T` slice type.
func isSliceType(t ast.Type) bool {
	_, ok := t.(*ast.SliceType)
	return ok
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

// fnLabel renders a CallExpr's Fun as a quoted label for error
// messages — `"f"` for bare identifiers, `"pkg.Fn"` for SelectorExpr,
// and `"<call>"` as a last-resort fallback.
func fnLabel(fn ast.Expr) string {
	switch x := fn.(type) {
	case *ast.IdentExpr:
		return fmt.Sprintf("%q", x.Name)
	case *ast.SelectorExpr:
		if pkg, ok := x.X.(*ast.IdentExpr); ok {
			return fmt.Sprintf("%q", pkg.Name+"."+x.Sel)
		}
	}
	return "<call>"
}

func isBorrowType(t ast.Type) bool {
	_, ok := t.(*ast.BorrowType)
	return ok
}

func isPointerType(t ast.Type) bool {
	_, ok := t.(*ast.PointerType)
	return ok
}
