---
id: obs-20260709-live-poller-symlink-branch-risk
session_date: '2026-07-09'
project: borg-collective
tool: claude-code
tags:
- launchd
- symlink
- git
- workflow
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260709-0431-orchestrator
superseded_by: null
created_at: '2026-07-09 15:26:37.446795+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260709-live-poller-symlink-branch-risk

## content

$HOME/.local/bin/borg-usage-watch is a symlink into the git repo. The live launchd poller executes whatever version of the script is on the currently checked-out branch. Checking out a feature branch that predates the PATH/preflight fix (pre-63b232e) silently makes the live poller blind again, with no warning.

## resolution

Keep the repo on main when not actively developing a branch. Add a note to the contributing guide or install script warning about this symlink behavior. Consider whether the install should copy the script rather than symlink it, trading live-reload convenience for deployment safety.
