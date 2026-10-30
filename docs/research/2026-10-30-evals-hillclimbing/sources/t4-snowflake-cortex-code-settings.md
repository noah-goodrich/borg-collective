# Source: Snowflake, "Cortex Code CLI Settings"

**Full citation:** Snowflake Inc. "Cortex Code CLI Settings." Snowflake Documentation, User Guide > Cortex Code. No last-updated date shown.
**URL:** https://docs.snowflake.com/en/user-guide/cortex-code/settings
**Date accessed:** 2026-10-30
**Evidence level:** vendor documentation
**Track:** T4 portability, config isolation and transcript location

## Verified Quote(s)

**Location:** environment variables table, `SNOWFLAKE_HOME` row.

> Overrides the default `~/.snowflake` directory.

**Location:** environment variables table, `CORTEX_AGENT_MODEL` row.

> Overrides model selection.

**Location:** settings precedence list, third of six levels.

> Project settings (`.cortex/settings.json` or `.claude/settings.json` in the working directory)

**Location:** environment variables table, `COCO_LOG_LEVEL` row.

> Minimum log level written to disk: `DEBUG`, `INFO`, `WARNING`, or `ERROR`. Default: `INFO`.

**Location:** storage section (followed by a list including `~/.snowflake/cortex/conversations/`).

> Conversations and settings are stored in:

## Key finding

`SNOWFLAKE_HOME` relocates the whole Cortex config tree, which is the hook an eval runner needs to give each case a clean, isolated skills/agents/hooks directory, and session files land under `cortex/conversations/` for recording. Cortex reads `.claude/settings.json` at project level, so a repo's Claude Code project settings can silently affect a Cortex eval run.

**Access status:** live
