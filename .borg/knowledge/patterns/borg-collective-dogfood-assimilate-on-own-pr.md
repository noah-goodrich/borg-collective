---
id: borg-collective-dogfood-assimilate-on-own-pr
project: borg-collective
domain: testing
tags:
- borg-collective
- borg-assimilate
- dogfooding
- acceptance-testing
preconditions: []
steps:
- Write a temporary 02-output extension at the per-machine config path
- Run /borg-assimilate on the feature PR
- Confirm the extension content was loaded and influenced output
- Remove the temporary extension
pitfalls:
- This only works after the release is installed on the target machine — the protocol
  must be live before dogfooding is possible.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.393637+00:00'
updated_at: '2026-06-11 22:41:19.393637+00:00'
---

# borg-collective-dogfood-assimilate-on-own-pr

## description

After shipping a protocol change to borg-assimilate, dogfood the change by running /borg-assimilate on the PR that introduced the change itself, using a temporary test extension to exercise the new load points.
