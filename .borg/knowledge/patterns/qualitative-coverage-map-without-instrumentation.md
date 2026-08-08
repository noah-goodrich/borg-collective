---
id: qualitative-coverage-map-without-instrumentation
project: borg-collective
domain: testing
tags:
- coverage
- zsh
- bash
- kcov
- bashcov
- audit
preconditions: []
steps:
- Enumerate all functions defined across lib/*.zsh and lib/*.sh (e.g., grep -n '^function\|^_[a-z]'
  or equivalent).
- For each function, grep the test files for any invocation by name.
- Classify each function as exercised (≥1 test call) or zero-coverage (no test call).
- Group zero-coverage functions by file to surface structural gaps (e.g., entire lib/tmux.zsh
  untouched).
- Report as a ratio (exercised/total) with the zero-coverage cluster called out explicitly.
pitfalls:
- A function appearing in a test file as a string (e.g., in a mock or comment) is
  not the same as being invoked—verify the grep matches are actual call sites.
- Helper functions called only by other lib functions (not directly by tests) will
  appear as zero-coverage even if they're transitively exercised; note this distinction.
- This method cannot detect branch coverage or partial execution paths—it only surfaces
  unexercised entry points.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.512711+00:00'
updated_at: '2026-06-16 10:27:02.512712+00:00'
---

# qualitative-coverage-map-without-instrumentation

## description

When no coverage tool (kcov, bashcov, etc.) is available, produce a function-level qualitative coverage map by cross-referencing all defined functions against the test suite's explicit call sites.
