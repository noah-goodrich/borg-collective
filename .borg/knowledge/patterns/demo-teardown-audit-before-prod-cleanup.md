---
id: demo-teardown-audit-before-prod-cleanup
project: borg-collective
domain: infrastructure
tags:
- snowfort
- data-quality
- audit
- demo-data
preconditions: []
steps:
- 'Run automated audit script to enumerate all objects (Snowflake: warehouses, databases,
  roles, users, etc.)'
- Classify each finding as demo/test (name pattern, creation date, no real workload
  evidence) vs. real
- 'Present two lists to user: ''will delete'' and ''will keep'' with classification
  rationale'
- Obtain explicit user confirmation before any destructive operation
- Execute teardown, then immediately re-run audit script to verify post-teardown state
- Record final finding count in decision log
pitfalls:
- Name patterns alone are insufficient — objects like SNOWFORT_TEST_* are obvious,
  but BAD_COST_WH required contextual analysis to confirm as demo
- Post-teardown rescan is mandatory; teardown scripts can silently skip objects due
  to dependency order or permission gaps
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.266838+00:00'
updated_at: '2026-06-16 10:27:02.266839+00:00'
---

# demo-teardown-audit-before-prod-cleanup

## description

Before executing a prod teardown of suspected demo/test objects, run a full audit to classify findings as demo vs. real, present the classification to the user for confirmation, then execute
