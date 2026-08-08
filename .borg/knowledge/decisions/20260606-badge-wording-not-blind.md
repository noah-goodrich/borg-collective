---
id: 20260606-badge-wording-not-blind
date: '2026-06-16'
project: borg-collective
domain: code-quality
tags:
- deep-research
- verification
- trust
- wording
alternatives: []
applies_to: []
confidence: 0.8
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.478551+00:00'
updated_at: '2026-06-16 10:27:02.478552+00:00'
---

# 20260606-badge-wording-not-blind

## decision

Verification badge must say 'a distinct agent ran and the files prove it' — explicitly NOT 'blind' or 'true blind' (context-blind, not model-blind).

## context

Prior badges claimed 'blind verification' which implies model-level isolation; actual isolation is only at the agent-invocation level (different context window), not model weights or knowledge.

## reasoning

Overclaiming isolation is itself a form of integrity failure. The honest claim — a distinct agent with a separate context ran, and the file artifacts prove it — is both true and verifiable. 'Blind' implies something stronger that the architecture cannot guarantee.
