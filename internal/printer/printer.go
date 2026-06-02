// Package printer walks a volt AST and emits canonical formatted
// source. Comments are preserved and interleaved by line position.
// Blank lines collapse to at most one.
//
// Formatting conventions:
//   - Tabs for indentation (gofmt-style).
//   - One blank line between top-level decls.
//   - K&R braces: `{` on the same line as the opening keyword.
//   - No trailing whitespace.
package printer

import (
	"fmt"
	"strconv"
	"strings"

	"github.com/codemodify/volt/internal/ast"
	"github.com/codemodify/volt/internal/lex"
)

// Format returns the canonical source for the given file.
func Format(file *ast.File) string {
	p := &printer{comments: file.Comments}
	p.printFile(file)
	return p.b.String()
}

type printer struct {
	b        strings.Builder
	indent   int
	comments []lex.Comment // remaining comments, sorted by source order
	lastLine int           // last source line we emitted from (for blank-line preservation)
}

func (p *printer) writeIndent() {
	for i := 0; i < p.indent; i++ {
		p.b.WriteByte('\t')
	}
}

// line writes one logical line at the current indent. Tracks no source
// position — used for printer-synthesized output (braces, separators).
func (p *printer) line(s string) {
	p.writeIndent()
	p.b.WriteString(s)
	p.b.WriteByte('\n')
}

// lineAt writes one logical line and attaches any pending comment whose
// line number matches `srcLine` as a trailing same-line comment. Used
// for source-derived statements so `var x = 1  // note` round-trips.
func (p *printer) lineAt(s string, srcLine int) {
	p.writeIndent()
	p.b.WriteString(s)
	if len(p.comments) > 0 && p.comments[0].Pos.Line == srcLine {
		c := p.comments[0]
		p.comments = p.comments[1:]
		p.b.WriteString("  ")
		p.b.WriteString(c.Text)
	}
	p.b.WriteByte('\n')
	p.markLine(srcLine)
}

func (p *printer) raw(s string) {
	p.b.WriteString(s)
}

// flushCommentsBefore emits any pending comments whose source line is
// strictly before targetLine. If preserveBlank is true and there is a
// blank line between the last emitted source line and the first pending
// comment, one blank line is emitted before the comment.
func (p *printer) flushCommentsBefore(targetLine int) {
	for len(p.comments) > 0 && p.comments[0].Pos.Line < targetLine {
		c := p.comments[0]
		p.comments = p.comments[1:]
		if p.lastLine > 0 && c.Pos.Line-p.lastLine > 1 {
			p.b.WriteByte('\n')
		}
		p.writeIndent()
		p.b.WriteString(c.Text)
		p.b.WriteByte('\n')
		p.lastLine = c.Pos.Line + strings.Count(c.Text, "\n")
	}
}

// emitBlankIfGap writes a blank line if there's a source-line gap > 1
// between p.lastLine and the next node's line. No-op for the first
// emission (lastLine == 0).
func (p *printer) emitBlankIfGap(nextLine int) {
	if p.lastLine == 0 {
		return
	}
	if nextLine-p.lastLine > 1 {
		p.b.WriteByte('\n')
	}
}

// markLine records that we just emitted output for source line n.
func (p *printer) markLine(n int) {
	if n > p.lastLine {
		p.lastLine = n
	}
}

