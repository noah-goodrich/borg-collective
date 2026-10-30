# Source: Snowflake Developers, "Get Started with Cortex Code CLI"

**Full citation:** Snowflake Inc. "Get Started with Cortex Code CLI." Snowflake Developers Guides. Page shows "Updated Oct 19, 2026".
**URL:** https://www.snowflake.com/en/developers/guides/getting-started-with-cortex-code-cli
**Date accessed:** 2026-10-30
**Evidence level:** vendor documentation (developer guide)
**Track:** T4 portability, authentication for headless use

## Verified Quote(s)

**Location:** authentication methods table, row label and its "use when" cell.

> Programmatic access token (PAT)

> Headless environments or automation

**Location:** prerequisites.

> not available on standard Snowflake trial accounts

## Key finding

Snowflake's own guide names a programmatic access token as the auth method for headless and automated runs, which is what an unattended eval runner would use. The guide does not mention print mode, CI, subagents or AGENTS.md, and it repeats the standard-trial exclusion without addressing the dedicated CoCo trial.

**Access status:** live
