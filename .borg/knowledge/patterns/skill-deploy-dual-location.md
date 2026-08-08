---
id: skill-deploy-dual-location
project: borg-collective
domain: infrastructure
tags:
- skills
- deployment
- hooks
- dotfiles
preconditions: []
steps:
- Edit the file under skills/ or hooks/ in the borg-collective repo
- Copy or symlink to the corresponding path under ~/.claude/skills/ or ~/.claude/hooks/
- Verify the live path reflects the change before testing
- Commit and PR the repo-side change
pitfalls:
- Easy to forget the live deploy step — repo change alone has no effect on running
  sessions
- If ~/.claude/ uses symlinks, the deploy may be automatic; if copies, it must be
  manual each time
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.460500+00:00'
updated_at: '2026-06-11 22:41:19.460500+00:00'
---

# skill-deploy-dual-location

## description

When modifying a skill or hook in borg-collective, changes must be deployed to both the repo path and the live ~/.claude/ path to take effect in active Claude sessions
