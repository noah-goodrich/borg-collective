# Source Record: Snowflake docs, Cortex Code CLI reference

- **Full citation:** Snowflake, "Cortex Code CLI reference," Snowflake Documentation, read 2026-10-30.
- **URL:** https://docs.snowflake.com/en/user-guide/cortex-code/cli-reference
- **Date accessed:** 2026-10-30
- **Evidence level:** vendor documentation
- **Track:** t2 tooling landscape

## Verified Quote(s)

CLI options table:
1. `-p`: "Pass specified prompt, print response, and exit"
2. `--output-format stream-json`: "JSON output (for scripting)"
3. `-m, --model <model_name>`: "Specify AI model to use"
4. Batch mode section: "Batch mode runs a single prompt without starting an interactive session."

## Key finding

Cortex Code exposes headless `-p` with stream-json and a `--model` flag, but the reference documents no eval or test subcommand and no usage, token or cost fields in its output. Any eval tool must therefore drive Cortex through a custom subprocess wrapper, and tokens or cost for Cortex runs are unverified from documentation (they may exist in the live stream but are not documented).

Access status: live
