# Source: Snowflake, "Cortex Code CLI extensibility"

**Full citation:** Snowflake Inc. "Cortex Code CLI extensibility." Snowflake Documentation, User Guide > Cortex Code. No last-updated date shown on the fetched page.
**URL:** https://docs.snowflake.com/en/user-guide/cortex-code/extensibility
**Date accessed:** 2026-10-30
**Evidence level:** vendor documentation
**Track:** T4 portability (Claude Code vs Cortex Code)

## Verified Quote(s)

**Location:** heading "Skills", subheading "Creating custom skills".

> Skills are directories containing a `SKILL.md` file with skill instructions, and optional examples and templates.

**Location:** heading "Skills", skill tools paragraph.

> Tool names in a skill's `tools:` list are runtime tool IDs and are case-sensitive.

**Location:** heading "Skills > Skill locations", sentence introducing the locations table (table rows list `.cortex/skills/` or `.claude/skills/` for project scope and `~/.snowflake/cortex/skills/` or `~/.claude/skills/` for user scope).

> Skills are loaded from multiple locations, listed below from highest to lowest priority:

**Location:** heading "Skills > Managing skills > Skill conflicts".

> When the same skill exists in multiple supported locations, and the contents differ, a conflict occurs

**Location:** heading "Subagents > Creating custom subagents".

> Custom subagents are defined in Markdown files with YAML front matter.

**Location:** heading "Subagents > Creating custom subagents > Agent configuration > Model selection" (examples on the page show a specific id `claude-sonnet-4-5` and `auto`).

> You can choose a model for a specific agent. This overrides the session’s default model.

**Location:** heading "Subagents", tool access paragraph.

> An unrecognized entry is skipped silently

**Location:** heading "Hooks" (intro).

> Hooks allow you to intercept and customize CoCo's behavior at key lifecycle points.

**Location:** heading "Hooks > Writing hook scripts".

> Hook scripts accept JSON input via standard input and return JSON output via standard output.

## Key finding

Cortex Code documents a Claude-Code-shaped extension surface: SKILL.md skills, Markdown+YAML subagents with name/description/tools/model, and Claude-named hook events (PreToolUse, PostToolUse, SessionStart, Stop, SubagentStop and others) read from both `.cortex/` and `.claude/` paths. The page shows `additionalContext` only for PostToolUse, never documents effort for subagents, documents no namespacing for agents, and says unrecognized tool entries are skipped silently, which is a silent-failure hazard for a portable eval case.

**Relation to measured facts:** Agrees with our measurements (no agent namespace, no subagent effort, SessionStart context not documented as delivered). The doc implies any model value overrides the session model, while we measured that only a full model id is honored; the doc's own example uses a full id, so this is an under-specification, not a direct contradiction.

**Access status:** live