// endLine returns the approximate last source line a statement occupies,
// including its closing brace. Used to update lastLine after emitting
// compound statements so blank-line preservation doesn't misfire.
func endLine(s ast.Stmt) int {
	if s == nil {
		return 0
	}
	line := s.Pos().Line
	walk := func(stmts []ast.Stmt) {
		for _, ss := range stmts {
			if l := endLine(ss); l > line {
				line = l
			}
		}
	}
	switch s := s.(type) {
	case *ast.Block:
		walk(s.Stmts)
		return line + 1
	case *ast.IfStmt:
		if s.Then != nil {
			walk(s.Then.Stmts)
		}
		if s.Else != nil {
			if l := endLine(s.Else); l > line {
				line = l
			}
		}
		return line + 1
	case *ast.ForStmt:
		if s.Body != nil {
			walk(s.Body.Stmts)
		}
		return line + 1
	case *ast.SwitchStmt:
		for _, cc := range s.Cases {
			walk(cc.Stmts)
		}
		return line + 1
	case *ast.SelectStmt:
		for _, cc := range s.Cases {
			walk(cc.Body)
		}
		return line + 1
	}
	return line
}

// flushRemaining emits any leftover comments at file end.
func (p *printer) flushRemaining() {
	for _, c := range p.comments {
		if p.lastLine > 0 && c.Pos.Line-p.lastLine > 1 {
			p.b.WriteByte('\n')
		}
		p.writeIndent()
		p.b.WriteString(c.Text)
		p.b.WriteByte('\n')
		p.lastLine = c.Pos.Line + strings.Count(c.Text, "\n")
	}
	p.comments = nil
}

// ---------------------------------------------------------------------
// Top-level
// ---------------------------------------------------------------------

func (p *printer) printFile(f *ast.File) {
	// Leading comments before the package clause.
	p.flushCommentsBefore(f.P.Line)
	p.emitBlankIfGap(f.P.Line)

	p.writeIndent()
	p.raw("package " + f.Package + "\n")
	p.markLine(f.P.Line)

	if len(f.Imports) > 0 {
		firstImpLine := f.Imports[0].P.Line
		p.flushCommentsBefore(firstImpLine)
		p.emitBlankIfGap(firstImpLine)
		if len(f.Imports) == 1 {
			p.line(`import "` + f.Imports[0].Path + `"`)
			p.markLine(f.Imports[0].P.Line)
		} else {
			p.line("import (")
			p.indent++
			for _, im := range f.Imports {
				p.flushCommentsBefore(im.P.Line)
				p.line(`"` + im.Path + `"`)
				p.markLine(im.P.Line)
			}
			p.indent--
			p.line(")")
		}
	}

	for _, d := range f.Decls {
		dl := d.Pos().Line
		p.flushCommentsBefore(dl)
		p.emitBlankIfGap(dl)
		// Ensure a blank line between top-level decls even when there's
		// no source gap (rare, but keeps output uniform).
		if p.lastLine > 0 && p.b.Len() > 0 {
			tail := p.b.String()
			// If the last char isn't already a blank-line boundary, add one.
			if !strings.HasSuffix(tail, "\n\n") {
				p.b.WriteByte('\n')
			}
		}
		p.printDecl(d)
	}

	p.flushRemaining()
}

func (p *printer) printDecl(d ast.Decl) {
	switch d := d.(type) {
	case *ast.TypeDecl:
		p.printTypeDecl(d)
	case *ast.FuncDecl:
		p.printFuncDecl(d)
	case *ast.ConstDecl:
		p.printConstDecl(d)
	}
}

