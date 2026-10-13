# Source: QuestionPro Engineering, Stop Asking Claude to Agree With You

**Full citation:** Karyakarte, Akash. "Stop Asking Claude to Agree With You." QuestionPro Engineering Blog, updated 2026-05-29. https://www.questionpro.com/engineering/engineering/developer%20tools/ai%20&%20machine%20learning/stop-asking-claude-to-agree-with-you/
**URL:** https://www.questionpro.com/engineering/engineering/developer%20tools/ai%20&%20machine%20learning/stop-asking-claude-to-agree-with-you/
**Date accessed:** 2026-10-13
**Evidence level:** 8 (practitioner anecdote and argument)
**Research topic area:** Grill-me vs native plan mode (what plan mode does not do)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 5/10 | Engineer at a company |
| 2 | Evidence Quality | 3/10 | Personal reasoning |
| 3 | Currency | 9/10 | May 2026 |
| 4 | Intent | 6/10 | Engineering blog |
| 5 | Bias & Objectivity | 4/10 | Advocates grilling |
| 6 | Logic & Coherence | 7/10 | Clear argument |
| 7 | Corroboration | 5/10 | Matches Matt's rationale |
| 8 | Intellectual Honesty | 5/10 | Little counter-evidence |
| 9 | Specificity | 6/10 | Quotes the skill |
| 10 | Relevance | 8/10 | Targets plan mode |

- Authority: a named engineer on a company engineering blog, not a recognized expert.
- Evidence Quality: reasoned argument and anecdote, no measurement.
- Currency: updated 2026-05-29.
- Intent: engineering blog sharing a workflow.
- Bias: pro-grilling advocacy; I scored dims 5, 6, and 8 harder because it aligns with Matt's thesis.
- Logic: the claim that plan mode optimizes execution, not idea quality, is coherent.
- Corroboration: it restates the README's "grilling" argument rather than testing it.
- Honesty: offers little evidence of grilling failures.
- Specificity: quotes the skill's core instruction.
- Relevance: the only found source directly contrasting native plan mode with grilling.

**Score band:** borderline

## Bias Guard Check

- [x] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [ ] Neutral / no strong reaction

## Key Findings

- The author argues native plan mode answers how to build, not whether the thing is worth building.
- Grill-me is described as interrogating a plan one decision at a time so vagueness is removed before code exists.
- This frames the one clear gap in native features that Matt's skills fill: a pre-plan interview, which Claude Code's plan mode does not do by default.
- Matt's own out-of-scope note shows the grilling is deliberately free-text questions rather than a native question picker.
- Weakness: one practitioner's view; no controlled comparison.

## Verified Quote(s)

**Location reference:** Section discussing plan mode, the sentences about its limits (near the start of the body).

> Plan mode assumes your idea is already sound and your only problem is execution.

> never asks whether the thing is worth building, or whether you’ve actually thought it through.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Borderline; the sole practitioner source on plan mode vs grilling; flagged as advocacy.

**Redundancy check:** Unique angle (plan mode contrast).

**Perspective category:** Boots-on-the-ground
