---
id: 20260611-retag-v010-optional
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
created_at: '2026-06-11 23:12:50.724607+00:00'
updated_at: '2026-06-11 23:12:50.724608+00:00'
---

# 20260611-retag-v010-optional

## decision

Left v0.1.0 tag at 7a14048 (before two style commits) rather than re-tagging to 9953ce4; re-tagging noted as an optional loose end

## context

The tag was created before the ruff format/lint cleanup commits landed. The clean tree is at 9953ce4 but the tag points to the pre-style state.

## reasoning

No functional code changed in the style commits, so v0.1.0 is semantically correct either way. Re-tagging is low-priority unless git blame cleanliness or the tag pointing to the formatted tree matters.
