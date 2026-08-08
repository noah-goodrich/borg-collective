---
id: obs-20260415-source-zshrc-typed-into-chat
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- shell
- zshrc
- cursor
- ai-chat
- session-hygiene
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.007410+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260415-source-zshrc-typed-into-chat

## content

At session end, the user typed `source ~/.zshrc` into the AI chat window instead of the terminal. The command was never executed. Any PATH or alias changes made during the session did not take effect in the running shell.

## resolution

Always verify shell-reload commands were run in an actual terminal, not the chat. If uncertain, open a new terminal tab (which sources .zshrc on init) and run `borg setup` again to confirm. For borg-collective specifically: run `jq '.permissions.allow | length' ~/.claude/settings.json` and confirm count ≥ 95 as a post-setup smoke test.