func (p *printer) printTypeDecl(d *ast.TypeDecl) {
	p.markLine(d.P.Line)
	if st, ok := d.Type.(*ast.StructType); ok {
		if len(st.Fields) == 0 {
			p.line("type " + d.Name + " struct {}")
			return
		}
		p.line("type " + d.Name + " struct {")
		p.indent++
		// Align field types like gofmt.
		nameWidth := 0
		for _, f := range st.Fields {
			if len(f.Name) > nameWidth {
				nameWidth = len(f.Name)
			}
		}
		for _, f := range st.Fields {
			p.flushCommentsBefore(f.P.Line)
			p.line(fmt.Sprintf("%-*s %s", nameWidth, f.Name, p.formatType(f.Type)))
			p.markLine(f.P.Line)
		}
		p.indent--
		p.line("}")
		return
	}
	if it, ok := d.Type.(*ast.InterfaceType); ok {
		if len(it.Methods) == 0 {
			p.line("type " + d.Name + " interface {}")
			return
		}
		p.line("type " + d.Name + " interface {")
		p.indent++
		for _, m := range it.Methods {
			p.flushCommentsBefore(m.P.Line)
			// Render each method's full signature so the formatted
			// source round-trips through the parser.
			sig := m.Name + "()"
			if ft, ok := m.Type.(*ast.FuncType); ok {
				var sb strings.Builder
				sb.WriteString(m.Name + "(")
				for j, prm := range ft.Params {
					if j > 0 {
						sb.WriteString(", ")
					}
					if prm.Name != "" {
						sb.WriteString(prm.Name + " ")
					}
					sb.WriteString(p.formatType(prm.Type))
				}
				sb.WriteByte(')')
				if len(ft.Results) == 1 {
					sb.WriteByte(' ')
					sb.WriteString(p.formatType(ft.Results[0]))
				} else if len(ft.Results) > 1 {
					sb.WriteString(" (")
					for j, r := range ft.Results {
						if j > 0 {
							sb.WriteString(", ")
						}
						sb.WriteString(p.formatType(r))
					}
					sb.WriteByte(')')
				}
				sig = sb.String()
			}
			p.line(sig)
			p.markLine(m.P.Line)
		}
		p.indent--
		p.line("}")
		return
	}
	p.line("type " + d.Name + " " + p.formatType(d.Type))
}

func (p *printer) printConstDecl(d *ast.ConstDecl) {
	p.markLine(d.P.Line)
	p.line("const " + d.Name + " = " + p.formatExpr(d.Value))
}

func (p *printer) printFuncDecl(d *ast.FuncDecl) {
	p.markLine(d.P.Line)
	p.writeIndent()
	p.raw("fun ")
	if d.Receiver != nil {
		p.raw("(" + d.Receiver.Name + " " + p.formatType(d.Receiver.Type) + ") ")
	}
	p.raw(d.Name + "(")
	for i, param := range d.Params {
		if i > 0 {
			p.raw(", ")
		}
		p.raw(param.Name + " " + p.formatType(param.Type))
	}
	p.raw(")")
	switch len(d.Results) {
	case 0:
		// no results
	case 1:
		p.raw(" " + p.formatType(d.Results[0]))
	default:
		parts := make([]string, len(d.Results))
		for i, r := range d.Results {
			parts[i] = p.formatType(r)
		}
		p.raw(" (" + strings.Join(parts, ", ") + ")")
	}
	if d.Body != nil {
		p.raw(" {\n")
		p.indent++
		for _, s := range d.Body.Stmts {
			p.printStmt(s)
		}
		// Flush any trailing comments inside the body.
		closeLine := d.Body.Pos().Line
		if closeLine < p.lastLine {
			closeLine = p.lastLine
		}
		p.flushCommentsBefore(closeLine + 1000000) // drain everything before the next decl; safer to drain in-body comments here
		p.indent--
		p.line("}")
	} else {
		p.raw("\n")
	}
}

// ---------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------

