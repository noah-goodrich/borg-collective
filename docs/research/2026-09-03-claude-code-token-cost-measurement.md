# Claude Code Token/Cost Observability — Measurement Habit #4

**Date:** 2026-09-03
**Question:** What existing tooling and transcript/hook data can be used to log token counts per turn,
per tool call, and per context source in Claude Code, before cutting anything? Precisely document the
transcript JSONL usage schema, the OTEL metrics surface, hook payload contents, and the state of the
"attribute cache tokens to a context source" problem.

## Executive summary

- The transcript JSONL (`~/.claude/projects/**/*.jsonl`) already contains a per-assistant-message
  `usage` block with `input_tokens`, `output_tokens`, `cache_creation_input_tokens`,
  `cache_read_input_tokens`, plus a nested `cache_creation.{ephemeral_1h_input_tokens,
  ephemeral_5m_input_tokens}` split — confirmed against a live local transcript, not just docs.
- Claude Code's native OTel export (`CLAUDE_CODE_ENABLE_TELEMETRY=1`) gives the same four token types
  as a `type` attribute on `claude_code.token.usage`, tagged by `model`, `query_source`
  (main/subagent/auxiliary), `agent.name`, `skill.name`, `mcp_tool.name`, etc. — richer attribution
  than the transcript alone, but still per-API-call, not per-context-source.
- `ccusage` (open-source npm CLI) is the mature, zero-setup tool for parsing local transcript JSONL
  into cost/token reports (daily/session/5h-window/per-model); `claude-code-otel` is the reference
  self-hosted OTel+Grafana stack for the telemetry export path. Neither solves attribution to context
  source.
- **The hard problem — attributing `cache_read`/`cache_creation` tokens to a specific context source
  (system prompt vs CLAUDE.md vs tool schemas vs conversation history vs file-read results) — is not
  solved by any tool found in this research.** Anthropic's API and Claude Code's telemetry report
  cache tokens as an undifferentiated total per call; the semantic-convention/observability ecosyston
  (Langfuse, Helicone, Braintrust, Weave, OTel GenAI semconv) all report token/cost per call or per
  span, not by which document contributed which cached tokens. Any per-source breakdown must be
  inferred indirectly (see below), not read off the wire.
- Hooks (PreToolUse/PostToolUse/Stop/SessionStart/SessionEnd) do **not** receive token counts or cost
  in their JSON stdin payload. They do receive `transcript_path`, so a hook can read the transcript
  file itself to pull the latest `usage` block — this is exactly what the user's existing
  `token-cost` SessionEnd hook already does.

## Findings

### 1. Transcript JSONL — exact `usage` schema (verified against a live file)

Confirmed by reading `/Users/noah/.claude/projects/-Users-noah-dev-borg-collective/*.jsonl` directly
(session from 2026-08-26, Claude Code v2.1.220) — this is ground truth from this machine, not a
secondary source:

```json
{
  "message": {
    "model": "claude-opus-5",
    "usage": {
      "input_tokens": 2,
      "cache_creation_input_tokens": 44502,
      "cache_read_input_tokens": 20628,
      "output_tokens": 267,
      "server_tool_use": { "web_search_requests": 0, "web_fetch_requests": 0 },
      "service_tier": "standard",
      "cache_creation": {
        "ephemeral_1h_input_tokens": 44502,
        "ephemeral_5m_input_tokens": 0
      },
      "inference_geo": "not_available",
      "iterations": [
        {
          "input_tokens": 2,
          "output_tokens": 267,
          "cache_read_input_tokens": 20628,
          "cache_creation_input_tokens": 44502,
          "cache_creation": { "ephemeral_5m_input_tokens": 0, "ephemeral_1h_input_tokens": 44502 },
          "type": "message"
        }
      ],
      "speed": "standard"
    }
  },
  "effort": "xhigh",
  "session_id": "9aed94d5-...",
  "cwd": "/Users/noah/dev/borg-collective",
  "version": "2.1.220",
  "gitBranch": "feat/link-one-front-door-s1-s2"
}
```

