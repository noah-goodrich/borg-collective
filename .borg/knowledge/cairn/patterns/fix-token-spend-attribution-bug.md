---
id: fix-token-spend-attribution-bug
project: cairn
domain: infrastructure
tags:
- token-spend
- claude-plugins
- shell
- bats
- worktree
preconditions: []
steps:
- Identify misattributed records in ~/.claude/token-spend.jsonl by inspecting the
  'project' field against known CWD patterns (e.g., run `borg spend` and look for
  implausible project names with high spend)
- Locate the offending CWD pattern (e.g., `.../local-agent-mode-sessions/.../outputs`,
  `.claude/worktrees/<slug>`)
- Open the collector hook at token-cost/hooks/token-spend-log.sh in the claude-plugins
  worktree
- Add a case arm matching the path pattern and emitting the canonical project name
  (e.g., `*/local-agent-mode-sessions/*) PROJECT=claude-desktop ;;` and `*/.claude/worktrees/*)
  _wt="${CWD%/.claude/worktrees/*}"; PROJECT="${_wt##*/}" ;;`)
- Extend token-cost/hooks/test/token-spend-log.bats with assertions for the new arms
- Run `bats token-cost/hooks/test/token-spend-log.bats` (full green) and `shellcheck`
  the hook
- Commit and PR the fix on a feature branch; merge after CI green
- Back up ~/.claude/token-spend.jsonl, then apply a sed/awk relabel for historical
  records matching the old bogus project names; verify with `borg spend`
pitfalls:
- Do not commit the hook edit before adding the worktree arm — the desktop arm alone
  leaves the troth worktree bug unresolved
- Always back up token-spend.jsonl before the historical relabel; it has no version
  control
- The collector fix only affects new sessions; historical records require a separate
  relabeling pass
- Run shellcheck on the hook — parameter expansion like `${CWD%/.claude/worktrees/*}`
  is easy to mis-quote
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260623-0355-cairn
superseded_by: null
created_at: '2026-06-23 03:56:23.661354+00:00'
updated_at: '2026-06-23 03:56:23.661355+00:00'
---

# fix-token-spend-attribution-bug

## description

How to diagnose and fix a CWD-based project attribution bug in the token-spend collector hook
