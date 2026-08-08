---
id: obs-20260423-drone-changes-require-new-session
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- drone
- tmux
- devcontainer
- hot-reload
- session-lifecycle
category: tool_behavior
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.322645+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260423-drone-changes-require-new-session

## content

`drone.zsh` changes (layout, scaffold defaults) do not apply to running drone sessions. tmux.conf changes require a server reload (`prefix + r` or `tmux kill-server && tmux`). Changes to scaffold templates only affect the next `drone up`, not any existing container.

## resolution

After committing drone/tmux changes: reload tmux config explicitly, then test with a fresh `drone up` invocation rather than inspecting an existing session. Document this in onboarding so developers don't spend time wondering why their edits aren't reflected.
