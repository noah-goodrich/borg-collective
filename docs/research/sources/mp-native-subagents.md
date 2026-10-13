# Source: Claude Code docs, Subagents

**Full citation:** Anthropic. "Create custom subagents." Claude Code documentation. https://code.claude.com/docs/en/sub-agents. Live page, accessed 2026-10-13.
**URL:** https://code.claude.com/docs/en/sub-agents
**Date accessed:** 2026-10-13
**Evidence level:** 4 (vendor primary documentation)
**Research topic area:** Native subagents (isolation: worktree, background, skills preload) vs Matt's subagent-heavy skills

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 10/10 | Feature owner |
| 2 | Evidence Quality | 8/10 | Full frontmatter spec |
| 3 | Currency | 10/10 | Live |
| 4 | Intent | 7/10 | Product docs |
| 5 | Bias & Objectivity | 8/10 | Gives when-not-to-use |
| 6 | Logic & Coherence | 9/10 | Clear structure |
| 7 | Corroboration | 9/10 | Teams, workflows pages agree |
| 8 | Intellectual Honesty | 8/10 | Tradeoffs stated |
| 9 | Specificity | 10/10 | Fields and defaults |
| 10 | Relevance | 9/10 | Substrate for nanoprobes |

- Authority and Currency: first-party and live; the fetched copy exceeded 108k characters.
- Evidence Quality: documents `isolation: worktree`, background subagents, `skills` preload, and model choice.
- Bias: has an explicit "main conversation versus subagent" decision section.
- Corroboration: agent-teams and workflows pages reuse the same definitions.
- Honesty: notes foreground subagents block the main conversation.
- Specificity: frontmatter fields with defaults, plus built-in Explore, Plan, and General-purpose agents.
- Relevance: both Matt's `code-review` and `implement-spec` and borg nanoprobes are instances of this primitive.

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- A subagent runs in its own context window with its own system prompt, tool access, and permissions, and returns only a summary.
- `isolation: worktree` runs a subagent in a temporary git worktree, auto-cleaned when it makes no changes; this is the native version of Matt's "each in its own worktree" step.
- The `skills` field preloads skill content into a subagent at startup, controlling what a worker knows without discovery.
- Subagents can be backgrounded; permission prompts surface in the main session.
- Matt's skills treat subagent recursion as the harness's problem, which matches the native design in which the harness decides what nesting a subagent can reach.

## Verified Quote(s)

**Location reference:** Frontmatter field table, row `isolation`; the introductory paragraph under "What subagents are".

> Set to `worktree` to run the subagent in a temporary

> Each subagent runs in its own context window with a custom system prompt, specific tool access, and independent permissions.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Substrate detail that explains how Matt's prose-level orchestration maps to native primitives.

**Redundancy check:** Partly overlaps the agents overview; adds field-level behavior (worktree isolation, preload).

**Perspective category:** Institutional
