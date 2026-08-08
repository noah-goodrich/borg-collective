---
id: obs-20260418-personal-dotfiles-seed-vs-managed
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- borg
- dotfiles
- claude
- configuration-management
- first-run
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.063615+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260418-personal-dotfiles-seed-vs-managed

## content

After the borg/dotfiles boundary split, personal dotfiles CLAUDE.md serves only as a first-run seed for the personal-content section. On subsequent borg setup runs, only the borg-managed block is touched; personal content is preserved. This means the dotfiles CLAUDE.md is the authoritative source for personal content but NOT for borg-managed content — a distinction that must be maintained in both repos' READMEs.

## resolution

Document in both borg-collective and dotfiles repos which sections of CLAUDE.md are authoritative where. The delimited block pattern makes this machine-readable but human documentation is still needed to prevent accidental edits to the wrong file.
