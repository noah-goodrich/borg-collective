---
id: verification-spike-before-directive-implementation
project: borg-collective
domain: architecture
tags:
- verification
- directive
- spike
- agentic
- orchestration
preconditions: []
steps:
- Identify the key assumptions the directive depends on (hook names, binary PATH,
  API behavior)
- Run the minimal commands needed to confirm or deny each assumption (e.g., `command
  -v <binary>`, trigger hook manually, test worktree exec)
- Save findings to `docs/plans/reviews/<date>-<slug>-verification.md`
- Amend the directive with verified findings before implementation begins
- If assumptions were substantially wrong, consider severing and rewriting rather
  than patching
pitfalls:
- Skipping the spike leads to implementing against wrong assumptions, requiring costly
  rework mid-implementation
- SubagentStop hook names and payload schemas may differ from documentation — always
  confirm empirically
- Binary absence vs PATH misconfiguration require different fixes; conflating them
  wastes time
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.348592+00:00'
updated_at: '2026-06-16 10:27:02.348592+00:00'
---

# verification-spike-before-directive-implementation

## description

Before implementing a complex agentic/orchestration directive, run a targeted verification spike to confirm foundational assumptions about tool behavior, hook availability, and binary presence.
