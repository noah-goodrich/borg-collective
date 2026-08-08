---
id: dev-directory-audit
project: borg-collective
domain: infrastructure
tags:
- housekeeping
- local-dev
- repository-hygiene
- stray-files
preconditions: []
steps:
- List all directories in ~/dev/ and identify any that are not registered in the borg
  registry
- 'For each unregistered directory: determine if it''s a live project (register it),
  a dead clone (delete), or a stray asset collection (move to ~/Documents/)'
- 'For each registered repo with local-only uncommitted content: commit and push,
  or move content to appropriate archive location'
- Check ~/dev/ root for loose files (markdown, configs, scripts) — commit to appropriate
  repo or delete
- 'For large binary/asset directories (>10MB): move to ~/Documents/ or appropriate
  non-dev storage'
- Delete local clones of repos where all content has been pushed and no active work
  is ongoing
pitfalls:
- A repo appearing in the borg registry does not mean its local clone is clean — always
  check `git status` before deleting a local clone
- Large asset directories (100M+) in ~/dev/ slow down any tooling that walks the dev
  tree; move them out proactively
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.468664+00:00'
updated_at: '2026-06-11 22:41:19.468665+00:00'
---

# dev-directory-audit

## description

Periodic audit of ~/dev/ root and sibling repos to route stray content, remove dead clones, and move large non-code assets out of the dev tree
