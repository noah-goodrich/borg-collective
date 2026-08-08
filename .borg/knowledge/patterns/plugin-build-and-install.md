---
id: plugin-build-and-install
project: borg-collective
domain: infrastructure
tags:
- claude-code
- plugins
- build
- install
- hooks
preconditions: []
steps:
- Run build-plugin.sh to regenerate the plugin bundle from source hooks
- Run `borg setup` to apply settings.json de-duplication (removes duplicate hook registrations)
- Run `claude plugin install <name>@<scope>` to install/reinstall the plugin
- Verify hook list in settings.json has no duplicate entries
- Restart Claude Code to activate newly installed hooks (hooks load at session start)
pitfalls:
- Hooks do not activate in the current session after install — a Claude Code restart
  is always required
- 'If de-dup logic is too aggressive, user-added hooks sharing a key name with borg
  hooks can be silently deleted (see data-loss incident, fixed in #45)'
- Running `borg setup` before verifying de-dup correctness on a new machine risks
  deleting user customizations — test on a clean env first
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.539157+00:00'
updated_at: '2026-06-11 22:41:19.539158+00:00'
---

# plugin-build-and-install

## description

Regenerate, install, and verify a Claude Code plugin with de-duplicated hooks
