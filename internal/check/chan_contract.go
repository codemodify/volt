package check

import (
	"fmt"

	"github.com/codemodify/volt/internal/ast"
	"github.com/codemodify/volt/internal/lex"
)

// Channel multiplicity contracts.
//
// A `var ch chanXY T = new(...)` declaration carries a compile-time
// contract about how many readers and writers the channel may have.
// Notation is <readers><writers>: 1 = exactly one, N = one or more.
//
//	chan11 T  — One Reader, One Writer
//	chan1N T  — One Reader, Many Writers
//	chanN1 T  — Many Readers, One Writer
//	chanNN T  — Many Readers, Many Writers
//
// The contract is checked at the declaring scope by walking the
// function body and counting reader / writer "endpoints":
//
//   - direct `read(ch)`  → main goroutine is a reader (+0/+1 once)
//   - direct `write(ch, v)` or `close(ch)` → main is a writer (+0/+1 once)
//   - `ch <- v` send statement → main is a writer
//   - `run f(ch, …)` where f's matching param is `chan read T`
//     → +1 reader endpoint (a new goroutine reading)
//   - `run f(ch, …)` where f's matching param is `chan write T`
//     → +1 writer endpoint
//   - `run f(ch, …)` where f's matching param is bidirectional `chan T`
//     → +1 reader AND +1 writer (conservative — f might do either)
//   - a regular (non-run) call `f(ch, …)` runs in the same goroutine, so
//     it just merges into main reads/writes per f's param direction.
//   - any `run` site lexically inside a `for` loop is treated as "many"
//     spawns of that endpoint (the loop body may execute 0..N times).
//
// Validation:
//   - "One X" requires exactly one X endpoint (main XOR spawn), with no
//     in-loop spawn — else the contract fails.
//   - "Many X" requires at least one X endpoint.
//
// Limitations (documented intentional):
//   - Only enforced at the variable's declaring scope. Aliasing
//     (`var b chan int = a`) or passing the channel out via a return is
//     not tracked.
//   - Function-parameter direction is the only signal used to classify
//     a `run f(ch)` endpoint — passing a contract channel to a bidi
//     param is conservatively counted as both reader and writer.
//   - A `read(ch)` appearing in multiple branches of an `if` is counted
//     once total (we only need to know "main reads at least once").

type chanCheck struct {
	pos                lex.Pos
	name               string
	isParam            bool // parameter-sourced (at-most semantics) vs var-decl (exactly-N)
	multi              ast.ChanMulti
	mainReads          bool
	mainWrites         bool
	spawnReaders       int
	spawnWriters       int
	spawnReadersInLoop bool
	spawnWritersInLoop bool
}

func (c *Checker) checkChanContracts(fd *ast.FuncDecl) {
	if fd.Body == nil {
		return
	}
	contracts := map[string]*chanCheck{}
	// Seed parameter-sourced contracts: any `chanXY T` parameter is
	// tracked with at-most semantics so the function body's endpoint
	// usage gets verified against the contract cap (the caller may be
	// supplying additional endpoints; we can only reject definite
	// violations from this function's side).
	for _, p := range fd.Params {
		ct, ok := p.Type.(*ast.ChanType)
		if !ok || ct.Multi == ast.ChanMultiNone {
			continue
		}
		contracts[p.Name] = &chanCheck{pos: p.Pos(), name: p.Name, isParam: true, multi: ct.Multi}
	}
	c.collectChanContracts(fd.Body, contracts)
	if len(contracts) == 0 {
		return
	}
	c.walkChanUses(fd.Body, contracts, false)
	for _, cc := range contracts {
		c.validateChanContract(cc)
	}
}

func (c *Checker) collectChanContracts(b *ast.Block, contracts map[string]*chanCheck) {
	if b == nil {
		return
	}
	for _, s := range b.Stmts {
		c.collectChanContractsStmt(s, contracts)
	}
}

