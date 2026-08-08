---
id: borg-claude-md-delimited-merge
project: borg-collective
domain: architecture
tags:
- borg-collective
- CLAUDE.md
- config-management
- merge-strategy
preconditions: []
steps:
- In borg-collective, own the canonical block content in config/claude/CLAUDE.md wrapped
  in <!-- BEGIN borg-managed --> ... <!-- END borg-managed -->
- 'In borg.zsh _borg_merge_claude_md(): read ~/.claude/CLAUDE.md'
- Strip any existing borg-managed block (sed between the delimiters)
- Append fresh block content from $BORG_HOME/config/claude/CLAUDE.md
- Write back to ~/.claude/CLAUDE.md
- In dotfiles, delete the sections now owned by borg (lines 20-67 of CLAUDE.md)
- Run `borg setup` to verify merged output is correct
pitfalls:
- If delimiters are missing from an existing file, the strip step is a no-op and content
  duplicates on next borg setup run — verify idempotency
- ~/.config/dotfiles/claude/code/CLAUDE.md still has the stale sections until the
  split is executed; don't commit borg changes before cleaning dotfiles
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.172366+00:00'
updated_at: '2026-06-16 10:27:02.172366+00:00'
---

# borg-claude-md-delimited-merge

## description

Merge borg-managed config blocks into user-owned files using HTML comment delimiters to allow both layers to coexist
