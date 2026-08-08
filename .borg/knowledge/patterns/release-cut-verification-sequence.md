---
id: release-cut-verification-sequence
project: borg-collective
domain: infrastructure
tags:
- release
- homebrew
- sha256
- tagging
- workflow
preconditions: []
steps:
- Run full test suite; confirm 0 failures
- Verify working tree is clean (`git status`)
- Cut and push the version tag
- Download the release tarball and compute sha256
- Update Homebrew formula with new version and sha256
- Push main (and formula if in same repo)
pitfalls:
- Tagging before the working tree is clean embeds dirty state in the release
- Forgetting to update the formula sha256 causes `brew install` to fail on checksum
  mismatch
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.347891+00:00'
updated_at: '2026-06-11 22:41:19.347892+00:00'
---

# release-cut-verification-sequence

## description

Sequence for cutting a clean release: all tests green → clean working tree → tag → verify tarball sha256 → update formula → push
