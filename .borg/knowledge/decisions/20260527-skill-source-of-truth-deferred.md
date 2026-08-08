---
id: 20260527-skill-source-of-truth-deferred
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- skill-files
- cross-project
- claude-plugins
- source-of-truth
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.445907+00:00'
updated_at: '2026-06-11 22:41:19.445908+00:00'
---

# 20260527-skill-source-of-truth-deferred

## decision

The question of which repo (borg-collective vs claude-plugins) owns skill files is deliberately left unresolved and captured as a handoff item rather than decided unilaterally by the AI agent.

## context

Both repos appear to carry copies of skill files. Deleting or re-symlinking in either direction has cross-project consequences.

## reasoning

The decision has downstream effects on claude-plugins that require human judgment about ownership and distribution strategy. Making the call without Noah risks invalidating the other repo's structure.
