---
id: obs-20260714-synthetic-session-guard-placement
session_date: '2026-07-14'
project: borg-collective
tool: claude-code
tags:
- borg-link-down
- synthetic-session
- launchd
- cairn
- usage-watch
- hooks
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260714-1733-borg-collective
superseded_by: null
created_at: '2026-07-14 17:34:17.057586+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260714-synthetic-session-guard-placement

## content

The usage-watch launchd poller (cwd `/`) invokes claude with `-p /usage`, which triggers borg hooks and writes synthetic `query='/'` rows into cairn's call_log. The correct fix has two parts: (1) the hook-side guard `[[ -z "$CWD" || "$CWD" == "/" ]] && exit 0` in borg-link-down.sh, and (2) the poller-side mute `BORG_NO_SESSION_HOOKS=1` set in bin/borg-usage-watch before spawning claude. Both must be deployed (`claude plugin update borg-collective` + `borg setup`) for the pollution to stop. Verifying requires waiting a full poller cycle then querying cairn for new `query='/'` rows.

## resolution

After deploying both changes, verify with `curl -fsS http://localhost:8767/stats/usage` and optionally the direct postgres query for `call_log where query='/' and created_at > now() - interval '30 min'`; expect count = 0.
