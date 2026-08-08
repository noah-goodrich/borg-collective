---
id: 20260611-sync-plugin-script
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- tooling
- plugin
- sync
- drift-prevention
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.520622+00:00'
updated_at: '2026-06-11 22:41:19.520623+00:00'
---

# 20260611-sync-plugin-script

## decision

Introduce `scripts/sync-plugin.sh` to mechanically sync skill files from the source repo into the plugin distribution directory, replacing manual copy.

## context

Hand-copying `SKILL.md` files between `borg-collective` and `claude-plugins` had already caused detectable drift before the session.

## reasoning

A script makes the sync step explicit, repeatable, and auditable in CI; it is the minimal viable guard against copy-paste drift without a full monorepo restructure.
