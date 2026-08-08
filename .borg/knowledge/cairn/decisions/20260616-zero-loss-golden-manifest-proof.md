---
id: 20260616-zero-loss-golden-manifest-proof
date: '2026-06-16'
project: cairn
domain: testing
tags:
- cairn
- zero-loss
- testing
- hypothesis
- manifest
- reconciler
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0914-cairn
created_at: '2026-06-16 10:27:03.265732+00:00'
updated_at: '2026-06-16 10:27:03.265733+00:00'
---

# 20260616-zero-loss-golden-manifest-proof

## decision

Zero-loss is proven against a hand-authored golden manifest compared three-way (manifest vs cairn vs FS-sha256), never via bare captured==recovered count

## context

Defining the acceptance criterion for zero-loss; needed a proof method that catches silent corruption, not just count equality

## reasoning

captured==recovered count equality is trivially satisfied by a system that loses documents consistently (if both sides are wrong by the same amount). A golden manifest with content-addressed sha256 comparison forces verification of actual document content, catching corruption and silent drops.
