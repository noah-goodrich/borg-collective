---
id: 20260504-three-load-points-per-skill
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- borg-collective
- skill-extensions
- load-points
- protocol-design
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.392223+00:00'
updated_at: '2026-06-11 22:41:19.392224+00:00'
---

# 20260504-three-load-points-per-skill

## decision

Standardize on exactly three load-point blocks per skill: 01-context (before planning/review begins), 02-output (before writing artifacts), 03-followup (after writing artifacts).

## context

The extension protocol needed a consistent, predictable structure so extension authors know where to inject content without reading the full skill.

## reasoning

Three points cover the three natural phases of a skill execution (pre-reasoning, pre-write, post-write) without over-engineering. Numbered prefixes ensure deterministic load order if multiple files exist.
