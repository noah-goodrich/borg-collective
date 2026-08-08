---
id: obs-20260504-live-verification-deferred-until-brew-install
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- borg-collective
- skill-extensions
- borg-setup
- brew
- deployment
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.393958+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260504-live-verification-deferred-until-brew-install

## content

Edits to SKILL.md files in the borg-collective repo do NOT take effect in the Claude environment until `brew upgrade borg-collective && borg setup` is run. The repo copy and the installed copy under ~/.claude/skills/ are separate. A session can fully implement and commit a protocol change while the live environment remains on the old version — creating a gap where the work looks done but is not actually exercisable.

## resolution

Always include a post-merge verification step: after brew upgrade + borg setup, grep the installed skill file to confirm the expected blocks are present before declaring the protocol live.
