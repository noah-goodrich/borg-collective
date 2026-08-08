---
id: obs-20260418-cairn-snowflake-not-git-repos
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- cairn
- snowflake-projects
- devcontainer
- git
category: gotcha
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.276378+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260418-cairn-snowflake-not-git-repos

## content

cairn and snowflake-projects are not git repositories. devcontainer.json and docker-compose.yml fixes applied during the ssh-agent sweep exist only on disk and are not version-controlled.

## resolution

Either initialize these as git repos or track their devcontainer configs in borg-collective. Until resolved, these containers are one disk wipe away from losing the socket-perm fix.
