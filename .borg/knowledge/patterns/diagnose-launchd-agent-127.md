---
id: diagnose-launchd-agent-127
project: borg-collective
domain: infrastructure
tags:
- launchd
- debugging
- '127'
- exit-code
- stderr
preconditions: []
steps:
- Check launchctl list | grep <agent-label> for last exit code
- Read the agent's stderr log file directly — do not theorize before reading it
- Look for 'no such file or directory' on source/. lines, which indicates a path-resolution
  failure in the sourced file
- Check whether the file uses BASH_SOURCE in a context where zsh may source it
- Check whether set -e causes arithmetic expressions like (( DEBUG )) to exit 1 when
  the expression is zero/false
- Add class-level tripwire tests (bats) to pin both failure modes once fixed
pitfalls:
- BASH_SOURCE is unset in zsh; ${BASH_SOURCE[0]} expands to empty string, producing
  path '/reaper.sh' at filesystem root
- (( expr )) as the last command in a function returns 1 when expr is 0/false; fatal
  under set -e
- Fixing PATH omission and redeploying may leave agent still at 127 if the actual
  cause is a source-path or arithmetic bug
- Theorizing a root cause (e.g., PATH) before reading the stderr log wastes a deploy
  cycle and risks shipping a false claim
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260709-1659-borg-collective
superseded_by: null
created_at: '2026-07-09 17:01:17.385038+00:00'
updated_at: '2026-07-09 17:01:17.385039+00:00'
---

# diagnose-launchd-agent-127

## description

Diagnosing launchd agents that silently exit 127 (command not found or sourcing failure).