func (c *Checker) collectChanContractsStmt(s ast.Stmt, contracts map[string]*chanCheck) {
	switch s := s.(type) {
	case *ast.VarStmt:
		if ct, ok := s.Type.(*ast.ChanType); ok && ct.Multi != ast.ChanMultiNone {
			contracts[s.Name] = &chanCheck{pos: s.Pos(), name: s.Name, multi: ct.Multi}
		}
	case *ast.IfStmt:
		if s.Init != nil {
			c.collectChanContractsStmt(s.Init, contracts)
		}
		c.collectChanContracts(s.Then, contracts)
		if s.Else != nil {
			c.collectChanContractsStmt(s.Else, contracts)
		}
	case *ast.ForStmt:
		c.collectChanContracts(s.Body, contracts)
	case *ast.Block:
		c.collectChanContracts(s, contracts)
	case *ast.SelectStmt:
		for _, cs := range s.Cases {
			if cs == nil {
				continue
			}
			for _, st := range cs.Body {
				c.collectChanContractsStmt(st, contracts)
			}
		}
	case *ast.SwitchStmt:
		for _, cl := range s.Cases {
			if cl == nil {
				continue
			}
			for _, st := range cl.Stmts {
				c.collectChanContractsStmt(st, contracts)
			}
		}
	}
}

func (c *Checker) walkChanUses(b *ast.Block, contracts map[string]*chanCheck, inLoop bool) {
	if b == nil {
		return
	}
	for _, s := range b.Stmts {
		c.walkChanUsesStmt(s, contracts, inLoop)
	}
}

func (c *Checker) walkChanUsesStmt(s ast.Stmt, contracts map[string]*chanCheck, inLoop bool) {
	switch s := s.(type) {
	case *ast.VarStmt:
		c.walkChanUsesExpr(s.Value, contracts, inLoop)
	case *ast.AssignStmt:
		c.walkChanUsesExpr(s.RHS, contracts, inLoop)
	case *ast.MultiVarStmt:
		c.walkChanUsesExpr(s.RHS, contracts, inLoop)
	case *ast.MultiAssignStmt:
		c.walkChanUsesExpr(s.RHS, contracts, inLoop)
	case *ast.RetStmt:
		for _, v := range s.Values {
			c.walkChanUsesExpr(v, contracts, inLoop)
		}
	case *ast.ExprStmt:
		c.walkChanUsesExpr(s.Expr, contracts, inLoop)
	case *ast.IfStmt:
		if s.Init != nil {
			c.walkChanUsesStmt(s.Init, contracts, inLoop)
		}
		c.walkChanUsesExpr(s.Cond, contracts, inLoop)
		c.walkChanUses(s.Then, contracts, inLoop)
		if s.Else != nil {
			c.walkChanUsesStmt(s.Else, contracts, inLoop)
		}
	case *ast.ForStmt:
		if s.Init != nil {
			c.walkChanUsesStmt(s.Init, contracts, inLoop)
		}
		c.walkChanUsesExpr(s.Cond, contracts, inLoop)
		c.walkChanUsesExpr(s.RangeOver, contracts, inLoop)
		c.walkChanUses(s.Body, contracts, true)
		if s.Post != nil {
			c.walkChanUsesStmt(s.Post, contracts, true)
		}
	case *ast.Block:
		c.walkChanUses(s, contracts, inLoop)
	case *ast.RunStmt:
		if s.Call != nil {
			c.handleCallArgs(s.Call, contracts, inLoop, true)
		}
	case *ast.SendStmt:
		c.markAsWrite(s.Channel, contracts)
		c.walkChanUsesExpr(s.Value, contracts, inLoop)
	case *ast.SelectStmt:
		for _, cs := range s.Cases {
			if cs == nil {
				continue
			}
			if !cs.IsDefault {
				if cs.SendValue != nil {
					c.markAsWrite(cs.Channel, contracts)
					c.walkChanUsesExpr(cs.SendValue, contracts, inLoop)
				} else {
					c.markAsRead(cs.Channel, contracts)
				}
			}
			for _, st := range cs.Body {
				c.walkChanUsesStmt(st, contracts, inLoop)
			}
		}
	case *ast.SwitchStmt:
		c.walkChanUsesExpr(s.Tag, contracts, inLoop)
		for _, cl := range s.Cases {
			if cl == nil {
				continue
			}
			for _, v := range cl.Vals {
				c.walkChanUsesExpr(v, contracts, inLoop)
			}
			for _, st := range cl.Stmts {
				c.walkChanUsesStmt(st, contracts, inLoop)
			}
		}
	case *ast.DeferStmt:
		if s.Call != nil {
			c.walkChanUsesExpr(s.Call, contracts, inLoop)
		}
	}
}

