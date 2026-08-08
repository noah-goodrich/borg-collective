---
id: obs-20260504-dogfood-assimilate-with-extension
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- borg-assimilate
- skill-extensions
- dogfooding
- testing
category: pattern_discovered
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.301916+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260504-dogfood-assimilate-with-extension

## content

The planned approach for testing the borg-assimilate load points is to write a temporary `02-output` extension, run `/borg-assimilate` on PR #20 itself, then remove the extension. This is a clean dogfooding pattern — using the feature being shipped to validate itself — but requires care to remove the test extension afterward to avoid polluting the local environment.

## resolution

When dogfooding assimilate load points: (1) write minimal test extension, (2) run assimilate, (3) confirm load point fired, (4) immediately remove test extension. Document the remove step explicitly in the plan to avoid leaving test artifacts.
