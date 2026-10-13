# Source: Claude Code docs, CLAUDE.md, AGENTS.md and auto memory

**Full citation:** Anthropic. "How Claude remembers your project." Claude Code documentation. https://code.claude.com/docs/en/memory. Live page, accessed 2026-10-13.
**URL:** https://code.claude.com/docs/en/memory
**Date accessed:** 2026-10-13
**Evidence level:** 4 (vendor primary documentation)
**Research topic area:** CLAUDE.md/AGENTS.md as the place for per-user preferences (Matt's SCOPE.md points users here)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 10/10 | Feature owner |
| 2 | Evidence Quality | 8/10 | Behavioral spec |
| 3 | Currency | 10/10 | Live |
| 4 | Intent | 7/10 | Product docs |
| 5 | Bias & Objectivity | 8/10 | Admits limits of memory |
| 6 | Logic & Coherence | 9/10 | Clear sections |
| 7 | Corroboration | 8/10 | Matches Pocock's AGENTS.md use |
| 8 | Intellectual Honesty | 9/10 | Context, not enforcement |
| 9 | Specificity | 9/10 | Size limits, rules directory |
| 10 | Relevance | 7/10 | Indirect to skills |

- Authority and Currency: first-party and live.
- Evidence Quality: explains scopes, loading, auto memory (first 200 lines or 25KB).
- Bias: it directs enforcement needs to hooks, not memory.
- Corroboration: Matt's SCOPE.md tells users to put one-person preferences in their own `CLAUDE.md` / `AGENTS.md`, consistent with this page, and his repo ships both files.
- Honesty: "Claude treats them as context, not enforced configuration."
- Specificity: `.claude/rules/`, auto memory limits, reading AGENTS.md in place of CLAUDE.md.
- Relevance: 7; indirect, because it covers memory not skills.

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Claude Code can read a repository's AGENTS.md in place of CLAUDE.md, so one instruction file can serve several agents.
- CLAUDE.md and auto memory are loaded every session but are context, not enforcement; blocking an action needs a PreToolUse hook.
- Auto memory is capped (first 200 lines or 25KB loaded) and is shared across worktrees of a repo.
- This is where Matt tells users to place preferences his shared skills should not encode (his out-of-scope note on AskUserQuestion), and it is also where borg's rules and locked criteria should be carried, since the skill text cannot enforce them.

## Verified Quote(s)

**Location reference:** Section "CLAUDE.md vs auto memory", paragraph before the comparison table.

> Claude treats them as context, not enforced configuration.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Establishes the native instruction layer and its enforcement limits.

**Redundancy check:** No other card covers instruction files or the hook-versus-memory distinction.

**Perspective category:** Institutional
