# Source: Snowflake, "Cortex Code CLI reference"

**Full citation:** Snowflake Inc. "Cortex Code CLI reference." Snowflake Documentation, User Guide > Cortex Code. No last-updated date shown.
**URL:** https://docs.snowflake.com/en/user-guide/cortex-code/cli-reference
**Date accessed:** 2026-10-30
**Evidence level:** vendor documentation
**Track:** T4 portability, headless/programmatic use

## Verified Quote(s)

**Location:** heading "CLI options", options table, row `-c, --connection <name>`.

> Use specific Snowflake connection

**Location:** heading "CLI options", options table, row `--bypass` / `--dangerously-allow-all-tool-calls`.

> Enable bypass mode, automatically approving all tool calls

Note: the fetch tool would not reproduce the full options table verbatim. It reported, unquoted, that the table lists `-p, --print`, `--output-format stream-json`, `-m, --model`, `--effort` (minimal/low/medium/high/max), `--max-turns`, `--allowed-tools`, `--disallowed-tools`, `--plan`, `--private`, and a `cortex exec` subcommand for CI with interactive prompts auto-rejected. Treat those as unquoted paraphrase for verification.

## Key finding

Snowflake documents `-p/--print`, `--output-format stream-json`, `--effort`, `--max-turns` and a `cortex exec` batch command, with no trial-account caveat on any of them. No seed or temperature flag is documented, and the only connection auth is via `~/.snowflake/connections.toml` (browser SSO or a programmatic access token).

**Relation to measured facts:** The docs list `--effort` as a CLI flag with five levels; we measured that subagents ignore effort and run at the session level. The docs do not claim per-subagent effort, so this is consistent but worth noting: a session-level effort flag exists.

**Access status:** live (partial: options table only paraphrased by the fetch tool)
