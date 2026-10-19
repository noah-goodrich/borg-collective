# Cortex Code CLI vs Claude Code, surface by surface

**Date:** 2026-10-18
**Checked against:** `cortex --version` = Cortex Code v1.2.14 (host). Docs pages fetched are not version-pinned; the newest public changelog entry I could read was 1.1.87 (2026-09-14), so 1.2.x has no public release-notes entry that I found.
**Question:** Compare Cortex Code CLI with Claude Code, surface by surface, for borg.

Evidence tags: DOC = docs.snowflake.com page; LOCAL = file shipped inside the 1.2.14 install (the bundled `cortex-code-guide` skill); BIN = strings in the 1.2.14 binary (implementation hint, not a contract); CLI = `cortex ... --help` on the host.

## Parity table

| Surface          | Claude Code     | Cortex 1.2.14   | Verdict |
|------------------|-----------------|-----------------|---------|
| Markdown tables  | renders         | not documented  | unknown |
| Code, color      | yes             | highlighter     | partial |
| Box-drawing      | passes through  | own boxes (BIN) | unknown |
| AskUserQuestion  | previews        | no previews     | partial |
| Statusline       | `statusLine`    | built-in only   | missing |
| Hook events      | about 9         | 12              | works   |
| Hook user output | systemMessage   | plus userMessage| works   |
| Hook context     | additionalCtx   | SessionStart ?  | partial |
| Skills           | SKILL.md        | reads .claude   | works   |
| Slash commands   | .claude/commands| 3 dirs          | works   |
| Subagents        | Task tool       | `task`, 50 bg   | works   |
| Teams, messaging | Agent Teams     | `--team`, ctx   | partial |
| Scheduled tasks  | cron, loop      | cloud only      | partial |
| Plugins          | native          | reads manifest  | partial |
| Evals harness    | none            | none found      | missing |

Details behind the short cells:

- Hook events: Cortex has 12, including SubagentStart.
- Hook context: `additionalContext` is documented in Cortex, but SessionStart delivery is still open.
- Skills: Cortex reads `.claude/skills` as well as its own directories.
- Slash commands: Cortex reads markdown files in three directories, including `.claude`.
- Plugins: Cortex reads the `.claude-plugin` manifest.
- Evals: neither tool has a first-party skill eval harness.

## Notes

