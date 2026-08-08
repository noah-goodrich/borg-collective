---
id: gnu-bsd-stat-portability-fix
project: borg-collective
domain: code-quality
tags:
- bash
- portability
- gnu
- bsd
- stat
- ci
preconditions: []
steps:
- Identify all uses of stat in shell scripts
- Check whether each call uses -f (BSD) or -c (GNU) format flags
- 'Replace with OS-detection guard: detect darwin vs linux and call the appropriate
  variant'
- Alternatively, use a portable fallback (e.g., wc -c < file for file size)
- Add tests that run on both OS types (or use a matrix in CI)
- Verify CI runs on the non-primary OS — silent RED CI can mask this bug class for
  extended periods
pitfalls:
- BSD stat -f returns garbage on GNU without error — the script appears to succeed
  but produces wrong values. No stderr, no nonzero exit.
- This bug class also appears in locale-sensitive regex (e.g., en-dash matching) —
  audit for both when fixing one
- CI may have been silently RED for many merges before the bug is noticed if the affected
  code path isn't exercised by a value-checking assertion
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.542218+00:00'
updated_at: '2026-06-16 10:27:02.542219+00:00'
---

# gnu-bsd-stat-portability-fix

## description

Fix shell scripts that use stat in a way that silently produces garbage on one OS while appearing to work on the other.
