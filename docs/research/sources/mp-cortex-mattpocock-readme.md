# Source: mattpocock/skills README (install matrix and Cortex absence)

**Full citation:** Pocock, Matt. "Skills For Real Engineers" (README). GitHub, mattpocock/skills (MIT; repo pushed 2026-10-13). https://github.com/mattpocock/skills
**URL:** https://github.com/mattpocock/skills
**Date accessed:** 2026-10-13
**Evidence level:** 5 (practitioner primary artifact)
**Research topic area:** Whether Matt's skills target or have been ported to Cortex Code

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 9/10 | The author's own repository. |
| 2 | Evidence Quality | 7/10 | Concrete install commands per agent; claims of model portability are asserted, not tested. |
| 3 | Currency | 10/10 | Pushed the day of access. |
| 4 | Intent | 6/10 | Partly promotional (newsletter funnel, paid-training adjacency). |
| 5 | Bias & Objectivity | 5/10 | Positions itself against GSD, BMAD, and Spec-Kit. |
| 6 | Logic & Coherence | 8/10 | Failure-mode framing is coherent. |
| 7 | Corroboration | 7/10 | Skill files in the repo match the README description. |
| 8 | Intellectual Honesty | 7/10 | Notes manual-update tradeoffs of each install route. |
| 9 | Specificity | 9/10 | Exact commands for Claude Code, Codex, Copilot, Gemini CLI, and generic installer. |
| 10 | Relevance | 8/10 | Defines the install matrix; Cortex is absent from it. |

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- The README names no Cortex Code or Snowflake support; a case-insensitive search of the README for "cortex", "snowflake", and "coco" returned no matches, and GitHub issue searches on the repo for "cortex" and "snowflake" returned 0 results at access time.
- Documented install routes cover Claude Code, Codex, GitHub Copilot, Gemini CLI, and a generic `npx skills ... -a <agent>` route listing cursor, opencode, devin, windsurf, amp, pi.
- The skills are authored for generic coding agents: "They work with any model."
- Repo state at access: about 289k stars (GitHub API), MIT license, skills split into engineering, productivity, misc, in-progress, deprecated.
- Per-repo setup (`/setup-matt-pocock-skills`) asks which issue tracker (GitHub, GitLab, local files) and label vocabulary to use.

## Verified Quote(s)

**Location reference:** README, paragraph 3 under the title ("These skills are designed to be small..."), the "Any other agent, or editable files" install block, and the "Why These Skills Exist" intro sentence.

> These skills are designed to be small, easy to adapt, and composable. They work with any model.

> npx skills@latest add mattpocock/skills -a <agent>  # cursor, opencode, devin, windsurf, amp, pi; omit -a to choose

> I built these skills as a way to fix common failure modes I see with Claude Code, Codex, and other coding agents.

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** The primary artifact for the claim "no evidence of Matt's skills on Cortex" and for the install route that would apply.

**Redundancy check:** Other tracks cover the repo content; this card isolates the Cortex-relevant facts.

**Perspective category:** Practitioner
