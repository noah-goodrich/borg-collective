---
id: obs-20260616-severed-coverage-gap-in-skills
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- severed-projects
- skills
- cli
- documentation-gap
- borg-link
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.213531+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-severed-coverage-gap-in-skills

## content

The docs/plans/severed/ directory and the concept of severed project state had no coverage in the borg-link skill or CLI. An audit of briefs references found zero stale refs, but the severed coverage gap was a real documentation hole — operators using /borg-link-up would not know how to handle severed project state.

## resolution

Severed coverage gap documented in skills/borg-link/SKILL.md data contract section. Full docs sweep (architecture.md, skills-guide.md, devcontainer-coco.md, boris-workflow.md, cheatsheet.md, six-pager.md) queued as a follow-up task.
