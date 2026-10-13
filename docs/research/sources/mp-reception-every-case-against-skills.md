# Source: Every, "The Case Against Skills" (Context Window)

**Full citation:** Laura Entis (staff writer), quoting Mike Taylor (head of tech consulting). "The Case Against Skills." Every, Context Window. 2026-07-16, updated 2026-09-17.
**URL:** https://every.to/context-window/the-case-against-skills
**Date accessed:** 2026-10-13
**Evidence level:** 7 (Expert opinion; secondhand reporting of SWE-Skills-Bench)
**Research topic area:** Reception of Matt Pocock skills (mp-reception)

## Credibility Scores

| # | Dimension | Score | Note |
|---|-----------|-------|------|
| 1 | Authority | 5/10 | Every staff + consultant |
| 2 | Evidence Quality | 5/10 | cites benchmark, partial |
| 3 | Currency | 10/10 | 3 months old |
| 4 | Intent | 4/10 | subscription publisher |
| 5 | Bias & Objectivity | 6/10 | pro-eval stance |
| 6 | Logic & Coherence | 6/10 | argument sound |
| 7 | Corroboration | 7/10 | benchmark verified |
| 8 | Intellectual Honesty | 6/10 | "skills have shelf life" |
| 9 | Specificity | 6/10 | figures, paywall cut |
| 10 | Relevance | 6/10 | generic, not Pocock |

Justifications (one line per dimension, same order):

1. Authority: Established AI publication; the argument is a consultant's opinion relayed by a staff writer.
2. Evidence Quality: Cites SWE-Skills-Bench (verified separately) and one anecdote about Fable 5 versus Opus 4.8; the evals framework is paywalled.
3. Currency: Published 2026-07-16 and updated 2026-09-17.
4. Intent: Subscription publisher with a related plugin (Compound Engineering) and an audience hook.
5. Bias & Objectivity: Takes a strong position but names legitimate skill uses.
6. Logic & Coherence: The "fighting the model's weights" and shelf-life arguments are coherent though unquantified.
7. Corroboration: The 49/39/3/7 benchmark figures match the arXiv abstract.
8. Intellectual Honesty: Says skills are still useful for private context, which tempers the headline.
9. Specificity: Gives benchmark figures and a four-step audit but hides the evals framework behind the paywall.
10. Relevance: Generic skills critique; Pocock is not mentioned, so applicability is inferential.

**Score band:** borderline

## Bias Guard Check

- [x] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [ ] Neutral / no strong reaction

The "prove it with evals" stance matches borg's measure-first principle, so dims 5, 6 and 8 were scored harder.

## Key Findings

- A senior AI consultant argues frontier models have absorbed most skills trending on social media, and extra instructions "fight the weights" of the model.
- Skills that patched Opus 4.8 mistakes reportedly harmed Fable 5 performance; skill utility has a shelf life tied to model generation.
- Cites SWE-Skills-Bench: of 49 public SWE skills 39 had no effect, three made things worse, and the worst raised token use 451%.
- Recommends a skills audit: keep private context and personal taste; retest model-quirk patches; retire skills that cannot prove value.
- Rest of the framework (4-step eval method, an anti-skills anecdote) is paywalled; Pocock is not named in the free portion.

## Verified Quote(s)

**Location reference:** Section "Signal" paragraph 3 (Mike Taylor Fable 5 anecdote) and section "Why it matters:" paragraph 1 (benchmark). Free portion ends before "Steal this workflow" paywall.

> SWE-Skills-Bench, a research benchmark that tests whether agent skills make agents better at software engineering, tested 49 public software-engineering skills and found that 39 didn’t impact performance, while three made things worse.

> Mike recently found when testing Fable 5 that some of the skills Opus 4.8 needed to avoid mistakes actually harmed the newer model’s performance.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Borderline band, included as the contrarian view from Compound Engineering's own publisher; shelf-life claim has one anecdote, so used with the arXiv cards.

**Redundancy check:** Adds the model-generation shelf-life argument that the benchmark cards lack; benchmark figures are redundant with the SWE-Skills-Bench card.

**Perspective category:** Contrarian
