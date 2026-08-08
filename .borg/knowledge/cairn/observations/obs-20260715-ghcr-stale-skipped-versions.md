---
id: obs-20260715-ghcr-stale-skipped-versions
session_date: '2026-07-15'
project: cairn
tool: docker
tags:
- ghcr
- docker
- release
- versioning
- devcontainer
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-15 15:41:50.299405+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260715-ghcr-stale-skipped-versions

## content

GHCR was stuck at 0.4.0 when the team deployed 0.5.2. Versions 0.5.0 and 0.5.1 were never published to the registry. Any devcontainer or consumer pulling from GHCR was silently running two minor versions behind without any error.

## resolution

Build locally for the immediate deploy; publish v0.5.2 (arm64, tags 0.5.2/0.5/latest) explicitly as part of the release. Add GHCR publish as a required release step going forward.
