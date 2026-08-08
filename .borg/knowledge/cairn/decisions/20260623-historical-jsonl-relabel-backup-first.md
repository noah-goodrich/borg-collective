---
id: 20260623-historical-jsonl-relabel-backup-first
date: '2026-06-23'
project: cairn
domain: data-integrity
tags:
- token-spend
- jsonl
- data-migration
- borg
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260623-0355-cairn
created_at: '2026-06-23 03:56:23.660652+00:00'
updated_at: '2026-06-23 03:56:23.660653+00:00'
---

# 20260623-historical-jsonl-relabel-backup-first

## decision

Back up ~/.claude/token-spend.jsonl before applying historical relabeling of 21 desktop + 3 worktree records

## context

After the collector fix ships, ~24 historical records need cwd-based relabeling. The file is append-only and the ground truth for all spend reports.

## reasoning

The file has no version control and is the authoritative spend ledger; a backup is mandatory before any mutation
