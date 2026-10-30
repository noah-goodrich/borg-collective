# Source: Snowflake, "Cortex Code CLI" (overview, access and trial)

**Full citation:** Snowflake Inc. "Cortex Code CLI." Snowflake Documentation, User Guide > Cortex Code. No last-updated date shown.
**URL:** https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code-cli
**Date accessed:** 2026-10-30
**Evidence level:** vendor documentation
**Track:** T4 portability, trial and account limits

## Verified Quote(s)

**Location:** top-level heading "CoCo CLI", access/trial note near the top of the page.

> If you don’t have a Snowflake account, you can sign up for a free CoCo CLI trial.

> CoCo CLI is not available on standard Snowflake trial accounts (for example, accounts created at trial.snowflake.com).

> To use CoCo CLI, you need either a paid Snowflake account or the dedicated CoCo CLI trial linked above.

**Location:** prerequisites section.

> This user must also have the SNOWFLAKE.CORTEX_USER or SNOWFLAKE.CORTEX_AGENT_USER database role.

**Location:** model selection section.

> instead of a fixed list, CoCo shows you the models that are currently available to you.

## Key finding

Snowflake distinguishes a dedicated CoCo CLI trial from standard Snowflake trials, and the model list is per-account and dynamic rather than fixed. The page says nothing about headless or print mode being restricted on the CoCo trial, so our measured refusal of `--print` on a trial account is not documented anywhere we could find.

**Access status:** live
