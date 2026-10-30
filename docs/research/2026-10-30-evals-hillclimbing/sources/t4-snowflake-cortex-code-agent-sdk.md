# Source: Snowflake, "Cortex Code Agent SDK" and "Cortex Code Agent SDK reference – Python"

**Full citation:** Snowflake Inc. "Cortex Code Agent SDK" and "Cortex Code Agent SDK reference – Python." Snowflake Documentation. Footer "© 2026 Snowflake, Inc."; no last-updated date.
**URL:** https://docs.snowflake.com/en/user-guide/cortex-code-agent-sdk/cortex-code-agent-sdk
**URL (reference):** https://docs.snowflake.com/en/user-guide/cortex-code-agent-sdk/python-reference
**Date accessed:** 2026-10-30
**Evidence level:** vendor documentation
**Track:** T4 portability, programmatic use and cost reporting

## Verified Quote(s)

**Location:** overview page, first paragraph.

> The Cortex Code Agent SDK lets you build agentic AI applications using Python and TypeScript.

**Location:** overview page, authentication section.

> The SDK authenticates through your Snowflake CLI connection settings.

**Location:** overview page, hooks section.

> Available hook events include `PreToolUse`, `PostToolUse`, `Stop`, `UserPromptSubmit`, and more.

**Location:** Python reference, `ResultMessage` class description (fields listed include `total_cost_usd: float | None = None` and `usage: dict[str, Any] | None = None`).

> Emitted when the agent finishes a turn. Check `subtype` and `is_error` for success or failure.

**Location:** Python reference, options table, `effort` row.

> Model effort level: `"minimal"` | `"low"` | `"medium"` | `"high"` | `"max"`

**Location:** Python reference, options table, `cli_path` row.

> Path to CLI binary. If omitted, the SDK first checks `CORTEX_CODE_CLI_PATH`

**Location:** Python reference, transport description.

> Defaults to subprocess CLI transport

## Key finding

Snowflake ships a Python and TypeScript Cortex Code Agent SDK that drives the `cortex` binary as a subprocess, exposes model, effort, permission mode, allowed tools, setting sources and hooks as options, and returns a `ResultMessage` with optional `total_cost_usd` and `usage`. No seed or temperature option is listed, and the `SystemMessage` init payload is an untyped `data` dict rather than a documented model/tools/skills list.

**Relation to measured facts:** The SDK offers an official programmatic path parallel to our hand-rolled stream-json harness; whether it works on the trial account (where `--print` was refused) is undocumented and untested. `total_cost_usd` is typed optional, so "no cost reporting" may be partial rather than absolute.

**Access status:** live
