---
id: obs-20260616-count-equality-insufficient-for-zero-loss
session_date: '2026-06-16'
project: cairn
tool: claude-code
tags:
- cairn
- testing
- zero-loss
- manifest
- sha256
category: gotcha
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0914-cairn
superseded_by: null
created_at: '2026-06-16 10:27:03.271364+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-count-equality-insufficient-for-zero-loss

## content

Using captured_count == recovered_count as the zero-loss acceptance criterion is insufficient. A system that consistently loses the same documents on both sides of a comparison passes the count check while silently dropping data.

## resolution

Prove zero-loss against a hand-authored golden manifest using three-way reconciliation (manifest vs cairn vs FS-sha256). Content-addressed sha256 comparison is required to detect corruption and silent drops.
