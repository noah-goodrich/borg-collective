---
id: obs-20260724-hooks-json-build-list-parity
session_date: '2026-07-24'
project: borg-collective
tool: claude-code
tags:
- hooks
- build
- plugin
- parity
- shellcheck
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-24 05:14:36.295535+00:00'
updated_at: '2026-07-24 05:14:37.898786+00:00'
---

# obs-20260724-hooks-json-build-list-parity

## content

A hook added to hooks.json but omitted from the build-list copy step in scripts/build-plugin.sh will be silently absent from the binary plugin. The hook file exists in the repo but is never packaged. This is undetectable at runtime without explicit parity testing.

## resolution

Added a source-parity bats/test assertion that verifies every hook in hooks.json also appears in the build-list copy step. This test caught the issue pattern during construction and should be maintained as hooks are added.
