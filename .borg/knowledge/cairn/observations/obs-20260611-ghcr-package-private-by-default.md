---
id: obs-20260611-ghcr-package-private-by-default
session_date: '2026-06-11'
project: cairn
tool: cursor
tags:
- ghcr
- docker
- visibility
- publishing
category: gotcha
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 22:41:19.541768+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260611-ghcr-package-private-by-default

## content

GHCR (GitHub Container Registry) packages default to private visibility on first publish. If public access is intended (e.g., for `docker pull` without auth), the package visibility must be explicitly set to public after the first push.

## resolution

Noted as a pending action: push a v* tag → GHCR publish workflow → manually set package visibility to public in GitHub package settings.
