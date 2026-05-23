# Source: Internal baseline — borg-collective project corpus (README, CLAUDE.md, boris-workflow,
  six-pager, architecture, competitive-landscape)

**Full citation:** Goodrich, Noah. Internal borg-collective project documentation. Composite
  citation: `README.md`, `CLAUDE.md`, `docs/boris-workflow.md`, `docs/six-pager.md`,
  `docs/architecture.md`, `docs/competitive-landscape.md`.
**URL:** github.com/goodrich-noah/borg-collective (private/local working repo at time of
  evaluation).
**Date accessed:** 2026-05-22
**Evidence level:** 8 (anecdotal / personal-experience documentation by the project author
  himself — N=1 source authored by the same person whose project is being analyzed)
**Research topic area:** Internal baseline — what does the existing borg corpus claim about
  positioning, ICP, and architecture? This becomes the comparison point against external
  evidence.

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 7/10 | Authored by the project's creator — primary-source authority on what borg IS and what its design intent is. Not authoritative on whether borg is correct or successful in the broader market. |
| 2 | Evidence Quality | 5/10 | Personal-experience documentation. Internal claims about ICP, philosophy, and architecture are author assertions, not externally validated findings. |
| 3 | Currency | 10/10 | Current internal documentation as of May 2026 — written within weeks/months of evaluation. |
| 4 | Intent | 8/10 | Internal project documentation for the project's own design and self-understanding. Not marketing-oriented in the public-facing sense (these are working docs, not the README marketing copy). Mostly educational / planning intent. |
| 5 | Bias & Objectivity | 4/10 | Author writing about author's own project. Maximum motivated-reasoning risk. Bias-guard applied (see below) — scored hard. |
| 6 | Logic & Coherence | 8/10 | The three-layer model (Philosophy / Skills + hooks / CLI plumbing) is internally consistent. The competitive-landscape.md acknowledges substrate risk explicitly. Reasoning is solid where it touches on internally observable facts. |
| 7 | Corroboration | 6/10 | Internal corpus is self-referencing across documents — not independent corroboration. Some external corroboration (from JetBrains data on ICP, from competitive cluster on architecture) but the internal documents themselves aren't independent. |
| 8 | Intellectual Honesty | 8/10 | competitive-landscape.md is structurally candid about substrate risk and competing tools. The six-pager.md acknowledges what's defensible vs. exposed. The corpus does the work of identifying its own weaknesses. |
| 9 | Specificity | 8/10 | Specific architectural details, named components, working code. Higher specificity than most secondary sources because it IS the primary documentation of the system. |
| 10 | Relevance | 10/10 | Maximum relevance — the research question IS about this specific project. By definition relevant. |

**Composite score:** (7 × 0.25) + (5 × 0.20) + (10 × 0.10) + (8 × 0.10) + (4 × 0.10) + (8 × 0.05)
  + (6 × 0.05) + (8 × 0.05) + (8 × 0.05) + (10 × 0.05)
  = 1.75 + 1.00 + 1.00 + 0.80 + 0.40 + 0.40 + 0.30 + 0.40 + 0.40 + 0.50 = **6.95**

## Bias Guard Check

- [x] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [ ] Neutral / no strong reaction

The evaluator and the source author share substantial overlap in interest — this is by
construction (a positioning research effort done from inside the project). Dimensions 5, 6, 8
scored hard to compensate. Dimension 5 (Bias & Objectivity) is especially constrained here:
no amount of self-aware framing fully escapes the fact that this is N=1 self-report.

## Key Findings

- Three-layer mental model already articulated in the internal corpus: Philosophy
  (boris-workflow narrative) / Skills + hooks (adhd-guardrails, borg-plan, borg-assimilate)
  / CLI plumbing (borg, drone). The external research validates this model but doesn't
  invent it.
- competitive-landscape.md identifies the substrate-risk problem before the external
  research did — internal awareness is more advanced than the public-facing positioning.
- ICP described as "ADHD/cognitive-load-sensitive AI-native developers managing multiple
  projects" — matches the JetBrains-validated growing segment.
- The current README headline ("AI development orchestration framework") understates the
  defensible-layer thesis present in the working docs.
- boris-workflow.md is the strongest narrative asset and is invisible to external readers.

## Inclusion Decision

**Decision:** Supporting (override applied)
**Rationale:** Override Protocol invoked. Rule that would have applied: Rule 6 (Default
Exclude) — composite 6.95 falls just below the 7.0 strong-include threshold; would have
been Rule 4 (Moderate Include) on contextual factors alone, but the source is self-authored
(N=1 with conflict of interest), which is a fatal flaw not captured by the rubric.
**Override reason:** Internal baseline must be documented to make the comparison against
external evidence meaningful. Excluding it would leave the comparison unanchored.
**Role in final document:** Comparison point / baseline. Cited in §4 and §5 as "what borg
internally claims about itself," then explicitly contrasted with external findings.

**Redundancy check:** Not redundant. The internal corpus is the comparison baseline; no
other source can play this role.

**Perspective category:** Practitioner — author is a practitioner building the tool being
analyzed. (Not "Override" — that was the inline category label in the original analysis.md;
"Override" describes the inclusion decision, not the perspective category. Per the
deep-research skill's five-category constraint, Practitioner is the correct mapping.)
