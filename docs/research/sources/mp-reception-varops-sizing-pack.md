# Source: VarOps: sizing the Pocock skill pack (measured install and token cost)

**Full citation:** Gritt Scott. "How to size an agent skill pack when three sources disagree on how many skills it has." VarOps (Skill Issue column). 2026-09-02.
**URL:** https://varops.com/how-to-size-an-agent-skill-pack-when-three-sources-disagree-on-how-many-skills-it-has/
**Date accessed:** 2026-10-13
**Evidence level:** 5 (Practitioner case study with data; estimates, no agent run)
**Research topic area:** Reception of Matt Pocock skills (mp-reception)

## Credibility Scores

| # | Dimension | Score | Note |
|---|-----------|-------|------|
| 1 | Authority | 5/10 | trade columnist |
| 2 | Evidence Quality | 6/10 | cloned, measured, est. |
| 3 | Currency | 10/10 | 6 weeks old |
| 4 | Intent | 5/10 | publisher, no pitch |
| 5 | Bias & Objectivity | 8/10 | fair, notes limits |
| 6 | Logic & Coherence | 8/10 | sound |
| 7 | Corroboration | 6/10 | plugin.json checkable |
| 8 | Intellectual Honesty | 10/10 | states limits up front |
| 9 | Specificity | 9/10 | numbers, file names |
| 10 | Relevance | 8/10 | cost angle |

Justifications (one line per dimension, same order):

1. Authority: Named trade-publication field-tester; a credible practitioner voice but not a recognized expert.
2. Evidence Quality: Cloned the repo and measured plugin manifest, frontmatter and file sizes, but token counts are characters divided by four and no agent was run.
3. Currency: Dated 2026-09-02 against repo state at main on that day.
4. Intent: Publisher's column with a newsletter business model but no affiliate or product pitch for the pack.
5. Bias & Objectivity: Reports both the bloat non-issue and the setup burden and the tension with the "not owning the process" claim.
6. Logic & Coherence: Conclusions follow from the stated measurements, and it declines to claim quality results.
7. Corroboration: Repo facts (37 SKILL.md, 25 in manifest) are checkable and the GitHub API now shows 289k stars; the token figures stand alone.
8. Intellectual Honesty: Opens with two explicit limits: estimated tokens and no live-agent test.
9. Specificity: Gives per-skill token sizes (wayfinder, ask-matt, writing-for-agents) and counts of files.
10. Relevance: Directly answers the "token cost of auto-triggering and bloat" question for the Claude plugin route.

**Score band:** borderline

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- The always-on cost is small: the 25 shipped skills' names and descriptions total roughly 1,030 tokens, about half a percent of a 200k window.
- The real cost is lumpy: bodies total about 28,800 tokens, supporting files about 21,500; three skills (wayfinder, ask-matt, writing-for-agents) carry roughly 8,500.
- Counts disagree by route: 37 SKILL.md in the repo, 25 in the Claude plugin manifest, 53 in the skills.sh index; the 12 not in the plugin are in-progress and misc.
- It reads the README claim that composable pieces avoid "owning the process" and finds a real process underneath (CONTEXT.md vocabulary, setup-emitted config), calling this a fair open question rather than hypocrisy.
- It explicitly cannot say whether any skill improves agent output; it is a sizing verdict only.

## Verified Quote(s)

**Location reference:** Standfirst (para 3), "What the bench did, and what it cannot tell anyone" (para 3), and "The cost that does bite is lumpy, and that is the method" (para 4).

> The thing most teams are hesitating over - context bloat - measures about half a percent of a 200,000-token window.

> Nothing here supports a claim about whether grill-me produces better specs, whether tdd holds an agent to red-green-refactor, or whether any skill in the pack improves an agent's output at all.

> Everything firing at once - every body plus every supporting file - is approximately 50,000 tokens, roughly a quarter of a 200k window.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Borderline band (6.8 average, top of the range), included as sole source that measures token cost rather than asserting it; limits stated by the author.

**Redundancy check:** Unique: no other card carries token measurements. The "no quality evidence" caveat complements SkillsBench cards.

**Perspective category:** Practitioner
