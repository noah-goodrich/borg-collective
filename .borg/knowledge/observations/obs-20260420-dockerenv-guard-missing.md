---
id: obs-20260420-dockerenv-guard-missing
session_date: '2026-04-20'
project: borg-collective
tool: cursor
tags:
- docker
- hooks
- notifications
- terminal-notifier
- container
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.084043+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260420-dockerenv-guard-missing

## content

hooks/notify.sh calls terminal-notifier without first checking whether it is running inside a container. Inside a devcontainer, terminal-notifier is not available and the call will fail. The acceptance criterion requires '[[ -f /.dockerenv ]] && exit 0' as the first guard after 'set -euo pipefail', but this was not added during the borg start commit — it remains an open gap.

## resolution

Add '[[ -f /.dockerenv ]] && exit 0' immediately after 'set -euo pipefail' in hooks/notify.sh. Smoke-test: 'docker exec <container> bash hooks/notify.sh <<<"{}"' should return exit 0 with no stderr output.
