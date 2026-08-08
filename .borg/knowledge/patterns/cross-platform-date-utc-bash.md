---
id: cross-platform-date-utc-bash
project: borg-collective
domain: testing
tags:
- bash
- date
- bsd
- gnu
- timezone
- ci
preconditions: []
steps:
- Identify all `date` invocations that parse or format UTC timestamps.
- 'For BSD compatibility: add `-u` flag to the `date` call.'
- 'For GNU compatibility: prefix the invocation with `TZ=UTC`.'
- 'Apply both in the same line: `TZ=UTC date -u -j -f ...` (BSD ignores `TZ=UTC`;
  GNU ignores `-j`).'
- Add TZ-boundary tests in the test suite that explicitly set `TZ` to a non-UTC zone
  and assert correct UTC behavior.
- Run CI matrix with both GNU and BSD `date` to verify.
pitfalls:
- Omitting `-u` on BSD causes silent wrong results — no error is thrown, the timestamp
  is just offset by the local timezone.
- '`TZ=UTC` alone is insufficient on BSD for `-j -f` parsing paths.'
- A 'known bug, do not fix here' comment in the source is not a substitute for an
  actual fix or a test that would catch regressions.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.560325+00:00'
updated_at: '2026-06-11 22:41:19.560325+00:00'
---

# cross-platform-date-utc-bash

## description

Pattern for writing portable UTC `date` parsing in bash scripts that must pass CI on both BSD (macOS) and GNU (Linux).
