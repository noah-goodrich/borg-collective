---
id: 20260611-version-tag-placement
date: '2026-06-11'
project: cairn
domain: release-management
tags:
- git
- tagging
- semver
- release
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1925-cairn
created_at: '2026-06-11 20:31:18.015742+00:00'
updated_at: '2026-06-11 20:31:18.015743+00:00'
---

# 20260611-version-tag-placement

## decision

Shipped v0.1.0 tag at commit 7a14048 (before two subsequent style commits); left a note to optionally re-tag to 9953ce4 rather than doing it immediately.

## context

The merge to main happened before the ruff lint/format cleanup commits, so the tag predates those. The question was whether to move the tag or leave it.

## reasoning

Moving a pushed tag rewrites shared history and can confuse consumers. Since the style commits contain no logic changes, the risk of leaving the tag early is low. Documented the gap for the next session to decide consciously rather than silently re-tagging.
