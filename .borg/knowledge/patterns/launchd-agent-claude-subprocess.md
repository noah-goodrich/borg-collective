---
id: launchd-agent-claude-subprocess
project: borg-collective
domain: infrastructure
tags:
- launchd
- macos
- claude-code
- polling
- environment
preconditions: []
steps:
- Set USER explicitly in plist EnvironmentVariables block — do not inherit from shell
  or clone a plist that omits it
- Set PATH explicitly to include the claude binary location
- 'In the polling script, guard: `if [[ -z "$USER" ]]; then echo ''ERROR: USER unset''
  >&2; exit 1; fi` before invoking claude'
- Test end-to-end by running the script directly in a launchctl context, not just
  in a shell where USER is already set
- Use `>>` append for log files rather than tmp+rename; single-line JSON records are
  atomic below PIPE_BUF
- Confirm live output by tailing the log file after the first poll interval, not by
  checking `launchctl list` alone
pitfalls:
- claude exits 0 with no output when USER is unset — the agent appears healthy while
  producing nothing
- Cloning cortex-wake.plist (or similar existing plists) without adding EnvironmentVariables
  inherits this bug
- pane_current_command for a Claude pane returns the version string, not 'claude'
  — any Claude-detection logic must account for this
- Each claude subprocess invocation appends a $0 record to token-spend.jsonl via SessionEnd
  hook regardless of --settings overrides
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260709-0431-orchestrator
superseded_by: null
created_at: '2026-07-09 15:25:36.243419+00:00'
updated_at: '2026-07-09 15:25:36.243421+00:00'
---

# launchd-agent-claude-subprocess

## description

Pattern for creating a launchd agent that periodically invokes the claude CLI as a subprocess, avoiding the two silent-failure traps.
