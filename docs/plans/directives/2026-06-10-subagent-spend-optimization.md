# Directive: Spend optimization — orchestrator-first

**Filed:** 2026-06-10 · **Status:** proposed · **Parent:** orchestration layer

> Reframed after instrumenting real spend. The original premise ("delegation is where the money is; route
> subagents to Sonnet for ~5×") was **wrong** — see below. The dominant cost is the **orchestrator / main
> loop**, not delegation.

## What the data actually shows

A real heavy multi-agent session, measured per-model from the transcripts (now collected automatically
in `~/.claude/token-spend.jsonl`):

| Layer | Cost | Share | Notes |
|-------|------|-------|-------|
| Main loop (orchestrator) | ~$327 | **~96%** | Opus; output incl. thinking (~1.4M tok) + ~80M cache reads |
| Subagents (12) | ~$13 | ~4% | Sonnet + Haiku — the harness already tier-routes them |

Earlier figures of "$56 / $43 per wave" were an artifact of pricing Sonnet/Haiku agents at Opus rates;
the real delegated cost was small. **Model-tier routing of subagents is already done by the harness** —
it is not a lever we need to add. The cost lives in the orchestrator's own context and turns.

## Levers, by magnitude (corrected)

1. **Keep the orchestrator context lean (biggest).** Cache reads of the main context are billed every
   turn and dominate (~80M reads in one session). Pulling large tool outputs (big diffs, full files,
   long command dumps) into the main loop means paying to re-read them on every subsequent turn.
   Mitigation: delegate output-heavy reads/edits to subagents that return **distilled summaries**; the
   orchestrator holds conclusions, not raw dumps. (This session violated that — instructive.)
2. **Fewer / shorter orchestrator turns.** Cost ≈ context-size × turns. Batch related work into a turn,
   avoid round-trips, end sessions when a unit of work is done rather than letting context grow.
3. **Less unnecessary thinking.** Extended thinking bills as output ($75/M on Opus). Reserve deep
   reasoning for genuinely hard steps; don't deliberate at length on mechanical ones.
4. **cairn-warm briefs (compounding).** Pre-load distilled facts so neither orchestrator nor agents
   re-derive from the repo. Gated on the cairn backfill (tracked in cairn).
5. **Ensure heavy/parallel work IS delegated.** Because subagents run on cheap tiers off the main loop,
   pushing bulk reading/searching/editing into them (and keeping only results in the main context) is
   both faster and cheaper. The win is delegation *with lean returns*, not subagent model choice.

## Acceptance criteria

- [ ] Orchestration rules (`CLAUDE.md` nanoprobe-orchestrator section) document the lean-context
      discipline: delegate output-heavy work, return summaries not dumps, keep the main context small.
- [ ] Guidance to minimize orchestrator turns and avoid unnecessary deep thinking on light steps.
- [ ] cairn-warm brief pattern documented + wired into dispatch (after the cairn backfill lands).
- [ ] Measurement: use `~/.claude/token-spend.jsonl` (the SessionEnd collector) to track the
      main-vs-subagent split per session over time; goal is to shrink the main-loop share.

## Out of scope (separate follow-ups)

- Running the orchestrator itself on a cheaper tier (risky — it needs to be smart; keep on Opus but
  minimize its context/turns instead).
- Automatic per-task model selection for subagents (the harness already handles tiering).
- The cairn backfill itself (tracked in the cairn repo).

## Reference

- Accurate per-session spend: `~/.claude/token-spend.jsonl` (per-model raw counts + `est_cost_usd`).
- Collector + pricing + the "inline line is a lower bound" caveat: the `token-cost` plugin skill.
