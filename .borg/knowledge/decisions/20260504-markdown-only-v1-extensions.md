---
id: 20260504-markdown-only-v1-extensions
date: '2026-06-16'
project: borg-collective
domain: architecture
tags:
- claude-code
- skills
- extensibility
- markdown
- scope-limiting
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.299318+00:00'
updated_at: '2026-06-16 10:27:02.299319+00:00'
---

# 20260504-markdown-only-v1-extensions

## decision

v1 of the skill extension protocol supports markdown files only — no executable scripts, no dynamic content generation at load time.

## context

Designing the minimum viable protocol for injecting local context into skills.

## reasoning

Markdown-only keeps the protocol simple, auditable, and safe. Executable extensions would introduce security surface area and complexity that isn't justified until there's evidence of need. The JIRA use case (injecting ticket data) requires a shell command to fetch content, but the extension file itself describes the instruction to Claude rather than executing the fetch — Claude handles the tool call.
