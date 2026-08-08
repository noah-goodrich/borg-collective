---
id: directive-orphan-retrospective
project: borg-collective
domain: documentation
tags:
- directives
- orphan-prevention
- retrospective
- reveal
preconditions: []
steps:
- Read session logs (Explore agent or tmux scrollback) to confirm when parent plan
  was assimilated and what directives existed at that time
- Check each suspected orphan for a `Parent plan:` back-link — absence confirms orphan
  status
- 'Assess real-world state: is the feature live? Is data being collected but ignored?
  Is the infrastructure inert?'
- 'Add `*Parent plan: <slug> (orphaned at <event> <date>; back-link added <date>).*`
  to each orphan'
- 'Prioritize shipping by impact: active user harm > missed capability > inert infrastructure'
- Capture recommendation with urgency rationale in session summary
pitfalls:
- Orphaned directives collecting dust while the corresponding UX is live and misleading
  users — check production state, not just code state
- Severing an orphan abandons real planned work; default to shipping unless scope
  has genuinely evaporated
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.357035+00:00'
updated_at: '2026-06-11 22:41:19.357035+00:00'
---

# directive-orphan-retrospective

## description

When a parent plan is assimilated and child directives are suspected to be orphaned, use session logs + git log to confirm orphan state, diagnose real-world impact, and add back-links before deciding to ship or sever
