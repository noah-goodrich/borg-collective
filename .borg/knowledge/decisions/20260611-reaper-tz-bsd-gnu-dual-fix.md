---
id: 20260611-reaper-tz-bsd-gnu-dual-fix
date: '2026-06-11'
project: borg-collective
domain: code-quality
tags:
- bash
- date
- timezone
- bsd
- gnu
- cross-platform
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.558664+00:00'
updated_at: '2026-06-11 22:41:19.558665+00:00'
---

# 20260611-reaper-tz-bsd-gnu-dual-fix

## decision

Fix BSD `date` UTC parsing with `-u` flag; fix GNU `date` UTC parsing with `TZ=UTC` prefix; apply both in the same code path to maintain cross-platform compatibility.

## context

`lib/reaper.sh:37` was parsing UTC `Z`-suffixed timestamps via `date -j -f` without `-u`, causing silent TZ-offset bugs on machines not set to UTC. The code had a standing 'known bug, do not fix here' comment, and a prior commit (#48) had been mistakenly believed to close the directive.

## reasoning

BSD `date` and GNU `date` have incompatible flags for UTC mode. Using `-u` satisfies BSD; wrapping with `TZ=UTC` satisfies GNU. Both are needed in the same codebase because CI runs both (GNU+BSD matrix).
