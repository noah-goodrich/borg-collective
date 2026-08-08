---
id: obs-20260606-ai-citation-rate
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- deep-research
- citations
- hallucination
- verification
- DeepTRACE
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.480194+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260606-ai-citation-rate

## content

Per DeepTRACE findings cited in the meta-review analysis: AI-generated citations are 47–97.5% unsupported depending on domain and model. This is the empirical baseline justifying why verification cannot be self-reported — the model generating citations has a strong prior toward producing plausible-sounding but unverifiable references.

## resolution

Architectural implication: any verification step that runs in the same context as generation shares the same hallucination prior. The fail-closed gate must be model-free (shell assertions on file content) to avoid laundering hallucinated citations through a second hallucination pass.
