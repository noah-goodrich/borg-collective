---
id: 20260616-surrogatepass-body-hashing
date: '2026-06-16'
project: cairn
domain: code-quality
tags:
- hashing
- unicode
- surrogates
- sha256
- python
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0914-cairn
created_at: '2026-06-16 10:27:03.286773+00:00'
updated_at: '2026-06-16 10:27:03.286773+00:00'
---

# 20260616-surrogatepass-body-hashing

## decision

Encode document body with errors='surrogatepass' before SHA-256 hashing

## context

Outbox compute_body_sha256 needs to hash arbitrary string bodies; Python str can contain lone surrogates (e.g. from some scrapers or mojibake)

## reasoning

str.encode('utf-8') raises UnicodeEncodeError on lone surrogates, crashing before the durable write completes. surrogatepass preserves the bytes round-trip and produces a stable, deterministic hash. The same encoding must be used in drain's read-back-verify step.
