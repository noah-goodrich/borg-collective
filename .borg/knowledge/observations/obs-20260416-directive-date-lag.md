---
id: obs-20260416-directive-date-lag
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- borg-collective
- directives
- cross-repo
- documentation-lag
- sync
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.026066+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260416-directive-date-lag

## content

Portfolio directives in borg-collective can lag behind the decisions they document by multiple days (here: 2 days). When a directive is formalized later than the decision date, sibling-repo plan files (e.g., `wayfinderai-waypoint/PROJECT_PLAN.md`) may already be ahead of the borg-collective record and diverge silently. The directive filename uses the decision date, not the creation date, which obscures the lag.

## resolution

When creating a backdated directive, immediately spot-check all referenced external repo paths to confirm they exist and are consistent with the directive's stack decisions. Add a `formalized_date` field to directive frontmatter distinct from the decision date to make lag explicit.
