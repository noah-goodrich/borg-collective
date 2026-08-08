---
id: 20260714-local-build-only-no-semver-tags
date: '2026-07-14'
project: cairn
domain: infrastructure
tags:
- docker
- ghcr
- publish-image
- tags
- deployment
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260714-0405-cairn
created_at: '2026-07-14 04:06:54.528036+00:00'
updated_at: '2026-07-14 04:06:54.528037+00:00'
---

# 20260714-local-build-only-no-semver-tags

## decision

Deployed cairn 0.5.1 via local image build rather than relying on GHCR pull, because no `v0.5.x` tags exist in the repo to trigger `publish-image.yml`.

## context

The publish-image workflow fires on semver tags; the project had been bumping versions without pushing matching git tags, leaving GHCR without any 0.5.x images.

## reasoning

Local build was the only available path to deploy the new version. Noted as tech debt to push a `v0.5.1` tag to restore the normal pull-based deploy path.
