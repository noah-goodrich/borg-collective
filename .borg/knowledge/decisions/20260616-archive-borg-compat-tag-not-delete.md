---
id: 20260616-archive-borg-compat-tag-not-delete
date: '2026-06-16'
project: borg-collective
domain: infrastructure
tags:
- git
- branch-management
- archival
- claude-plugins
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.553834+00:00'
updated_at: '2026-06-16 10:27:02.553835+00:00'
---

# 20260616-archive-borg-compat-tag-not-delete

## decision

Archive the `borg-compat` branch (3 unmerged commits, 3269 lines) to tag `archive/borg-compat` before deleting, rather than hard-deleting

## context

borg-compat was superseded by claude-plugins and a dead dev.sh; it had unmerged commits that could not be recovered from branch history after deletion.

## reasoning

The tag preserves the ref permanently and cheaply. Future sessions can inspect what was abandoned without risking silent loss of potentially useful code.
