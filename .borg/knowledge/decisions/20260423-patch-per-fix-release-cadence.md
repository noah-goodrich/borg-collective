---
id: 20260423-patch-per-fix-release-cadence
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- homebrew
- releases
- versioning
- bisectability
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 20:39:25.113139+00:00'
updated_at: '2026-06-11 20:39:25.113140+00:00'
---

# 20260423-patch-per-fix-release-cadence

## decision

Cut a separate patch release (v0.7.3 → v0.7.4 → v0.7.5) for each independent fix rather than batching them into one release.

## context

Multiple independent bugs (atomic write, missing mkdir -p, dangling symlink) were found in sequence while verifying the work-machine setup path.

## reasoning

Keeps the Homebrew formula history clean and bisectable — if a future setup regression occurs, it's immediately clear which fix to examine. The overhead of three patch bumps is low compared to the debugging value.
