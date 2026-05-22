// Package types implements the volt type checker.
//
// The type checker walks the AST, resolves names across imports,
// determines the type of every expression, and reports type errors.
// Borrow checking is a separate pass — added in v0.2.
package types

import "github.com/codemodify/volt/internal/ast"

// Checker performs type checking on a File.
type Checker struct {
	// TODO (v0.1a): scopes, symbol tables, package symbol resolution.
}

// New returns a fresh Checker.
func New() *Checker {
	return &Checker{}
}

// Check type-checks the given file and returns any errors encountered.
func (c *Checker) Check(file *ast.File) error {
	// TODO (v0.1a): walk decls, resolve names, check signatures.
	return nil
}
