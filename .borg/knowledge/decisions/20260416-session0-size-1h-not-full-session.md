---
id: 20260416-session0-size-1h-not-full-session
date: '2026-06-11'
project: borg-collective
domain: project-management
tags:
- reveal
- wallpaper-kit
- rename
- scope-estimation
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.246578+00:00'
updated_at: '2026-06-11 22:41:19.246579+00:00'
---

# 20260416-session0-size-1h-not-full-session

## decision

Size the wallpaper-kit reference sweep (Session 0) as ~1h, not a full session.

## context

The borg-collective portfolio directive still flagged the wallpaper-kit → reveal rename as a pending blocker. Initial instinct was to treat it as substantial work.

## reasoning

grep enumeration showed ~24 files with lingering references, mostly cosmetic docstrings, script comments, and one compose service rename. A batch-replace pass is a single commit, not a multi-hour effort.
