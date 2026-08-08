---
id: obs-20260606-ai-ideation-homogenization
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- brainstorm
- diversity
- multi-agent
- council
- invention
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.480588+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260606-ai-ideation-homogenization

## content

Meta-review finding: AI ideation homogenizes outputs by ~10.7% unless diversity is explicitly designed for. A single-agent brainstorm or a council of agents with shared context will converge on the same solution space. The 9-voice council design with 9 genuine dissents in Workflow 2 is a direct response to this — diversity must be structurally enforced, not hoped for.

## resolution

When running councils or multi-agent brainstorms, assign distinct roles/axes to agents before generation, not after. Require dissents as a typed field in StructuredOutput so they cannot be omitted. Track whether dissents are substantive vs. cosmetic.
