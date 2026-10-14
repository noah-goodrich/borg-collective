# Source: mattpocock/skills SCOPE.md and .out-of-scope decisions

**Full citation:** Matt Pocock. "Scope" (SCOPE.md) and ".out-of-scope/new-skills.md", ".out-of-scope/subagent-recursion.md". mattpocock/skills, GitHub. Live 2026-10-13.
**URL:** https://github.com/mattpocock/skills/blob/main/SCOPE.md
**Date accessed:** 2026-10-13
**Evidence level:** 7 (author's governance statement / thought leadership)
**Research topic area:** WHAT IT IS (primary sources): mattpocock/skills, Sandcastle, AI Hero, Matt's stated philosophy

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 9/10 | The owner's own contribution policy and recorded rejections. |
| 2 | Evidence Quality | 5/10 | Policy statements with cited prior issue numbers, but no data on outcomes. |
| 3 | Currency | 10/10 | Live, current files. |
| 4 | Intent | 7/10 | Maintenance-load management for an open-source project; some brand protection. |
| 5 | Bias & Objectivity | 6/10 | Frank about reasons for rejecting ideas, though only one side (the maintainer's). |
| 6 | Logic & Coherence | 8/10 | The rules are internally consistent: observed failure plus fits philosophy. |
| 7 | Corroboration | 5/10 | Philosophy echoed in the README and the AI Engineer talk (small, adaptable skills); not otherwise independently audited. |
| 8 | Intellectual Honesty | 8/10 | Explains the costs of each rejection ('permanent maintenance surface'). |
| 9 | Specificity | 8/10 | Names the exact bar, buckets, and prior rejected issue numbers. |
| 10 | Relevance | 9/10 | Explains what the library will not become, which matters for adoption decisions. |

**Score band:** keep

(Intermediate weighted average about 7.5; the disposition is the band word.)

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- The repo is explicitly a curated personal set: 'the set of skills I use every day', not a community-driven framework; new-skill proposals and contributions are closed.
- An idea stays open only if it describes an observed failure in a real session and fits the philosophy; reactions and +1 comments do not count.
- misc/ skills (git-guardrails-claude-code, setup-pre-commit, scaffold-exercises, migrate-to-shoehorn) are frozen and unmaintained and do not ship in the Claude Code plugin.
- Skills deliberately do not guard against sub-agent recursion: the harness, not skill prose, should stop infinite subagent loops.
- Grilling is deliberately not routed through a harness's native question tool, because structured pickers push toward multiple-choice questions, the opposite of open grilling.

## Verified Quote(s)

**Location reference:** Quote 1: SCOPE.md, first paragraph; Quote 2: .out-of-scope/new-skills.md, section 'Why this is out of scope', first sentence; Quote 3: .out-of-scope/subagent-recursion.md, section 'Why this is out of scope', first sentence

> This repo is the set of skills I use every day. It is curated: ideas are welcome, and each one is judged against the bar below.

> The catalog is the set of skills I use myself every day, and it's deliberately small.

> The harness should be responsible for stopping infinite subagent loops, not skills.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Primary evidence of philosophy and governance (curated personal kit, not a framework). Lower evidence quality, high relevance to the 'Matt vs borg' comparison.

**Redundancy check:** Adds governance and non-goals that the README does not state.

**Perspective category:** Practitioner
