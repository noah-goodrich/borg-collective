# Source: Anthropic, "Run Claude Code programmatically" (headless docs)

**Full citation:** Anthropic. "Run Claude Code programmatically." Claude Code Docs. No date shown; references versions up to v2.1.302.
**URL:** https://code.claude.com/docs/en/headless
**Date accessed:** 2026-10-30
**Evidence level:** vendor documentation
**Track:** T4 portability, Claude-side adapter baseline

## Verified Quote(s)

**Location:** heading "Start faster with bare mode", first paragraph.

> Add `--bare` to reduce startup time by skipping auto-discovery of hooks, skills, custom commands, [subagents](https://code.claude.com/docs/en/sub-agents.md), installed plugins, MCP servers, auto memory, and CLAUDE.md.

Note: quote taken from the page's markdown rendering; "subagents" is link text on the rendered page.

**Location:** heading "Start faster with bare mode", second paragraph.

> Bare mode is useful for CI and scripts where you need the same result on every machine.

**Location:** heading "Pipe data through Claude", paragraph after the example.

> Both figures are [client-side estimates](https://code.claude.com/docs/en/agent-sdk/cost-tracking.md) and can differ from your actual bill.

**Location:** heading "Read session metadata", first sentence.

> The `system/init` event reports session metadata including the model, tools, MCP servers, and loaded plugins.

**Location:** heading "Stream responses", after the example.

> The last line of the stream is a `result` message with the final response text, cost, and session metadata.

## Key finding

Claude Code offers a reproducibility mode (`--bare`) that strips host-specific hooks, skills, plugins and CLAUDE.md, a `system/init` event naming the model and loaded plugins, and per-run cost estimates in the final `result`. These are the fields a cross-CLI transcript normalizer would key on; Cortex documents no `--bare` equivalent and an untyped init payload, so the Cortex adapter must get isolation from `SNOWFLAKE_HOME` and model identity from elsewhere.

**Access status:** live
