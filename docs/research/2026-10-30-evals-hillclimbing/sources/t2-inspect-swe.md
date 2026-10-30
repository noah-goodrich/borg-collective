# Source Record: Meridian Labs, inspect_swe (Claude Code agent for Inspect)

- **Full citation:** Meridian Labs, "Inspect SWE: Claude Code" documentation page and CHANGELOG, read 2026-10-30.
- **URL:** https://meridianlabs-ai.github.io/inspect_swe/claude_code.html ; https://meridianlabs-ai.github.io/inspect_swe/CHANGELOG.html
- **Date accessed:** 2026-10-30
- **Evidence level:** vendor documentation (open-source project docs)
- **Track:** t2 tooling landscape

## Verified Quote(s)

claude_code.html:
1. "Model API calls that occur in the sandbox are proxied back to Inspect for handling by the model provider for the current task."
2. `skills` option: "Additional skills to make available to the agent."
3. `version` option: "Download and use a specific version number."
4. `disallowed_tools`: "Optionally disallow tools (e.g. "WebSearch")."

CHANGELOG.html, newest headings:
5. "0.2.67 (2026-07-29)"
6. "0.2.66 (2026-07-14)"

## Key finding

inspect_swe runs the real Claude Code binary as an Inspect agent inside a (Docker) sandbox, supports skills and version pinning, and routes model traffic through Inspect so tokens and transcripts land in Inspect logs. The page does not mention plugin loading, and the last changelog entry is 2026-07-29, three months before this read, so maintenance is slower than core Inspect.

Access status: live
