---
id: obs-20260418-borg-dotfiles-subtree-orphan
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- borg-collective
- dotfiles
- git
- technical-debt
category: gotcha
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.276041+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260418-borg-dotfiles-subtree-orphan

## content

borg-collective/dotfiles/ is an orphan subtree that partially overlaps with ~/.config/dotfiles/ and was used as a target for some ssh-agent devcontainer fix commits (dbbd5cd). After the borg/dotfiles boundary split, this subtree is likely fully redundant but has not been audited or deleted.

## resolution

Needs a diff-and-decide pass before deletion: compare borg-collective/dotfiles/ against ~/.config/dotfiles/ to confirm no unique content remains, then remove the subtree. Low priority but will cause confusion if someone assumes it is the authoritative dotfiles location.
