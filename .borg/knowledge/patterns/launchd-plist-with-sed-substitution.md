---
id: launchd-plist-with-sed-substitution
project: borg-collective
domain: infrastructure
tags:
- launchd
- install.sh
- macos
- launchagent
- sed
preconditions: []
steps:
- Store plist as template in repo with placeholder strings (e.g., __BORG_DIR__, __USER__)
- In install.sh, use sed -e 's|__BORG_DIR__|'"$BORG_DIR"'|g' to produce the real plist
- Write substituted plist to ~/Library/LaunchAgents/<label>.plist
- 'Run: launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/<label>.plist'
- 'Verify with: launchctl print gui/$(id -u)/<label>'
pitfalls:
- launchctl load is deprecated on modern macOS — use launchctl bootstrap gui/$(id
  -u) <plist>
- If the agent is already loaded, bootstrap will fail; use bootout first or check
  before bootstrapping
- ProgramArguments paths must be absolute; relative paths silently fail to launch
- Homebrew PATH is not inherited by LaunchAgents — daemon must explicitly prepend
  /opt/homebrew/bin or /usr/local/bin
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.099576+00:00'
updated_at: '2026-06-11 20:39:25.099577+00:00'
---

# launchd-plist-with-sed-substitution

## description

Install a parameterized LaunchAgent plist by storing a template with placeholders, using sed to substitute real paths at install time, then bootstrapping with launchctl
