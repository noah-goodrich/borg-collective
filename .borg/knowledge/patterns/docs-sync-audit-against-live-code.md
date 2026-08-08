---
id: docs-sync-audit-against-live-code
project: borg-collective
domain: documentation
tags:
- docs
- audit
- sync
- code-verification
- borg-workflow
preconditions: []
steps:
- Identify all doc files that reference versioned behaviors (commands, hooks, skills,
  agents, config)
- Diff docs against actual code artifacts — flag phantom commands (documented but
  absent in code) and undocumented features
- Run a blind review pass on any research/analysis docs before incorporating conclusions
- Update version strings in code (e.g., BORG_VERSION in borg.zsh) to match the target
  version
- Move completed WIP/recon issues to assimilated/ to reflect plan hygiene
- Produce a PROJECT_PLAN.md with explicit acceptance criteria; verify all criteria
  met before cutting PR
- Open PR scoped strictly to the sync objective; leave planning/research artifacts
  uncommitted for post-merge assimilation
pitfalls:
- Docs can reference commands or flags that were removed — these phantom references
  pass casual review but break user trust; explicit code-vs-doc diff is required
- Model routing config (settings.json) and its documentation (ROUTING.md) drift independently
  — both must be updated atomically
- Research/competitive analysis docs may contain unverified claims; blind review before
  incorporation prevents laundering speculation into official docs
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: null
superseded_by: null
created_at: '2026-08-01 03:01:33.333113+00:00'
updated_at: '2026-08-01 03:01:33.333115+00:00'
---

# docs-sync-audit-against-live-code

## description

Systematic process for syncing documentation to a new code version, including cross-checking docs against live code to catch phantom/stale references