func (p *printer) formatType(t ast.Type) string {
	switch t := t.(type) {
	case *ast.NamedType:
		return t.Name
	case *ast.BorrowType:
		if t.Mut {
			return "&mut " + p.formatType(t.Elem)
		}
		return "&" + p.formatType(t.Elem)
	case *ast.PointerType:
		return "*" + p.formatType(t.Elem)
	case *ast.SliceType:
		return "[]" + p.formatType(t.Elem)
	case *ast.MapType:
		return "map[" + p.formatType(t.Key) + "]" + p.formatType(t.Value)
	case *ast.ChanType:
		head := t.Multi.MultiName()
		switch t.Dir {
		case ast.ChanRead:
			head = head + " read"
		case ast.ChanWrite:
			head = head + " write"
		}
		return head + " " + p.formatType(t.Elem)
	case *ast.AtomicType:
		return "atomic " + p.formatType(t.Elem)
	case *ast.MutexType:
		return "mutex " + p.formatType(t.Elem)
	case *ast.RwMutexType:
		return "rwmutex " + p.formatType(t.Elem)
	case *ast.WaitgroupType:
		return "waitgroup"
	case *ast.OnceType:
		return "once"
	case *ast.FuncType:
		var sb strings.Builder
		sb.WriteString("fun(")
		for i, prm := range t.Params {
			if i > 0 {
				sb.WriteString(", ")
			}
			if prm.Name != "" {
				sb.WriteString(prm.Name + " ")
			}
			sb.WriteString(p.formatType(prm.Type))
		}
		sb.WriteByte(')')
		if len(t.Results) == 1 {
			sb.WriteByte(' ')
			sb.WriteString(p.formatType(t.Results[0]))
		} else if len(t.Results) > 1 {
			sb.WriteString(" (")
			for i, r := range t.Results {
				if i > 0 {
					sb.WriteString(", ")
				}
				sb.WriteString(p.formatType(r))
			}
			sb.WriteByte(')')
		}
		return sb.String()
	case *ast.InterfaceType:
		if len(t.Methods) == 0 {
			return "interface{}"
		}
		var sb strings.Builder
		sb.WriteString("interface { ")
		for i, m := range t.Methods {
			if i > 0 {
				sb.WriteString("; ")
			}
			sb.WriteString(m.Name)
			// Each method's Type is a *ast.FuncType holding the
			// parameters + return types. Emit `(P1, P2) R` so the
			// formatted source round-trips through the parser.
			if ft, ok := m.Type.(*ast.FuncType); ok {
				sb.WriteByte('(')
				for j, prm := range ft.Params {
					if j > 0 {
						sb.WriteString(", ")
					}
					if prm.Name != "" {
						sb.WriteString(prm.Name + " ")
					}
					sb.WriteString(p.formatType(prm.Type))
				}
				sb.WriteByte(')')
				if len(ft.Results) == 1 {
					sb.WriteByte(' ')
					sb.WriteString(p.formatType(ft.Results[0]))
				} else if len(ft.Results) > 1 {
					sb.WriteString(" (")
					for j, r := range ft.Results {
						if j > 0 {
							sb.WriteString(", ")
						}
						sb.WriteString(p.formatType(r))
					}
					sb.WriteByte(')')
				}
			} else {
				sb.WriteString("()")
			}
		}
		sb.WriteString(" }")
		return sb.String()
	case *ast.StructType:
		// Anonymous structs: rare in v0.4; emit single-line.
		if len(t.Fields) == 0 {
			return "struct{}"
		}
		var sb strings.Builder
		sb.WriteString("struct {")
		for i, f := range t.Fields {
			if i > 0 {
				sb.WriteString("; ")
			} else {
				sb.WriteByte(' ')
			}
			sb.WriteString(f.Name + " " + p.formatType(f.Type))
		}
		sb.WriteString(" }")
		return sb.String()
	}
	return "<?type>"
}

// ---------------------------------------------------------------------
// Statements
// ---------------------------------------------------------------------

