---
id: borg-managed-block-injection
project: borg-collective
domain: configuration-management
tags:
- borg-collective
- dotfiles
- claude
- idempotent
- configuration
preconditions: []
steps:
- Define canonical borg content in borg-collective/config/<tool>/<file> (e.g., config/claude/CLAUDE.md).
- 'In the merge helper (_borg_merge_claude_md or equivalent): strip any existing <!--
  BEGIN borg-managed --> ... <!-- END borg-managed --> block and trailing blank lines
  from the target file.'
- Append the current borg-managed block from source to the end of the stripped target.
- Verify byte-identical output on consecutive runs (idempotency check).
- 'In cmd_setup: read from $BORG_HOME/config/* not $DOTFILES_DIR/*; treat personal
  dotfiles version as first-run seed only.'
pitfalls:
- Trailing blank lines after the END marker accumulate on each run if not stripped
  before re-appending — the strip step must remove trailing whitespace/newlines.
- If the source borg file is edited and cmd_setup is not re-run, the injected block
  in the target file goes stale — there is no auto-sync.
- Personal content in the target file must appear before the BEGIN marker; content
  after the END marker will be lost on next merge.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.275019+00:00'
updated_at: '2026-06-11 22:41:19.275020+00:00'
---

# borg-managed-block-injection

## description

Idempotent injection of borg-managed config blocks into shared config files (e.g., CLAUDE.md) using delimited markers.
