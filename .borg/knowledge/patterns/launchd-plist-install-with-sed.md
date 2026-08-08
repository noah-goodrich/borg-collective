---
id: launchd-plist-install-with-sed
project: borg-collective
domain: infrastructure
tags:
- launchd
- install.sh
- launchctl
- macos
preconditions: []
steps:
- Store plist template in repo with a placeholder (e.g., __HOME__ or literal /Users/TEMPLATE_USER)
- install.sh runs sed -e "s|__HOME__|$HOME|g" on the template, writing to ~/Library/LaunchAgents/<label>.plist
- Run 'launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/<label>.plist' to register
  without requiring logout
- For updates, run 'launchctl bootout' before re-bootstrapping
pitfalls:
- launchctl load is deprecated on macOS 13+; use bootstrap/bootout
- If the plist already exists and is loaded, bootstrapping again will error — check
  with 'launchctl print gui/$(id -u)/<label>' first
- ProgramArguments must use absolute paths; $HOME expansion does not happen inside
  plist XML
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.303311+00:00'
updated_at: '2026-06-11 22:41:19.303311+00:00'
---

# launchd-plist-install-with-sed

## description

Install a LaunchAgent plist that contains user-specific paths by using sed substitution at install time