func (p *printer) printStmt(s ast.Stmt) {
	// Flush comments that come before this statement, and preserve any
	// blank line in front of it.
	sl := s.Pos().Line
	p.flushCommentsBefore(sl)
	p.emitBlankIfGap(sl)
	p.markLine(sl)

	switch s := s.(type) {
	case *ast.ExprStmt:
		p.lineAt(p.formatExpr(s.Expr), sl)
	case *ast.VarStmt:
		p.printVarStmt(s, sl)
	case *ast.MultiVarStmt:
		p.printMultiVarStmt(s, sl)
	case *ast.AssignStmt:
		p.lineAt(p.formatExpr(s.LHS)+" = "+p.formatExpr(s.RHS), sl)
	case *ast.MultiAssignStmt:
		p.printMultiAssignStmt(s, sl)
	case *ast.SendStmt:
		// Render as the canonical write(ch, v) call. The SendStmt AST node
		// is no longer produced by the parser (sends are CallExprs now) but
		// any synthesized AST would round-trip parseably this way.
		p.lineAt("write("+p.formatExpr(s.Channel)+", "+p.formatExpr(s.Value)+")", sl)
	case *ast.RetStmt:
		switch len(s.Values) {
		case 0:
			p.lineAt("ret", sl)
		case 1:
			p.lineAt("ret "+p.formatExpr(s.Values[0]), sl)
		default:
			parts := make([]string, len(s.Values))
			for i, v := range s.Values {
				parts[i] = p.formatExpr(v)
			}
			p.lineAt("ret "+strings.Join(parts, ", "), sl)
		}
	case *ast.BreakStmt:
		p.lineAt("break", sl)
	case *ast.ContinueStmt:
		p.lineAt("continue", sl)
	case *ast.IfStmt:
		p.printIfStmt(s, false)
		p.markLine(endLine(s))
	case *ast.ForStmt:
		p.printForStmt(s)
		p.markLine(endLine(s))
	case *ast.SwitchStmt:
		p.printSwitchStmt(s)
		p.markLine(endLine(s))
	case *ast.SelectStmt:
		p.printSelectStmt(s)
		p.markLine(endLine(s))
	case *ast.DeferStmt:
		p.lineAt("def "+p.formatExpr(s.Call), sl)
	case *ast.RunStmt:
		p.lineAt("run "+p.formatExpr(s.Call), sl)
	case *ast.Block:
		p.line("{")
		p.indent++
		for _, ss := range s.Stmts {
			p.printStmt(ss)
		}
		p.indent--
		p.line("}")
	}
}

func (p *printer) printVarStmt(s *ast.VarStmt, srcLine int) {
	if s.Type == nil && s.Value != nil {
		p.lineAt(s.Name+" := "+p.formatExpr(s.Value), srcLine)
		return
	}
	out := "var " + s.Name
	if s.Type != nil {
		out += " " + p.formatType(s.Type)
	}
	if s.Value != nil {
		out += " = " + p.formatExpr(s.Value)
	}
	p.lineAt(out, srcLine)
}

func (p *printer) printMultiVarStmt(s *ast.MultiVarStmt, srcLine int) {
	// MultiVarStmt is the `v, ok := read(ch)` / `a, b := f()` short form.
	p.lineAt(strings.Join(s.Names, ", ")+" := "+p.formatExpr(s.RHS), srcLine)
}

func (p *printer) printMultiAssignStmt(s *ast.MultiAssignStmt, srcLine int) {
	lhs := make([]string, len(s.LHS))
	for i, e := range s.LHS {
		lhs[i] = p.formatExpr(e)
	}
	p.lineAt(strings.Join(lhs, ", ")+" = "+p.formatExpr(s.RHS), srcLine)
}

func (p *printer) printIfStmt(s *ast.IfStmt, asElseIf bool) {
	prefix := ""
	if asElseIf {
		prefix = "} else "
	}
	p.writeIndent()
	head := prefix + "if "
	if s.Init != nil {
		head += p.formatSimpleStmt(s.Init) + "; "
	}
	p.raw(head + p.formatExpr(s.Cond) + " {\n")
	p.indent++
	if s.Then != nil {
		for _, ss := range s.Then.Stmts {
			p.printStmt(ss)
		}
	}
	p.indent--
	if s.Else == nil {
		p.line("}")
		return
	}
	switch e := s.Else.(type) {
	case *ast.IfStmt:
		p.printIfStmt(e, true)
	case *ast.Block:
		p.writeIndent()
		p.raw("} else {\n")
		p.indent++
		for _, ss := range e.Stmts {
			p.printStmt(ss)
		}
		p.indent--
		p.line("}")
	}
}

