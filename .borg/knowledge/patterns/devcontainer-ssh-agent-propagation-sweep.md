---
id: devcontainer-ssh-agent-propagation-sweep
project: borg-collective
domain: infrastructure
tags:
- devcontainer
- ssh
- docker
- multi-repo
preconditions: []
steps:
- Identify the canonical fix pattern (e.g., remove chmod from postCreateCommand, add
  socket chmod to postStartCommand)
- Update the scaffold template in borg-collective/templates/ first as the source of
  truth
- Update the reference template in claude-plugins if it exists
- Apply the same change to each project's devcontainer.json individually
- Commit each repo separately with --no-verify if changes are devcontainer-only and
  pre-commit hooks are project-code-focused
- Verify end-to-end in one representative container before sweeping (avoids discovering
  a second bug mid-sweep)
pitfalls:
- Non-git repos (e.g. cairn, snowflake-projects) will be missed — track these as explicit
  blockers
- 'postCreateCommand vs postStartCommand distinction is critical: don''t apply runtime
  fixes to the wrong lifecycle hook'
- :ro bind-mounts will silently cause chmod to fail with 'Read-only file system' —
  check mount mode before adding any chmod in postCreateCommand
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.061543+00:00'
updated_at: '2026-06-11 20:39:25.061544+00:00'
---

# devcontainer-ssh-agent-propagation-sweep

## description

Propagate a devcontainer SSH fix across all repos when a systemic pattern is identified, using a consistent template change plus per-repo commits.
