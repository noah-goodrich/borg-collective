---
id: obs-20260417-bash-guard-intent-classifier-prod
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- bash-guard
- intent-classifier
- hooks
- permissions
- docker
- read-only
category: tool_behavior
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.037029+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260417-bash-guard-intent-classifier-prod

## content

The `bash-guard` hook's intent classifier correctly auto-approves read-only commands (e.g., `docker ps`) without requiring manual permission grants. Confirmed in production on commit `94e898c`. Log shows `permissionDecision: allow, reason: read-only by intent classifier`.

## resolution

No action needed — confirms the feature works as designed. If a read-only command is unexpectedly blocked, check whether the classifier is correctly identifying the command's intent (e.g., aliased commands or shell pipelines may not be classified correctly).
