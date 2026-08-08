---
id: borg-skill-sync-after-repo-update
project: borg-collective
domain: infrastructure
tags:
- borg-link
- skill-sync
- bash-guard
- manual-step
preconditions: []
steps:
- Edit skill file in /path/to/borg-collective/skills/<skill>/SKILL.md
- Commit and push to borg-collective repo
- 'Manually run: cp /path/to/borg-collective/skills/<skill>/SKILL.md ~/.claude/skills/<skill>/SKILL.md'
- Verify installed copy matches repo copy
pitfalls:
- bash-guard correctly blocks rm -rf ~/.claude, which means Claude sessions cannot
  perform this sync — it is always a manual human step
- Easy to forget after a commit; the installed skill will silently remain stale
- No automatic mechanism exists to detect installed vs. repo drift
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.333351+00:00'
updated_at: '2026-06-16 10:27:02.333351+00:00'
---

# borg-skill-sync-after-repo-update

## description

After updating a skill's SKILL.md in the borg-collective repo, the installed copy at ~/.claude/skills/<skill>/SKILL.md must be manually synced — Claude sessions cannot do this automatically
