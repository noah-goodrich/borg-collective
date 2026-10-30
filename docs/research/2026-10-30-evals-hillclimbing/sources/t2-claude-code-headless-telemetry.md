# Source Record: Claude Code docs, headless mode and monitoring usage

- **Full citation:** Anthropic, "Run Claude Code programmatically" (headless) and "Monitoring" (monitoring-usage), Claude Code Docs, read 2026-10-30.
- **URL:** https://code.claude.com/docs/en/headless.md ; https://code.claude.com/docs/en/monitoring-usage.md
- **Date accessed:** 2026-10-30
- **Evidence level:** vendor documentation
- **Track:** t2 tooling landscape (result-history path)

## Verified Quote(s)

headless.md, "Pipe data through Claude":
1. "With `--output-format json`, the response payload includes `total_cost_usd` and a per-model cost breakdown, so scripted callers can track spend without consulting the [usage dashboard](https://code.claude.com/docs/en/costs.md)."

headless.md, "Stream responses":
2. "The last line of the stream is a `result` message with the final response text, cost, and session metadata."

headless.md, "Read session metadata":
3. "The `system/init` event reports session metadata including the model, tools, MCP servers, and loaded plugins."

headless.md, "Start faster with bare mode":
4. "`--bare` is the recommended mode for scripted and SDK calls, and will become the default for `-p` in a future release."

monitoring-usage.md, metric tables:
5. `claude_code.token.usage`: "Number of tokens used"
6. Token counter attribute: "`model`: Model identifier (for example, "claude-sonnet-5")"

## Key finding

Every `claude -p` run already emits what borg's runner is missing: the `system/init` event names the model and loaded plugins, and the final `result` message carries cost and a per-model breakdown, so model id and tokens can be captured by parsing output the harness already receives. OpenTelemetry export (`CLAUDE_CODE_ENABLE_TELEMETRY=1`, console exporter) is a second, heavier route that attaches the model id to token and cost counters.

Access status: live (monitoring page read to 100k of 172k characters)
