---
id: 20260715-usage-watch-fail-closed-regex
date: '2026-07-15'
project: borg-collective
domain: code-quality
tags:
- usage-guardian
- regex
- parsing
- fail-closed
- borg-usage-watch
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260715-0256-borg-collective
created_at: '2026-07-15 02:57:12.423230+00:00'
updated_at: '2026-07-15 02:57:12.423232+00:00'
---

# 20260715-usage-watch-fail-closed-regex

## decision

Make the reset-clause suffix optional in the usage-watch session-percentage regex, while preserving fail-closed behavior for empty/garbage input

## context

The regex at bin/borg-usage-watch:171 required a '· resets' suffix after the percentage, but Claude Code omits this suffix when session usage is exactly 0%. This caused 582/591 observed parse_failed events to be misclassifications of legitimate 0%-idle polls.

## reasoning

The suffix is absent in a real, common state (0% usage). Making it optional fixes the false-positive storm without weakening the fail-closed guarantee: empty or genuinely malformed lines still produce parse_failed, because the required percentage-capture group is still enforced.
