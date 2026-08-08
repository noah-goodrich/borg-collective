---
id: 20260714-merge-over-red-ci-acknowledged
date: '2026-07-14'
project: borg-collective
domain: infrastructure
tags:
- ci
- bats
- merge-strategy
- technical-debt
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260714-1747-borg-collective
created_at: '2026-07-14 17:49:55.806862+00:00'
updated_at: '2026-07-14 17:49:55.806863+00:00'
---

# 20260714-merge-over-red-ci-acknowledged

## decision

Merge claude-plugins #33 only after confirming CI is green on that PR specifically, even though the suite had been red since #14 and prior PRs (#30/#31) had merged over red.

## context

The BATS CI suite was broken for weeks due to the same borg-link-down bug. Before merging the rebuilt plugin (0.8.8), the team verified zero build-drift from merged main and confirmed green CI on the fix PR.

## reasoning

Merging a deployment artifact (the plugin build) over known-red CI that was caused by the very bug being fixed would leave ambiguity about whether the fix actually worked. Requiring green CI on the fix PR closes the loop definitively.
