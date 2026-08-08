---
id: obs-20260723-ghcr-publish-lag
session_date: '2026-07-24'
project: cairn
tool: claude-code
tags:
- ghcr
- docker
- ci
- publish-image
- deployment
category: tool_behavior
files_involved: []
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-07-24 05:15:46.527656+00:00'
updated_at: '2026-07-24 05:15:48.186761+00:00'
---

# obs-20260723-ghcr-publish-lag

## content

Tagging a release (vX.Y.Z) triggers publish-image.yml to push to GHCR, but this workflow may still be in_progress when the local host is already running the new version from a local build. The two deployment paths are independent.

## resolution

After a release, verify GHCR publish separately: `gh run list --workflow=publish-image.yml --limit 1`. This matters when other hosts or devcontainers need to pull the new image — they depend on GHCR, not the local build.
