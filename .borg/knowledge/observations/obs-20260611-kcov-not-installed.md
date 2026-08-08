---
id: obs-20260611-kcov-not-installed
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- test-coverage
- kcov
- bashcov
- zsh
- tooling-gap
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.529515+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-kcov-not-installed

## content

Neither kcov nor bashcov is installed in the dev environment. There is no instrumented coverage baseline for the borg-collective shell codebase. The ~69% figure (44/64 functions) is a manual estimate, not a measured value.

## resolution

Accept qualitative map for planning purposes. If a precise baseline is needed, install kcov via brew and wrap the test runner. Document the gap so future sessions don't assume a coverage number exists in CI.
