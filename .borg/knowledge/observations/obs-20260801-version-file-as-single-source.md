---
id: obs-20260801-version-file-as-single-source
session_date: '2026-08-01'
project: borg-collective
tool: claude-code
tags:
- versioning
- borg-zsh
- VERSION-file
- git-tags
- single-source-of-truth
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-08-01 02:47:55.668530+00:00'
updated_at: '2026-08-01 02:47:55.668531+00:00'
---

# obs-20260801-version-file-as-single-source

## content

BORG_VERSION in borg.zsh was updated from v0.8.0 to v0.8.9 by treating the authoritative VERSION file + latest git tag as the source of truth. The hardcoded version string in borg.zsh was a derivative, not the source.

## resolution

Updated borg.zsh to reflect v0.8.9. Future version bumps should update the VERSION file and git tag first, then propagate to borg.zsh — not the reverse.
