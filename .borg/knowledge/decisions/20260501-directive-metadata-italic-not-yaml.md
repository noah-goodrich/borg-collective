---
id: 20260501-directive-metadata-italic-not-yaml
date: '2026-06-11'
project: borg-collective
domain: documentation
tags:
- directives
- metadata
- conventions
- frontmatter
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.355204+00:00'
updated_at: '2026-06-11 22:41:19.355204+00:00'
---

# 20260501-directive-metadata-italic-not-yaml

## decision

Use italic inline metadata lines (`*Parent plan: <slug>*`) instead of YAML frontmatter for directive back-links

## context

Orphan-prevention directive initially designed with YAML frontmatter for parent plan references; existing reveal directives use italic-line style

## reasoning

Consistency with existing directive corpus; italic lines are visible in rendered markdown without tooling; no parser dependency
