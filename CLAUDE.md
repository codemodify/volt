# CLAUDE.md — volt project execution policy

You are working on **volt**, a Go-syntax / Rust-memory language. The
roadmap and design decisions are documented; your job is to execute
without re-asking what's already been decided.

## Decision authority — DO NOT ASK, JUST DECIDE

When you hit a choice point, apply this hierarchy:

1. **Already decided** — check `memory/project_v1_decisions.md` first.
   The five load-bearing decisions are locked in: simple sentinel
   errors (no Unwrap), Drop-auto-close on files, OS threads + worker
   pool, fmt/log split (stdout/stderr), git-URL package management.

2. **Pattern match** — look for the closest existing item in the
   codebase and follow its shape. Volt has strong style conventions:
   - `new {...}` (with space) for "no size" composite literals
   - `new(N) T {...}` with size before init
   - `:=` no spaces
   - tabs in code, 4-space manual indent only in `docs/design/*.volt`
   - Method receiver pointer: `fun (r *T) Name() …`
   - Per-type detection for ownership transfer (Copy primitives copy;
     movables move; reference handles like chan/mutex share)

3. **Pick simplest** — if no precedent, pick the simplest viable
   option and proceed. Document the choice in the commit message.
   Never agonize over reversible decisions.

4. **Only ask when:**
   - The change would alter the existing public spec in
     `docs/design/0-intent.volt` (the canonical syntax/semantics
     reference).
   - The change requires destructive git operations (force push to
     dev/main, reset --hard with uncommitted work, branch deletion).
   - You discover that an item in the roadmap is impossible given
     current architecture and the workaround is itself a major
     redesign.

   Routine compiler/runtime/stdlib decisions: just decide.

## What "done" means for any roadmap item

Mark complete only when ALL of:

1. **Compiler builds clean:** `go build -o .tempbins/volt ./cmd/volt`
   (no errors, IDE diagnostics info-level only).
2. **Regression passes:** every test in `tests-internal/` either
   builds + runs without crashing, OR is in the known set of 57
   expected-negative tests that intentionally fail compilation
   (aliasing, assign_type_mismatch_reject,
   binop_type_mismatch_reject, branch_move,
   c8_double_borrow_reject, c8_mut_during_borrow_reject,
   c13_closure_escape_reject, c13_storage_escape_reject,
   call_nonfn_reject,
   chan_contract_param_reject, chan_dir_param_reject,
   composite_type_mismatch_reject, const_cycle_reject,
   const_var_collide_reject, cross_pkg_borrow_reject,
   dup_closure_param_reject,
   dup_field_lit_reject, dup_field_reject,
   dup_iface_method_reject, dup_iface_param_reject,
   dup_multivar_reject, dup_param_reject,
   dup_var_same_scope_reject, escape_borrow, field_move_reject,
   field_on_nonstruct_reject, field_typo_suggest_reject,
   fn_const_collide_reject, has_tests, partial_borrow_conflict_reject,
   iface_missing_method_reject, iface_sig_mismatch_reject,
   ident_typo_suggest_reject, main_signature_reject,
   method_arg_borrow_reject, move_xpkg,
   pkg_func_typo_reject, recursive_struct_reject,
   reborrow_mut_via_shared_reject,
   ret_type_mismatch_reject, run_borrow_reject,
   rwmutex_readonly_reject, struct_eq_reject,
   type_mismatch_reject, unknown_field_lit_reject,
   unknown_type_param_reject, unknown_type_reject,
   use_after_move, var_shadows_param_reject,
   xpkg_method_borrow_reject, copy_drop_reject,
   ptr_write_xor_reject, return_param_borrow_reject,
   ret_borrow_escape_reject, closure_arg_borrow_escape_reject,
   move_on_insert_reject, chan_deadlock_reject).
   One test is neither positive nor build-negative: `chan_deadlock_runtime`
   BUILDS fine but is EXPECTED to abort at runtime (rc=1) via the deadlock
   backstop within ~1.25s — the harness runs it expecting that clean abort
   (a hang → timeout, or rc=0/42, is a failure).
3. **Targeted test exists:** every new feature has at least one
   `tests-internal/<name>.volt` that exercises it end-to-end.
4. **Design doc reflects it:** if the feature is user-visible, the
   relevant `docs/design/*.volt` or `0-intent.volt` shows the syntax.
5. **Memory updated:** add a one-line pass note to
   `memory/project_roadmap.md` describing what landed.

If any of these fail, the item stays IN PROGRESS, not DONE.

## Project conventions

- **Build artifacts:** `.tempbins/` only. Never leave binaries at
  repo root. After `volt build foo.volt`, `mv foo .tempbins/`.
- **Design docs are hand-formatted:** never run `volt fmt -w` on
  `docs/design/*.volt`. They're the spec; alignment is manual.
- **String of operations:** read → check → edit → build → run
  regression. If regression breaks, fix before moving on.
- **No commits unless asked:** make changes and run tests; the user
  reviews and commits.
- **Atomic ops:** `Read` / `Write` / `Add` / `CompSwap` (NOT Load /
  Store / CompareAndSwap — those were renamed).
- **Channels:** unbuffered by default (`new()`), `chan read T` /
  `chan write T` for direction, `chan11/1N/N1/NN` for multiplicity
  contracts.
- **Errors:** simple sentinels (`errors.New(msg)`), `==` for
  comparison, NO `Unwrap` / `errors.Is` / `errors.As`.

## Verification commands

```bash
# Build
go build -o .tempbins/volt ./cmd/volt

# Full regression — copy/paste these scripts
/tmp/smoke.sh           # see scripts/smoke.sh
/tmp/run_smoke2.sh      # see scripts/run_smoke2.sh
```

(The smoke scripts live at `/tmp/smoke.sh` and `/tmp/run_smoke2.sh`
in this dev environment; re-create them from `scripts/` if missing.)

## Where to find context

- `memory/MEMORY.md` — index to all persistent memories
- `memory/project_v1_decisions.md` — the 5 locked-in design decisions
- `memory/project_roadmap.md` — chronological pass-by-pass history
- `TODO.md` — outstanding work items, marked DONE/IN PROGRESS/READY
- `docs/design/0-intent.volt` — canonical syntax/semantics reference
- `docs/design/3-concurrency.{md,volt}` — concurrency primitives
- `internal/runtime/asm/runtime.c` — runtime (alloc, chan, sync, etc.)
- `internal/codegen/codegen.go` — main codegen
- `internal/check/check.go` + `chan_contract.go` — ownership checker
- `internal/stdlib/` — embedded stdlib packages

## When the loop runs you

If you're being invoked by `/loop` or a scheduled agent: pick the
next item from TODO.md that's marked READY, implement it according
to the rules above, run the regression, update memory, and STOP for
this turn. Don't try to do five items at once — one item per turn,
clean.
