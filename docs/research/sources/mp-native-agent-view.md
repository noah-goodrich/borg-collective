# Source: Claude Code docs, Agent view and background sessions

**Full citation:** Anthropic. "Manage agents with agent view." Claude Code documentation. https://code.claude.com/docs/en/agent-view. Live page (research preview), accessed 2026-10-13.
**URL:** https://code.claude.com/docs/en/agent-view
**Date accessed:** 2026-10-13
**Evidence level:** 4 (vendor primary documentation)
**Research topic area:** Native session visibility and background sessions vs borg link / borg next and Sandcastle

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 10/10 | Feature owner |
| 2 | Evidence Quality | 8/10 | Normative behavior spec |
| 3 | Currency | 10/10 | Live, research preview |
| 4 | Intent | 7/10 | Product docs |
| 5 | Bias & Objectivity | 7/10 | Own product only |
| 6 | Logic & Coherence | 9/10 | State table, clear flow |
| 7 | Corroboration | 8/10 | Agents, commands, messaging pages agree |
| 8 | Intellectual Honesty | 9/10 | Preview, quota, local-only caveats |
| 9 | Specificity | 10/10 | States, flags, isolation rules |
| 10 | Relevance | 10/10 | Native twin of queen/drone view |

- Authority, Currency: first-party and live, flagged as a research preview, so the UI may change.
- Evidence Quality: normative behavior description, no usage data.
- Intent and Bias: product documentation describing only itself.
- Logic: a state table (Working, Needs input, Idle, Completed, Failed, Stopped) and grouped rows (Pinned, Ready for review, Needs input, Working, Completed).
- Corroboration: the parallel-agents overview and cross-session messaging pages describe the same surface consistently.
- Honesty: the page states quota use scales per session and that sessions are local.
- Specificity: names `claude agents`, `--bg`, `/bg`, worktree behavior, and disable flags.
- Relevance: the closest native analogue to borg's session visibility (Needs input maps to WAITING ON YOU), but it has no project, stack, or manifest concept.

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- `claude agents` opens one screen for all background sessions with states Working, Needs input, Idle, Completed, Failed, Stopped; sessions can be started with `claude --bg`, `/bg`, or the left-arrow shortcut.
- Dispatched background sessions are moved into an isolated git worktree before editing, and worktree isolation is then enforced for the session and its subagents.
- Sessions are local and independent: each uses subscription quota on its own, and they stop if the machine shuts down.
- Linked PRs show as `#N` labels on rows, but there is no notion of cross-project ordering, acceptance criteria, or "what is next"; that is the layer borg adds.
- Still a research preview, so borg should treat it as plumbing to adopt cautiously, not a foundation to depend on.

## Verified Quote(s)

**Location reference:** Page opening paragraph (first and second sentences); section "How file edits are isolated" first paragraph; Requirements/limits note on quota.

> Agent view, opened with `claude agents`, is one screen for all your background sessions: what's running, what needs your input, and what's done.

> Agent view is in research preview.

> so parallel sessions can read the same checkout but each writes to its own

> Each session uses your subscription quota independently, so see [Limitations](#limitations) before dispatching many at once.

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** The most direct native overlap with borg's visibility layer; essential to the "plumbing, not replacement" judgment.

**Redundancy check:** Not dominated: the agents-overview card compares approaches, this card is the surface spec.

**Perspective category:** Institutional
