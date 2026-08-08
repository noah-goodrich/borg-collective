---
id: 20260723-contradiction-threshold-config-driven
date: '2026-07-24'
project: cairn
domain: architecture
tags:
- configuration
- similarity
- contradiction-detection
- belief-store
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: null
created_at: '2026-07-24 05:15:46.523725+00:00'
updated_at: '2026-07-24 05:15:48.083615+00:00'
---

# 20260723-contradiction-threshold-config-driven

## decision

Similarity threshold for contradiction detection is config-driven via CAIRN_CONTRADICTION_SIMILARITY_THRESHOLD (default 0.85) rather than hardcoded

## context

Needed to tune how aggressively the system flags potential contradictions

## reasoning

The right threshold will vary by corpus maturity and operator preference; hardcoding would require code changes to tune. Default of 0.85 is conservative enough to avoid excessive false positives
