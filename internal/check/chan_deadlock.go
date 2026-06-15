package check

import (
	"fmt"

	"github.com/codemodify/volt/internal/ast"
	"github.com/codemodify/volt/internal/lex"
)

// Static deadlock detection (#7, stage 1 — the SOUND compile-time half
// of the hybrid model).
//
// An UNBUFFERED channel (`new()` / `new(0)`, cap = 0) is a rendezvous:
// every `read`/`write` blocks until a DIFFERENT thread performs the
// paired operation. So a cap-0 channel that never reaches another thread
// can never be serviced — any blocking op on it hangs forever.
//
// This pass flags exactly that, and ONLY that, so it can NEVER reject a
// valid program (the no-false-reject half of the "no deadlocks"
// invariant): a channel is reported iff
//
//   - it is declared locally with `new()` / `new(0)` (provably cap = 0),
//   - it has at least one `read`/`write` (a BLOCKING op) in this function,
//   - and it NEVER escapes this thread — it appears only as argument 0 of
//     read/write/close. The instant the channel is passed to ANY function
//     (a `run` spawn, or a plain call that might itself spawn), returned,
//     stored, aliased, or otherwise mentioned, we can no longer prove it
//     stays single-threaded, so we stay silent.
//
// Cross-thread deadlock cycles (two goroutines each waiting on the other)
// are undecidable here and are left to stage 2, the runtime all-blocked
// backstop. Misses are fine; false reports are not.

type dlChan struct {
	pos      lex.Pos
	hasRead  bool
	hasWrite bool
	escaped  bool // mentioned anywhere other than read/write/close arg 0
}

