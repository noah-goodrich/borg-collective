# Directive: Sub-agent / workflow spend optimization

**Filed:** 2026-06-10 · **Status:** proposed (awaiting validation) · **Parent:** orchestration layer

## Why now

Delegation is where the money is. Measured this session (cache-aware Opus pricing, summed from the
sub-agent transcripts):

| Wave | real cost | dominant component |
|------|-----------|--------------------|
| Wave 1 (7 agents) | **$56.14** | cache-read ~63% ($35.40) |
| Wave 2 (4 agents) | **$43.08** | cache-read ~63% |

The main-loop token-cost line reported pennies for the same turns — fixed in `token-cost` #10, which now
counts delegated spend. With the accounting honest, the next step is to *reduce* the spend. ~63% is
**cache reads** — agents re-reading their own accumulated context every turn — so the wins come from
smaller contexts, fewer turns, and cheaper models, not from trimming output.

Measurement handle: `subagent_tokens` in the workflow `<usage>` block = summed per-agent final-context
footprint (verified to 0.02%). Quick cost proxy ≈ `subagent_tokens × $0.16 / 1k` for Opus (within ~10%);
exact figure via the cache-aware `jq` over the agent transcripts (documented in the token-cost skill).

## Levers, by magnitude

1. **Model-tier routing (~5×, the big one).** Route each task to the cheapest model that does it
   correctly; reserve Opus for genuinely hard work. In workflows this is `agent(..., {model})`; for the
   Agent tool it is the orchestrator's per-spawn choice.
2. **Lean agents / fewer turns (~2-3×).** Cost scales with context-size × turns. Tight briefs, read
   line-ranges not whole files, decompose so each agent's context stays small, never re-derive what the
   brief can state.
3. **cairn-warm context (10-30%, grows with the graph).** Query cairn for distilled facts (decisions,
   contracts, file locations) and pre-load them into briefs so agents don't rediscover from the repo.
   Gated on the cairn backfill (currently too sparse — tracked in cairn).

## Model-tier routing table (chosen defaults — tuned to "quality over cheap")

| Task class | Default model | Rationale |
|------------|---------------|-----------|
| Mechanical (rename, move, format, single-file mechanical edit, grep/collate) | Haiku | deterministic, low-risk |
| Implementation on a clear, well-scoped brief (+ tests) | Sonnet | strong code at ~1/5 Opus cost |
| Adversarial verify / review | Sonnet panel (diverse lenses) — escalate to Opus on high-stakes diffs | diversity beats one premium reviewer |
| Hard reasoning / architecture / synthesis / ambiguous scope | Opus | reserve the premium tier where it pays |

Default stance (per "done right, not cheap"): **Sonnet for implementation, Opus only when the task is
genuinely hard or high-stakes, Haiku only for truly mechanical work.** When unsure, do not downgrade —
correctness first. The savings come from *not* defaulting everything to Opus, not from cutting corners.

## cairn-warm brief pattern

- Before dispatch, the orchestrator runs `borg search` / cairn for relevant prior knowledge and injects
  the distilled hits into the brief (so the agent starts warm instead of re-reading the repo).
- After each wave, the orchestrator writes the distilled decisions/contracts back to cairn.
- Net effect: smaller agent contexts → fewer/cheaper cache reads → lower cost, compounding as the graph
  fills. Manual version already in use (tight fact-loaded briefs); this makes it persistent + queryable.

## Acceptance criteria

- [ ] Model-tier routing guidance lands in the orchestration rules (`CLAUDE.md` nanoprobe-orchestrator
      section) so sessions default to the cheapest-correct tier and reserve Opus.
- [ ] Lean-context discipline documented as a brief checklist (scope tight, read ranges, decompose, no
      re-derivation).
- [ ] cairn-warm brief pattern documented and wired into the orchestrator dispatch flow (after the cairn
      backfill lands).
- [ ] Measurement convention: capture per-wave `subagent_tokens` + the proxy cost in checkpoints to track
      reductions over time.
- [ ] (Stretch) a borg helper / workflow snippet that selects model tier by task class.

## Out of scope (separate follow-ups)

- Automatic tier-selection tooling (file only if the documented guidance proves insufficient).
- The cairn backfill itself (tracked in the cairn repo).

## Open decisions (defaults chosen above; flag to override)

1. Implementation default tier — **Sonnet** (chosen) vs Opus-always for maximum quality.
2. Adversarial verify — **Sonnet panel, Opus on high-stakes** (chosen) vs single Opus.
3. Haiku for mechanical tasks — **yes, only truly mechanical** (chosen) vs Sonnet-floor everywhere.
