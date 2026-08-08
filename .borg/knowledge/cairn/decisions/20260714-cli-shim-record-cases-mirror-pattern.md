---
id: 20260714-cli-shim-record-cases-mirror-pattern
date: '2026-07-14'
project: cairn
domain: code-quality
tags:
- cli
- shim
- record-kinds
- dotfiles
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260714-0405-cairn
created_at: '2026-07-14 04:06:54.518028+00:00'
updated_at: '2026-07-14 04:06:54.518032+00:00'
---

# 20260714-cli-shim-record-cases-mirror-pattern

## decision

Added `record document` case to both the canonical `cli/cairn` shim AND the on-PATH dotfiles shim (`~/.config/dotfiles/zsh/bin/cairn`), mirroring the existing sibling record cases without introducing a shared helper.

## context

Checkpoint writes were failing with `unknown record kind: document` because the CLI shim had no case for the `document` record kind introduced in service v0.2, despite the API endpoint existing.

## reasoning

The handler is a simple pass-through case matching siblings exactly; no reusable abstraction exists across the two shims, and introducing one would add complexity for a single-line addition. `/simplify` review confirmed no helper was warranted.
