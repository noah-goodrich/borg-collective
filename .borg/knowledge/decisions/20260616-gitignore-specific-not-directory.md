---
id: 20260616-gitignore-specific-not-directory
date: '2026-06-16'
project: borg-collective
domain: infrastructure
tags:
- gitignore
- install.sh
- borg-setup
- bug-fix
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.448656+00:00'
updated_at: '2026-06-16 10:27:02.448656+00:00'
---

# 20260616-gitignore-specific-not-directory

## decision

install.sh should append only specific runtime exclusions (e.g. .borg/state.json) to per-project .gitignore files, NOT the entire .borg/ directory.

## context

PR #29 fixed an erroneous .borg/ line in .gitignore, but the root cause in install.sh was not addressed. borg setup continued to re-inject .borg/ on every run.

## reasoning

Ignoring the entire .borg/ directory would hide potentially useful tracked files (hooks, config) inside that directory. Only volatile runtime state (state.json) should be excluded from version control.
