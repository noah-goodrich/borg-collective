---
id: homebrew-formula-atomic-release-per-fix
project: borg-collective
domain: infrastructure
tags:
- homebrew
- formula
- releases
- sha256
- versioning
preconditions: []
steps:
- Identify the minimal independent fix (one logical change per release).
- Commit and push the fix to the repo.
- Generate a new archive tarball and compute its SHA256.
- Bump the version in Formula/<name>.rb and update the SHA256.
- Tag and push the release.
- Repeat for each subsequent independent fix.
pitfalls:
- Batching multiple independent fixes into one release makes future bisection harder
  — resist the temptation even under time pressure.
- SHA256 must be recomputed from the actual release tarball, not the source tree,
  since GitHub archive generation can differ.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.114549+00:00'
updated_at: '2026-06-11 20:39:25.114550+00:00'
---

# homebrew-formula-atomic-release-per-fix

## description

Workflow for iterating on a Homebrew formula through multiple rapid patch releases during an active debugging session, maintaining bisectability.
