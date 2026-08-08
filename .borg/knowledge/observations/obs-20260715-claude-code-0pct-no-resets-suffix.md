---
id: obs-20260715-claude-code-0pct-no-resets-suffix
session_date: '2026-07-15'
project: borg-collective
tool: claude-code
tags:
- usage-guardian
- parsing
- claude-code
- ui-format
- 0-percent
- parse_failed
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260715-0256-borg-collective
superseded_by: null
created_at: '2026-07-15 02:57:12.426155+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260715-claude-code-0pct-no-resets-suffix

## content

Claude Code renders session usage differently at exactly 0%: it outputs 'Current session: 0% used' with no '· resets <timestamp>' suffix. At any nonzero percentage the suffix is always present. Any parser that requires the suffix will misclassify all 0%-idle polls as parse failures. In the observed dataset this accounted for 582 of 591 parse_failed events (~98.5%) and caused a ~6-hour false-alarm block on 2026-07-14.

## resolution

Make the reset-clause suffix optional in the regex (PR #80). Regression test added using tests/fixtures/usage-output-idle.txt.