func (p *printer) printForStmt(s *ast.ForStmt) {
	p.writeIndent()
	p.raw("for ")
	switch {
	case s.RangeOver != nil:
		// `for i, v := range EXPR { ... }` (RangeV may be "")
		i := s.RangeI
		if i == "" {
			i = "_"
		}
		if s.RangeV != "" {
			p.raw(i + ", " + s.RangeV + " := range " + p.formatExpr(s.RangeOver) + " ")
		} else {
			p.raw(i + " := range " + p.formatExpr(s.RangeOver) + " ")
		}
	case s.Init == nil && s.Cond == nil && s.Post == nil:
		// `for { ... }`
	case s.Init == nil && s.Post == nil:
		// `for cond { ... }`
		p.raw(p.formatExpr(s.Cond) + " ")
	default:
		p.raw(p.formatSimpleStmt(s.Init) + "; ")
		if s.Cond != nil {
			p.raw(p.formatExpr(s.Cond))
		}
		p.raw("; ")
		p.raw(p.formatSimpleStmt(s.Post) + " ")
	}
	p.raw("{\n")
	p.indent++
	if s.Body != nil {
		for _, ss := range s.Body.Stmts {
			p.printStmt(ss)
		}
	}
	p.indent--
	p.line("}")
}

func (p *printer) printSwitchStmt(s *ast.SwitchStmt) {
	p.writeIndent()
	if s.Tag != nil {
		p.raw("switch " + p.formatExpr(s.Tag) + " {\n")
	} else {
		p.raw("switch {\n")
	}
	for _, cc := range s.Cases {
		if cc.Vals == nil {
			p.line("default:")
		} else {
			parts := make([]string, len(cc.Vals))
			for i, v := range cc.Vals {
				parts[i] = p.formatExpr(v)
			}
			p.line("case " + strings.Join(parts, ", ") + ":")
		}
		p.indent++
		for _, ss := range cc.Stmts {
			p.printStmt(ss)
		}
		p.indent--
	}
	p.line("}")
}

func (p *printer) printSelectStmt(s *ast.SelectStmt) {
	p.writeIndent()
	p.raw("select {\n")
	for _, cs := range s.Cases {
		p.writeIndent()
		switch {
		case cs.IsDefault:
			p.raw("default:\n")
		case len(cs.RecvNames) == 0 && cs.SendValue == nil:
			p.raw("case read(" + p.formatExpr(cs.Channel) + "):\n")
		case cs.SendValue != nil:
			p.raw("case write(" + p.formatExpr(cs.Channel) + ", " + p.formatExpr(cs.SendValue) + "):\n")
		default:
			p.raw("case " + strings.Join(cs.RecvNames, ", ") + " := read(" + p.formatExpr(cs.Channel) + "):\n")
		}
		p.indent++
		for _, ss := range cs.Body {
			p.printStmt(ss)
		}
		p.indent--
	}
	p.line("}")
}

// formatSimpleStmt is the inline form used in for-clauses.
func (p *printer) formatSimpleStmt(s ast.Stmt) string {
	if s == nil {
		return ""
	}
	switch s := s.(type) {
	case *ast.VarStmt:
		if s.Type == nil && s.Value != nil {
			return s.Name + " := " + p.formatExpr(s.Value)
		}
		out := "var " + s.Name
		if s.Type != nil {
			out += " " + p.formatType(s.Type)
		}
		if s.Value != nil {
			out += " = " + p.formatExpr(s.Value)
		}
		return out
	case *ast.AssignStmt:
		return p.formatExpr(s.LHS) + " = " + p.formatExpr(s.RHS)
	case *ast.ExprStmt:
		return p.formatExpr(s.Expr)
	case *ast.MultiVarStmt:
		return strings.Join(s.Names, ", ") + " := " + p.formatExpr(s.RHS)
	case *ast.MultiAssignStmt:
		lhs := make([]string, len(s.LHS))
		for i, e := range s.LHS {
			lhs[i] = p.formatExpr(e)
		}
		return strings.Join(lhs, ", ") + " = " + p.formatExpr(s.RHS)
	}
	return ""
}

