---
id: obs-20260612-ghcr-multiarch-public-required
session_date: '2026-06-12'
project: cairn
tool: cursor
tags:
- cairn
- ghcr
- docker
- multi-arch
- public
- distribution
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-12 03:25:39.256041+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260612-ghcr-multiarch-public-required

## content

cairn v0.2.0 distribution depended on the GHCR image being both public AND multi-arch. A private or single-arch image would silently fail for ARM-based work machines or CI runners pulling without credentials.

## resolution

Explicitly verified public + multi-arch status after push. Add GHCR visibility + architecture checks to the release checklist for cairn.
