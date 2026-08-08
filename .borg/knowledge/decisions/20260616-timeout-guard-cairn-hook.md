---
id: 20260616-timeout-guard-cairn-hook
date: '2026-06-16'
project: borg-collective
domain: infrastructure
tags:
- cairn
- hooks
- shell
- reliability
- timeout
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.219011+00:00'
updated_at: '2026-06-16 10:27:02.219012+00:00'
---

# 20260616-timeout-guard-cairn-hook

## decision

Add `timeout 5` guard to `cairn record session` call in borg-link-up.sh to match the existing timeout on `cairn search` in borg-link-down.sh

## context

During /simplify review, parity check between borg-link-up.sh and borg-link-down.sh revealed that borg-link-down.sh already had a timeout guard on its cairn invocation but borg-link-up.sh did not, creating an asymmetry where a hung cairn process could block session startup indefinitely.

## reasoning

Session lifecycle hooks must never block the shell. Timeout parity ensures neither link-up nor link-down can hang on a slow or absent cairn service. Consistency also reduces cognitive overhead when reading both files.
