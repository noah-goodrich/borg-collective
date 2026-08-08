---
id: 20260616-rescue-commits-to-feature-branch
date: '2026-06-16'
project: borg-collective
domain: git-workflow
tags:
- git
- branch-management
- recovery
- main-branch-hygiene
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.427203+00:00'
updated_at: '2026-06-16 10:27:02.427204+00:00'
---

# 20260616-rescue-commits-to-feature-branch

## decision

Rescued commits made directly to local main by creating a feature branch at the current HEAD, then hard-resetting local main to origin/main

## context

5 commits had been made directly to local main without pushing, creating a divergence from origin/main that needed to be untangled before further work

## reasoning

Creating a rescue branch preserves the work without rewriting any history. Hard-resetting local main to origin/main then makes local main clean again. This is safer than cherry-picking or rebasing when the commits are contiguous at HEAD.
