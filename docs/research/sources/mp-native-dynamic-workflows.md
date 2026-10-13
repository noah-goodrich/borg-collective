# Source: Claude Code docs, Dynamic workflows

**Full citation:** Anthropic. "Orchestrate subagents at scale with dynamic workflows." Claude Code documentation. https://code.claude.com/docs/en/workflows. Live page, accessed 2026-10-13.
**URL:** https://code.claude.com/docs/en/workflows
**Date accessed:** 2026-10-13
**Evidence level:** 4 (vendor primary documentation)
**Research topic area:** Native workflows vs Matt's implement-spec and borg dynamic workflows

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 10/10 | Feature owner |
| 2 | Evidence Quality | 8/10 | Full runtime spec |
| 3 | Currency | 10/10 | Live, v2.1.27x cited |
| 4 | Intent | 7/10 | Product docs |
| 5 | Bias & Objectivity | 7/10 | Own product only |
| 6 | Logic & Coherence | 9/10 | Who-holds-the-plan table |
| 7 | Corroboration | 8/10 | Agents overview agrees |
| 8 | Intellectual Honesty | 8/10 | Cost, limits, resume caveats |
| 9 | Specificity | 10/10 | Caps, API, resume rules |
| 10 | Relevance | 10/10 | Same primitive borg uses |

- Authority and Currency: first-party and live; cites versions v2.1.202 through v2.1.281.
- Evidence Quality: complete behavioral spec including limits (16 concurrent agents by default, 1,000 agents per run).
- Logic: its comparison table of subagents, skills, agent teams, and workflows organizes by who holds the plan.
- Corroboration: the parallel-agents overview lists the same five approaches.
- Honesty: documents cost warnings, "Large workflow" flag, and that resume replays after a failure.
- Specificity: shows `agent()`, `pipeline()`, `parallel()`, `phase()`, `args`, schema, and save locations.
- Relevance: borg's nanoprobes and dynamic workflows rely on this primitive; Matt's `implement-spec` expresses a similar fan-out as prose in a skill instead of a script.

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- A dynamic workflow is a JavaScript script that orchestrates many subagents; the runtime runs it in the background and keeps intermediate results in script variables, not Claude's context.
- Workflows can be saved to `.claude/workflows/` or `~/.claude/workflows/` and distributed in plugins, then run as `/name`; plugin workflows are namespaced.
- The docs table says workflows are resumable in the same session, while a skill or subagent plan restarts the turn on interruption; it also supports pausing at a usage limit and auto-continuing with v2.1.271 or later.
- Matt's `implement-spec` has the model itself manage the task-graph frontier in prose; a workflow moves that loop into code. This is the one place where native capability can partly replace a Matt skill's mechanics (not its process).
- Limit: no mid-run user input, so sign-off between stages needs separate workflows, which fits borg's locked-acceptance-criteria gates.

## Verified Quote(s)

**Location reference:** Page opening paragraph (after the plan-availability note); section "When to use a workflow", the sentence directly after the comparison table; the table's "Interruption" row.

> A dynamic workflow is a JavaScript script that orchestrates many [subagents](/docs/en/sub-agents) at once.

> A workflow moves the plan into code.

> | Interruption | Restarts the turn | Restarts the turn | Teammates keep running | Resumable in the same session |

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** The key native primitive that overlaps borg and parts of Matt's `implement-spec`; documents hard limits.

**Redundancy check:** Distinct from agent teams (lead-supervised peers) and subagents (turn-by-turn).

**Perspective category:** Institutional
