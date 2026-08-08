---
id: 20260611-reaper-posix-single-home
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- shell
- reaper
- posix
- deduplication
- mechanism-layer
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.519834+00:00'
updated_at: '2026-06-11 22:41:19.519834+00:00'
---

# 20260611-reaper-posix-single-home

## decision

Consolidate `_borg_should_reap` + `BORG_REAP_STALE_HOURS` into a single POSIX-compatible `lib/reaper.sh`; all callers source it rather than maintaining inline copies.

## context

The reaper predicate was duplicated across `lib/registry.zsh`, `lib/borg-hooks.sh`, and `skills/borg-link/SKILL.md` prose, causing drift and making changes require triple updates.

## reasoning

A single authoritative file eliminates drift, is shellcheck-clean, and is sourceable by both zsh and bash callers. POSIX compatibility is required because `borg-hooks.sh` runs in non-zsh contexts.
