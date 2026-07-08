# Fable 5 Zero-Hour Execution Plan — Tracker

Generated: 2026-07-07 · Source brief: `~/Downloads/Fable 5 Zero-Hour Execution Plan_ Borg_Cairn Ecosystem.md`

## Framing

Fable 5 is leaving the subscription tier for pay-per-use. Before then, point its reasoning at durable
artifacts — audits, blueprints, distilled skills — so Opus 4.8 / Sonnet can safely run the
borg-collective / claude-plugins / cairn triad afterward. The brief lists four workstreams. Under today's
real constraints (a session-limit window resetting 12pm Denver; finite credits), the operating pattern is:

> **Cheap models READ, Fable REASONS + WRITES.** Post-noon, dispatch Haiku/Sonnet workflow agents to gather
> and distill evidence from the repos; Fable (main loop) authors the final judgment and the durable `.md`
> artifacts. This applies the expensive tier to exactly what it is uniquely good at and nothing else — which
> is the whole point of the zero-hour brief AND the cost audit.

## Workstream status

| # | Workstream | Fable's role | Reading via | Status |
|---|------------|--------------|-------------|--------|
| 3 | **Token cost / routing optimization** | Author the audit + fix the rules | (small configs, main loop) | **DONE** — `00-cost-and-routing-audit.md`; ROUTING.md patched; settings.json flipped to Opus 4.8; CLAUDE.md rule drafted (`01-…`, not yet applied). |
| 4 | **"Fable Mode" operating skill** | Author `fable-reviewer` skill (5-gate discipline) | Haiku inventoried the test suites | **DONE** — `skills/fable-reviewer/SKILL.md` (canonical + mirrored to claude-plugins so it loads). |
| 2 | **Agentic orchestration blueprint** | Finalize immutable architecture from agent-teams research | Sonnet distilled the research + agents/*.md | **DONE** — `docs/orchestration-architecture.md` (frozen spec, 10 decisions + open questions). |
| 1 | **Cross-repo security audits** | Judge findings, specify fixes | Sonnet hostile review of cairn + bash-guard | **DONE (audit)** — `03-security-audit-triaged.md`. Patch *application* queued as nanoprobe jobs (gated by new bats/pytest tests). |

**Open follow-ups (queued, not done today):** (a) apply the bash-guard normalization fix — Tier A/B/C bypasses,
incl. the **critical `.borg-project` unconditional-pre-approval** (A1) — via a nanoprobe with new bats regression
tests; (b) cairn K1 bind-`127.0.0.1` default; (c) apply the CLAUDE.md workflow-routing rule; (d) reconcile the
two divergent nanoprobe definitions (open question in orchestration-architecture.md).

Sequencing rationale: 3 first (urgent + de-risks the rest). Then 4 (pure reasoning, highest durable value,
smallest reading surface). Then 2 (blueprint from existing research). Then 1 (security — highest value but
largest reading surface, so it rides the cheap-reader pattern hardest). Security-first is a defensible reorder
if Noah prefers; flagged as a question.

## Per-workstream execution notes

### WS4 — `fable-reviewer` skill (5-gate discipline)
- Deliverable: an installable skill `.md` that forces any model (esp. Opus 4.8) to adopt the working
  discipline: (1) scope before working, (2) require evidence — open the real files — before reasoning,
  (3) adversarially attack its own plan, (4) verify against the existing `.bats`/`pytest` suites,
  (5) calibrate the response to the task size.
- Reading (cheap): one Haiku agent inventories `cairn/tests/` and `borg-collective/tests/` — names the test
  runners, the bats/pytest entry points, and how a subagent would invoke them. Returns a short brief only.
- Authoring (Fable): write the skill grounded in that brief + this session's own discipline (the blind-verify
  gate loop is a worked example of gates 3–4).

### WS2 — orchestration blueprint
- Reading (cheap): one Sonnet agent reads `borg-collective/docs/research/2026-05-23-agent-teams/` (esp.
  `analysis.md`, `substrate-risk-anthropic-agent-teams.md`) + the current `agents/*.md`, returns a structured
  digest of the Conductor→Grunt/Scout handoff model and open questions.
- Authoring (Fable): finalize an immutable `architecture.md` (and any ROUTING deltas) that lighter models can
  reference without re-deriving the multi-agent philosophy. ROUTING.md is already the routing half; this adds
  the state-machine/handoff half.

### WS1 — security audits (cheap-reader pattern hardest)
- 1a cairn: one Sonnet reviewer does a hostile adversarial review of `cairn/src/cairn/mcp.py`, `api.py`, and the
  alembic schema for MCP-injection, unauthorized knowledge-graph mutation, and Postgres inefficiency. Returns
  ranked findings with file:line evidence — NO patches.
- 1b borg: one Sonnet reviewer designs edge-case bypasses of `borg-collective/hooks/bash-guard.sh` + core
  `borg.zsh`; returns concrete bypass cases + evidence.
- Authoring (Fable): judge the findings (kill false positives), then write patches for the real ones — patches
  land via nanoprobe/grunt, not inline in the main loop.

## Done criteria for today

Realistic under credits: WS3 complete (done) + WS4 skill authored. WS2 and WS1 set up as cheap-reader workflows
and carried as far as the limit budget allows; whatever doesn't finish is a clean queued handoff (this tracker
+ the per-workstream reading briefs) that Opus can pick up. Not trying to force all four to Fable-depth today —
that is the scope-explosion the cost audit warns against.
