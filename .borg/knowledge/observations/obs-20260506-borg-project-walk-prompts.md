---
id: obs-20260506-borg-project-walk-prompts
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- borg-collective
- bash-guard
- permissions
- borg-link
category: tool_behavior
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.325058+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260506-borg-project-walk-prompts

## content

The `/borg-link` skill walks the directory tree looking for `.borg-project` marker files to determine project context. This walk triggers 2 separate bash permission prompts on every invocation because the bash-guard was not pre-approving the specific glob pattern used for marker discovery.

## resolution

Added bash-guard pre-approval for the `.borg-project` marker walk pattern in v0.7.13. If similar repeated prompts appear for other skills, audit the skill's bash calls for filesystem discovery patterns and add targeted pre-approvals rather than broadly loosening bash permissions.
