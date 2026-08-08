---
id: obs-20260527-optional-dep-blocked-on-real-tag
session_date: '2026-05-27'
project: cairn
tool: cursor
tags:
- semver
- borg-collective
- optional-dependency
- release
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:18.009216+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260527-optional-dep-blocked-on-real-tag

## content

The borg-collective plugin's optional-Cairn integration path cannot declare a stable dependency (`cairn>=0.1.0`) until a real git tag exists on main. Working against an untagged SHA is fragile — SHA-pinned optional extras break on repo history rewrites and are not resolvable by standard package managers.

## resolution

The release tag (`v0.1.0`) must be cut from main immediately after the feat branch squash-merges. Make this the first action in the next session so plugin work can proceed.
