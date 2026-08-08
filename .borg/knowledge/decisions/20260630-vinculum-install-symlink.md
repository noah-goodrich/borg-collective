---
id: 20260630-vinculum-install-symlink
date: '2026-06-30'
project: borg-collective
domain: infrastructure
tags:
- vinculum
- install
- symlink
- PATH
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260630-2202-borg-collective
created_at: '2026-06-30 22:03:12.817189+00:00'
updated_at: '2026-06-30 22:03:12.817190+00:00'
---

# 20260630-vinculum-install-symlink

## decision

Have `install.sh` explicitly symlink `borg-vinculum-watch` into `$BIN_DIR`

## context

PR #61 was a fix PR — the initial vinculum ship (PR #60) omitted the symlink, causing `sub` to silently fail live delivery on real installs because `borg-vinculum-watch` wasn't on PATH

## reasoning

The `sub` verb spawns the watcher by bare name, relying on PATH resolution. Without the symlink in `$BIN_DIR`, the watcher binary was only accessible via absolute path — silent failure in production while tests passed (tests likely used absolute paths or ran from repo root).
