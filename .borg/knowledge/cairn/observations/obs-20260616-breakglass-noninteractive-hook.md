---
id: obs-20260616-breakglass-noninteractive-hook
session_date: '2026-06-16'
project: cairn
tool: claude-code
tags:
- cairn
- hooks
- non-interactive
- break-glass
- zero-loss
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0914-cairn
superseded_by: null
created_at: '2026-06-16 10:27:03.270008+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-breakglass-noninteractive-hook

## content

Adversarial review identified that any design requiring an interactive user prompt inside a borg Stop hook is impossible — hooks run non-interactively and a blocking prompt will hang indefinitely or be killed by the shell. This was one of 8 data-loss holes found.

## resolution

All break-glass / user-consent flows in hooks must be deferred and async (e.g., write a pending approval file; user reviews and approves later). No interactive prompts in hook context.
