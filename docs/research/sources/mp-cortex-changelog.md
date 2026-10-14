# Source: Snowflake docs, Cortex Code changelog (CLI)

**Full citation:** Snowflake Inc. "Cortex Code changelog." Snowflake Documentation. https://docs.snowflake.com/user-guide/cortex-code/changelog. Newest entry 1.1.87 (Sep 14, 2026); observed 2026-10-13.
**URL:** https://docs.snowflake.com/user-guide/cortex-code/changelog
**Date accessed:** 2026-10-13
**Evidence level:** 4 (vendor primary release record)
**Research topic area:** Cortex Code CLI release history and Claude Code compatibility drift

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 10/10 | Official release notes. |
| 2 | Evidence Quality | 8/10 | Dated, versioned entries, though some entries (1.1.60) lack dates and mirrors have shown inconsistent numbering. |
| 3 | Currency | 10/10 | Includes a Sep 2026 release. |
| 4 | Intent | 8/10 | Record of changes. |
| 5 | Bias & Objectivity | 8/10 | Neutral list; includes a revert notice (1.1.60) admitting a bad rollout. |
| 6 | Logic & Coherence | 8/10 | Chronological and categorized. |
| 7 | Corroboration | 8/10 | Consistent with the extensibility and plugins pages on skill paths and plugin flows. |
| 8 | Intellectual Honesty | 9/10 | Publishes the 1.1.60 erroneous-rollout correction. |
| 9 | Specificity | 9/10 | Exact flags, commands, and version numbers. |
| 10 | Relevance | 9/10 | Shows the direction of Claude Code compatibility: added `.agents/skills`, added Claude MCP import, but dropped `.claude/settings.json` as project settings. |

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Version 1.0.77 added `.agents/skills` as a project-level skill discovery directory, which is the shared path that Codex, Cline, Warp, and others use, so skills installed for those agents are also discoverable.
- Version 1.1.53 added Claude Code config reuse: MCP servers are merged from `~/.claude.json` at read time and `/import-claude-config` imports theme and permission rules.
- The same release stopped reading `.claude/settings.json` as project settings; only `.cortex/settings.json` is used. This contradicts the extensibility page's hooks table, which still lists `.claude/settings.json` as a project hook location, so the docs disagree internally and hooks portability must be tested.
- Version 1.1.65 added `--only-explicit-plugins` and `--only-explicit-skills` flags for isolating what a session loads.
- Version 1.1.60 was published solely to revert an unintended stable-channel promotion.

## Verified Quote(s)

**Location reference:** Entry 1.0.77 under "Project skill discovery"; entry 1.1.53 under "Added" ("Reuse your Claude Code configuration") and under "Changed" ("Project settings source"). Rendered page text; code spans (such as `.agents/skills`) appear as monospace in the page.

> Project skill discovery: Added .agents/skills as a project-level skill discovery directory alongside the existing .snowflake/cortex/skills.

> Cortex Code can now pick up an existing Claude Code setup.

> Cortex Code no longer reads .claude/settings.json as project settings. Only its own .cortex/settings.json is used, so move any project-level configuration into .cortex/settings.json.

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Only source that shows the trajectory (and a reversal) of Claude Code compatibility; resolves ambiguity in the static docs.

**Redundancy check:** Not redundant; static docs do not record the settings.json removal.

**Perspective category:** Institutional
