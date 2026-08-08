---
id: obs-20260611-capacity-count-scope
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- hooks
- adhd-guardrails
- capacity
- borg-state
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.462140+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-capacity-count-scope

## content

The capacity warning counts active + waiting projects (not just active). Including waiting projects in the count matters because they represent committed cognitive load even if not currently in-flight.

## resolution

Hook implementation counts both statuses against BORG_MAX_ACTIVE threshold. adhd-guardrails Capacity Management section instructs Claude to surface the warning first before any other response when it appears.
