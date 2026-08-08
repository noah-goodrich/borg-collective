---
id: 20260715-agents-additive-sync-loop
date: '2026-07-15'
project: borg-collective
domain: infrastructure
tags:
- agent-roster
- sync-plugin
- distro
- source-of-truth
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260715-0256-borg-collective
created_at: '2026-07-15 02:57:12.425467+00:00'
updated_at: '2026-07-15 02:57:12.425468+00:00'
---

# 20260715-agents-additive-sync-loop

## decision

Extend sync-plugin.sh with an additive, existing-targets-only loop over agents/ rather than a full bidirectional sync or a separate sync script

## context

Five agents existed only in the claude-plugins distro, violating the source→distro invariant. The fix needed to back-port them to agents/ and keep future drift detectable.

## reasoning

An existing-targets-only additive loop is the minimal, safe change: it only writes files that already have a corresponding destination, preventing accidental creation of stale entries in the distro. A full bidirectional sync risked overwriting or creating unintended files.
