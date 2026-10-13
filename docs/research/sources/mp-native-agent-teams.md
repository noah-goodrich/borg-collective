# Source: Claude Code docs, Agent teams

**Full citation:** Anthropic. "Orchestrate teams of Claude Code sessions." Claude Code documentation. https://code.claude.com/docs/en/agent-teams. Live page (experimental feature), accessed 2026-10-13.
**URL:** https://code.claude.com/docs/en/agent-teams
**Date accessed:** 2026-10-13
**Evidence level:** 4 (vendor primary documentation)
**Research topic area:** Native multi-agent coordination vs borg queen/drone and Matt's implement-spec

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 10/10 | Feature owner |
| 2 | Evidence Quality | 8/10 | Detailed mechanics, no data |
| 3 | Currency | 10/10 | Live, 2026 versions cited |
| 4 | Intent | 7/10 | Product docs |
| 5 | Bias & Objectivity | 8/10 | Lists many limitations |
| 6 | Logic & Coherence | 9/10 | Subagent comparison table |
| 7 | Corroboration | 8/10 | Matches workflows, agents pages |
| 8 | Intellectual Honesty | 10/10 | Experimental, disabled by default |
| 9 | Specificity | 10/10 | Files, hooks, model selection |
| 10 | Relevance | 9/10 | Overlaps queen/drone idea |

- Authority and Currency: first-party and live; it cites specific Claude Code versions through v2.1.281.
- Evidence Quality: thorough mechanics but no outcomes data.
- Bias: unusually candid, with an explicit Limitations section.
- Logic: a subagents-versus-teams table sets out when each fits.
- Corroboration: consistent with the workflows page comparison table and the agents overview.
- Honesty: opens with "experimental and disabled by default" and warns of higher token cost.
- Specificity: mailbox JSON path, hooks `TeammateIdle`, `TaskCreated`, `TaskCompleted`, task claiming with file locks.
- Relevance: the native analogue of a lead plus workers, but session-scoped, unlike borg's persistent per-project drones.

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Agent teams are experimental and disabled by default; one lead session coordinates teammates that share a task list and message each other directly.
- A session has exactly one team, scoped to that session; there is no resumption of in-process teammates, no nested teams, and the lead cannot be changed.
- Teammates do not share the lead's conversation; each loads CLAUDE.md, MCP servers, and skills (so Matt-style skills load in teammates) but not the lead's history.
- Split panes need tmux or iTerm2 and are listed as unsupported in Ghostty's own panes (tmux inside any terminal remains the supported route).
- Hooks (`TeammateIdle`, `TaskCreated`, `TaskCompleted`) give a native gate point comparable to borg's verifier gates.

## Verified Quote(s)

**Location reference:** Warning callout directly under the title; "Limitations" bullet list, bullets "One team per session" and "Split panes require tmux or iTerm2"; section "Token usage" first sentence region.

> Agent teams are experimental and disabled by default.

> **One team per session**: a session has exactly one team, scoped to that session.

> Split-pane mode isn't supported in VS Code's integrated terminal, Windows Terminal, or Ghostty.

> Agent teams add coordination overhead and use significantly more tokens than a single session.

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** The direct native counterpart to orchestrator-plus-drones; limitations show why persistent cross-project drones are still a distinct design.

**Redundancy check:** Distinct from workflows (script-held plan) and agent view (user-dispatched sessions).

**Perspective category:** Institutional
