# Source: Claude.com plugin listing: Matt Pocock's Skills

**Full citation:** Anthropic. "Matt Pocock's Skills" plugin listing, Claude plugin marketplace. claude.com/plugins/mattpocock-skills. Accessed 2026-10-13.
**URL:** https://claude.com/plugins/mattpocock-skills
**Date accessed:** 2026-10-13
**Evidence level:** 4 (platform vendor listing)
**Research topic area:** WHAT IT IS (primary sources): mattpocock/skills, Sandcastle, AI Hero, Matt's stated philosophy

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 8/10 | Hosted by Anthropic on the official plugin directory, so it confirms that the plugin is listed and counts installs. |
| 2 | Evidence Quality | 4/10 | A listing summary; install count (1,745) is a platform counter. |
| 3 | Currency | 6/10 | Live but visibly stale: it says 21 skills and CONTEXT.md while the repo lists 27 skills and GLOSSARY.md. |
| 4 | Intent | 6/10 | Vendor directory page; descriptive and not strongly promotional. |
| 5 | Bias & Objectivity | 6/10 | Repeats the maintainer's framing; no critique. |
| 6 | Logic & Coherence | 6/10 | Concise and consistent with the README's four failure modes. |
| 7 | Corroboration | 8/10 | Matches the README install route and the four failure modes; skill count lags. |
| 8 | Intellectual Honesty | 6/10 | Does not mention its own lag. |
| 9 | Specificity | 7/10 | Gives skill count, install count and usage steps. |
| 10 | Relevance | 8/10 | Shows how the skills appear inside Anthropic's own channel, a direct 'Matt vs native' data point. |

**Score band:** borderline

(Intermediate weighted average about 6.4; the disposition is the band word.)

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Anthropic's official marketplace lists the plugin as 'Matt Pocock's Skills', made by Matt Pocock, with 1,745 installs on the access date; this is the Claude Code distribution route the README points to.
- The listing says 21 composable skills while the repo README lists 27, so the plugin build or listing lags the repo (and still names CONTEXT.md rather than GLOSSARY.md).
- The listing restates the four failure modes (misalignment, verbosity, non-functional code, architectural decay), confirming the framing is the maintainer's own, copied into Anthropic's catalogue.
- Run /setup-matt-pocock-skills once per repo to configure issue tracking and documentation paths is part of the vendor-hosted usage guidance.

## Verified Quote(s)

**Location reference:** Quote 1: Listing body text, first sentence of the description; Quote 2: Listing body text, second paragraph

> A collection of 21 composable agent skills that embed real software engineering discipline into your AI-assisted workflow.

> The skills address four core failure modes when working with AI agents: misalignment (use grilling to clarify intent before building), verbosity (build domain language via CONTEXT.md and ADRs), non-functional code (TDD and structured debugging loops), and architectural decay (specs, architecture review, and codebase design skills).

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Borderline band: included as the only Institutional confirmation that the plugin ships through Anthropic's official marketplace (gap-fill), with a visible lag.

**Redundancy check:** Adds install count and Anthropic-channel evidence not found elsewhere.

**Perspective category:** Institutional
