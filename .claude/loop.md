Pick the next READY item from TODO.md (skip items marked BLOCKED or
DONE). Implement it according to CLAUDE.md execution policy. When
complete:

1. Run the full regression: build the compiler, build every
   tests-internal/*.volt, run each binary, verify only the 41
   expected-negative tests fail and 0 binaries crash.
2. Add a one-line entry to memory/project_roadmap.md under the
   appropriate pass-N section describing what landed.
3. Mark the TODO.md item ~~struck through~~ to indicate DONE.
4. Stop. One item per turn.

If you hit a true blocker (the item is impossible without redesign),
mark it BLOCKED in TODO.md with a one-line reason and pick the next
READY item instead. Do NOT pause to ask.

If the regression breaks while implementing, fix the regression
first (that takes priority over completing the item). The codebase
must be green at the end of every turn.

Decision rule: when in doubt, pick the option closest to existing
patterns and proceed. Do not stop to ask routine questions — read
memory/project_v1_decisions.md and CLAUDE.md, follow the rules,
keep going.
