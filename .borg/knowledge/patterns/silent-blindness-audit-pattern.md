---
id: silent-blindness-audit-pattern
project: borg-collective
domain: code-quality
tags:
- shell-scripting
- error-handling
- audit
- defensive-coding
preconditions: []
steps:
- 'Read the script and list every instance of: || true, || x='''', exit 0 in an error
  branch, 2>/dev/null without a fallback check'
- 'For each instance, ask: if this fails because of a permanent misconfiguration (wrong
  path, missing binary, wrong env), does the script still exit 0 and log something
  reassuring?'
- If yes, replace with a preflight check (command -v, test -f, etc.) that exits nonzero
  and logs ERROR
- Add a regression test that verifies the script exits nonzero under the misconfiguration
  condition, then confirm the test fails against the pre-fix script (proving it's
  a real pin, not a tautology)
pitfalls:
- Unit tests run in the developer's shell environment and will not catch PATH or env
  mismatches that only appear under launchd/cron/systemd.
- Three instances of this class were found in a single ~200-line script before it
  was caught. Auditing once is not enough; re-audit before each new deployment context.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260709-0431-orchestrator
superseded_by: null
created_at: '2026-07-09 15:26:37.440072+00:00'
updated_at: '2026-07-09 15:26:37.440073+00:00'
---

# silent-blindness-audit-pattern

## description

Before shipping action code that depends on a monitoring script, audit every error-suppression construct to distinguish transient failures from permanent misconfigurations.
