---
id: obs-20260418-borg-orphan-subtree-risk
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- borg
- dotfiles
- git
- subtree
- technical-debt
category: gotcha
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.062809+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260418-borg-orphan-subtree-risk

## content

borg-collective/dotfiles/ is an orphan subtree that partially overlaps with ~/.config/dotfiles/ and was also the target of some ssh-agent devcontainer fix commits. After the borg/dotfiles boundary split, this directory is likely fully redundant but has not been deleted. It could cause confusion about which copy is authoritative.

## resolution

Needs a diff-and-decide pass: compare borg-collective/dotfiles/ against ~/.config/dotfiles/ to confirm full redundancy, then delete the subtree and update any references. Flag as a blocker before the next major borg refactor.
