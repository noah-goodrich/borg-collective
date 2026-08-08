---
id: obs-20260417-bash-guard-intent-classifier-production
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- bash-guard
- intent-classifier
- permissions
- docker
- read-only
category: tool_behavior
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.261829+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260417-bash-guard-intent-classifier-production

## content

The `bash-guard` hook's intent classifier (introduced in commit `94e898c`) correctly auto-approved a `docker ps` command in production with `permissionDecision: allow, reason: read-only by intent classifier` — without requiring manual human approval. This confirms the classifier is live and working for read-only shell commands in the borg-collective workspace.

## resolution

No action needed — working as intended. Noteworthy as first confirmed production observation of the classifier operating correctly on a real session command.
