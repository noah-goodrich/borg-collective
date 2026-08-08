---
id: obs-20260420-supabase-cli-devcontainer-mirror
session_date: '2026-04-20'
project: borg-collective
tool: cursor
tags:
- supabase
- devcontainer
- dockerfile
- dotfiles
- canonical-template
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.084877+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260420-supabase-cli-devcontainer-mirror

## content

The canonical borg devcontainer template (dotfiles/devcontainer/Dockerfile.base) must be kept in sync with the dotfiles repo Dockerfile. The Supabase CLI install block was added here to mirror commit c5fdb62 in dotfiles. This is a manually-maintained mirror — there is no automated sync.

## resolution

When the dotfiles Dockerfile gains new tooling, remember to propagate the same block to borg's Dockerfile.base. Consider adding a comment in both files referencing the other to make the mirror relationship explicit.
