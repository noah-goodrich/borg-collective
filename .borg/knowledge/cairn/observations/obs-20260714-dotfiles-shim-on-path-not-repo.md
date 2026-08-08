---
id: obs-20260714-dotfiles-shim-on-path-not-repo
session_date: '2026-07-14'
project: cairn
tool: claude-code
tags:
- cli
- shim
- dotfiles
- path
- deployment
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260714-0405-cairn
superseded_by: null
created_at: '2026-07-14 04:06:54.532599+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260714-dotfiles-shim-on-path-not-repo

## content

The `cairn` command on PATH resolves to `~/.config/dotfiles/zsh/bin/cairn` (the dotfiles repo copy), NOT the canonical `cli/cairn` in the cairn repo. Updating only the cairn repo shim has zero effect on the running system until the dotfiles copy is also updated.

## resolution

Always treat dotfiles as the authoritative deployed shim. Any record-kind addition requires a PR to both repos. A new shell or dotfiles reload is needed to pick up the change.
