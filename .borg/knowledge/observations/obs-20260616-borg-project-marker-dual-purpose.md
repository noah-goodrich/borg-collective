---
id: obs-20260616-borg-project-marker-dual-purpose
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- borg-link
- .borg-project
- project-detection
- skill-design
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.420578+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-borg-project-marker-dual-purpose

## content

The .borg-project marker file serves dual purpose: (1) marks a directory as a borg-aware project root, and (2) can now be used by skills like borg-link to make invocation context-sensitive. Skills should check for this file when no-arg invocation needs to be context-aware.

## resolution

Documented in SKILL.md update. Future skills that need 'am I inside a project?' detection should use .borg-project presence rather than inventing new signals.
