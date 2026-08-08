---
id: 20260709-self-auditing-poller
date: '2026-07-09'
project: borg-collective
domain: architecture
tags:
- observability
- polling
- jsonl
- borg-usage-watch
- launchd
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260709-1659-borg-collective
created_at: '2026-07-09 17:01:17.377791+00:00'
updated_at: '2026-07-09 17:01:17.377793+00:00'
---

# 20260709-self-auditing-poller

## decision

Every poll writes exactly one row to usage-samples.jsonl (ok|idle|suspect|error + reason), making silence unambiguous: the poller did not run.

## context

192 parse failures vs 116 samples in the first 10.5h — 62% of polls wrote nothing, invisibly. A 6-hour blind window could not be diagnosed.

## reasoning

When a poller can write zero rows on failure, silence is ambiguous (poller down vs. nothing to report). Forcing exactly one row per poll makes absence of rows a definitive signal about the poller itself, not about the monitored resource.
