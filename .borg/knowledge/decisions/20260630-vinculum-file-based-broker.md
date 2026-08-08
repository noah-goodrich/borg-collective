---
id: 20260630-vinculum-file-based-broker
date: '2026-06-30'
project: borg-collective
domain: architecture
tags:
- vinculum
- pubsub
- ipc
- tmux
- resilience
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260630-2202-borg-collective
created_at: '2026-06-30 22:03:12.810429+00:00'
updated_at: '2026-06-30 22:03:12.810432+00:00'
---

# 20260630-vinculum-file-based-broker

## decision

Implement cross-session pubsub as an append-only JSONL log + per-subscriber cursor files with no central broker process

## context

Needed durable messaging between concurrent Claude/tmux sessions; needed to survive crashes and require no daemon management

## reasoning

A central broker process is a single point of failure — if it crashes, all subscribers lose messages. File-based append-only logs are crash-safe by nature; cursor files per subscriber give N-subscriber fan-out without coordination. The filesystem IS the broker.
