---
id: obs-20260420-borg-switch-window-name-mismatch
session_date: '2026-04-20'
project: borg-collective
tool: borg/tmux
tags:
- borg
- tmux
- borg-switch
- registry
- window-naming
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.083614+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260420-borg-switch-window-name-mismatch

## content

'borg switch borg-collective' failed at session end with 'no tmux window named borg-collective'. The active tmux window for this project had been given a different name (the slug 'dynamic-wiggling-phoenix') rather than the project name. borg switch looks up the registered window name, which was not in sync with the actual window name at that moment.

## resolution

Ensure the tmux window name used when registering a project in the borg registry exactly matches what borg switch will look up. When a session opens with a slug-named window, either rename it to the project name or register it under the slug. Non-critical if session is already complete, but blocks clean handoff automation.
