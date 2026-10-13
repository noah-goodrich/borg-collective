# Source: Snowflake-Labs/subagent-cortex-code (Claude Code skill that delegates to Cortex)

**Full citation:** Snowflake-Labs. "subagent-cortex-code" (README). GitHub, created 2026-04-08, last push 2026-05-05, about 61 stars at access, license field NOASSERTION. https://github.com/Snowflake-Labs/subagent-cortex-code
**URL:** https://github.com/Snowflake-Labs/subagent-cortex-code
**Date accessed:** 2026-10-13
**Evidence level:** 5 (vendor-lab practitioner artifact)
**Research topic area:** Reverse integration, Claude Code driving Cortex Code

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 8/10 | Published under Snowflake's Labs organization. |
| 2 | Evidence Quality | 6/10 | Install and routing instructions; no benchmarks or user reports. |
| 3 | Currency | 7/10 | Last push May 2026; not updated for 1.1.x. |
| 4 | Intent | 7/10 | Pulls coding-agent users toward Cortex. |
| 5 | Bias & Objectivity | 6/10 | Vendor-lab promotion of its own CLI. |
| 6 | Logic & Coherence | 8/10 | Clear routing principle. |
| 7 | Corroboration | 7/10 | skills.sh listing and Snowflake docs confirm the same install paths. |
| 8 | Intellectual Honesty | 7/10 | Lists prerequisites and a security mode. |
| 9 | Specificity | 8/10 | Exact per-agent commands. |
| 10 | Relevance | 9/10 | Shows Snowflake's own preferred pattern: keep Claude Code as the general agent and route only Snowflake work to Cortex. |

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Snowflake-Labs ships a skill that lets Claude Code, Cursor, Codex, Copilot, and Windsurf route Snowflake operations to Cortex Code CLI in headless mode.
- The routing rule is "Snowflake operations go to Cortex, everything else stays with your coding agent", an official endorsement of a dual-tool setup rather than replacing Claude Code.
- The skill installs to `~/.claude/skills/cortex-code` for Claude Code, again showing SKILL.md directories are the shared unit.
- The prerequisite is a working `cortex` binary and an active connection.

## Verified Quote(s)

**Location reference:** README opening paragraph (under the H1 "Cortex Code Skill") and the "Claude Code" section.

> This skill routes Snowflake-related operations to Cortex Code CLI, enabling coding agents to leverage specialized Snowflake expertise in headless mode.

> `npx skills add` installs to `~/.agents/skills/cortex-code/`. Move it into Claude Code's skills directory:

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Relevant to the design choice of whether Noah's Claude-based workflow (including borg) should wrap Cortex rather than port to it.

**Redundancy check:** Unique among sources (the reverse direction).

**Perspective category:** Practitioner
