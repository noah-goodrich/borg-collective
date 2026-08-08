---
id: obs-20260611-borg-link-no-arg-ambiguity
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- borg-link
- skills
- project-detection
- .borg-project
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.461818+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-borg-link-no-arg-ambiguity

## content

borg-link invoked with no arguments had no defined behavior. The intended semantics depend on context: if a .borg-project marker exists in the working directory, no-arg means deep-dive on the current project; if no marker exists, it means overview of everything.

## resolution

Codified both branches explicitly in SKILL.md Modes and When-to-use sections. The .borg-project marker file is the disambiguation signal.
