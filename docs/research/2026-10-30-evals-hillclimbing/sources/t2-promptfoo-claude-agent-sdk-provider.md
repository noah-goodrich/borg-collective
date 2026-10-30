# Source Record: promptfoo docs, Claude Agent SDK provider

- **Full citation:** Promptfoo, "Claude Agent SDK" provider documentation, promptfoo.dev, read 2026-10-30.
- **URL:** https://www.promptfoo.dev/docs/providers/claude-agent-sdk
- **Date accessed:** 2026-10-30
- **Evidence level:** vendor documentation
- **Track:** t2 tooling landscape

## Verified Quote(s)

1. "This allows you to prepare a directory with files or sub-directories before running your tests."
2. "By default, Claude Agent SDK runs in a temporary directory with no tools enabled, using the `default` permission mode."
3. "By default, when you specify a working directory, Claude Agent SDK is given read-only access to the directory."
4. "You can also allow Claude Agent SDK to write to files, run system commands, call MCP servers, and more."
5. "Promptfoo normalizes Claude `Skill` tool invocations into `response.metadata.skillCalls`,"
6. "`cost`, `tokenUsage`, and `metadata.modelUsage` cover only the current call, including subagents."
7. "Calls that use `copy_working_dir` are never cached."

Location: provider page sections on working directory, permissions, caching, assertions and cost.

## Key finding

promptfoo has a first-party provider (`anthropic:claude-agent-sdk`, alias `anthropic:claude-code`) that runs the Claude Code agent loop against a prepared working directory, records cost, tokens and per-model usage, and exposes Skill calls to a `skill-used` assertion. It covers Claude Code through the SDK rather than through `claude -p` with a plugin directory, and has no equivalent for Cortex.

Access status: live
