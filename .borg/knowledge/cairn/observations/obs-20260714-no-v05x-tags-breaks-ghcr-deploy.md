---
id: obs-20260714-no-v05x-tags-breaks-ghcr-deploy
session_date: '2026-07-14'
project: cairn
tool: claude-code
tags:
- docker
- ghcr
- publish-image
- semver-tags
- ci-cd
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260714-0405-cairn
superseded_by: null
created_at: '2026-07-14 04:06:54.532996+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260714-no-v05x-tags-breaks-ghcr-deploy

## content

No `v0.5.x` git tags exist in the cairn repo. The `publish-image.yml` workflow triggers on semver tags, so GHCR has never received any 0.5.x image. All 0.5.x deployments have been local builds only, which is invisible from the deploy log and only discovered when investigating the deploy process.

## resolution

Push a `v0.5.1` tag to fire the publish workflow and restore pull-based deploys. Until then, deploys require `docker build` on the host.
