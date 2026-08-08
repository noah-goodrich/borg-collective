---
id: obs-20260609-unpushed-commits-cross-project
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- git
- claude-plugins
- staged-commits
- cross-repo
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.514532+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260609-unpushed-commits-cross-project

## content

Two commits were staged but not pushed in ~/dev/claude-plugins/borg-collective (a sibling repo, not the main borg-collective repo). Working tree clean checks on the main repo give a false sense of 'nothing outstanding' when sibling repos have unpushed work.

## resolution

When closing a session that touched multiple repos, explicitly check git status in each repo touched, not just the primary one. The outstanding commits are: hooks/notify.sh inlined _borg_osa_notify + borg-link/borg-next SKILL.md re-sync.
