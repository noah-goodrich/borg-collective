---
id: 20260616-reaper-single-home-posix
date: '2026-06-16'
project: borg-collective
domain: architecture
tags:
- shell
- reaper
- deduplication
- posix
- mechanism-layer
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.502429+00:00'
updated_at: '2026-06-16 10:27:02.502430+00:00'
---

# 20260616-reaper-single-home-posix

## decision

Collapse the triple-mirror of `_borg_should_reap` + `BORG_REAP_STALE_HOURS` into a single POSIX-compatible `lib/reaper.sh`, sourced by both `lib/registry.zsh` and `lib/borg-hooks.sh`.

## context

The reaper predicate existed in three places: `lib/registry.zsh`, `lib/borg-hooks.sh`, and as inline prose in `skills/borg-link/SKILL.md`. Any change had to be made in all three locations and the SKILL.md prose was already stale.

## reasoning

Single source of truth eliminates drift. POSIX compatibility (not zsh-specific) means the same file can be sourced from both zsh and bash contexts. The 80/20 rule (plugin = 80% of runtime, CLI = 20%) justified extracting this as a shared mechanism layer rather than leaving it in either consumer.
