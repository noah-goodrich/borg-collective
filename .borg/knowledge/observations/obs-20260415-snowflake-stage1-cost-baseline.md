---
id: obs-20260415-snowflake-stage1-cost-baseline
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- snowflake
- cost
- postgres
- infrastructure
- saas
- stage1
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.008316+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260415-snowflake-stage1-cost-baseline

## content

Snowflake Postgres at Stage 1 (smallest tier) costs approximately $10/month with no activity. For a pre-launch consumer SaaS product with zero users this is dead cost. Supabase free tier supports equivalent workloads (estimated 0–500 households) at $0.

## resolution

Use Supabase free tier for MVP validation of consumer SaaS products. Migrate to paid tiers or Snowflake only when workload or compliance requirements justify the cost.
