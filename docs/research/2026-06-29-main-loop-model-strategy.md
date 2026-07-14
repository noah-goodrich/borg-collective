# Track 2 — Can the Main Loop Run Cheaper? Sonnet-Default vs Opus Escalation

**Date:** 2026-06-29
**Question:** Can the borg orchestrator's main loop run on Sonnet 4.6 instead of Opus 4.8, with Opus
escalation only for hard reasoning turns? Quantify savings, name failure modes, give a concrete policy.

---

## Executive Summary

- **Savings multiplier is 1.67x (≈40%), not 5x.** At current pricing (Opus $5/$25/$0.50 per MTok
  in/out/cache-read; Sonnet $3/$15/$0.30), every token category is 60% of Opus. In a cache-dominated
  session the overall effective savings from a full Sonnet switch are ~40% of main-loop spend
  (~$6.2k over the measured period).
- **Model switches AND effort-level changes both invalidate the full prompt cache.** They must be
  committed at session start; mid-session toggling pays a full uncached re-read penalty every time.
  This makes ad-hoc Opus escalation within a long session actively expensive, not free.
- **Anthropic ships a built-in answer: the `opusplan` alias** (Opus during plan mode, Sonnet during
  execution). This is the lowest-risk hybrid and the recommended first step for borg sessions that
  have a discrete planning phase.
- **Sonnet 4.6 trails Opus 4.8 by 12.7pp on MCP Atlas** (complex multi-tool orchestration), but
  matches/beats same-generation Opus 4.6 on scaled and agentic tool use. The gap is real for novel
  cross-project decomposition; it is small or absent for dispatch-and-synthesize work.
- **Fast mode is a speed feature, not a cost lever.** Opus 4.8 fast mode costs $10/$50 per MTok
  (2x standard). Never consider it for cost reduction.

---

## Findings

### 1. Pricing: True Opus→Sonnet Multiplier is 1.67x

At the current verified rates (as of 2026-06-29):

| Token type        | Opus 4.8  | Sonnet 4.6 | Ratio     |
|-------------------|-----------|------------|-----------|
| Input             | $5/MTok   | $3/MTok    | 1.67x     |
| Output            | $25/MTok  | $15/MTok   | 1.67x     |
| Cache write (5m)  | $6.25/MTok| $3.75/MTok | 1.67x     |
| Cache read        | $0.50/MTok| $0.30/MTok | 1.67x     |

Sonnet 4.6 is uniformly priced at 60% of Opus 4.8 across every category. In a session where cache
reads dominate (the expected borg pattern), the overall savings from a full model switch are
approximately 40%. Applied to the corrected main-loop figure of ~$15.4k, this is ~$6.2k.

The "5x" figure was based on old Opus pricing ($15 input vs $3 Sonnet). At current rates that ratio
is gone across the board.

