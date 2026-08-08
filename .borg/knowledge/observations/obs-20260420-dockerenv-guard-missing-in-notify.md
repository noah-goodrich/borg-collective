---
id: obs-20260420-dockerenv-guard-missing-in-notify
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- container
- notifications
- hooks
- docker
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.286546+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260420-dockerenv-guard-missing-in-notify

## content

hooks/notify.sh lacks a `[[ -f /.dockerenv ]] && exit 0` guard. When notify.sh runs inside a devcontainer it will attempt to call terminal-notifier, which either fails silently or errors — the whole notification pathway breaks without a clear signal to the developer.

## resolution

Insert `[[ -f /.dockerenv ]] && exit 0` immediately after `set -euo pipefail` in hooks/notify.sh. Smoke-test with: `docker exec <container> bash hooks/notify.sh <<<'{}'` — should return 0 with no stderr.
