---
id: 20260507-nanoprobe-v2-severed-from-v1
date: '2026-06-16'
project: borg-collective
domain: architecture
tags:
- nanoprobe
- orchestration
- agentic
- directive
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.348200+00:00'
updated_at: '2026-06-16 10:27:02.348201+00:00'
---

# 20260507-nanoprobe-v2-severed-from-v1

## decision

Sever the v1 agentic orchestrator directive and rewrite as nanoprobe v2 rather than iterating on v1

## context

Multi-persona architectural review surfaced that the v1 directive had unverified assumptions about SubagentStop hook behavior and worktree × drone exec compatibility.

## reasoning

Verification spike showed enough of v1's assumptions were wrong or unconfirmed that patching it risked compounding errors. A clean v2 based on verified findings is lower risk.
