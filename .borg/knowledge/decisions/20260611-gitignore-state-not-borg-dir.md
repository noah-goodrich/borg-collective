---
id: 20260611-gitignore-state-not-borg-dir
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- borg-collective
- gitignore
- install
- borg-setup
- bug
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.484944+00:00'
updated_at: '2026-06-11 22:41:19.484944+00:00'
---

# 20260611-gitignore-state-not-borg-dir

## decision

install.sh should append only .borg/state.json (the specific runtime file) to each project's .gitignore, NOT the entire .borg/ directory.

## context

PR #29 fixed an erroneous .borg/ line in the repo's own .gitignore, but the root cause in install.sh was not addressed. borg setup re-injects .borg/ on every run, undoing the fix.

## reasoning

Ignoring .borg/ wholesale would hide any tracked files stored under that directory (e.g. config, templates). Only the volatile runtime file state.json needs to be excluded from version control.
