# Source: Claude Code docs, Commands and bundled skills

**Full citation:** Anthropic. "Commands." Claude Code documentation. https://code.claude.com/docs/en/commands. Live page, accessed 2026-10-13.
**URL:** https://code.claude.com/docs/en/commands
**Date accessed:** 2026-10-13
**Evidence level:** 4 (vendor primary reference)
**Research topic area:** Native commands and bundled skills that duplicate Matt's skills (/code-review, /verify, /batch, /plan, /init)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 10/10 | Feature owner |
| 2 | Evidence Quality | 8/10 | Exhaustive reference |
| 3 | Currency | 10/10 | Live, v2.1.28x cited |
| 4 | Intent | 7/10 | Reference docs |
| 5 | Bias & Objectivity | 8/10 | Neutral table form |
| 6 | Logic & Coherence | 9/10 | Alphabetical, typed rows |
| 7 | Corroboration | 9/10 | Pocock issues cite clashes |
| 8 | Intellectual Honesty | 8/10 | Notes alias and version changes |
| 9 | Specificity | 10/10 | Flags, versions, aliases |
| 10 | Relevance | 9/10 | Name and function overlap |

- Authority and Currency: first-party and live.
- Evidence Quality: each built-in and bundled skill is described with flags and version requirements.
- Bias: reference-table form, little spin.
- Corroboration: Matt Pocock's `.out-of-scope/harness-name-collisions.md` independently records issues where his `/code-review` and `/prototype` collided with Claude Code built-ins.
- Honesty: includes history, for example that `/review` was once a separate command.
- Specificity: `/code-review` takes effort levels and `--fix`, `--comment`; `/verify` runs the app and observes.
- Relevance: shows which of Matt's named skills now have a native homonym.

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Native `/code-review` (alias `/review`) reviews the current diff or a PR for correctness bugs, with effort levels, `--fix`, `--comment`, and a cloud `ultra` mode; Matt's `/code-review` is a two-axis (Standards and Spec) review with parallel sub-agents, so the names clash but the intent differs (spec conformance is his differentiator).
- Native `/verify` builds and runs the app to observe the result, which is in the same space as borg's borg-verifier gate but without acceptance criteria.
- Native `/batch` splits one big change into 5 to 30 worktree-isolated background subagents and publishes each; it overlaps Matt's `implement-spec` and borg nanoprobes, but not their ticket graph or locked criteria.
- `/plan` enters plan mode, a native counterpart to part of the planning step but without Matt's grilling interview.
- `/init` can import Codex and Gemini CLI configuration, a sign of convergence on cross-agent config.

## Verified Quote(s)

**Location reference:** Table rows for `/verify`, `/init`, and `/code-review` in the command reference table.

> Confirm a code change does what it should by building your project's app, running it, and observing the result, rather than relying on tests or type checks.

> If `/init` finds OpenAI Codex or Google Gemini CLI configuration, it offers to carry it over with `/import`

> Review the current diff, or a PR number, branch, or path you pass, for correctness bugs.

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Direct evidence of which native commands duplicate named Matt skills.

**Redundancy check:** Unique: the only source enumerating bundled skills with names matching Matt's.

**Perspective category:** Institutional
