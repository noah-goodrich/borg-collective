---
id: 20260724-dispatch-guard-no-poller-change
date: '2026-07-24'
project: borg-collective
domain: architecture
tags:
- hooks
- usage-guardian
- coupling
- separation-of-concerns
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: null
created_at: '2026-07-24 05:14:36.291735+00:00'
updated_at: '2026-07-24 05:14:37.809065+00:00'
---

# 20260724-dispatch-guard-no-poller-change

## decision

The dispatch guard reads the existing usage-samples.jsonl file directly—no changes to the poller, no new IPC, no shared state beyond the file.

## context

Needed a way for the hook to know current usage without adding a daemon dependency or new communication channel.

## reasoning

The poller already writes samples to a well-known path. Reading the latest row at hook-fire time is zero-coupling: the hook doesn't care how or when the file was written, and the poller doesn't know the hook exists. Avoids race conditions from shared mutable state and keeps the hook independently testable.