func (c *Checker) walkChanUsesExpr(e ast.Expr, contracts map[string]*chanCheck, inLoop bool) {
	if e == nil {
		return
	}
	switch ex := e.(type) {
	case *ast.CallExpr:
		// Direct builtin: read(ch) / write(ch, v) / close(ch).
		c.handleBuiltinOnContract(ex, contracts)
		// Or a regular call passing ch as an arg — classify by callee
		// param direction. (Skipped for the builtins above.)
		c.handleCallArgs(ex, contracts, inLoop, false)
		for _, a := range ex.Args {
			c.walkChanUsesExpr(a, contracts, inLoop)
		}
	case *ast.BinaryExpr:
		c.walkChanUsesExpr(ex.X, contracts, inLoop)
		c.walkChanUsesExpr(ex.Y, contracts, inLoop)
	case *ast.UnaryExpr:
		c.walkChanUsesExpr(ex.X, contracts, inLoop)
	case *ast.SelectorExpr:
		c.walkChanUsesExpr(ex.X, contracts, inLoop)
	case *ast.IndexExpr:
		c.walkChanUsesExpr(ex.X, contracts, inLoop)
		c.walkChanUsesExpr(ex.Index, contracts, inLoop)
	}
}

func (c *Checker) handleBuiltinOnContract(call *ast.CallExpr, contracts map[string]*chanCheck) {
	id, ok := call.Fun.(*ast.IdentExpr)
	if !ok {
		return
	}
	switch id.Name {
	case "read":
		if len(call.Args) >= 1 {
			c.markAsRead(call.Args[0], contracts)
		}
	case "write":
		if len(call.Args) >= 1 {
			c.markAsWrite(call.Args[0], contracts)
		}
	case "close":
		if len(call.Args) >= 1 {
			c.markAsWrite(call.Args[0], contracts)
		}
	}
}

func (c *Checker) markAsRead(arg ast.Expr, contracts map[string]*chanCheck) {
	id, ok := arg.(*ast.IdentExpr)
	if !ok {
		return
	}
	if cc, ok := contracts[id.Name]; ok {
		cc.mainReads = true
	}
}

func (c *Checker) markAsWrite(arg ast.Expr, contracts map[string]*chanCheck) {
	id, ok := arg.(*ast.IdentExpr)
	if !ok {
		return
	}
	if cc, ok := contracts[id.Name]; ok {
		cc.mainWrites = true
	}
}

// handleCallArgs classifies each contract-channel argument of `call`.
// If isRun is true, each ch arg adds a spawn endpoint to its direction;
// otherwise it merges into main reads/writes (same goroutine as caller).
// Skips the read/write/close builtins (handled separately) and other
// builtins that don't take the channel as a typed param.
func (c *Checker) handleCallArgs(call *ast.CallExpr, contracts map[string]*chanCheck, inLoop bool, isRun bool) {
	id, ok := call.Fun.(*ast.IdentExpr)
	if !ok {
		return
	}
	switch id.Name {
	case "read", "write", "close", "len", "cap", "append", "clone", "new":
		return
	}
	sig, ok := c.funcs[id.Name]
	if !ok || sig == nil {
		return
	}
	for i, arg := range call.Args {
		if i >= len(sig.Params) {
			break
		}
		argId, ok := arg.(*ast.IdentExpr)
		if !ok {
			continue
		}
		cc, isContract := contracts[argId.Name]
		if !isContract {
			continue
		}
		paramCT, ok := sig.Params[i].Type.(*ast.ChanType)
		if !ok {
			continue
		}
		if isRun {
			switch paramCT.Dir {
			case ast.ChanRead:
				cc.spawnReaders++
				if inLoop {
					cc.spawnReadersInLoop = true
				}
			case ast.ChanWrite:
				cc.spawnWriters++
				if inLoop {
					cc.spawnWritersInLoop = true
				}
			case ast.ChanBoth:
				cc.spawnReaders++
				cc.spawnWriters++
				if inLoop {
					cc.spawnReadersInLoop = true
					cc.spawnWritersInLoop = true
				}
			}
		} else {
			switch paramCT.Dir {
			case ast.ChanRead:
				cc.mainReads = true
			case ast.ChanWrite:
				cc.mainWrites = true
			case ast.ChanBoth:
				cc.mainReads = true
				cc.mainWrites = true
			}
		}
	}
}

