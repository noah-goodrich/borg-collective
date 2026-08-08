---
id: obs-20260418-token-cost-stale-import
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- CLAUDE.md
- import
- claude-plugins
- token-cost
- path
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.175892+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260418-token-cost-stale-import

## content

~/.claude/CLAUDE.md had an @import pointing to ~/.config/dotfiles/claude/plugins/token-cost/... which was a stale install path. The live source had moved to the claude-plugins marketplace repo at /Users/noah/dev/claude-plugins/token-cost/skills/token-cost/SKILL.md. The stale import silently failed (no visible error), meaning the token-cost skill was not active.

## resolution

Updated @import in ~/.claude/CLAUDE.md:92 to point to the live marketplace path. The ~/.config/dotfiles copy at line 92 also has the stale path but will be superseded by the planned borg/dotfiles split refactor.
