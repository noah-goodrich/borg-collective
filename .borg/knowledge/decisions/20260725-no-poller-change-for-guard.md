---
id: 20260725-no-poller-change-for-guard
date: '2026-07-25'
project: borg-collective
domain: architecture
tags:
- hooks
- usage-guardian
- coupling
- shell
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: null
created_at: '2026-07-25 16:56:41.541857+00:00'
updated_at: '2026-07-25 17:54:08.360727+00:00'
---

# 20260725-no-poller-change-for-guard

## decision

The dispatch-guard hook reads the existing usage-samples.jsonl file written by the existing poller; no new poller logic or IPC mechanism was added.

## context

The guard needs fresh usage data at hook invocation time. Options included reading the shared file, adding a socket/pipe, or querying a daemon.

## reasoning

The samples file is already written by the usage-watch poller on its own cadence. Reusing it avoids coupling the hook to poller internals and keeps the hook stateless and independently testable. The 'staleness' check (fresh ok reading) handles the edge case where the file exists but is old.
