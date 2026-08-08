---
id: obs-20260616-cairn-status-vs-health
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- cairn
- cli
- subcommands
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.504568+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-cairn-status-vs-health

## content

`cairn status` is not a valid subcommand. The correct subcommand for checking cairn health is `cairn health`. The failure nudge in `borg-link-up.sh` was pointing developers to `cairn status`, causing a confusing error when they tried to diagnose write failures.

## resolution

PR #40 updated the failure nudge to reference `cairn health`. When writing any diagnostic message that includes a CLI invocation, verify the exact subcommand against the tool's help output.