func (c *Checker) checkChanDeadlocks(fd *ast.FuncDecl) {
	if fd.Body == nil {
		return
	}
	cands := map[string]*dlChan{}

	// Phase 1 — collect cap-0 channel locals.
	var collect func(b *ast.Block)
	var collectStmt func(s ast.Stmt)
	collect = func(b *ast.Block) {
		if b == nil {
			return
		}
		for _, s := range b.Stmts {
			collectStmt(s)
		}
	}
	collectStmt = func(s ast.Stmt) {
		switch s := s.(type) {
		case *ast.VarStmt:
			if ne, ok := s.Value.(*ast.NewExpr); ok && isChanNew(ne, s.Type) && newExprIsUnbuffered(ne) {
				cands[s.Name] = &dlChan{pos: s.Pos()}
			}
		case *ast.IfStmt:
			collectStmt(s.Init)
			collect(s.Then)
			collectStmt(s.Else)
		case *ast.ForStmt:
			collect(s.Body)
		case *ast.Block:
			collect(s)
		case *ast.SelectStmt:
			for _, cs := range s.Cases {
				if cs == nil {
					continue
				}
				for _, st := range cs.Body {
					collectStmt(st)
				}
			}
		case *ast.SwitchStmt:
			for _, cl := range s.Cases {
				if cl == nil {
					continue
				}
				for _, st := range cl.Stmts {
					collectStmt(st)
				}
			}
		}
	}
	collect(fd.Body)
	if len(cands) == 0 {
		return
	}

	// Phase 2 — classify every occurrence. read/write/close arg 0 is a
	// borrow (records the op); anything else escapes the thread.
	var walkStmt func(s ast.Stmt)
	var walkExpr func(e ast.Expr) // marks every candidate ident it reaches as escaped

	markEscape := func(name string) {
		if cc, ok := cands[name]; ok {
			cc.escaped = true
		}
	}

	walkExpr = func(e ast.Expr) {
		if e == nil {
			return
		}
		switch ex := e.(type) {
		case *ast.IdentExpr:
			markEscape(ex.Name)
		case *ast.CallExpr:
			if id, ok := ex.Fun.(*ast.IdentExpr); ok {
				switch id.Name {
				case "read", "write", "close":
					for i, a := range ex.Args {
						if i == 0 {
							if argId, isID := a.(*ast.IdentExpr); isID {
								if cc, ok := cands[argId.Name]; ok {
									switch id.Name {
									case "read":
										cc.hasRead = true
									case "write":
										cc.hasWrite = true
									}
									// close is non-blocking: a borrow, no op.
								}
								continue // arg 0 borrowed, not escaped
							}
						}
						walkExpr(a)
					}
					return
				}
			}
			walkExpr(ex.Fun)
			for _, a := range ex.Args {
				walkExpr(a)
			}
		case *ast.BinaryExpr:
			walkExpr(ex.X)
			walkExpr(ex.Y)
		case *ast.UnaryExpr:
			walkExpr(ex.X)
		case *ast.SelectorExpr:
			walkExpr(ex.X)
		case *ast.IndexExpr:
			walkExpr(ex.X)
			walkExpr(ex.Index)
		case *ast.NewExpr:
			for _, a := range ex.SizeArgs {
				walkExpr(a)
			}
			for _, p := range ex.Pairs {
				if p != nil {
					walkExpr(p.Value)
				}
			}
			for _, me := range ex.MapEntries {
				if me != nil {
					walkExpr(me.Key)
					walkExpr(me.Value)
				}
			}
			for _, el := range ex.SliceElems {
				walkExpr(el)
			}
		case *ast.FuncLit:
			if ex.Body != nil {
				for _, st := range ex.Body.Stmts {
					walkStmt(st)
				}
			}
		}
	}

	walkStmt = func(s ast.Stmt) {
		switch s := s.(type) {
		case *ast.VarStmt:
			// The channel's own `new()` initializer doesn't mention the
			// candidate name, so this never marks the just-declared channel.
			walkExpr(s.Value)
		case *ast.AssignStmt:
			walkExpr(s.LHS)
			walkExpr(s.RHS)
		case *ast.MultiVarStmt:
			walkExpr(s.RHS)
		case *ast.MultiAssignStmt:
			for _, l := range s.LHS {
				walkExpr(l)
			}
			walkExpr(s.RHS)
		case *ast.RetStmt:
			for _, v := range s.Values {
				walkExpr(v)
			}
		case *ast.ExprStmt:
			walkExpr(s.Expr)
		case *ast.IfStmt:
			walkStmt(s.Init)
			walkExpr(s.Cond)
			walkBlock(walkStmt, s.Then)
			walkStmt(s.Else)
		case *ast.ForStmt:
			walkStmt(s.Init)
			walkExpr(s.Cond)
			walkExpr(s.RangeOver)
			walkBlock(walkStmt, s.Body)
			walkStmt(s.Post)
		case *ast.Block:
			walkBlock(walkStmt, s)
		case *ast.RunStmt:
			if s.Call != nil {
				walkExpr(s.Call) // a `run f(ch)` marks ch escaped (reaches a new thread)
			}
		case *ast.DeferStmt:
			if s.Call != nil {
				walkExpr(s.Call)
			}
		case *ast.SelectStmt:
			for _, cs := range s.Cases {
				if cs == nil {
					continue
				}
				// A select on a channel is a multi-thread coordination point;
				// the channel's use there is not a provable single-thread
				// block, so treat the guard as an escape (stay silent).
				walkExpr(cs.Channel)
				walkExpr(cs.SendValue)
				for _, st := range cs.Body {
					walkStmt(st)
				}
			}
		case *ast.SwitchStmt:
			walkExpr(s.Tag)
			for _, cl := range s.Cases {
				if cl == nil {
					continue
				}
				for _, v := range cl.Vals {
					walkExpr(v)
				}
				for _, st := range cl.Stmts {
					walkStmt(st)
				}
			}
		}
	}

	for _, s := range fd.Body.Stmts {
		walkStmt(s)
	}

	// Phase 3 — report the provable hangs.
	for name, cc := range cands {
		if cc.escaped || (!cc.hasRead && !cc.hasWrite) {
			continue
		}
		op := "read"
		if cc.hasWrite && !cc.hasRead {
			op = "write"
		}
		c.errs = append(c.errs, fmt.Sprintf(
			"%s: deadlock — unbuffered channel %q is used (%s) but never reaches another thread, so the rendezvous can never complete; spawn the other side with `run`, or buffer it with `new(N)`",
			cc.pos, name, op))
	}
}

// walkBlock applies walkStmt to each statement in b (nil-safe helper so
// the mutually-recursive closures stay readable).
func walkBlock(walkStmt func(ast.Stmt), b *ast.Block) {
	if b == nil {
		return
	}
	for _, s := range b.Stmts {
		walkStmt(s)
	}
}

// isChanNew reports whether a `new(...)` expression (with the optional
// declared var type) constructs a channel. The channel type may sit on
// the NewExpr (`new() chan T`) or on the declared type (`var c chan T =
// new(N)`).
func isChanNew(ne *ast.NewExpr, declType ast.Type) bool {
	if _, ok := ne.Type.(*ast.ChanType); ok {
		return true
	}
	_, ok := declType.(*ast.ChanType)
	return ok
}

// newExprIsUnbuffered reports whether a channel `new(...)` is cap = 0:
// either no size argument, or an explicit integer-literal 0. A non-literal
// size is conservatively treated as buffered (we can't prove cap 0).
func newExprIsUnbuffered(ne *ast.NewExpr) bool {
	if len(ne.SizeArgs) == 0 {
		return true
	}
	if len(ne.SizeArgs) == 1 {
		if lit, ok := ne.SizeArgs[0].(*ast.IntLit); ok {
			return lit.Value == 0
		}
	}
	return false
}
