// Package printer walks a volt AST and emits canonical formatted
// source. v0.4 covers the common shapes used in testdata; some edge
// cases may format unconventionally and can be refined later.
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
)

// Format returns the canonical source for the given file.
func Format(file *ast.File) string {
	p := &printer{}
	p.printFile(file)
	return p.b.String()
}

type printer struct {
	b      strings.Builder
	indent int
}

func (p *printer) writeIndent() {
	for i := 0; i < p.indent; i++ {
		p.b.WriteByte('\t')
	}
}

func (p *printer) line(s string) {
	p.writeIndent()
	p.b.WriteString(s)
	p.b.WriteByte('\n')
}

func (p *printer) raw(s string) {
	p.b.WriteString(s)
}

// ---------------------------------------------------------------------
// Top-level
// ---------------------------------------------------------------------

func (p *printer) printFile(f *ast.File) {
	p.line("package " + f.Package)

	if len(f.Imports) > 0 {
		p.b.WriteByte('\n')
		if len(f.Imports) == 1 {
			p.line(`import "` + f.Imports[0].Path + `"`)
		} else {
			p.line("import (")
			p.indent++
			for _, im := range f.Imports {
				p.line(`"` + im.Path + `"`)
			}
			p.indent--
			p.line(")")
		}
	}

	for _, d := range f.Decls {
		p.b.WriteByte('\n')
		p.printDecl(d)
	}
}

func (p *printer) printDecl(d ast.Decl) {
	switch d := d.(type) {
	case *ast.TypeDecl:
		p.printTypeDecl(d)
	case *ast.FuncDecl:
		p.printFuncDecl(d)
	}
}

func (p *printer) printTypeDecl(d *ast.TypeDecl) {
	if st, ok := d.Type.(*ast.StructType); ok {
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
			p.line(fmt.Sprintf("%-*s %s", nameWidth, f.Name, p.formatType(f.Type)))
		}
		p.indent--
		p.line("}")
		return
	}
	p.line("type " + d.Name + " " + p.formatType(d.Type))
}

func (p *printer) printFuncDecl(d *ast.FuncDecl) {
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
	if len(d.Results) > 0 {
		p.raw(" " + p.formatType(d.Results[0]))
	}
	if d.Body != nil {
		p.raw(" {\n")
		p.indent++
		for _, s := range d.Body.Stmts {
			p.printStmt(s)
		}
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
		return "&" + p.formatType(t.Elem)
	case *ast.PointerType:
		return "*" + p.formatType(t.Elem)
	case *ast.SliceType:
		return "[]" + p.formatType(t.Elem)
	case *ast.StructType:
		// Anonymous structs: rare in v0.4; emit single-line.
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
	switch s := s.(type) {
	case *ast.ExprStmt:
		p.line(p.formatExpr(s.Expr))
	case *ast.VarStmt:
		p.printVarStmt(s)
	case *ast.AssignStmt:
		p.line(p.formatExpr(s.LHS) + " = " + p.formatExpr(s.RHS))
	case *ast.RetStmt:
		switch len(s.Values) {
		case 0:
			p.line("ret")
		case 1:
			p.line("ret " + p.formatExpr(s.Values[0]))
		default:
			parts := make([]string, len(s.Values))
			for i, v := range s.Values {
				parts[i] = p.formatExpr(v)
			}
			p.line("ret " + strings.Join(parts, ", "))
		}
	case *ast.IfStmt:
		p.printIfStmt(s, false)
	case *ast.ForStmt:
		p.printForStmt(s)
	case *ast.SwitchStmt:
		p.printSwitchStmt(s)
	case *ast.DeferStmt:
		p.line("def " + p.formatExpr(s.Call))
	case *ast.RunStmt:
		p.line("run " + p.formatExpr(s.Call))
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

func (p *printer) printVarStmt(s *ast.VarStmt) {
	if s.Type == nil && s.Value != nil {
		p.line(s.Name + " := " + p.formatExpr(s.Value))
		return
	}
	out := "var " + s.Name
	if s.Type != nil {
		out += " " + p.formatType(s.Type)
	}
	if s.Value != nil {
		out += " = " + p.formatExpr(s.Value)
	}
	p.line(out)
}

func (p *printer) printIfStmt(s *ast.IfStmt, asElseIf bool) {
	prefix := ""
	if asElseIf {
		prefix = "} else "
	}
	p.writeIndent()
	p.raw(prefix + "if " + p.formatExpr(s.Cond) + " {\n")
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
	}
	return ""
}

// ---------------------------------------------------------------------
// Expressions
// ---------------------------------------------------------------------

func (p *printer) formatExpr(e ast.Expr) string {
	switch e := e.(type) {
	case *ast.IntLit:
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
		return e.Op + p.formatExpr(e.X)
	case *ast.BinaryExpr:
		return p.formatExpr(e.X) + " " + e.Op + " " + p.formatExpr(e.Y)
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
		sb.WriteString("new ")
		sb.WriteString(p.formatType(e.Type))
		if e.Pairs != nil {
			sb.WriteByte('{')
			for i, kv := range e.Pairs {
				if i > 0 {
					sb.WriteString(", ")
				}
				sb.WriteString(kv.Key + ": " + p.formatExpr(kv.Value))
			}
			sb.WriteByte('}')
		} else {
			sb.WriteByte('(')
			for i, a := range e.Args {
				if i > 0 {
					sb.WriteString(", ")
				}
				sb.WriteString(p.formatExpr(a))
			}
			sb.WriteByte(')')
		}
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
