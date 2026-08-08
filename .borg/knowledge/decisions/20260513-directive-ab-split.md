---
id: 20260513-directive-ab-split
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- borg-collective
- migration
- directives
- sequencing
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.428148+00:00'
updated_at: '2026-06-11 22:41:19.428148+00:00'
---

# 20260513-directive-ab-split

## decision

Split orchestrator-mode separation (Directive A) and per-project state migration (Directive B) into strictly sequenced directives rather than shipping together

## context

Both changes were related (both touched session classification) but Directive B (moving state out of registry) depends on borg setup being re-run with Directive A's new hooks active. Shipping them together would create an unverifiable intermediate state.

## reasoning

Directive B cannot be safely planned or executed until Directive A is confirmed live in the installed hooks. The stub captures the full plan so no design work is lost, but execution is gated on A being verified.
