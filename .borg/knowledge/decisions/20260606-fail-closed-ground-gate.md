---
id: 20260606-fail-closed-ground-gate
date: '2026-06-16'
project: borg-collective
domain: architecture
tags:
- deep-research
- verification
- integrity
- claude-plugins
- research-tools
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.477549+00:00'
updated_at: '2026-06-16 10:27:02.477550+00:00'
---

# 20260606-fail-closed-ground-gate

## decision

Implement a fail-closed ground gate (Directive 01) as a shell-based Stop hook that blocks report delivery unless 6 falsifiable assertions pass — no model involvement, pure file inspection.

## context

Audit of 7+ deep-research runs found that Phase 3.5 'blind' verification is honor-system self-certification: the workflow cannot distinguish 'verifier ran and passed' from 'verifier was skipped.' Two shipped corpora (troth: 65 cards, 0 quote sections, no verification report; reveal: retroactive cached/partial status) are concrete evidence the gate was bypassed without detection.

## reasoning

A prose manifest in SKILL.md cannot enforce itself. Converting post-check to an executable that the Stop hook must pass before output is delivered makes bypass visible as a hard failure rather than a silent omission. Shell-only (no model) keeps the check fast, deterministic, and unbypassable by a downstream LLM rewriting its own evidence.
