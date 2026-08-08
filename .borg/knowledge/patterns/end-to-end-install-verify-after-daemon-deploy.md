---
id: end-to-end-install-verify-after-daemon-deploy
project: borg-collective
domain: infrastructure
tags:
- launchd
- daemon
- verification
- shell-scripting
preconditions: []
steps:
- Install the agent and confirm launchctl list shows it registered
- Wait one full poll interval (or use launchctl kickstart -k to force an immediate
  run)
- Inspect the actual output file/log to confirm a new sample was written
- If no sample exists, check the launchd job's stderr log (ProgramArguments stderr
  redirect) for errors that exited 0
- Confirm the binary is resolvable under launchd's minimal PATH by running the script
  directly via launchctl kickstart, not from a login shell
pitfalls:
- launchd uses a minimal PATH that omits user-local bin dirs ($HOME/.local/bin, $HOME/.cargo/bin,
  etc.) that login shells pick up via .profile or .zshrc. A script that works in a
  terminal may silently fail under launchd.
- Exit-0 error handling in the script masks permanent misconfigurations as transient
  misses. launchctl list will show the job as healthy even when it has never produced
  a sample.
- The unit test suite may be entirely green while the live daemon is blind — unit
  tests run in a login shell environment, not the launchd environment.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260709-0431-orchestrator
superseded_by: null
created_at: '2026-07-09 15:26:37.439423+00:00'
updated_at: '2026-07-09 15:26:37.439424+00:00'
---

# end-to-end-install-verify-after-daemon-deploy

## description

After installing a launchd agent, verify it is actually producing output — not just that it exits 0 and launchctl reports healthy.
