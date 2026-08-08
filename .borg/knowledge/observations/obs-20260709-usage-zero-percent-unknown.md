---
id: obs-20260709-usage-zero-percent-unknown
session_date: '2026-07-09'
project: borg-collective
tool: claude-code
tags:
- claude
- /usage
- parsing
- edge-case
- phase-2
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260709-1659-borg-collective
superseded_by: null
created_at: '2026-07-09 17:01:17.388708+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260709-usage-zero-percent-unknown

## content

What /usage prints at 0% usage and at >=95% usage is unknown — zero observations exist at either limit, which are exactly the regimes Phase 2 must act in. A 6-hour blind window (07:00–13:58 UTC) strongly suggests /usage omits the 'Current session' line at 0%, causing parse failures.

## resolution

Raw-output logging added in #68 will capture the output at the next window rollover. Check usage-watch.log for 'output excerpt' lines after the next 0% period. Do not write Phase 2 parsing logic until both edge cases are observed.
