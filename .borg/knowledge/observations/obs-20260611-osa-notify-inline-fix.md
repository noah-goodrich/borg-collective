---
id: obs-20260611-osa-notify-inline-fix
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- hooks
- notify
- fresh-install
- borg-hooks.sh
- claude-plugins
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.530172+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-osa-notify-inline-fix

## content

_borg_osa_notify was extracted to the mechanism layer but the claude-plugins/directives-02-06 branch inlined it back into hooks/notify.sh as a fresh-install fix. This means the function exists in two places during the transition period. The staged-but-unpushed commits in ~/dev/claude-plugins/borg-collective resolve this but are not yet on remote.

## resolution

Push the claude-plugins branch and open a PR as the first action of the next session touching that project. Until merged, fresh installs that load hooks/notify.sh will use the inlined version while existing installs may use the mechanism-layer version — behavior is consistent but the duplication is a maintenance hazard.