func (c *Checker) validateChanContract(cc *chanCheck) {
	readerCount := cc.spawnReaders
	if cc.mainReads {
		readerCount++
	}
	writerCount := cc.spawnWriters
	if cc.mainWrites {
		writerCount++
	}
	name := cc.multi.MultiName()
	pos := cc.pos
	decl := cc.name

	needOneReader := cc.multi == ast.ChanMulti11 || cc.multi == ast.ChanMulti1N
	needOneWriter := cc.multi == ast.ChanMulti11 || cc.multi == ast.ChanMultiN1

	// Parameter-sourced contracts use at-most semantics: the caller may
	// be supplying additional endpoints we can't see, so we only reject
	// the function-body usage that DEFINITELY violates the cap (a count
	// > 1 or an in-loop spawn). count == 0 is fine for params.
	site := "declared"
	if cc.isParam {
		site = "parameter"
	}

	if needOneReader {
		switch {
		case cc.spawnReadersInLoop:
			c.errs = append(c.errs, fmt.Sprintf(
				"%s: %s %q contract violated — %s `One Reader` but a `run` reading from %q appears inside a loop (each iteration spawns a new reader); use chanN1 or chanNN for many readers",
				pos, name, decl, site, decl))
		case readerCount > 1:
			c.errs = append(c.errs, fmt.Sprintf(
				"%s: %s %q contract violated — %s `One Reader` but found %d reader endpoint(s); use chanN1 or chanNN for many readers",
				pos, name, decl, site, readerCount))
		case readerCount == 0 && !cc.isParam:
			c.errs = append(c.errs, fmt.Sprintf(
				"%s: %s %q contract violated — declared `One Reader` but no reader endpoint exists",
				pos, name, decl))
		}
	} else if !cc.isParam {
		if readerCount == 0 && !cc.spawnReadersInLoop {
			c.errs = append(c.errs, fmt.Sprintf(
				"%s: %s %q contract violated — declared `Many Readers` but no reader endpoint exists",
				pos, name, decl))
		}
	}

	if needOneWriter {
		switch {
		case cc.spawnWritersInLoop:
			c.errs = append(c.errs, fmt.Sprintf(
				"%s: %s %q contract violated — %s `One Writer` but a `run` writing to %q appears inside a loop (each iteration spawns a new writer); use chan1N or chanNN for many writers",
				pos, name, decl, site, decl))
		case writerCount > 1:
			c.errs = append(c.errs, fmt.Sprintf(
				"%s: %s %q contract violated — %s `One Writer` but found %d writer endpoint(s); use chan1N or chanNN for many writers",
				pos, name, decl, site, writerCount))
		case writerCount == 0 && !cc.isParam:
			c.errs = append(c.errs, fmt.Sprintf(
				"%s: %s %q contract violated — declared `One Writer` but no writer endpoint exists",
				pos, name, decl))
		}
	} else if !cc.isParam {
		if writerCount == 0 && !cc.spawnWritersInLoop {
			c.errs = append(c.errs, fmt.Sprintf(
				"%s: %s %q contract violated — declared `Many Writers` but no writer endpoint exists",
				pos, name, decl))
		}
	}
}
