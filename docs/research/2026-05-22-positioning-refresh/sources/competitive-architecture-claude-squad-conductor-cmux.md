# Source: Claude Squad / Conductor / cmux / workmux / claude-tmux — competing tmux + worktree orchestrators

**Full citation:** Cluster of 2026 OSS projects implementing tmux + git-worktree + Claude
  Code orchestration patterns: Claude Squad, Conductor (Mac-only), cmux, workmux,
  claude-tmux (composite citation of GitHub repos, project READMEs, and HN/X discussion
  threads).
**URL:** github.com/claude-squad/... ; conductor.build ; github.com/{cmux,workmux,...}
  (composite reference; specific URLs verifiable per project).
**Date accessed:** 2026-05-22
**Evidence level:** 5 (practitioner case studies / product observations with measurable
  star counts and adoption indicators)
**Research topic area:** Competitive architecture — how many independently-built tmux +
  worktree orchestrators exist, and how do they compare to borg's `drone`?

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 6/10 | Each individual project is a small practitioner effort. The cluster's authority comes from independence (six projects converging on similar architecture) rather than any single one's credibility. Conductor has the strongest individual profile (named team, dedicated landing page); Claude Squad is the most-starred. |
| 2 | Evidence Quality | 6/10 | Star counts, install counts, README descriptions are observable. The CLAIM being made here ("identical architecture to borg's drone") is verifiable by reading the projects' code; not based on the projects' own self-descriptions of relative competitiveness. |
| 3 | Currency | 10/10 | All 2026 projects. Six independent projects in roughly the same calendar year is itself the key data point. |
| 4 | Intent | 6/10 | Each project has its own intent (most are practitioner-tools-for-the-builder; Conductor has commercial / SaaS aspirations). Mixed. |
| 5 | Bias & Objectivity | 6/10 | Each project's README is naturally biased toward its own value proposition. The cluster-level inference (architecture has been independently rediscovered six times) is observation, not a project's self-claim. |
| 6 | Logic & Coherence | 7/10 | The "six independent implementations of the same architecture" pattern is logically coherent and code-verifiable. |
| 7 | Corroboration | 8/10 | Multiple independent practitioners arriving at similar designs IS the corroboration mechanism — the cluster corroborates itself. |
| 8 | Intellectual Honesty | 6/10 | Project READMEs vary in honesty about limitations. Conductor is most candid about scope (Mac-only, opinionated workflow). Other projects more boosterish. |
| 9 | Specificity | 7/10 | Each project has a specific stack: tmux + git worktree + Claude Code subprocess invocation. The borg.zsh / drone.zsh architecture is verifiable as architecturally similar. |
| 10 | Relevance | 9/10 | Directly answers the "is borg's CLI plumbing layer architecturally differentiated?" question. The cluster's existence is the strongest evidence for the substrate-risk argument's "CLI plumbing has been commoditized" claim. |

**Composite score:** (6 × 0.25) + (6 × 0.20) + (10 × 0.10) + (6 × 0.10) + (6 × 0.10) + (7 × 0.05)
  + (8 × 0.05) + (6 × 0.05) + (7 × 0.05) + (9 × 0.05)
  = 1.50 + 1.20 + 1.00 + 0.60 + 0.60 + 0.35 + 0.40 + 0.30 + 0.35 + 0.45 = **6.75**

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

The evaluator's incentive cuts both ways here — the cluster validates the substrate-risk
argument (good for the analysis) but undermines the value of borg's existing CLI work
(uncomfortable). Net: roughly neutral.

## Key Findings

- At least six independently-built tmux + git-worktree + Claude Code orchestrators emerged
  in 2025–26: Claude Squad, Conductor, cmux, workmux, claude-tmux, and borg's own
  `drone` layer.
- Architectural convergence is strong: tmux for pane management, git worktree for
  branch isolation, subprocess invocation of `claude` for sessions. The borg `drone`
  command's design is independently rediscovered, not unique.
- Conductor targets solo Mac developers explicitly — confirms the existence of borg's
  ICP, but also confirms competition for it.
- No single project has dominant share. Claude Squad has the highest star count, but
  none of these are positioning-defining.
- Implication for borg: the CLI plumbing layer is commoditized as an architecture pattern
  even before Anthropic's Agent Teams shipped. Differentiation must come from elsewhere.

## Inclusion Decision

**Decision:** Core
**Rationale:** Rule 4 (Moderate Include) — composite 5.0–6.9, AND ≥2 contextual factors
favor inclusion: actionability (drives the "stop investing in CLI plumbing growth"
recommendation), unique insight (the six-project convergence is not articulated elsewhere),
relevance to substrate-risk argument.

**Redundancy check:** Not redundant. Agent Teams covers vendor competition; this cluster
covers OSS-peer competition. Different competitive threats requiring different responses.

**Perspective category:** Practitioner — these are practitioner-built tools by individual
or small-team developers operating in the same niche as borg.
