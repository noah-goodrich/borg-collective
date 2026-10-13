# Source: Claude Code docs, Routines

**Full citation:** Anthropic. "Automate work with routines." Claude Code documentation. https://code.claude.com/docs/en/routines. Live page (research preview), accessed 2026-10-13.
**URL:** https://code.claude.com/docs/en/routines
**Date accessed:** 2026-10-13
**Evidence level:** 4 (vendor primary documentation)
**Research topic area:** Native unattended/cloud runs vs borg unattended execution

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 10/10 | Feature owner |
| 2 | Evidence Quality | 8/10 | Full spec, API example |
| 3 | Currency | 10/10 | Live, preview |
| 4 | Intent | 7/10 | Product docs |
| 5 | Bias & Objectivity | 7/10 | Own product only |
| 6 | Logic & Coherence | 9/10 | Triggers, limits, troubleshooting |
| 7 | Corroboration | 8/10 | Matches scheduled-tasks page |
| 8 | Intellectual Honesty | 9/10 | Preview, hourly caps, no overage |
| 9 | Specificity | 10/10 | Endpoint, beta header, caps |
| 10 | Relevance | 7/10 | Adjacent to the question |

- Authority and Currency: first-party and live, marked research preview.
- Evidence Quality: documents trigger types, caps (100 scheduled runs per hour per account, 30 per routine for API or Run now), and an example request.
- Bias: describes only the Anthropic cloud path.
- Logic: schedule, API, and GitHub triggers are each explained in turn.
- Corroboration: the scheduled-tasks page cross-links the same comparison.
- Honesty: warns that the API beta header may change and that a green run status does not mean the task succeeded.
- Specificity: the `experimental-cc-routine-2026-04-01` beta header and minimum hourly interval.
- Relevance: 7, because routines run in a fresh cloud clone and cannot touch local files or tmux sessions.

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- A routine is a saved prompt plus repositories and connectors that runs on Anthropic-managed cloud infrastructure on a schedule, an API call, or GitHub events.
- Routines run autonomously with no permission-mode picker, using skills committed to the cloned repository.
- Minimum schedule interval is one hour; the feature is in research preview and limits may change.
- Because it runs from a fresh clone, a routine cannot reach local worktrees, local databases, or a tmux-based drone fleet; it is complementary to, not a replacement for, local orchestration.
- Skills committed to a repo (Matt-style plugin skills only if vendored in) are the way a routine reuses process.

## Verified Quote(s)

**Location reference:** Note callout directly under the title; first paragraph after the callout.

> Routines are in research preview.

> Routines execute on Anthropic-managed cloud infrastructure

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Marks the boundary of native unattended execution; relevant to borg's planned deploy and unattended steps.

**Redundancy check:** Distinct from `/loop` (session-scoped) in the scheduled-tasks card.

**Perspective category:** Institutional
