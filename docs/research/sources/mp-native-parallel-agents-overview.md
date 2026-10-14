# Source: Claude Code docs, Run agents in parallel (overview)

**Full citation:** Anthropic. "Run agents in parallel." Claude Code documentation. https://code.claude.com/docs/en/agents. Live page, accessed 2026-10-13.
**URL:** https://code.claude.com/docs/en/agents
**Date accessed:** 2026-10-13
**Evidence level:** 4 (vendor primary documentation)
**Research topic area:** Map of native parallelism features (subagents, agent view, teams, projects, workflows, /batch)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 10/10 | Feature owner |
| 2 | Evidence Quality | 7/10 | Summary of other pages |
| 3 | Currency | 10/10 | Live, lists projects beta |
| 4 | Intent | 7/10 | Product guidance |
| 5 | Bias & Objectivity | 7/10 | Own product only |
| 6 | Logic & Coherence | 10/10 | Decision questions, one table |
| 7 | Corroboration | 9/10 | Each row has a source page |
| 8 | Intellectual Honesty | 8/10 | Marks preview, cost multiplier |
| 9 | Specificity | 8/10 | Commands per approach |
| 10 | Relevance | 10/10 | Native feature map |

- Authority and Currency: first-party index of the current parallelism features, including the cloud "Projects" beta.
- Evidence Quality: it is a router page; the detail lives on the linked pages, hence 7.
- Logic: "who coordinates, do workers talk, do tasks touch the same files" gives a clean decision rule.
- Corroboration: each row is backed by a separate documentation page that was also fetched.
- Honesty: marks agent view as research preview and agent teams as experimental and disabled by default, and warns that parallelism multiplies token use.
- Specificity: names `/batch`, `/fork`, `/subtask`, `/tasks`, `/workflows`, `claude agents`.
- Relevance: the quickest way to see which borg features have a native sibling.

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Claude Code now has five native parallelism approaches: subagents, agent view, agent teams, projects (cloud, beta), and dynamic workflows, plus worktrees, cross-session messaging, and `/batch` as supporting tools.
- `/batch` is a bundled skill that splits a large change into 5 to 30 worktree-isolated subagents; it is a packaged use of subagents and worktrees, not a new coordination style.
- Agent teams do not isolate teammates in worktrees; subagents and sessions started from agent view can.
- Agent view sessions report results only to the user, while subagents report to their parent; cross-session messaging bridges the gap between sessions.
- All workers are Claude sessions; other tools must be exposed to Claude as MCP servers (relevant to non-Claude agents in Sandcastle).

## Verified Quote(s)

**Location reference:** Opening paragraph; bullet list under "Three more tools support this work", third bullet; final sentence of the paragraph following the approach table.

> Claude Code has five ways to work on several tasks at once:

> It's a packaged use of subagents and worktrees, not a separate coordination style.

> In every approach the workers are Claude sessions.

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Single most efficient source for the native feature map; anchors the overlap analysis.

**Redundancy check:** Overlaps the individual feature cards deliberately (index versus detail); the "workers are Claude sessions" point is unique here.

**Perspective category:** Institutional
