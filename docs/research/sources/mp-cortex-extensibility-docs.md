# Source: Snowflake docs, Cortex Code CLI extensibility

**Full citation:** Snowflake Inc. "CoCo CLI extensibility" (Cortex Code CLI extensibility). Snowflake Documentation. https://docs.snowflake.com/user-guide/cortex-code/extensibility. Living page, observed 2026-10-13 (reflects CLI 1.1.x).
**URL:** https://docs.snowflake.com/user-guide/cortex-code/extensibility
**Date accessed:** 2026-10-13
**Evidence level:** 4 (vendor primary documentation of the product's own behavior; closest analogue to professional-body guidance)
**Research topic area:** Cortex Code CLI extension model (skills, subagents, hooks, MCP)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 10/10 | The vendor that ships the CLI; there is no more authoritative source for what it supports. |
| 2 | Evidence Quality | 8/10 | Concrete paths, slash commands, and event tables, but the skill frontmatter options table did not render in the fetched page. |
| 3 | Currency | 10/10 | Living doc that mentions CLI 1.1.8 renames, so it tracks 2026 releases. |
| 4 | Intent | 8/10 | Documentation meant to help users; mild promotional framing around catalog and stage sharing. |
| 5 | Bias & Objectivity | 7/10 | Vendor describing its own product; silent on gaps such as which Claude Code frontmatter keys are honored. |
| 6 | Logic & Coherence | 9/10 | Well structured by feature with examples. |
| 7 | Corroboration | 9/10 | Corroborated by the plugins page, changelog, vercel-labs/skills agent table, and Snowflake-Labs skill repos. |
| 8 | Intellectual Honesty | 7/10 | Notes surface differences (CLI vs Desktop tool names) but does not list incompatibilities with Claude Code. |
| 9 | Specificity | 9/10 | Exact directories, commands, hook events, limits. |
| 10 | Relevance | 10/10 | Directly answers how skills, subagents, hooks, MCP work on Cortex. |

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Skills are directories with a SKILL.md, loaded from `.cortex/skills/` or `.claude/skills/` (project) and `~/.snowflake/cortex/skills/` or `~/.claude/skills/` (user), so an existing Claude Code skill directory is on the discovery path with no copying.
- Skills install from a local path, Git repository, tarball, or Snowflake stage via `/skill add` or `cortex skill add`; Git-based skills are cached locally, and `/skill sync` resolves conflicts between scopes. Verification is `/skill list` or `$$`; invocation is `$skill-name`.
- Skill `tools:` entries are case-sensitive runtime IDs (lowercase `bash`, `read`, `write`; SQL tool is `sql_execute`), so a Claude Code style capitalized tool list does not map one-to-one.
- Subagents are Markdown files with YAML front matter in `.cortex/agents/` or `.claude/agents/` (project) and `~/.claude/agents/` (user), with worktree isolation (branch `agent/<agentId>`) and a swarm pattern.
- Hooks cover 11 events (PreToolUse, PostToolUse, PermissionRequest, UserPromptSubmit, SessionStart, SessionEnd, PreCompact, Stop, SubagentStop, Notification, Setup); MCP is configured in `~/.snowflake/cortex/mcp.json`.

## Verified Quote(s)

**Location reference:** Section "Skills" > "Creating custom skills" (first sentence), "Managing skills" subsection under "Skill sharing > Git repositories", "Subagents" > "Worktree isolation" (first sentence), and "Hooks" (first sentence). Quotes taken from the page's markdown rendering at the card URL (append .md).

> Skills are directories containing a `SKILL.md` file with skill instructions, and optional examples and templates.

> Git-based skills are cached locally.

> Agents can be run in isolated git worktrees, or branches.

> Hooks allow you to intercept and customize CoCo's behavior at key lifecycle points.

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Primary source for the Cortex extension model; the whole compatibility analysis rests on it. Strongest-evidence, highest relevance.

**Redundancy check:** Not redundant; the plugins page and changelog cover different surfaces (plugin packaging, release history). This is the only page covering skills, subagents, hooks, and MCP together.

**Perspective category:** Institutional
