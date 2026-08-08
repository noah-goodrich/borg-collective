---
id: obs-20260616-lone-surrogate-sha256-crash
session_date: '2026-06-16'
project: cairn
tool: claude-code
tags:
- python
- unicode
- surrogates
- hashing
- encoding
- data-loss
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0914-cairn
superseded_by: null
created_at: '2026-06-16 10:27:03.291518+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-lone-surrogate-sha256-crash

## content

Python str objects can contain lone surrogates (U+D800–U+DFFF not paired). Calling str.encode('utf-8') on such a string raises UnicodeEncodeError. In an enqueue-first queue, this crash occurs BEFORE the durable write, silently dropping the document — a data_loss bug that's invisible unless you test with surrogate-containing inputs.

## resolution

Use errors='surrogatepass' in all encode() calls on document bodies within the outbox (both enqueue hashing and drain read-back-verify). This is lossless and produces a stable deterministic hash.
