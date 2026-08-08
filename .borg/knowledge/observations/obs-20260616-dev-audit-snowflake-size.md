---
id: obs-20260616-dev-audit-snowflake-size
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- disk-usage
- dev-audit
- repo-hygiene
category: performance
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.441054+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-dev-audit-snowflake-size

## content

The `snowflake_assets` repo in ~/dev was 102MB — large enough to warrant moving out of the active dev tree to ~/Documents/ rather than leaving it cloned. Unneeded large repos in ~/dev/ slow down tools that scan the directory tree.

## resolution

Moved to ~/Documents/. For future ~/dev audits: flag any repo >50MB that hasn't been touched recently as a candidate for Documents/ relocation rather than staying in the active dev workspace.
