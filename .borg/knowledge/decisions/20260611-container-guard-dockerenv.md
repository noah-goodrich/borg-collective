---
id: 20260611-container-guard-dockerenv
date: '2026-06-11'
project: borg-collective
domain: infrastructure
tags:
- devcontainer
- hooks
- guard
- docker
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.301819+00:00'
updated_at: '2026-06-11 22:41:19.301819+00:00'
---

# 20260611-container-guard-dockerenv

## decision

Use /.dockerenv file existence as the canonical guard to skip host-only operations inside containers

## context

hooks/notify.sh and hooks/borg-start.sh were executing host-only code (macOS popups, CLAUDE.md sync) inside devcontainers, causing pollution and errors

## reasoning

/.dockerenv is created by Docker on container start and is the standard, reliable signal that code is running inside a container. It requires no environment variable discipline from callers.
