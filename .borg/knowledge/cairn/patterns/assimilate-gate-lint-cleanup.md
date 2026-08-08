---
id: assimilate-gate-lint-cleanup
project: cairn
domain: code-quality
tags:
- ruff
- lint
- assimilate
- pre-existing-errors
preconditions: []
steps:
- Run `cairn-lint` as part of the assimilate gate.
- Collect all reported errors (don't fix inline yet — get a full count first).
- Apply ruff autofix for mechanical issues (`ruff check --fix`).
- Add `# noqa` with justification for intentional suppressions (e.g., complex functions
  that can't be trivially decomposed).
- Run `cairn-format` across all modified files.
- Re-run full test suite (`174 passed`) to confirm no logic was changed.
- Commit lint/format fixes as a separate commit from logic changes to keep `git blame`
  clean.
pitfalls:
- A large ruff format pass (20 files) creates a noisy diff that hurts `git blame`.
  Consider whether to squash or keep it as a distinct commit depending on blame sensitivity.
- Autofix can silently remove imports that look unused but are re-exported — review
  removals before committing.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:18.017045+00:00'
updated_at: '2026-06-11 20:31:18.017046+00:00'
---

# assimilate-gate-lint-cleanup

## description

Use the assimilate gate as a forcing function to clear pre-existing lint/format debt before closing a milestone.