Field-by-field, this is the exact shape to build against:

- `input_tokens` — fresh (non-cached) input tokens for this API call.
- `output_tokens` — generated tokens (includes any invisible thinking billed as output).
- `cache_creation_input_tokens` — total tokens newly written into cache this call (sum of the
  `cache_creation` breakdown below).
- `cache_read_input_tokens` — tokens served from cache this call (~10x cheaper than fresh input).
- `cache_creation.ephemeral_5m_input_tokens` / `ephemeral_1h_input_tokens` — split of the creation
  total by cache TTL tier (Anthropic offers both a 5-minute and a 1-hour cache breakpoint; this repo's
  own pricing table in `~/.claude/plugins/token-cost/SKILL.md` only prices the 5m tier — the 1h tier
  observed here (44502 tokens, $/M differs from the 5m rate) is a gap in that pricing table worth
  fixing).
  [Anthropic prompt caching docs](https://docs.claude.com/en/docs/build-with-claude/prompt-caching)
  confirm the two TTL tiers exist and are priced differently `[2024-2026]`.
- `iterations[]` — present on this session; appears to record one entry per underlying
  model "turn" inside a single logged assistant message (relevant for effort/extended-thinking
  loops where one visible message may correspond to multiple upstream iterations). This field is not
  documented publicly as far as this research found — treat as unstable/internal shape, verify shape
  hasn't changed before depending on it in a script.
- `service_tier`, `speed`, `effort`, `inference_geo`, `server_tool_use` — metadata, not token counts,
  but useful correlation keys (e.g., join `effort` against token usage to see if `xhigh` reasoning
  effort is inflating output tokens).
- Top-level (outside `message`): `sessionId`, `session_id` (both appear — worth normalizing on one),
  `cwd`, `gitBranch`, `version`, `timestamp`, `requestId`, `uuid`/`parentUuid` (message-chain linkage
  useful for reconstructing turn boundaries), `userType`, `entrypoint`.

This matches (and is slightly more detailed than) the fields ccusage's own README documents it
parsing (`input_tokens`, `output_tokens`, `cache_creation_input_tokens`, `cache_read_input_tokens`).
[ccusage](https://ccusage.com/) `[2024-2026]`.

### 2. Existing tooling landscape

| Tool | What it does | Data source | Context-source attribution? |
|---|---|---|---|
| `ccusage` | npm CLI, parses local transcript JSONL into daily/weekly/monthly/session/5h-window cost reports, per-model breakdown, zero network calls | Transcript JSONL | No — per-session/per-model only |
| `claude-code-otel` ([GitHub](https://github.com/ColeMurray/claude-code-otel)) | Self-hosted OTel collector + Grafana dashboards for Claude Code's native telemetry export | OTLP metrics/logs from Claude Code | No — per-call/per-tool, tagged by agent/skill/mcp name but not by prompt content |
| Claude Code native OTel (`CLAUDE_CODE_ENABLE_TELEMETRY=1`) | 8 metrics + 6 event types exported via OTLP/Prometheus/console | In-process instrumentation | No |
| AWS CloudWatch / SigNoz / Dash0 guides | Ingest the same OTel export into a hosted backend | Same OTel export | No |
| Langfuse / Helicone / Braintrust / W&B Weave | General LLM observability platforms: per-call token+cost tracking, tracing, eval gates | API call interception (proxy or SDK instrumentation) | No — these track per-span/per-call token usage, not sub-call attribution to which document/context-block generated the cached tokens |
| `/cost` slash command | Anthropic docs referenced by some third-party guides but **not found in the official monitoring-usage page fetched for this research** — cost is exposed via the OTel `claude_code.cost.usage` metric, not confirmed as a live slash command in the docs checked | — | — |

Sources: [ccusage.com](https://ccusage.com/) `[2024-2026]`,
[claude-code-otel GitHub](https://github.com/ColeMurray/claude-code-otel) `[2024-2026]`,
[Anthropic/Claude Code monitoring-usage docs](https://code.claude.com/docs/en/monitoring-usage)
`[2024-2026]`, [Braintrust LLM tracing tools 2026 review](https://www.braintrust.dev/articles/best-llm-tracing-tools-2026)
`[2024-2026]`, [Langfuse token/cost tracking docs](https://langfuse.com/docs/observability/features/token-and-cost-tracking)
`[2024-2026]`.

**Gap to flag explicitly**: the `/cost` command's existence was not verified from a primary source
in this pass — treat as unconfirmed until checked directly in a running `claude` session (`/cost` at
the prompt) or in the CLI's own `--help`/slash-command list.

### 3. Claude Code native OpenTelemetry metrics (exact, from official docs)

Enable with:

```bash
export CLAUDE_CODE_ENABLE_TELEMETRY=1
export OTEL_METRICS_EXPORTER=otlp
export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
```

(`console` exporter with `OTEL_METRIC_EXPORT_INTERVAL=1000` is the fastest way to eyeball this
locally without standing up a collector.)

Eight metrics, per
[docs.code.claude.com/en/docs/monitoring-usage](https://code.claude.com/docs/en/monitoring-usage)
`[2024-2026]`:

| Metric | Attributes relevant to token/cost accounting |
|---|---|
| `claude_code.token.usage` | `type` ("input"/"output"/"cacheRead"/"cacheCreation"), `model`, `query_source` ("main"/"subagent"/"auxiliary"), `speed`, `effort`, `agent.name`, `skill.name`, `plugin.name`, `mcp_server.name`, `mcp_tool.name` |
| `claude_code.cost.usage` | Same attribution chain, in USD |
| `claude_code.session.count` | `start_type` |
| `claude_code.active_time.total` | `type` ("user" vs "cli") |
| `claude_code.lines_of_code.count`, `.pull_request.count`, `.commit.count`, `.code_edit_tool.decision` | Not token/cost, but useful for correlating token spend against actual output (lines changed per token spent) |

Six event types via OTel logs/events (all carry `prompt.id` for cross-correlation):
`claude_code.user_prompt`, `claude_code.assistant_response`, `claude_code.tool_result`,
`claude_code.api_request`, `claude_code.api_error`, `claude_code.tool_decision`.

This `query_source`/`agent.name`/`skill.name`/`mcp_tool.name` attribution chain is the single most
useful thing this surface offers beyond the raw transcript: it lets you split token spend by
**which skill or subagent triggered the call**, which is a real, already-solved slice of "attribute
tokens to a source" — just not attribution *within* a call to *which piece of the prompt* was
cached/read.

### 4. The attribution problem: cache tokens to context source — genuinely unsolved

This is the load-bearing negative finding. Searched specifically for (a) LLM observability platforms
doing sub-call attribution, and (b) the OTel GenAI semantic-conventions spec for any such field.

- OTel GenAI semconv defines `gen_ai.usage.input_tokens`, `gen_ai.usage.output_tokens`, and (per
  [open-telemetry/semantic-conventions#1959](https://github.com/open-telemetry/semantic-conventions/issues/1959)
  and the [Gen AI attribute registry](https://opentelemetry.io/docs/specs/semconv/registry/attributes/gen-ai/))
  a `gen_ai.usage.cached_tokens` attribute — but this is a single scalar per span, not a breakdown by
  which document/message contributed to the cache write or read. `[2024-2026]`
- Anthropic's own API surface (`cache_creation_input_tokens`, `cache_read_input_tokens`, and the
  `ephemeral_5m`/`ephemeral_1h` split) is the finest granularity available anywhere, and it is still
  per-call, not per-block. The API does not return "block N of your prompt (CLAUDE.md) contributed X
  cached tokens." [Anthropic prompt caching docs](https://docs.claude.com/en/docs/build-with-claude/prompt-caching)
  `[2024-2026]`.
- None of Langfuse, Helicone, Braintrust, or W&B Weave — the four most-cited LLM observability
  platforms as of 2026 — claim sub-call context-source attribution; all four instrument at the
  call/span level (one row per API request, with token/cost fields from the same provider response).
  [Braintrust 2026 tracing tools review](https://www.braintrust.dev/articles/best-llm-tracing-tools-2026)
  `[2024-2026]`, [Langfuse token/cost docs](https://langfuse.com/docs/observability/features/token-and-cost-tracking)
  `[2024-2026]`.
- **Conclusion**: nobody has solved provider-side attribution of cache tokens to a named context
  source. The only path to an approximate breakdown is *inference from prompt construction*, not
  measurement — e.g.:
  1. Compute (or log) the token length of each static block you assemble into the system prompt
     (CLAUDE.md contents, tool schema JSON, skill files) at the point you construct the request —
     this requires instrumenting the harness/CLI itself, which for Claude Code is closed-source, so
     it's not available to a hook or transcript reader.
  2. Approximate via **delta analysis**: since Anthropic's prompt caching requires a stable prefix,
     the FIRST call in a session that establishes the cache has `cache_creation_input_tokens` roughly
     equal to (system prompt + CLAUDE.md + tool schemas + skills loaded), and every subsequent call's
     `cache_read_input_tokens` growth tracks conversation history added since. You can back out a
     rough split by diffing `cache_creation_input_tokens` across the session's first few turns against
     known artifact sizes (e.g., token-count your own CLAUDE.md with a local tokenizer and compare).
     This is an inference technique, not a measurement — flag it as such in any tool built on it.
  3. Practically: log the byte/token size of CLAUDE.md, active skill files, and MCP tool-schema JSON
     independently (you control these — they're files on disk or loadable payloads), then correlate
     against the transcript's first-turn `cache_creation_input_tokens` for a same-session, same-day
     approximate attribution — not exact, but directionally useful for "which context source is the
     heaviest."

### 5. Hooks — do they see token counts? (No — but they can read the transcript)

Fetched the official [hooks reference](https://code.claude.com/docs/en/hooks) `[2024-2026]` directly.
Confirmed:

- Every hook payload includes `session_id`, `transcript_path`, `cwd`, `permission_mode`,
  `effort.level`, `hook_event_name`; subagent-context hooks add `agent_id`/`agent_type`.
- **No hook event's stdin payload includes token counts, cost, or usage totals.** This applies to
  PreToolUse, PostToolUse, Stop, SubagentStop, SessionStart, SessionEnd, and Notification alike per
  the fetched doc.
- `Stop`/`SubagentStop` do carry `last_assistant_message` (the final text of the turn) — useful for
  debrief-style hooks, not for token accounting.
- The `transcript_path` field is the workaround already exploited by the user's own `token-cost`
  SessionEnd hook (per `~/.claude/plugins/token-cost/SKILL.md`): a hook reads the transcript JSONL
  itself, sums the `.message.usage` blocks (input/output/cache_creation/cache_read) across the
  session, applies the per-model price table, and appends one row to
  `~/.claude/token-spend.jsonl`. This is the correct and only mechanism available to hooks for
  token/cost visibility — there is no push-based alternative.
- Caveat surfaced in the docs: the transcript file is written **asynchronously** and "may lag the
  in-memory conversation," so a hook reading it at `Stop` time may not yet see the very last message's
  usage block — worth a retry/backoff or reading `last_assistant_message` where sufficient instead of
  depending on the transcript being fully flushed.

### 6. Practical recipe for habit #4 ("log before cutting")

Given the above, a concrete, implementable measurement layer for borg-collective specifically:

1. **Per-turn, per-model**: already solved. Read `.message.usage` from the current session's
   transcript JSONL (the four core fields plus the `cache_creation` TTL split) — no new tooling
   needed, this is what `ccusage` and the existing `token-cost` hook already do.
2. **Per-tool-call**: not directly in `.message.usage` (usage is per assistant *message*, and a
   message can contain multiple tool_use blocks). To get a per-tool-call estimate, correlate
   `PostToolUse` hook events (which do carry `tool_name` and timing, though not tokens) against the
   nearest preceding/following transcript `usage` block by `uuid`/`parentUuid` chain — an
   approximation, not exact, since multiple tool calls can share one assistant turn's token cost.
3. **Per-context-source**: NOT achievable via measurement with current tooling (see Section 4). Best
   available is the delta/inference technique above — log known artifact sizes (CLAUDE.md, skills,
   MCP schemas) independently and correlate against first-turn `cache_creation_input_tokens`. Be
   explicit in any deliverable that this is inferred, not measured.
4. **Cross-session aggregate**: `claude_code.token.usage` via OTel with `OTEL_METRICS_EXPORTER=otlp`
   into any collector (or `console` for quick local checks) gives the richest attribution available
   today — by `skill.name`/`agent.name`/`mcp_tool.name` — without needing to build your own
   transcript-diffing logic. This is a stronger foundation than parsing more transcript fields by
   hand, since Anthropic already tags the call site.

## Evidence gaps and uncertainties

- `/cost` slash command existence/behavior was not confirmed from a primary source in this pass —
  verify directly (`/cost` inside a running session) before building around it.
- The `iterations[]` array observed in the live transcript is not documented in any fetched source —
  treat its shape as internal/unstable.
- Whether Claude Code's OTel `claude_code.token.usage` metric's `cacheRead`/`cacheCreation` types
  further split by the 5m/1h TTL tiers (the way the transcript's `cache_creation` object does) was not
  confirmed — the fetched OTel doc only lists the four `type` values, not a TTL sub-attribute. Worth
  checking with a live `console` exporter run before assuming parity with the transcript schema.
- No primary source found for any tool or technique that attributes cache tokens to a named context
  source at the provider/measurement level — this is reported as an evidence gap AND a substantive
  finding (Section 4), not merely an omission in this research.

## Paywalled must-reads

None identified — all load-bearing sources (Anthropic/Claude Code docs, ccusage, claude-code-otel,
OTel semconv, Langfuse docs) are open-access.

## Sources index

| # | Title | URL | Date | Tier |
|---|-------|-----|------|------|
| 1 | Claude Code Monitoring & Observability (OTel metrics, exact schema) | https://code.claude.com/docs/en/monitoring-usage | 2026 | [2024-2026] |
| 2 | Claude Code Hooks reference (payload schema) | https://code.claude.com/docs/en/hooks | 2026 | [2024-2026] |
| 3 | ccusage — Coding Agent CLI Usage Analysis | https://ccusage.com/ | 2026 | [2024-2026] |
| 4 | claude-code-otel (GitHub, self-hosted OTel+Grafana stack) | https://github.com/ColeMurray/claude-code-otel | 2026 | [2024-2026] |
| 5 | Anthropic prompt caching docs (TTL tiers, cache_creation/cache_read semantics) | https://docs.claude.com/en/docs/build-with-claude/prompt-caching | 2026 | [2024-2026] |
| 6 | OpenTelemetry GenAI semantic conventions attribute registry | https://opentelemetry.io/docs/specs/semconv/registry/attributes/gen-ai/ | 2026 | [2024-2026] |
| 7 | OTel semconv issue #1959 — detailed token usage attributes/metrics | https://github.com/open-telemetry/semantic-conventions/issues/1959 | 2026 | [2024-2026] |
| 8 | Braintrust — Best LLM tracing tools for multi-agent systems (2026 review) | https://www.braintrust.dev/articles/best-llm-tracing-tools-2026 | 2026 | [2024-2026] |
| 9 | Langfuse — Token & Cost Tracking docs | https://langfuse.com/docs/observability/features/token-and-cost-tracking | 2026 | [2024-2026] |
| 10 | Local transcript JSONL (primary, direct file read) | /Users/noah/.claude/projects/-Users-noah-dev-borg-collective/c2773ad6-...jsonl | 2026-08-26 | direct-measurement |
| 11 | Braintrust — How to track LLM token usage (2026) | https://www.braintrust.dev/articles/how-to-track-llm-token-usage-2026 | 2026 | [2024-2026] |
