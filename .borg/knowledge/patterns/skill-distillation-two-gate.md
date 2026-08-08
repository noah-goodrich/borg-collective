---
id: skill-distillation-two-gate
project: borg-collective
domain: code-quality
tags:
- skill-distillation
- verification
- grep
- blind-review
- workflow
preconditions: []
steps:
- Author a rubric listing what to cut (boilerplate, redundancy) and a preserve-verbatim
  list of critical literal strings/clauses (store in SKILL-DISTILLATION-RUBRIC.md
  or equivalent).
- Perform the distillation with a capable model (Fable/Opus); produce the candidate
  file.
- 'Run the self-check: author verifies their own output against the preserve list.'
- 'Run the grep gate: independent script/command checks that every literal on the
  preserve list appears in the distilled file.'
- 'Run a blind operational review: a separate model instance (no context from the
  distillation session) reviews the distilled file for behavioral completeness, pretending
  it is the only version.'
- Restore any dropped clauses flagged by either gate using a grunt model (Haiku/Sonnet)
  to minimize cost.
- Re-run both gates on the restored file.
- Backup the original (SKILL.md.pre-distill.bak), swap the distilled version live,
  gitignore or delete the backup after commit.
pitfalls:
- Self-check alone misses dropped clauses — the independent blind review is not optional.
- The grep gate only catches literals on the preserve list; semantic behavioral changes
  that rephrase rather than delete content will pass the grep gate but may be caught
  by the blind review.
- Do not commit the .pre-distill.bak file; gitignore the pattern *.pre-distill.bak.
- Human diff-read of the distilled file is still advised before merging if the skill
  is load-bearing production config.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260708-1940-orchestrator
superseded_by: null
created_at: '2026-07-08 19:41:01.403441+00:00'
updated_at: '2026-07-08 19:41:01.403442+00:00'
---

# skill-distillation-two-gate

## description

Safe procedure for reducing skill/prompt files while preserving all load-bearing behavioral clauses, using two independent verification passes before swapping the live file.
