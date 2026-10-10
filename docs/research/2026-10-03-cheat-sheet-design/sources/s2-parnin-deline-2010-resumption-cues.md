# Source: Parnin & DeLine 2010 - Evaluating cues for resuming interrupted programming tasks (CHI)

**Full citation:** Parnin C, DeLine R. "Evaluating cues for resuming interrupted programming tasks." Proceedings of CHI 2010. doi:10.1145/1753326.1753342
**URL:** https://api.openalex.org/works/doi:10.1145/1753326.1753342
**Date accessed:** 2026-10-04
Card revised: 2026-10-04 (location audit before verification)
**Evidence level:** 2
**Research topic area:** S2 re-entry, resumption and handoff - Developer task-context recovery

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 8/10 | Established software-engineering HCI researchers (Georgia Tech / Microsoft Research); CHI peer review. |
| 2 | Evidence Quality | 7/10 | Survey of 371 programmers plus a controlled lab study comparing two automated cues with note-taking. |
| 3 | Currency | 4/10 | 2010; +2 timeless bonus for human-memory findings, but tooling has changed. |
| 4 | Intent | 9/10 | Academic research with a tool-prototype motive. |
| 5 | Bias & Objectivity | 7/10 | Reports the participant preference result even though it differed from performance equivalence. |
| 6 | Logic & Coherence | 8/10 | Design is simple and claims follow. |
| 7 | Corroboration | 8/10 | Consistent with Parnin & Rugaber 2009 on note-taking and with Altmann & Trafton on cues. |
| 8 | Intellectual Honesty | 7/10 | Abstract-only access. |
| 9 | Specificity | 8/10 | Success-rate ratio and sample size. |
| 10 | Relevance | 9/10 | Directly tests resumption cues for developers against the status quo (notes). |

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions -> scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions -> scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Programmers rely heavily on note-taking across media to suspend and resume tasks (survey, n=371).
- Both automated cues (activity summaries) gave twice the task success rate of note-taking alone.
- The two cues performed similarly, but developers strongly preferred the chronological, code-snippet presentation - preference and performance diverged, so user choice should not be the only evidence for a layout.

## Verified Quote(s)

**Location reference:** Quote 1: Abstract, sentence 3. Quote 2: Abstract, sentence 6. Quote 3: Abstract, sentence 7
(the last of seven sentences; the abstract is unlabelled). Counting rule: the abstract text is split at a terminal
period or question mark followed by a capital letter (decimals, "vs.", "i.e." and "e.g." do not split). The abstract
is reconstructed from the record's `abstract_inverted_index` by ordering words by position. Snapshot:
docs/research/snapshots/s2-parnin-deline-2010-resumption-cues.txt
(Snapshot not committed; re-derive from the card URL.)

> We surveyed 371 programmers on the nature of their tasks, interruptions, task suspension and resumption strategies and found that they rely heavily on note-taking across several types of media.

> Both cues performed well: developers using either cue completed their tasks with twice the success rate as those using note-taking alone.

> Despite the similar performance of the cues, developers strongly preferred the cue that presents activities chronologically as code snippets.

**Access status:** cached/partial - ACM page returned HTTP 403; quotes are verbatim spans of the OpenAlex abstract snapshot. Card URL changed 2026-10-04 from the DOI landing page (publisher host blocks automated fetch) to the OpenAlex API record (Europe PMC holds no abstract for this DOI), on which the quotes were re-verified.

## Inclusion Decision

**Decision:** Core
**Rationale:** Best experimental evidence that an automated activity cue beats a developer's own notes at re-entry.

**Redundancy check:** Complements Parnin 2013 (field coping tactics) with a controlled comparison.

**Perspective category:** Academic
