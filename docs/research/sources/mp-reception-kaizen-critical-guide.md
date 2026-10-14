# Source: Kaizen Craft: "Matt Pocock's Skills, Actually Explained: A Critical Guide"

**Full citation:** Kaitlin Z. Albasi. "Matt Pocock's Skills, Actually Explained: A Critical Guide for Current Usage." kaizencode.art (digital garden). 2026-07-16.
**URL:** https://kaizencode.art/notepad/matt-pocock-skills-guide/
**Date accessed:** 2026-10-13
**Evidence level:** 7 (Expert opinion / thought leadership, with primary-source reading)
**Research topic area:** Reception of Matt Pocock skills (mp-reception)

## Credibility Scores

| # | Dimension | Score | Note |
|---|-----------|-------|------|
| 1 | Authority | 5/10 | practitioner, personal site |
| 2 | Evidence Quality | 5/10 | read SKILL.md + issues |
| 3 | Currency | 9/10 | 3 months old |
| 4 | Intent | 8/10 | non-commercial garden |
| 5 | Bias & Objectivity | 8/10 | fair, names critiques |
| 6 | Logic & Coherence | 7/10 | mostly sound |
| 7 | Corroboration | 6/10 | HN, issues partly verified |
| 8 | Intellectual Honesty | 8/10 | "trust your own week" |
| 9 | Specificity | 8/10 | issue numbers cited |
| 10 | Relevance | 10/10 | core topic |

Justifications (one line per dimension, same order):

1. Authority: Independent writer with an AI-labor-market day job; credible reader of the repo but not a recognized authority.
2. Evidence Quality: Reports reading the SKILL.md files, repo issues and HN threads rather than secondhand blogs; no measurements.
3. Currency: Dated 2026-07-16, before v1.3 changes, so part of it may be superseded.
4. Intent: Personal digital garden; says outright that search results are SEO slop.
5. Bias & Objectivity: Balanced: praises diagnosing-bugs and writing-great-skills while listing self-report bias, stack lock-in and rough edges.
6. Logic & Coherence: Separates "load-bearing structure" from "unvalidated phrasing" with reasons.
7. Corroboration: Issue 527 and the TDD attention-dilution issue could be checked on GitHub, and the HN thread I could not locate (one of two cited).
8. Intellectual Honesty: Closes by telling readers to trust their own week of usage over any blog, including this one.
9. Specificity: Cites issue 527, setup-skill changes, 39-skill count, 120k "smart zone".
10. Relevance: The most direct critical treatment of the pack in the corpus.

**Score band:** borderline

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Names the structural critique from HN: no controlled comparison shows the elaborate phrasing ("walk down each branch of the decision tree") outperforms plain "ask me clarifying questions".
- Documents repo issues: TDD skill "attention dilution" in long sessions, code-review subagents trusted without verification, grill-me scoped only to plans (issue 527).
- Stack lock-in was a fair complaint (TypeScript/Node, GitHub issues, Husky); the changelog shows setup now supports local markdown and GitLab.
- Warns that the repo is "literally his dotfiles" with personal skills, and advises curation instead of installing all 39.
- Observes most search results about the repo are near-identical SEO posts with inconsistent star counts.

## Verified Quote(s)

**Location reference:** Intro paragraph 4 (SEO warning); section "Critiques: self-report bias, skill reliability, stack lock-in, and MCP" paragraph 1; section "Assessment: transferable discipline vs. unvalidated phrasing" paragraph 2.

> nobody in that thread had run a controlled comparison showing the elaborate phrasing actually produces a different outcome versus the plain version.

> some of this is genuinely load-bearing structure, and some of it is confident phrasing that hasn’t been shown to outperform plainer instructions.

> half of what comes up when you search this repo’s name is SEO content-mill slop.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Borderline band (6.7 average), included as the most thorough critical treatment and the only one citing issue-level critiques; claims also checked against the repo issue tracker.

**Redundancy check:** Provides issue-level critiques (TDD dilution, review trust) no other card has; the HN claim is also confirmed independently by card hn-ai-coding-agent-skills-thread.

**Perspective category:** Contrarian
