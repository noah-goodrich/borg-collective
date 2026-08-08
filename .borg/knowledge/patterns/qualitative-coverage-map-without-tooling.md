---
id: qualitative-coverage-map-without-tooling
project: borg-collective
domain: testing
tags:
- test-coverage
- zsh
- shell
- coverage-analysis
- kcov
preconditions: []
steps:
- List all function definitions across lib/*.zsh and lib/*.sh (grep for '^function
  ' or '^_.*(')
- List all function calls appearing in test files
- 'Produce a two-column map: function name | covered (Y/N)'
- Compute raw ratio (covered/total) as the headline estimate
- Group zero-coverage functions by source file to identify highest-leverage test targets
- Call out whether gaps are untestable (e.g., OS-specific notify) vs. merely untested
pitfalls:
- Function calls inside sourced helpers may not appear directly in test files — trace
  one level deeper
- A function 'called' in tests but only via a mock stub should be counted as uncovered
  for logic purposes
- lib/tmux.zsh and lib/desktop.zsh tend to be zero-covered because they require live
  display state — note this explicitly so the gap isn't filed as a bug
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.529179+00:00'
updated_at: '2026-06-11 22:41:19.529180+00:00'
---

# qualitative-coverage-map-without-tooling

## description

When kcov/bashcov are unavailable, produce a function-level coverage estimate by cross-referencing test files against lib/* function definitions and grouping uncovered functions by file.
