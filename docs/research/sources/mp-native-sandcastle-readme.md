# Source: mattpocock/sandcastle README (primary)

**Full citation:** Pocock, Matt. "Sandcastle" README, repository mattpocock/sandcastle (npm package @ai-hero/sandcastle). https://github.com/mattpocock/sandcastle. Raw README fetched 2026-10-13; repository created 2026-03-17, last pushed 2026-10-08, MIT, 8,418 stars per the GitHub API.
**URL:** https://raw.githubusercontent.com/mattpocock/sandcastle/main/README.md
**Date accessed:** 2026-10-13
**Evidence level:** 7 (practitioner's own product documentation)
**Research topic area:** Sandcastle vs native agent view, teams, workflows

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 8/10 | Author of the tool |
| 2 | Evidence Quality | 5/10 | Docs, no benchmarks |
| 3 | Currency | 9/10 | Pushed Oct 2026 |
| 4 | Intent | 5/10 | Part of AI Hero ecosystem |
| 5 | Bias & Objectivity | 6/10 | No native comparison given |
| 6 | Logic & Coherence | 8/10 | Clear API model |
| 7 | Corroboration | 6/10 | Stars, workshop material |
| 8 | Intellectual Honesty | 7/10 | Documents opt-out of sandbox |
| 9 | Specificity | 9/10 | Providers, strategies, API |
| 10 | Relevance | 9/10 | Direct comparison target |

- Authority: written by the tool's author, who also runs the training content around it.
- Evidence Quality: API documentation; no evidence of outcomes beyond adoption.
- Currency: active development through October 2026.
- Intent: part of a commercial education ecosystem (the package is under the `@ai-hero` scope).
- Bias: the README does not compare itself with Claude Code's own background agents, worktree isolation, or workflows.
- Logic: the three branch strategies (head, merge-to-head, branch) and providers are cleanly specified.
- Corroboration: stars and independent workshop material on "AFK" Ralph loops with Docker sandboxes.
- Honesty: it documents `noSandbox()` as an explicit opt-in to run on the host.
- Specificity: named providers (Docker, Podman, Vercel), a `createWorktree()` lifecycle, and agent lists.
- Relevance: the one non-Claude-native orchestrator in Matt's stack.

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Sandcastle is a TypeScript library: one `run()` call sandboxes an agent, runs it on a configurable branch strategy, and merges its commits back; providers are Docker, Podman, Vercel microVMs, a custom provider, or none.
- Its differentiator versus native is container or microVM isolation plus programmatic control from TypeScript; native agent view isolates with git worktrees only and agent teams do not isolate at all.
- It is agent-agnostic: `claudeCode(...)` is one of several agents (the init command lists claude-code, pi, codex, cursor, opencode, copilot), while the native parallel features only run Claude sessions.
- It authenticates the container with `CLAUDE_CODE_OAUTH_TOKEN` from `claude setup-token`, so it rides the same subscription as local sessions.
- It has no equivalent of agent view's state board or cross-session messaging: it returns results from `run()` to the calling script, so visibility is the caller's job.
- It is explicitly AFK (away from keyboard) infrastructure, the same niche borg's unattended execution targets for long unattended work.

## Verified Quote(s)

**Location reference:** Heading "What Is Sandcastle?" first line and last paragraph; section "createWorktree() — independent worktree lifecycle", sentence 7 of that section.

> A TypeScript library for orchestrating AI coding agents in isolated sandboxes:

> Great for parallelizing multiple AFK agents, creating review pipelines, or even just orchestrating your own agents.

> The worktree persists after `run()`, `interactive()`, and `createSandbox()` complete, so you can hand it to another agent or inspect it.

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Needed to answer Sandcastle vs native; details its distinct isolation model.

**Redundancy check:** Not covered by other tracks' cards on the skills repo.

**Perspective category:** Practitioner