### 1. Rendering
- DOC cites nothing on markdown table, box-drawing or color rendering of assistant output. The CLI reference lists `/theme` (dark, light, pro) [CONFIGURATION.md LOCAL; https://docs.snowflake.com/en/user-guide/cli-reference page lists `/theme`]. BIN contains a highlight.js bundle and its own box-drawing border constants, so code blocks and colors are very likely handled.
- Changelog 1.1.53 says SQL result tables resize to terminal width. That is the SQL result viewer, not assistant markdown (https://docs.snowflake.com/en/user-guide/cortex-code/changelog).
- Verdict unknown for tables and box characters. Needs one live prompt asking Cortex to print a table and a box; I did not start an interactive session.

### 2. Ask-user tool
- DOC: AskUserQuestion supports multiple choice with descriptions, free-form with suggested defaults, and multi-select. It does not mention previews (https://docs.snowflake.com/en/user-guide/cortex-code/tools). Tool id is `ask_user_question` (borg directive; BIN).
- The only "preview" string in BIN is unrelated (a Datadog schema field and an internal call-site label). I found no evidence of a preview field. Treat previews as absent (unverified negative).
- Changelog 1.1.52 fixed rendering in selection prompts; 1.2.x LOCAL changelog notes background-agent permission prompts queue behind a foreground AskUserQuestion modal.
- `cortex exec` auto-rejects interactive prompts (CLI), so choosers only work interactively.

### 3. Statusline
- No user-configurable statusline in DOC (extensibility, settings and CLI reference pages are silent). A BIN search found no `statusLine` setting. 
- A built-in status bar exists: changelog 1.1.53 says it shows /effort, token estimate and elapsed time while thinking (https://docs.snowflake.com/en/user-guide/cortex-code/changelog). `/status` shows config. borg cannot feed it.

### 4. Hooks
- Events (LOCAL HOOKS.md and DOC extensibility): PreToolUse, PostToolUse, PermissionRequest, UserPromptSubmit, Stop, SubagentStart, SubagentStop, Notification, SessionStart, SessionEnd, PreCompact, Setup (https://docs.snowflake.com/en/user-guide/cortex-code/extensibility). DOC marks only PreToolUse and PermissionRequest as able to block.
- Locations: DOC lists `.cortex|.claude/settings(.local).json`, `~/.claude/settings.json`, `~/.snowflake/cortex/hooks.json`. LOCAL HOOKS.md names hooks.json. Conflict: changelog 1.1.47 says Cortex no longer reads `.claude/settings.json` as project settings, while the extensibility page still lists it. The borg directive's loader-log evidence (user-level `~/.claude/settings.json` and hooks.json read) is not contradicted, but the project-level claim is uncertain.
- Output: DOC says `systemMessage` displays a message to the user. BIN shows the hook runner builds both `systemMessage` and `userMessage`, plus `updatedInput` and `additionalContext`. LOCAL HOOKS.md warns "stdout goes to agent", so plain stdout is context, not display.
- Matchers are case-sensitive and use lowercase tool names (`bash`, `edit`) per DOC tools page; LOCAL HOOKS.md example still uses `Bash`, a doc inconsistency. BIN passes a normalised name to hooks (a `rNs` mapper), unverified.
- Hook input has `session_id`, `transcript_path`, `cwd`, `permission_mode`. No `CLAUDE_SESSION_ID` env (borg directive).
- SessionStart additionalContext reaching the model: open (directive AC6), still unverified.

### 5. Skills and commands
- Skills: dirs with SKILL.md, frontmatter `name`, `description`, `tools`; locations `.cortex/skills/`, `.claude/skills/`, `~/.claude/skills/`, `~/.snowflake/cortex/skills/` (https://docs.snowflake.com/en/user-guide/cortex-code/extensibility; LOCAL SKILLS.md). `cortex skill add|list|find|publish` (CLI). Dynamic `!` injection is not expanded (borg directive).
- Custom slash commands: markdown files in `.cortex/commands/`, `.claude/commands/`, `~/.snowflake/cortex/commands/`, `~/.claude/commands/` (LOCAL COMMANDS.md; DOC cli-reference names `~/.snowflake/cortex/commands/`, https://docs.snowflake.com/en/user-guide/cortex-code/cli-reference). `/commands`, `/skill`, `/hooks`, `/agents` exist.

### 6. Agents, teams, scheduling
- Subagents: markdown with frontmatter in `.cortex/agents/`, `.claude/agents/`, `~/.claude/agents/`, `~/.snowflake/cortex/agents/`; built-ins general-purpose, explore, plan, feedback; max 50 concurrent background agents; background agents cannot spawn background agents (https://docs.snowflake.com/en/user-guide/cortex-code/extensibility). `task` accepts `model: "inherit"` (changelog 1.1.52). `--agent` selects one (CLI).
- Teams: changelog 1.1.41 "team mode"; CLI `--team` loads a `team-workflow` skill. `cortex ctx` has `team`, `task`, `step`, `message`, `discovery` for agent-to-agent messaging (CLI). Messaging goes through a ctx database, not live cross-session push. No docs page; partial.
- Scheduling: "automations" via `cortex automation create`; run in a Snowflake server-side sandbox as an AGENT TASK, min hourly, no local filesystem, no cron syntax, Preview (https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-automations). No local recurring/loop equivalent found.
- Other: `cortex worktree`, `--worktree`, `--fork`, `--session-id`, `--session-name`, `cortex resume` (CLI).

### 7. Plugins
- The earlier note "Cortex cannot load Claude Code plugins" is outdated. DOC: CoCo reads `.cortex-plugin/plugin.json` or `.claude-plugin/plugin.json` (cortex-plugin wins); bundles skills, agents, commands, hooks (`hooks/hooks.json`) and MCP; `.claude/plugins/` is scanned (https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-plugins). CLI has `cortex plugin install|validate|list|enable|publish` and `--plugin-dir`.
- Not verified: that borg's built plugin actually loads and that its hooks run. Claude-specific tool names, `${CLAUDE_PLUGIN_ROOT}` and marketplace.json format compatibility are unknown. Docs say compatibility "isn't described in detail". Test with `cortex plugin validate <borg plugin dir>` (non-interactive).
- Changelog 1.1.53: `/import-claude-config` imports theme and permissions once; MCP servers merged from `~/.claude.json`.

### 8. Evals
- None for skills or agents found in DOC, CLI help or changelog. `cortex agent-studio ... eval` concerns Snowflake Cortex Agents/semantic views, not Cortex Code skills. `cortex exec` (headless, `--format json`, `--allowed`) is the only scriptable harness, and `--output-format stream-json` plus `--input-format stream-json` exist on the main command. Verdict missing for first-party evals.

### 9. Cortex-only capabilities
- Snowflake-native tools: SQL execution, object search, Cortex Analyst, DataDiff, notebooks; connections, `/sql`, `/table`, lineage (DOC tools; CLI).
- Server-side cloud sandbox (`--cloud`, `--github`), restricted session scope, FIPS mode, guardrails (CLI).
- Plugin/skill publishing to Snowflake stages and Cortex Extensions (`cortex plugin publish`, `cortex skill publish`).
- Remote hooks fetched from a git source (LOCAL HOOKS.md); ACP and an Agent SDK (DOC index); `--private` sessions; `--setting-sources`; profiles; `--effort` including `max`; a tgrep semantic code index (`--index`).

## Evidence gaps and uncertainties
- Rendering of tables, box drawing and color in assistant output: no source; live test required.
- AskUserQuestion previews: absence inferred from docs and binary strings only.
- Statusline: absence inferred from docs and binary strings only.
- 1.2.x has no public changelog entry I could read; the doc pages may describe 1.1.x behavior. The local CHANGELOG.md in the 1.2.14 install is sparse.
- Docs conflict on hooks location and `.claude/settings.json` project reading (see section 4).
- Tool-name casing (docs say lowercase, hook examples use `Bash`).
- Binary string inspection is implementation hint, not a supported contract.

## Paywalled must-reads
None. All sources were public or local.

## Sources index
All 2024-2026 tier.

1. Cortex Code CLI landing, 2026: https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli
2. Extensibility (hooks, skills, agents), 2026: https://docs.snowflake.com/en/user-guide/cortex-code/extensibility
3. Plugins, 2026: https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-plugins
4. Tools, 2026: https://docs.snowflake.com/en/user-guide/cortex-code/tools
5. CLI reference, 2026: https://docs.snowflake.com/en/user-guide/cortex-code/cli-reference
6. Automations, 2026: https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-automations
7. Changelog, 2026-09: https://docs.snowflake.com/en/user-guide/cortex-code/changelog
8. Local HOOKS.md, COMMANDS.md, SKILLS.md, AGENTS.md in the bundled `cortex-code-guide` skill, 2026.
9. `cortex --help`, plugin, skill, ctx, exec on host CLI v1.2.14, 2026-10-18.
10. Borg directive [2026-10-15-borg-in-cortex.md](../../plans/directives/2026-10-15-borg-in-cortex.md), 2026-10-15.
