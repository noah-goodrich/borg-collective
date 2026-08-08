---
id: obs-20260612-cmd-search-stall
session_date: '2026-06-12'
project: borg-collective
tool: cursor
tags:
- borg
- cairn
- graceful-degradation
- search
- stall
- timeout
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-12 03:25:39.254791+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260612-cmd-search-stall

## content

cmd_search in borg would stall indefinitely when cairn was unavailable, rather than failing fast. This blocked the graceful degradation story even though all other cairn call-sites had been made resilient.

## resolution

Fixed in c87bf46 — cmd_search now times out and degrades gracefully. When auditing cairn call-sites for graceful degradation, cmd_search must be explicitly checked; it is not covered by the same code path as other commands.