// ---------------------------------------------------------------------
// Expressions
// ---------------------------------------------------------------------

// formatStmtInline returns a single-line rendering of `s` suitable for
// embedding in a closure body literal. Best-effort: complex statements
// (nested blocks, control flow) collapse to a single statement string
// that the parser will still accept.
func (p *printer) formatStmtInline(s ast.Stmt) string {
	switch s := s.(type) {
	case *ast.RetStmt:
		if len(s.Values) == 0 {
			return "ret"
		}
		var parts []string
		for _, v := range s.Values {
			parts = append(parts, p.formatExpr(v))
		}
		return "ret " + strings.Join(parts, ", ")
	case *ast.ExprStmt:
		return p.formatExpr(s.Expr)
	case *ast.AssignStmt:
		return p.formatExpr(s.LHS) + " = " + p.formatExpr(s.RHS)
	case *ast.VarStmt:
		out := "var " + s.Name
		if s.Type != nil {
			out += " " + p.formatType(s.Type)
		}
		if s.Value != nil {
			out += " = " + p.formatExpr(s.Value)
		}
		return out
	case *ast.IfStmt:
		out := "if " + p.formatExpr(s.Cond) + " {"
		if s.Then != nil {
			for i, st := range s.Then.Stmts {
				if i > 0 {
					out += "; "
				} else {
					out += " "
				}
				out += p.formatStmtInline(st)
			}
		}
		out += " }"
		return out
	}
	return "<?stmt>"
}

// binaryPrec returns the precedence of a binary operator (higher =
// binds tighter). Matches the parser's parsing levels so the printer
// can decide where parentheses are necessary to preserve evaluation
// order when re-emitting. Mirrors Go's operator precedence:
//
//	5: * / % & << >>      (multiplicative)
//	4: + - | ^            (additive)
//	3: == != < <= > >=    (comparison)
//	2: &&                 (logical and)
//	1: ||                 (logical or)
//	0: unknown / non-binary
func binaryPrec(op string) int {
	switch op {
	case "*", "/", "%", "&", "<<", ">>":
		return 5
	case "+", "-", "|", "^":
		return 4
	case "==", "!=", "<", "<=", ">", ">=":
		return 3
	case "&&":
		return 2
	case "||":
		return 1
	}
	return 0
}

