# Source: GitHub issue 1071 "Skill Bloating and Regressions" (mattpocock/skills)

**Full citation:** fuzzyhope1502 (issue author); frabonomi; mattpocock (maintainer reply). "Skill Bloating and Regressions #1071." github.com/mattpocock/skills. Opened 2026-09-11, closed as not planned 2026-10-07.
**URL:** https://github.com/mattpocock/skills/issues/1071
**Date accessed:** 2026-10-13
**Evidence level:** 8 (Anecdotal / personal experience, first-hand user report on the primary repo)
**Research topic area:** Reception of Matt Pocock skills (mp-reception)

## Credibility Scores

| # | Dimension | Score | Note |
|---|-----------|-------|------|
| 1 | Authority | 3/10 | self-described ex-fan |
| 2 | Evidence Quality | 4/10 | first-hand, no repro |
| 3 | Currency | 10/10 | 5 weeks old |
| 4 | Intent | 8/10 | improve the tool |
| 5 | Bias & Objectivity | 5/10 | one-sided |
| 6 | Logic & Coherence | 6/10 | coherent |
| 7 | Corroboration | 5/10 | 2nd user agrees |
| 8 | Intellectual Honesty | 6/10 | admits unsure |
| 9 | Specificity | 6/10 | names skills |
| 10 | Relevance | 10/10 | core topic |

Justifications (one line per dimension, same order):

1. Authority: An anonymous GitHub user, though a self-described long-time user filing on the maintainer's own tracker.
2. Evidence Quality: First-hand observation of specific behaviors, but no session logs or repro, which the maintainer's own bar asks for.
3. Currency: Filed 2026-09-11 against the v1.x line, so current.
4. Intent: Filed to improve the tool, no commercial motive.
5. Bias & Objectivity: Single-sided complaint, though the reporter says "I'm not sure if it's the skills or the models".
6. Logic & Coherence: Complaints are specific and internally consistent.
7. Corroboration: frabonomi (non-native speaker) agrees on vocabulary; SkillsBench-style regressions and the HN thread align.
8. Intellectual Honesty: The reporter explicitly flags uncertainty about skills versus model changes.
9. Specificity: Names ask-matt, diagnosing-bugs, wait-what, wayfinder, and four grilling skills.
10. Relevance: Direct evidence of a regression complaint from an adopter of the repo this track studies.

**Score band:** borderline

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- A former enthusiast reports the skills "nowadays" add work instead of removing it, and attributes it either to skill changes or to model changes (uncertain).
- Names concrete problems: /ask-matt gives inconsistent routing on repeated questions, /diagnosing-bugs fires in non-coding chats and "poisons" context, 3-4 overlapping grilling skills, jargon needing /wait-what on almost every reply.
- A second user (frabonomi) agrees the wording became hard to follow, suspecting stripped-down sentence structure.
- The maintainer closed it as not planned with an AI-generated triage reply, pointing to SCOPE.md "the bar": issues need an observed failure with session detail, not general impressions.
- Shows the maintainer curates by policy: feedback without a reproducible session is routed to Discussions rather than acted on.

## Verified Quote(s)

**Location reference:** Issue body, 1st, 2nd and 5th paragraphs (reporter fuzzyhope1502, 2026-09-11); maintainer reply by mattpocock dated 2026-10-07.

> nowadays these skills just do not give me many benefits, and most of the time it now seems to add work.

> Even having regular non-coding conversations this skill just randomly gets invoked and run around in circles solving nothing (while also ruining/poisoning the context).

> Issues here track specific changes to skills, so general impressions fit better in GitHub Discussions.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Borderline band, included as sole primary-venue evidence of a regression and unwanted-auto-trigger case (gap-fill for falsification); one report, so never used alone.

**Redundancy check:** Only first-hand regression report found on the repo itself; the Kaizen Craft guide cites other issues (TDD attention dilution) that this one does not.

**Perspective category:** Boots-on-the-ground
