# Source: mattpocock/skills, git-guardrails-claude-code SKILL.md

**Full citation:** Pocock, Matt. "git-guardrails-claude-code" skill (SKILL.md). GitHub, mattpocock/skills, skills/misc. https://github.com/mattpocock/skills/blob/main/skills/misc/git-guardrails-claude-code/SKILL.md. Observed 2026-10-13.
**URL:** https://github.com/mattpocock/skills/blob/main/skills/misc/git-guardrails-claude-code/SKILL.md
**Date accessed:** 2026-10-13
**Evidence level:** 5 (primary practitioner artifact)
**Research topic area:** What would and would not port to Cortex Code (hooks)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 9/10 | The skill's author. |
| 2 | Evidence Quality | 9/10 | The artifact itself. |
| 3 | Currency | 9/10 | Current main branch; lives in the "misc" bucket. |
| 4 | Intent | 8/10 | Functional setup instructions. |
| 5 | Bias & Objectivity | 8/10 | Used only as evidence of contents. |
| 6 | Logic & Coherence | 8/10 | Clear. |
| 7 | Corroboration | 7/10 | Cortex hooks docs independently confirm PreToolUse exists. |
| 8 | Intellectual Honesty | 7/10 | Named as Claude Code specific, honestly. |
| 9 | Specificity | 8/10 | Lists blocked git commands. |
| 10 | Relevance | 7/10 | The one hook-dependent skill; a bounded edge case for the port analysis. |

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- The skill is explicitly Claude Code specific and works by installing a PreToolUse hook that blocks destructive git commands.
- Cortex supports a PreToolUse hook that can block (exit code 2) and matches on case-sensitive runtime tool names, so the idea ports but a Claude-written matcher on `Bash` would not match Cortex's lowercase `bash` (inference from the Cortex docs, untested).
- This is the minority case; most skills in the repo are pure Markdown instructions.

## Verified Quote(s)

**Location reference:** Frontmatter `description` field (line 3) and first sentence under the H1 "Setup Git Guardrails".

> Set up Claude Code hooks to block dangerous git commands (push, reset --hard, clean, branch -D, etc.) before they execute.

> Sets up a PreToolUse hook that intercepts and blocks dangerous git commands before Claude executes them.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Illustrates the hooks edge of the port; narrower than to-tickets but not redundant.

**Redundancy check:** Only hook-dependent skill examined.

**Perspective category:** Practitioner
