# Source: nocoders: Superpowers vs Matt Pocock's skills, two opposite bets

**Full citation:** Mick Brzeziński. "Superpowers vs Matt Pocock's skills: two opposite bets on who runs your agent." nocoders.com. 2026-06-26.
**URL:** https://www.nocoders.com/blog/superpowers-vs-pocock-agent-skills/
**Date accessed:** 2026-10-13
**Evidence level:** 7 (Expert opinion; read plugin manifests, hooks, SKILL.md files)
**Research topic area:** Reception of Matt Pocock skills (mp-reception)

## Credibility Scores

| # | Dimension | Score | Note |
|---|-----------|-------|------|
| 1 | Authority | 5/10 | indie builder |
| 2 | Evidence Quality | 6/10 | read repos end to end |
| 3 | Currency | 8/10 | 3.5 months old |
| 4 | Intent | 6/10 | personal blog |
| 5 | Bias & Objectivity | 8/10 | balanced |
| 6 | Logic & Coherence | 8/10 | clean framing |
| 7 | Corroboration | 7/10 | matches Addy, Zenn |
| 8 | Intellectual Honesty | 7/10 | "neither bet is wrong" |
| 9 | Specificity | 8/10 | manifest/hook detail |
| 10 | Relevance | 8/10 | good fit for borg |

Justifications (one line per dimension, same order):

1. Authority: Independent builder who documents reading the repos; reputable enough but unknown credentials.
2. Evidence Quality: Based on files (manifests, SessionStart hook, frontmatter) rather than runs; no usage data.
3. Currency: Dated 2026-06-26, at Pocock v1.0.1, so partly dated.
4. Intent: Personal blog and project showcase, low commercial motive.
5. Bias & Objectivity: States costs of both bets, including that Pocock's discipline is opt-in.
6. Logic & Coherence: Clear framework-versus-library argument backed by hook mechanics.
7. Corroboration: Same split appears in Zenn, Addy Osmani's page and the glean write-up from different authors.
8. Intellectual Honesty: Concludes neither is wrong and asks the reader to pick by how much override they want.
9. Specificity: Includes a feature table with versions (6.0.3 vs 1.0.1) and the 94 percent PR rejection rate.
10. Relevance: Directly on the Superpowers comparison and the invoke-versus-inject axis that matters for auto-triggering cost.

**Score band:** borderline

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Both libraries use the same primitive (SKILL.md folders); the fork is default invocation: Superpowers injects a SessionStart hook ("1% chance, you MUST invoke"), Pocock has no hook and fires skills on explicit call or description match.
- v1.0 formalised user-invoked (disable-model-invocation) versus model-invoked skills, which is Pocock's answer to auto-trigger cost.
- Superpowers has an eval harness and a 94% PR rejection rate; Pocock's repo ships no skill tests in-repo at that date.
- Cost of Superpowers: drags a one-line question through a brainstorming workflow; cost of Pocock: discipline is opt-in, so skipping the skill means nothing stops you.
- Frames the choice as architecture (enforced process versus toolkit you drive), not repo preference.

## Verified Quote(s)

**Location reference:** Section "Pocock 1.0: small tools you stay in front of" final paragraph; section "The trade-off" paragraphs 1 and 3.

> The difference is the default. Superpowers assumes a skill applies; Pocock fires one only when you invoke it, or when a skill explicitly opted into auto-firing.

> The cost: the discipline is opt-in: skip the skill and nothing stops you.

> Neither bet is wrong. They’re tuned for different failure modes.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Borderline band, included as the cleanest statement of the invoke-versus-inject split, corroborated by Zenn and the Addy page.

**Redundancy check:** The Superpowers comparison is also in Zenn and Addy; this adds hook mechanics and eval-harness facts.

**Perspective category:** Practitioner
