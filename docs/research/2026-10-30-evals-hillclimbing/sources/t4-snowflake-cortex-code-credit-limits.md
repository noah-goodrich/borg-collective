# Source: Snowflake, "Cost controls for Cortex Code"

**Full citation:** Snowflake Inc. "Cost controls for Cortex Code." Snowflake Documentation, User Guide > Cortex Code. No last-updated date shown.
**URL:** https://docs.snowflake.com/en/user-guide/cortex-code/credit-usage-limit
**Date accessed:** 2026-10-30
**Evidence level:** vendor documentation
**Track:** T4 portability, cost reporting

## Verified Quote(s)

**Location:** page intro.

> Account administrators can set daily estimated credit usage limits for CoCo on a per-user basis.

**Location:** parameters section.

> Each parameter tracks the corresponding user's estimated credit usage over a rolling 24-hour window.

## Key finding

Cortex Code spend is metered as estimated Snowflake credits per user over a rolling 24-hour window, with admin-set caps that block access when exceeded. An eval or hillclimb loop can therefore be cut off mid-run by a credit cap, and the page gives no per-call token or dollar reporting.

**Access status:** live