func (p *printer) formatExpr(e ast.Expr) string {
	switch e := e.(type) {
	case *ast.IntLit:
		return e.Text
	case *ast.FloatLit:
		return e.Text
	case *ast.BoolLit:
		if e.Value {
			return "true"
		}
		return "false"
	case *ast.NilLit:
		return "nil"
	case *ast.StringLit:
		return strconv.Quote(e.Text)
	case *ast.IdentExpr:
		return e.Name
	case *ast.SelectorExpr:
		return p.formatExpr(e.X) + "." + e.Sel
	case *ast.UnaryExpr:
		// Legacy `<-ch` receive form: render as the canonical `read(ch)`
		// so any AST round-trip produces parseable output. Real parser
		// output no longer contains UnaryExpr{Op:"<-"}.
		if e.Op == "<-" {
			return "read(" + p.formatExpr(e.X) + ")"
		}
		// `&mut` is a multi-character keyword-style operator — needs a
		// space before the operand, else `&mut x` round-trips as the
		// unparseable `&mutx`.
		if e.Op == "&mut" {
			return "&mut " + p.formatExpr(e.X)
		}
		return e.Op + p.formatExpr(e.X)
	case *ast.BinaryExpr:
		// Parenthesize each operand if it's a BinaryExpr whose
		// operator has lower precedence than ours (left-associative:
		// same precedence on RHS also requires parens).
		outerP := binaryPrec(e.Op)
		left := p.formatExpr(e.X)
		if be, ok := e.X.(*ast.BinaryExpr); ok && binaryPrec(be.Op) < outerP {
			left = "(" + left + ")"
		}
		right := p.formatExpr(e.Y)
		if be, ok := e.Y.(*ast.BinaryExpr); ok && binaryPrec(be.Op) <= outerP {
			right = "(" + right + ")"
		}
		return left + " " + e.Op + " " + right
	case *ast.CallExpr:
		var sb strings.Builder
		sb.WriteString(p.formatExpr(e.Fun))
		sb.WriteByte('(')
		for i, a := range e.Args {
			if i > 0 {
				sb.WriteString(", ")
			}
			sb.WriteString(p.formatExpr(a))
		}
		sb.WriteByte(')')
		return sb.String()
	case *ast.IndexExpr:
		return p.formatExpr(e.X) + "[" + p.formatExpr(e.Index) + "]"
	case *ast.NewExpr:
		var sb strings.Builder
		sb.WriteString("new")
		if e.HasParens {
			sb.WriteByte('(')
			for i, a := range e.SizeArgs {
				if i > 0 {
					sb.WriteString(", ")
				}
				sb.WriteString(p.formatExpr(a))
			}
			sb.WriteByte(')')
		}
		if e.Type != nil {
			sb.WriteByte(' ')
			sb.WriteString(p.formatType(e.Type))
		}
		if e.HasBraces {
			sb.WriteByte('{')
			first := true
			for _, kv := range e.Pairs {
				if !first {
					sb.WriteString(", ")
				}
				sb.WriteString(kv.Key + ": " + p.formatExpr(kv.Value))
				first = false
			}
			for _, m := range e.MapEntries {
				if !first {
					sb.WriteString(", ")
				}
				sb.WriteString(p.formatExpr(m.Key) + ": " + p.formatExpr(m.Value))
				first = false
			}
			for _, x := range e.SliceElems {
				if !first {
					sb.WriteString(", ")
				}
				sb.WriteString(p.formatExpr(x))
				first = false
			}
			sb.WriteByte('}')
		}
		return sb.String()
	case *ast.FuncLit:
		var sb strings.Builder
		sb.WriteString("fun(")
		for i, prm := range e.Params {
			if i > 0 {
				sb.WriteString(", ")
			}
			if prm.Name != "" {
				sb.WriteString(prm.Name + " ")
			}
			sb.WriteString(p.formatType(prm.Type))
		}
		sb.WriteByte(')')
		if len(e.Results) == 1 {
			sb.WriteByte(' ')
			sb.WriteString(p.formatType(e.Results[0]))
		} else if len(e.Results) > 1 {
			sb.WriteString(" (")
			for i, r := range e.Results {
				if i > 0 {
					sb.WriteString(", ")
				}
				sb.WriteString(p.formatType(r))
			}
			sb.WriteByte(')')
		}
		// Body on one line — multi-line closure pretty-printing is a
		// future widening (the parser accepts the single-line form).
		sb.WriteString(" { ")
		if e.Body != nil {
			for i, st := range e.Body.Stmts {
				if i > 0 {
					sb.WriteString("; ")
				}
				sb.WriteString(p.formatStmtInline(st))
			}
		}
		sb.WriteString(" }")
		return sb.String()
	case *ast.SliceLit:
		var sb strings.Builder
		sb.WriteString("[]" + p.formatType(e.Elem) + "{")
		for i, x := range e.Elems {
			if i > 0 {
				sb.WriteString(", ")
			}
			sb.WriteString(p.formatExpr(x))
		}
		sb.WriteByte('}')
		return sb.String()
	}
	return "<?expr>"
}
