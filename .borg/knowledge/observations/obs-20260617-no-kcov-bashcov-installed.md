---
id: obs-20260617-no-kcov-bashcov-installed
session_date: '2026-06-17'
project: borg-collective
tool: claude-code
tags:
- coverage
- kcov
- bashcov
- zsh
- bash
- tooling
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-17 18:03:01.147671+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260617-no-kcov-bashcov-installed

## content

Neither kcov nor bashcov is installed in this environment, making automated line/branch coverage measurement for shell scripts impossible without first provisioning tooling. The coverage question had to be answered via static function-level analysis instead.

## resolution

Use the qualitative function-enumeration pattern (see qualitative-coverage-map-without-tooling) as a stopgap. If real coverage metrics are needed, install kcov (C tool, requires build) or bashcov (Ruby gem) before the next test sprint.
