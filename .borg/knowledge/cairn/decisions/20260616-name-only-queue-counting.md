---
id: 20260616-name-only-queue-counting
date: '2026-06-16'
project: cairn
domain: architecture
tags:
- outbox
- filesystem
- performance
- demotion
- signal
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0914-cairn
created_at: '2026-06-16 10:27:03.289611+00:00'
updated_at: '2026-06-16 10:27:03.289611+00:00'
---

# 20260616-name-only-queue-counting

## decision

queue_nonempty uses name-only directory listing (os.scandir or equivalent) as the demotion gate, not stat or open

## context

The _signal demotion check (DOWN→UP transition gate) needs to know if the outbox queue has pending entries; it must be fast and not compete with drain I/O

## reasoning

Name-only listing avoids stat() calls per entry and doesn't open any files, keeping the hot path cheap. The demotion gate only needs to know emptiness, not entry count or content. Opening/statting entries would create contention with concurrent claim operations.
