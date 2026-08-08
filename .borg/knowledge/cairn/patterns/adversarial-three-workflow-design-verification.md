---
id: adversarial-three-workflow-design-verification
project: cairn
domain: architecture
tags:
- design
- adversarial
- verification
- subagent
preconditions: []
steps:
- Identify the three orthogonal design axes (placement, schema/architecture, loss/conformance)
- Run each as an independent adversarial subagent workflow with ~800k token budget
- Have the adversary enumerate concrete failure modes (e.g., 8 data-loss holes)
- For each hole, produce a named revision (e.g., OUTBOX-RECONCILE-v2) that closes
  it
- Lock PROJECT_PLAN.md only after all holes are closed and verified
pitfalls:
- Adversarial review of non-interactive contexts (hooks, daemons) reliably finds interactive-prompt
  assumptions that would hang in production
- ~2.4M subagent tokens is a significant cost — scope the adversarial surface carefully
  before running
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0914-cairn
superseded_by: null
created_at: '2026-06-16 10:27:03.266396+00:00'
updated_at: '2026-06-16 10:27:03.266397+00:00'
---

# adversarial-three-workflow-design-verification

## description

Run three independent adversarial design workflows (placement, architecture, zero-loss/conformance) before locking a PROJECT_PLAN.md, using subagents to find failure modes