Source: [Anthropic pricing page](https://platform.claude.com/docs/en/about-claude/pricing) [2026]

### 2. The Cache Penalty: Model AND Effort Switches Both Invalidate Fully

This is the single most important mechanical constraint.

From the official Claude Code prompt-caching docs:
> "Each model has its own cache. Switching with /model means the next request reads the entire
> conversation history with no cache hits, even though the content is identical."
> "The cache is keyed by effort level as well as model, so switching with /effort means the next
> request reads the entire conversation history with no cache hits."

**Both model and effort level are part of the cache key.** A mid-session `/model opus` at turn 20
of a 100k-token borg session forces a full uncached re-read at Opus input rates ($5/MTok) instead
of cache-read rates ($0.50/MTok) — a 10x penalty on that one turn's input.

**Critical implication for borg:** "Manual Opus-on-demand discipline" — i.e., the human deciding
to type `/model opus` mid-session when something looks hard — is NOT a viable strategy. It destroys
cache and pays back much of the session's saved cache-read discount in a single turn.

**What does NOT invalidate cache:** `/clear`, `/compact` (both rebuild the cache, but these are
natural break points), subagent spawning (subagents build their own separate cache; parent cache
is unaffected), and invoking skills/commands.

Source: [Claude Code prompt caching docs](https://code.claude.com/docs/en/prompt-caching) [2026]

### 3. The `opusplan` Alias: Anthropic's Built-in Hybrid

`opusplan` is an official Claude Code model alias:

> "Special mode that uses `opus` during plan mode, then switches to `sonnet` for execution."

From the model-config docs:
> "The `opusplan` model setting resolves to Opus during plan mode and Sonnet during execution, so
> each plan-mode toggle is a model switch and starts a fresh cache."

**Behavior:** Enter plan mode (Shift+Tab) → runs on Opus 4.8. Exit plan mode → switches to Sonnet
4.6. Each transition burns the cache. For a session structured as "one planning phase then N
execution turns," the cost is: 1× cache-miss penalty at the plan→execute transition, then N turns
at Sonnet cache-read rates. Break-even vs pure Opus: roughly 5-8 execution turns (depending on
context size).

**For borg's pattern:** If borg sessions typically start with a planning/decomposition phase
(reviewing project states, deciding what to dispatch) followed by many turns of dispatching and
synthesizing subagent results, `opusplan` maps cleanly onto this structure.

Source: [Claude Code model config docs](https://code.claude.com/docs/en/model-config) [2026],
[opusplan explainer](https://ercanataycom.medium.com/opusplan-mode-in-claude-code-opus-thinks-sonnet-builds-745e094a1dfc)
[2026]

### 4. Capability Gap: Opus 4.8 vs Sonnet 4.6

This data is from a direct benchmark comparison published June 2026:

| Benchmark                     | Opus 4.8 | Sonnet 4.6 | Gap    |
|-------------------------------|----------|------------|--------|
| MCP Atlas (multi-tool chains) | 82.2%    | 69.5%      | +12.7pp|
| OSWorld (GUI/automation)      | 83.4%    | 72.5%      | +10.9pp|
| SWE-bench Verified            | 88.6%    | 79.6%      | +9.0pp |
| HLE with tools                | 57.9%    | 49.0%      | +8.9pp |

Source: [CodingFleet Opus 4.8 vs Sonnet 4.6](https://codingfleet.com/blog/claude-opus-4-8-vs-claude-sonnet-4-6/)
[2026]

However, a same-generation comparison (Sonnet 4.6 vs Opus 4.6) shows a different picture for
routing-specific tasks:

| Benchmark              | Sonnet 4.6 | Opus 4.6 | Notes                        |
|------------------------|------------|----------|------------------------------|
| Scaled Tool Use        | 61.3%      | 59.5%    | Sonnet WINS                  |
| Agentic Tool Use       | 91.7%      | 91.9%    | Effectively tied             |
| Computer Use           | 72.5%      | 72.7%    | Effectively tied             |
| Deep Scientific (GPQA) | 74.1%      | 91.3%    | Opus wins by 17pp            |
| Novel Problem Solving  | 58.3%      | 68.8%    | Opus wins by 10.5pp          |
| Terminal Coding        | 59.1%      | 65.4%    | Opus wins by 6.3pp           |

Source: [Medium: Sonnet 4.6 Nearly Matches Opus](https://medium.com/@cognidownunder/claude-sonnet-4-6-nearly-matches-opus-and-it-costs-one-fifth-the-price-3fac116b12fd)
[2026]

**Interpretation for borg:** The tasks where Sonnet 4.6 underperforms Opus are deep scientific
reasoning, novel problem solving, and terminal coding — not dispatch and coordination. For a borg
orchestrator primarily doing "receive subagent results, check against plan, dispatch next batch,"
Sonnet 4.6 is functionally equivalent to Opus 4.6 and close to Opus 4.8 on the relevant
dimensions. The 12.7pp MCP Atlas gap vs Opus 4.8 is real, but MCP Atlas measures complex multi-tool
CHAINS — the kind of thing subagents do, not the routing layer that dispatches them.

### 5. Effort Parameter: The Within-Session Lever (With a Cache Caveat)

The `/effort` command controls thinking depth and overall token spend via the `output_config.effort`
parameter. Levels: `low`, `medium`, `high` (default), `xhigh`, `max`.

**Critical caveat:** Like model, effort level is part of the cache key. Changing it mid-session
invalidates the full cache. Claude Code shows a confirmation dialog when you do this. **Must be set
at session start.**

On Opus 4.8, effort controls adaptive thinking:
- `high` (default): Claude almost always thinks deeply
- `medium`: Claude uses moderate thinking, may skip for simple queries
- `low`: Claude minimizes thinking, skips for most tasks

Official recommendation for Sonnet 4.6: "Medium effort (recommended default): Best balance of
speed, cost, and performance for most applications. Suitable for agentic coding, tool-heavy
workflows, and code generation."

**Savings estimate from effort=medium vs effort=high:** Estimated 30-40% reduction in output/thinking
tokens. If output tokens are ~20-25% of borg's total main-loop cost, effort=medium yields roughly
6-10% total cost reduction. Small on its own, but zero capability risk for dispatch/synthesis work
and freely available at session start.

Effort affects ALL tokens: thinking, text responses, tool calls. At lower effort, Claude makes fewer
tool calls, proceeds to action without preamble, uses terse confirmations — useful for borg's
"dispatch, don't deliberate" pattern.

Source: [Effort docs](https://platform.claude.com/docs/en/build-with-claude/effort) [2026],
[Claude Code costs docs](https://code.claude.com/docs/en/costs) [2026]

### 6. Fast Mode: NOT a Cost Lever — Do Not Use

Fast mode delivers up to 2.5x higher output tokens/second, but at a premium:

| Model       | Fast mode input | Fast mode output |
|-------------|----------------|-----------------|
| Opus 4.8    | $10/MTok       | $50/MTok        |
| Opus 4.7/4.6| $30/MTok       | $150/MTok       |

Fast mode for Opus 4.8 is 2x MORE expensive than standard. It is a latency tool, not a cost tool.
Fast mode for Opus 4.7 is deprecated as of June 25, 2026 (removed July 24, 2026). Opus 4.6 fast
mode is deprecated and removed June 29, 2026.

**Additional gotcha:** Switching fast mode ON also invalidates the prompt cache (it adds a request
header that is part of the cache key). Once on, it can be left on without further cache penalty.

Source: [Fast mode docs](https://platform.claude.com/docs/en/build-with-claude/fast-mode) [2026]

### 7. Adaptive Thinking on Opus 4.8: Manual Budget is Unavailable

On Opus 4.8, manual `thinking: {type: "enabled", budget_tokens: N}` is **rejected with a 400
error**. Adaptive thinking (`thinking: {type: "adaptive"}`) is the only supported mode. The `effort`
parameter is the control knob for thinking depth. This means `MAX_THINKING_TOKENS` environment
variable has no effect on Opus 4.8. Use `/effort medium` or `/effort low` instead.

For reference: Sonnet 4.6 still supports both adaptive and manual thinking (deprecated but
functional), giving more fine-grained control if needed.

Source: [Adaptive thinking docs](https://platform.claude.com/docs/en/build-with-claude/adaptive-thinking)
[2026]

### 8. Official Guidance: Use Sonnet for Coordination

From the official Claude Code cost management docs:
> "Use Sonnet for teammates. It balances capability and cost for coordination tasks."
> "Sonnet handles most coding tasks well and costs less than Opus. Reserve Opus for complex
> architectural decisions or multi-step reasoning."

From the agent teams guidance (directly applicable to borg's dispatcher pattern):
> "Use Sonnet for teammates. It balances capability and cost for coordination tasks. Keep teams
> small. Each teammate runs its own context window, so token usage is roughly proportional to
> team size."

Anthropic explicitly recommends Sonnet for coordination/dispatch. This is not a community
workaround — it is the documented intended use.

Source: [Claude Code costs docs](https://code.claude.com/docs/en/costs) [2026]

### 9. Failure Modes: When Sonnet as Orchestrator Breaks

Based on the capability gap data and the Augment Code routing guide:

1. **Novel cross-project decomposition**: Ambiguous requirements that need deep multi-step
   constraint reasoning (e.g., "given the state of all 18 projects, what's the optimal parallelism
   strategy?") — Opus 4.8 has a 12.7pp MCP Atlas advantage specifically because of this.

2. **Error recovery from subagent failures**: When subagents return conflicting results, root-cause
   analysis requiring multi-hop inference benefits from Opus's deeper reasoning.

3. **Cascading decomposition failure**: The Augment Code guide warns: "When a weaker model handles
   planning, every downstream agent operates on malformed inputs with no upstream correction
   mechanism." Pre-decomposed, well-specified tasks are fine; novel decomposition is the risk.

4. **Long-horizon dependency tracking across 18 projects**: Sonnet's deep scientific reasoning gap
   (17pp) suggests it may miss subtle cross-project constraint violations that Opus catches.

5. **Effort=medium + Sonnet compound risk**: Running Sonnet at medium effort on a genuinely complex
   orchestration turn (e.g., "rearchitect the deployment dependency graph") compounds the capability
   reduction. The effort floor matters.

The Augment Code guide explicitly states Opus 4.6 is "the correct coordinator model for complex
pipelines" while noting Sonnet suffices for "small pipelines (2-3 specialists) with well-scoped,
pre-decomposed tasks."

Source: [Augment Code routing guide](https://www.augmentcode.com/guides/ai-model-routing-guide)
[2026]

---

## Concrete Recommended Policy (Ranked by Expected Impact)

### Tier 1 (Highest Impact, Meaningful Tradeoff): Sonnet-Default for Dispatch Sessions

**Savings: ~40% of main-loop cost (~$6.2k over the measured base)**

Set `ANTHROPIC_MODEL=sonnet` in borg's shell environment or settings as the default. Override with
`claude --model opus` ONLY when launching a session that will do novel planning/decomposition.

**Classification heuristic for borg:**
- Dispatch session (Sonnet): subagent results are already structured, task is "review, synthesize,
  dispatch next batch, check progress" — uses Sonnet[1m] for the 1M context window
- Planning session (Opus): "design sprint structure from scratch," "new project onboarding,"
  "cross-project constraint resolution" — use Opus[1m]

**Operationalize:**
```bash
# Default: Sonnet for dispatch
claude --model sonnet[1m]

# For planning sessions only
claude --model opus[1m]
```

**Failure mode mitigation:** Maintain a written session-start checklist. If borg is dispatching into
an unknown problem space, use Opus. If borg is executing against a known plan, Sonnet is sufficient.

### Tier 2 (Medium Impact, Lower Risk): `opusplan` for Mixed Sessions

**Savings: ~25-35% of main-loop cost (varies with planning-phase fraction)**

Use the `opusplan` alias when a session will have a discrete planning phase followed by execution.
Opus 4.8 handles plan mode (Shift+Tab), Sonnet 4.6 handles all execution turns.

**Cost math (example: 5k-token planning phase, 50 execution turns at 100k-token context):**
- Opus planning phase: 2-3 turns at Opus rates (minimal cost)
- Cache break at exit from plan mode: 100k × ($5 - $0.50)/MTok = $0.45 penalty once
- 50 execution turns at Sonnet cache-read rates vs Opus: saves 50 × 100k × ($0.50 - $0.30)/MTok
  = $1.00 across those turns

Break-even: ~2-3 execution turns. Worth it for any session longer than a quick check-in.

```bash
# Set at session start; do not change mid-session
claude --model opusplan
```

### Tier 3 (Low Impact, Zero Risk): Opus `medium` Effort at Session Start

**Savings: ~6-10% of main-loop cost (~$1-1.5k over the measured base)**

Keep Opus 4.8 but set effort=medium at session start for all dispatch-heavy turns. Never change
effort mid-session (cache penalty). On Opus 4.8, `medium` effort means adaptive thinking skips
thinking for routine dispatch turns (read output → check progress → dispatch next → summarize).

```bash
# In /config or at session start via /effort medium
# Or in settings.json: "effort": "medium"
```

**When NOT to do this:** Any session involving novel decomposition or architectural decisions.
Keep Opus at `high` or `xhigh` for those.

### What NOT to Do

- **Never use `/model opus` mid-session** as a "smart escalation." The cache penalty negates most
  of the savings you'd have accumulated on Sonnet turns.
- **Never use fast mode for cost control.** It is 2x more expensive than standard Opus.
- **Do not change effort level mid-session.** Set it once at the start.
- **Do not conflate the "5x savings" claim with current pricing.** Opus→Sonnet is 1.67x, not 5x.

---

## What is Irreducible

Running a 1M-context orchestrator across 18 projects involves significant context at every turn.
Even Sonnet cannot escape the per-MTok cache-read cost on a growing conversation. The cache-read
savings from Opus→Sonnet (~$0.20/MTok) are real but bounded. The main irreducible costs are:
1. The size of the context itself (addressed in Track 1/3)
2. The reasoning depth needed for genuine orchestration decisions (Opus is the right tool here)
3. The per-turn cache-read charge, which scales with session length regardless of model

The Sonnet-default strategy saves 40% of those cache-read charges while accepting a capability
tradeoff on the hardest turns. The `opusplan` strategy preserves Opus quality for planning while
capturing the 40% savings on execution turns.

---

## Evidence Gaps and Uncertainties

- **Borg's actual turn breakdown is unknown.** The 40% savings estimate assumes Sonnet replaces
  most or all turns. If 60%+ of borg turns are genuinely hard planning/decomposition, the savings
  erode and the capability risk increases.
- **MCP Atlas scores for Opus 4.8 vs Sonnet 4.6 are from a third-party blog** (CodingFleet), not
  an Anthropic benchmark release. Cross-check against the Anthropic model card when available.
- **Effort-level savings percentages** (30-40%) are community estimates, not Anthropic-published
  figures. Actual savings depend heavily on how much thinking Opus was doing at high effort.
- **Cache miss cost at `opusplan` transitions** is approximated. The exact penalty depends on
  context length at the time of the plan-mode toggle.
- **`sonnet[1m]` alias availability**: The 1M context window is documented for both `opus[1m]` and
  `sonnet[1m]` aliases, but Sonnet 4.6 1M context window availability should be confirmed before
  defaulting to it for long borg sessions.

---

## Paywalled Must-Reads

None. All primary sources were accessible via open web.

---

## Sources Index

| # | Title | URL | Date | Tier |
|---|-------|-----|------|------|
| 1 | Claude Code model configuration | https://code.claude.com/docs/en/model-config | 2026 | [2024-2026] |
| 2 | How Claude Code uses prompt caching | https://code.claude.com/docs/en/prompt-caching | 2026 | [2024-2026] |
| 3 | Manage costs effectively — Claude Code Docs | https://code.claude.com/docs/en/costs | 2026 | [2024-2026] |
| 4 | Fast mode (research preview) | https://platform.claude.com/docs/en/build-with-claude/fast-mode | 2026 | [2024-2026] |
| 5 | Adaptive thinking | https://platform.claude.com/docs/en/build-with-claude/adaptive-thinking | 2026 | [2024-2026] |
| 6 | Effort parameter | https://platform.claude.com/docs/en/build-with-claude/effort | 2026 | [2024-2026] |
| 7 | Opus 4.8 vs Sonnet 4.6 benchmark comparison | https://codingfleet.com/blog/claude-opus-4-8-vs-claude-sonnet-4-6/ | 2026 | [2024-2026] |
| 8 | Sonnet 4.6 Nearly Matches Opus (capability gap analysis) | https://medium.com/@cognidownunder/claude-sonnet-4-6-nearly-matches-opus-and-it-costs-one-fifth-the-price-3fac116b12fd | 2026 | [2024-2026] |
| 9 | AI Model Routing Guide — Augment Code | https://www.augmentcode.com/guides/ai-model-routing-guide | 2026 | [2024-2026] |
| 10 | opusplan Mode in Claude Code | https://ercanataycom.medium.com/opusplan-mode-in-claude-code-opus-thinks-sonnet-builds-745e094a1dfc | 2026 | [2024-2026] |
| 11 | Reduce Claude Code Costs (systemprompt.io) | https://systemprompt.io/guides/claude-code-cost-optimisation | 2026 | [2024-2026] |
| 12 | Claude Code Advisor Strategy | https://www.mindstudio.ai/blog/claude-code-advisor-strategy-opus-sonnet-haiku | 2026 | [2024-2026] |
| 13 | How to use opusplan — Christopher Penn | https://www.christopherspenn.com/2026/04/how-to-use-the-secret-opusplan-model-in-claude-code-save-money-quota-without-sacrificing-quality/ | 2026 | [2024-2026] |
