# Source: HN comment (diegof79): grill-me used instead of Claude Code plan mode

**Full citation:** diegof79. Comment on "Plan mode is dead". news.ycombinator.com. 2026-09-25.
**URL:** https://news.ycombinator.com/item?id=49851420
**Date accessed:** 2026-10-13
**Evidence level:** 8 (Anecdotal / personal experience)
**Research topic area:** Reception of Matt Pocock skills (mp-reception)

## Credibility Scores

| # | Dimension | Score | Note |
|---|-----------|-------|------|
| 1 | Authority | 3/10 | anonymous handle |
| 2 | Evidence Quality | 3/10 | first-hand, no data |
| 3 | Currency | 10/10 | 3 weeks old |
| 4 | Intent | 7/10 | sharing practice |
| 5 | Bias & Objectivity | 6/10 | pro-skill |
| 6 | Logic & Coherence | 6/10 | coherent |
| 7 | Corroboration | 5/10 | others echo |
| 8 | Intellectual Honesty | 6/10 | names a trade-off |
| 9 | Specificity | 5/10 | names opusplan |
| 10 | Relevance | 8/10 | native-feature angle |

Justifications (one line per dimension, same order):

1. Authority: Anonymous HN user, though the detail suggests real daily use.
2. Evidence Quality: Personal workflow account with no metrics.
3. Currency: Posted 2026-09-25.
4. Intent: Sharing a practice in a discussion thread.
5. Bias & Objectivity: Positive on the skill but explains the two jobs plan mode did for them.
6. Logic & Coherence: Reasoning (review choices, then run on another model) is coherent.
7. Corroboration: Other commenters in the same thread (valzam, a Grilling-pointer comment) say similar things.
8. Intellectual Honesty: Notes a personal fork was needed for the ask tool, a limit of the stock skill.
9. Specificity: Names the opusplan option and subagent routing.
10. Relevance: Directly speaks to the Pocock-versus-native-features question (plan mode).

**Score band:** borderline

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- A user prefers /grill-me to Claude Code plan mode and to "a complex, spec-driven set of skills".
- They forked the skill to use Claude's ask tool for a better UX, while the maintainer's repo explicitly declines native question tools (see the native-question-tool card).
- They replaced the opusplan cross-model feature with an explicit subagent on another model, so the native feature was substituted piecemeal.
- Adoption pattern: the skill is a drop-in replacement for part of a native feature, not an add-on.

## Verified Quote(s)

**Location reference:** Comment by diegof79 on HN item "Plan mode is dead" (story 49840054), paragraphs 1 and 3; comment id 49851420.

> Lately, I've been using Matt Pocock's “/grill-me” skill more and more, rather than plan mode or a complex, spec-driven set of skills.

> The grill-me skill is much better for reviewing and clarifying choices (and modifying it to use the ask tool makes you go faster).

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Borderline band, included as first-hand evidence of the native-feature substitution pattern; corroborated by two other plan-mode-thread comments seen in the same run.

**Redundancy check:** Complements the maintainer's native-question-tool policy (the divergence between user and maintainer).

**Perspective category:** Boots-on-the-ground
