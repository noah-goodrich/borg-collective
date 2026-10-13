# Source: mattpocock/sandcastle README (TypeScript orchestrator for sandboxed agents)

**Full citation:** Matt Pocock. "Sandcastle" README.md, mattpocock/sandcastle (npm @ai-hero/sandcastle 0.12.0). GitHub. Live 2026-10-13.
**URL:** https://github.com/mattpocock/sandcastle
**Date accessed:** 2026-10-13
**Evidence level:** 7 (author's own primary documentation)
**Research topic area:** WHAT IT IS (primary sources): mattpocock/skills, Sandcastle, AI Hero, Matt's stated philosophy

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 9/10 | Written by the author; the README is the contract for the library. |
| 2 | Evidence Quality | 6/10 | Describes an API and behaviour; no benchmarks or outcome data, but the API is concrete and verifiable. |
| 3 | Currency | 9/10 | Live; repo pushed 2026-10-08, npm latest 0.12.0 (2026-06-29), so recent but the library may have moved on. |
| 4 | Intent | 6/10 | Open-source docs; also supports AI Hero brand (scoped under @ai-hero). |
| 5 | Bias & Objectivity | 6/10 | Describes only its own design; no stated limitations section. |
| 6 | Logic & Coherence | 8/10 | Clear model: provider, branch strategy, merge back. |
| 7 | Corroboration | 6/10 | Consistent with third-party descriptions (aggregators) but those are derivative; no independent hands-on review found. |
| 8 | Intellectual Honesty | 7/10 | Notes that noSandbox() opts out of isolation, and that bind-mount providers write to the host filesystem. |
| 9 | Specificity | 10/10 | Gives exact providers, branch strategies, defaults and API calls. |
| 10 | Relevance | 9/10 | Directly answers what Sandcastle is, how it orchestrates agents and its isolation model. |

**Score band:** keep

(Intermediate weighted average about 7.6; the disposition is the band word.)

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Sandcastle is a TypeScript library: you call run() with an agent (Claude Code, Codex, Pi), a sandbox provider and a prompt; it sandboxes the agent, applies a branch strategy, and merges commits back.
- Isolation model: built-in providers are Docker, Podman (bind-mount, worktree mounted into the container) and Vercel (isolated Firecracker microVMs); noSandbox() runs on the host; custom providers are supported.
- Three branch strategies: head (default for bind-mount, writes straight to the working directory), merge-to-head (temp branch in a git worktree merged back; default for isolated providers), and branch (commits land on an explicitly named branch, reused across runs).
- It is a code-level orchestration primitive (iterations, structured output, session resume and fork, <promise>COMPLETE</promise> early termination), not an opinionated process like the skills; it targets AFK parallel agents and review pipelines.
- Authentication to Claude Code uses CLAUDE_CODE_OAUTH_TOKEN (from claude setup-token) or ANTHROPIC_API_KEY placed in a .sandcastle/.env file.

## Verified Quote(s)

**Location reference:** Quote 1: Section 'What Is Sandcastle?', first line; Quote 2: Section 'What Is Sandcastle?', paragraph after the numbered list; Quote 3: Subsection 'Branch strategies', bullet 'When to use each', merge-to-head entry

> A TypeScript library for orchestrating AI coding agents in isolated sandboxes:

> Sandcastle is provider-agnostic — it ships with built-in providers for Docker, Podman, and Vercel, and you can create your own.

> The agent works on a throwaway branch; if something goes wrong, HEAD is untouched.

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Only primary source for Sandcastle; essential for the borg comparison (code-level orchestration versus borg's session-level orchestration).

**Redundancy check:** Unique. Third-party Sandcastle pages (aggregators) are derivative and were cut.

**Perspective category:** Practitioner
