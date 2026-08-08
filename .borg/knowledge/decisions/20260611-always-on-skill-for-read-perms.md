---
id: 20260611-always-on-skill-for-read-perms
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- skills
- claude
- permissions
- always-on
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:24.964847+00:00'
updated_at: '2026-06-11 20:39:24.964848+00:00'
---

# 20260611-always-on-skill-for-read-perms

## decision

Encode the read-permission rule as a SKILL.md (auto-installed) rather than relying solely on global CLAUDE.md

## context

Global CLAUDE.md entries can be missed if the file isn't synced or if Claude's context window deprioritizes it. The no-unnecessary-read-perms rule was being violated.

## reasoning

Skills are installed per-project and surface in the active context more reliably than a global config entry. Making it always-on (no trigger) means it applies without any invocation.
