---
id: 20260723-age-seconds-clock-skew-clamp
date: '2026-07-24'
project: cairn
domain: architecture
tags:
- postgresql
- sql
- clock-skew
- belief-store
- views
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: null
created_at: '2026-07-24 05:15:46.522036+00:00'
updated_at: '2026-07-24 05:15:48.083615+00:00'
---

# 20260723-age-seconds-clock-skew-clamp

## decision

Use `GREATEST(0, EXTRACT(...))` to clamp age_seconds in the belief VIEW rather than a bare EXTRACT

## context

age_seconds is computed from timestamps; in edge cases (clock skew, race conditions) raw subtraction can yield negative values

## reasoning

Negative age values are semantically nonsensical and would confuse consumers of the VIEW; clamping to 0 is the correct defensive behavior with no downside
