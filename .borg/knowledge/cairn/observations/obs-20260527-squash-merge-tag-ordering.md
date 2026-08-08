---
id: obs-20260527-squash-merge-tag-ordering
session_date: '2026-06-11'
project: cairn
tool: cursor
tags:
- git
- release
- squash-merge
- tagging
- semver
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 23:12:50.719130+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260527-squash-merge-tag-ordering

## content

The v0.1.0 release tag must be cut from main AFTER the feat branch is squash-merged, not from the feat branch itself. If tagged from the feat branch tip, the tag points to a commit that will not exist in main's history after squash-merge, making `cairn>=0.1.0` pinning in the borg plugin resolve to an unreachable commit.

## resolution

Sequence: (1) squash-merge feat branch to main, (2) git tag v0.1.0 on the resulting merge commit on main, (3) git push origin v0.1.0. Add this ordering to the merge-and-tag handoff doc.
