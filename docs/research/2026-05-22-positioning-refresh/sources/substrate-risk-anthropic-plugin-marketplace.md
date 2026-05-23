# Source: Anthropic Plugin Marketplace (early 2026)

**Full citation:** Anthropic. "Claude Code Plugin Marketplace — official curated and community
  plugin distribution." Early 2026.
**URL:** docs.claude.com / Anthropic marketplace listing (composite reference; 55+ curated,
  72+ community plugins as of research date).
**Date accessed:** 2026-05-22
**Evidence level:** 4 (institutional product documentation + observable marketplace state)
**Research topic area:** Distribution surface — does borg have a credible path to reach
  external users? What does the official channel look like?

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 9/10 | Vendor primary source. The marketplace exists or doesn't — Anthropic is the only authoritative source on its scope, curation rules, and growth. |
| 2 | Evidence Quality | 7/10 | Documentation + observable state of the marketplace. Plugin counts (55+ / 72+) are countable facts. Not research, but verifiable. |
| 3 | Currency | 10/10 | Early 2026 launch with continuous updates. Plugin counts as of research date are within weeks of evaluation. |
| 4 | Intent | 6/10 | Product marketing intent. Marketplace exists partly to capture distribution value — favorable framing of own ecosystem. |
| 5 | Bias & Objectivity | 6/10 | Vendor reporting on vendor channel. No external audit of curation criteria or rejection rates. |
| 6 | Logic & Coherence | 8/10 | The marketplace's structure (curated + community tiers, auto-update default) is logically described and operationally consistent. |
| 7 | Corroboration | 8/10 | Plugin count corroborable by inspection. Practitioner blogs (including Simon Willison) and developer tweets confirm the marketplace's existence and growth pattern. |
| 8 | Intellectual Honesty | 6/10 | Acknowledges community vs curated distinction. Doesn't deeply discuss curation criteria or rejected submissions. |
| 9 | Specificity | 9/10 | Concrete counts, named tiers, named install mechanism (`claude plugin install ...`). |
| 10 | Relevance | 9/10 | This is the channel through which borg's defensible-layer skills could reach external users. Direct relevance to Recommendation 1 in the analysis. |

**Composite score:** (9 × 0.25) + (7 × 0.20) + (10 × 0.10) + (6 × 0.10) + (6 × 0.10) + (8 × 0.05)
  + (8 × 0.05) + (6 × 0.05) + (9 × 0.05) + (9 × 0.05)
  = 2.25 + 1.40 + 1.00 + 0.60 + 0.60 + 0.40 + 0.40 + 0.30 + 0.45 + 0.45 = **7.85**

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Official Claude Code plugin marketplace launched early 2026 with two tiers: curated
  (55+ plugins) and community (72+ plugins, growing).
- Auto-update by default — installed plugins refresh without explicit user action, which
  amplifies any plugin's reach over time but also bakes in dependency on vendor uptime.
- Cortex Code reads from the same `.claude/skills/`, `.claude/agents/`, `.claude/hooks/`
  paths — submitting a plugin to the Anthropic marketplace yields parallel discoverability
  in the Cortex Code ecosystem at no extra effort.
- Marketplace install syntax: `claude plugin install <name>@<marketplace>` (not file paths).
- Implication for borg: this is the realistic distribution channel for the defensible skill
  layer; the channel exists and is reaching scale.

## Inclusion Decision

**Decision:** Core
**Rationale:** Rule 1 (Strong Include) — composite ≥ 7.0, not redundant. Directly informs
the Recommendation 1 distribution-strategy proposal.

**Redundancy check:** Not redundant. Other Anthropic sources cover competing products;
this one covers distribution mechanism.

**Perspective category:** Institutional — vendor primary documentation of the official
distribution channel.
