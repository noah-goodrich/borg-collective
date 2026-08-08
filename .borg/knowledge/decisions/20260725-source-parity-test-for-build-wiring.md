---
id: 20260725-source-parity-test-for-build-wiring
date: '2026-07-25'
project: borg-collective
domain: testing
tags:
- bats
- build
- hooks
- ci
- shell
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: null
created_at: '2026-07-25 16:56:41.542395+00:00'
updated_at: '2026-07-25 17:54:08.360727+00:00'
---

# 20260725-source-parity-test-for-build-wiring

## decision

Wiring of the new hook into hooks.json and build-plugin.sh is asserted by a source-parity test rather than relying on manual checklist.

## context

build-plugin.sh must include every hook in both the hooks.json generation and the copy-to-dist list. Missing either step silently ships a broken plugin.

## reasoning

A bats test that diffs the hook registration in hooks.json against the files present in the hooks/ directory catches the class of bug where a hook is coded but not wired (or wired but not copied). This has real failure history in the project pattern.
