# Source: Anthropic Agent Teams (Feb 2026 release)

**Full citation:** Anthropic. "Agent Teams — coordinated multi-agent workflows for Claude
  Code." Product launch, February 2026.
**URL:** docs.claude.com / Anthropic blog post announcing Agent Teams (composite reference).
**Date accessed:** 2026-05-22
**Evidence level:** 4 (institutional product documentation from the vendor — primary source for
  what the vendor itself ships)
**Research topic area:** Substrate risk / competitive exposure — has Anthropic shipped what
  borg's CLI plumbing does?

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 9/10 | Vendor primary documentation. The most authoritative source on what Anthropic ships and how it works — by definition. |
| 2 | Evidence Quality | 7/10 | Documentation describes feature capabilities directly. Not research, but the FACT of the feature shipping is the relevant data point, not a measured outcome. |
| 3 | Currency | 10/10 | February 2026 release — three months before research date. |
| 4 | Intent | 5/10 | Product marketing intent — sells the feature, highlights capability over limitation. Stated limitations (state wipes on restart) are buried. |
| 5 | Bias & Objectivity | 5/10 | Marketing-leaning documentation. Limitations are present but de-emphasized. Reports on its own product. |
| 6 | Logic & Coherence | 8/10 | Architecture description is coherent: team-lead role + mailbox + shared task list. Logical model of multi-agent coordination. |
| 7 | Corroboration | 7/10 | Practitioner reviews (e.g., 2026-05-07 agentic orchestrator review in borg's own corpus) confirm the feature's behavior. Multiple early users wrote about it. |
| 8 | Intellectual Honesty | 6/10 | Acknowledges state wipes on restart — partial disclosure of limitations. Doesn't deeply discuss the cross-session memory gap. |
| 9 | Specificity | 8/10 | Named components, specific behaviors documented. Reproducible by users. |
| 10 | Relevance | 9/10 | Directly answers "did Anthropic ship a competitor to borg's CLI plumbing?" — yes. Critical for substrate-risk analysis. |

**Composite score:** (9 × 0.25) + (7 × 0.20) + (10 × 0.10) + (5 × 0.10) + (5 × 0.10) + (8 × 0.05)
  + (7 × 0.05) + (6 × 0.05) + (8 × 0.05) + (9 × 0.05)
  = 2.25 + 1.40 + 1.00 + 0.50 + 0.50 + 0.40 + 0.35 + 0.30 + 0.40 + 0.45 = **7.55**

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

The "conclusion" here is essentially "this feature exists and works as described" — a
factual claim with low emotional content. Standard scoring.

## Key Findings

- Anthropic shipped Agent Teams in February 2026 — coordinated multi-agent workflows for
  Claude Code.
- Architecture: team-lead agent + shared mailbox + shared task list — the conventional
  multi-agent orchestration pattern.
- State wipes on restart — agents can coordinate within a session but lose context across
  restarts, leaving the cross-session memory gap that addendum identifies as legitimate
  borg territory.
- Native UI ships with Claude Code, removing the rationale for a separate orchestrator CLI
  for any user not invested in tmux + worktree workflows.
- Implication for borg: the multi-project orchestration claim is now substantially
  commoditized by the vendor itself.

## Inclusion Decision

**Decision:** Core
**Rationale:** Rule 1 (Strong Include) — composite ≥ 7.0, not redundant. Direct vendor
documentation of the feature most directly overlapping with borg's CLI plumbing layer.

**Redundancy check:** Not redundant. Plugin Marketplace (separate source) and the third-party
ban (separate source) cover different dimensions of substrate risk.

**Perspective category:** Institutional — vendor primary documentation is the canonical
institutional source for the AI tooling ecosystem.
