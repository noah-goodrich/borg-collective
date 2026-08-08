---
id: obs-20260617-staged-unpushed-commits-cross-session
session_date: '2026-06-17'
project: borg-collective
tool: claude-code
tags:
- git
- claude-plugins
- staged-commits
- cross-session
- directives-02-06
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-17 18:03:01.149602+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260617-staged-unpushed-commits-cross-session

## content

Two commits in ~/dev/claude-plugins/borg-collective are staged but unpushed across session boundary: hooks/notify.sh inlined _borg_osa_notify (fresh-install fix) and borg-link/borg-next SKILL.md re-synced. These exist only locally and will be invisible to any collaborator or CI until pushed.

## resolution

Next session touching claude-plugins must push the branch and open a PR before doing any new work. Branch: claude-plugins/directives-02-06. Do not start new commits on top of unpushed work without first confirming the branch is remote.
