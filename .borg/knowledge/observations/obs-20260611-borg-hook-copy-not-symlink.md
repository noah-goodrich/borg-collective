---
id: obs-20260611-borg-hook-copy-not-symlink
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- borg
- hooks
- deployment
- claude
- topology
category: domain_knowledge
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.514371+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-borg-hook-copy-not-symlink

## content

Borg hook files deployed to ~/.claude are copies, not symlinks. This means edits to hook files in the source repo are NOT automatically live — they must be manually copied to ~/.claude after each change.

## resolution

After any hook file edit in the borg-collective repo, always run: cp <repo>/hooks/<file> ~/.claude/<file>. lib/*.zsh files do not require this step as they are sourced directly.
