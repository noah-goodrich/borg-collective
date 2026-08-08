---
id: 20260616-reaper-dual-definition
date: '2026-06-16'
project: borg-collective
domain: infrastructure
tags:
- borg
- reaper
- hooks
- zsh
- bash
- deployment
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.490945+00:00'
updated_at: '2026-06-16 10:27:02.490946+00:00'
---

# 20260616-reaper-dual-definition

## decision

Define borg reap in both lib/registry.zsh (CLI path) and lib/borg-hooks.sh (hook path), and deploy hook files to ~/.claude

## context

The reaper needs to fire both from the CLI (borg reap) and from link-down hooks. The two execution contexts load different files.

## reasoning

Duplicating the definition is the lowest-risk approach given the two contexts have different shell environments and load paths. Alternative of sourcing from a shared file would require path assumptions that break across deployment topologies.
