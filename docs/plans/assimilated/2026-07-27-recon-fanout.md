# Plan: Source-Agnostic Recon Fan-Out Primitive (borg-collective, 2026-07-27)

**Owner:** borg-collective (Noah's personal machine) · **Status:** MVP built, up for review on
`feat/recon-fanout`.

## Objective

Build the reusable engine behind a "morning link-up": sweep activity across many sources since a
mark, reconcile against what each project already knows locally, and synthesize a prioritized,
by-project briefing that splits work into "only a human can do this" vs "an agent can take this."

The engine must be **source-agnostic**. Employer-specific sources (Slack/Jira/Notion) are NOT
built here — they are injected on a work machine via a pluggable adapter interface. The primitive
works for any project on any machine, work or personal. This repo ships exactly one reference adapter
(GitHub via `gh`) as proof-of-interface.

## Recon Contract v0 (the interface we built to)

1. **Inputs:** `since` (ISO ts; default = newest `.borg` checkpoint mtime, else last-run marker,
   else 24h ago), `projects` (from `~/.config/borg/registry.json`), `sources` (subset of adapters).
2. **Fan-out:** one independent recon track per source, concurrent + bounded. Each adapter returns a
   terse summary AND a normalized JSON array of Items. No raw dumps.
3. **Item** = `{project, source, ref, title, state, changed, owner, action_needed, urgency,
   one_line}`. `owner ∈ {you, agent, unknown}`; `urgency ∈ {now, this_week, fyi}`;
   `action_needed` is boolean; `changed` describes what moved since `since`.
4. **Reconcile:** merge Items by project; detect + collapse contradictions between a project's local
   `.borg` checkpoint blockers and live source state (e.g. "checkpoint says X blocked" vs "source
   says X merged").
5. **Synthesize:** group by project, sort projects by highest urgency then recency; within a project
   list Items; then emit TWO action lists — "Yours (human calls)" vs "Mine (agent-delegable)"; then
   a recommended parallel kickoff batch of read-only prep tracks (bounded).
6. **Persist:** write each reconciliation/decision to cairn via its `record` CLI. cairn is WIP — a
   thin, optional, fail-quiet hook. Never a hard dependency.
7. **Output style:** by-project, most-urgent-first, plain-language (ELI10), terse, markdown wrapped
   at 120 chars.

## The adapter interface (how sources are injected, never hardcoded)

An adapter is any **executable named `recon-adapter-<source>`** found on the adapter search path
`BORG_RECON_ADAPTER_PATH` (default `~/.config/borg/recon/adapters : <repo>/lib/recon/adapters`).
Dropping an executable on the path registers a source; there is no code change and no central list.
The config dir precedes the repo dir, so a machine-local adapter shadows a repo one of the same name.
This is how an employer layer gets injected on the work machine without touching this repo.

Invocation and I/O contract:

```
recon-adapter-<source> --since <ISO8601> --projects <projects.json path>
# projects.json is the registry's `.projects` object: { "<name>": {"path": "...", ...} }
# stdout: exactly one JSON object → {"source": "...", "summary": "<terse>", "items": [Item, ...]}
# exit 0 = success (even for an empty sweep). Non-zero / malformed = engine records a failed track
#          and continues. NEVER emit raw dumps — only the structured object.
```

The engine is the last line of defense: it validates every track object and every Item, drops
malformed Items (counting them in `dropped`), and synthesizes a failed-track record for any adapter
that errors, times out, or emits garbage — so one bad source can never wedge the sweep.

## Architecture (native to borg: bash engine + zsh CLI + skill)

- **`lib/recon.sh`** — portable-sh engine (sourceable by both bash tests and the zsh CLI, same split
  as `reaper.sh` ↔ `registry.zsh`). Functions: `_recon_resolve_since`, `_recon_discover_adapters`,
  `_recon_validate_track` / `_recon_validate_item`, `_recon_run_adapter`, `_recon_fanout` (concurrent,
  bounded by `BORG_RECON_MAX_TRACKS`), `_recon_merge_by_project`, `_recon_checkpoint_blockers`,
  `_recon_project_contradictions`, `_recon_assemble`, `_recon_cairn_record` (fail-quiet).
- **`lib/recon.zsh`** — one-line shim so `borg.zsh`'s `lib/*.zsh` source glob loads the engine.
- **`borg recon`** (`cmd_recon` in `borg.zsh`) — the driver: resolve inputs, build the projects file,
  fan out, reconcile, assemble. `--json` emits the reconciled doc (what the skill consumes); no flag
  prints a terse most-urgent-first digest. `--adapters` lists discovered sources.
- **`lib/recon/adapters/recon-adapter-github`** — the ONE reference adapter (`gh`), proof-of-interface.
- **`skills/borg-recon/SKILL.md`** — the judgment/synthesis layer (`/borg-recon`): deeper reconcile,
  the by-project ELI10 briefing, Yours-vs-Mine action lists, the bounded kickoff batch, cairn decisions.

Division of labor matches borg's "skills do the thinking" pattern: the engine gathers + normalizes +
validates + detects mechanical contradictions; the skill adds judgment, prioritization, and voice.

## The cairn hook

`_recon_cairn_record <decision|observation> <project> <text>`: no-op + return 0 when `cairn` is
absent or `BORG_RECON_NO_CAIRN` is set; otherwise `cairn record ... --notes ...` under a 5s timeout,
swallowing every failure. `cmd_recon` records the sweep as an observation; the skill records each
reconciliation judgment as a decision. Nothing in the primitive hard-depends on cairn.

## Acceptance criteria

- [x] `borg recon --adapters` lists discovered adapters and explains how to add one.
- [x] `borg recon --json` emits `{since, generated_at, sources, items_by_project, contradictions}`.
- [x] `since` resolves: explicit `--since` > newest checkpoint mtime > last-run marker > 24h fallback.
- [x] Fan-out is concurrent and bounded; a broken/garbage/slow adapter yields `ok:false` and never
      aborts the sweep; malformed Items are dropped and counted.
- [x] Items are merged by project; a checkpoint-blocker-vs-resolved-source contradiction is detected.
- [x] The plain digest is by-project, most-urgent-first; the `/borg-recon` skill produces the full
      briefing + Yours-vs-Mine lists + bounded read-only kickoff batch, ELI10, 120-wrapped.
- [x] The GitHub reference adapter sweeps real repos into valid Items and degrades gracefully when
      `gh` is missing/unauthenticated or a project has no GitHub remote.
- [x] The cairn hook is fail-quiet (no-op, returns 0) when cairn is absent.
- [x] `tests/recon.bats` covers since-resolution, discovery/dedup, validation, fan-out isolation,
      item-dropping, merge, blocker extraction, contradiction detection, and the cairn no-op.
- [ ] employer source adapters (Slack/Jira/Notion) — explicitly OUT of scope here; a separate layer.

## Key design decisions / trade-offs

1. **Adapters = executables on a search path, not a plugin registry.** Zero coupling: a machine adds
   a source by dropping a file; the repo never learns about employer sources. Trade-off: the contract is
   a stdout JSON shape, not a typed API — the engine defends by validating and dropping bad data.
2. **Engine (mechanical) vs skill (judgment) split.** The bash engine is deterministic and testable;
   the LLM skill owns prioritization, voice, and the action-list calls. Trade-off: two artifacts to
   keep in lockstep, but it mirrors the existing `borg-link` CLI-plus-skill pattern.
3. **Reconcile is a cheap mechanical heuristic + skill refinement.** The engine flags only the
   obvious "resolved-but-still-listed-as-blocker" case via substring match; the skill does the
   nuanced comparison. Trade-off: some contradictions are caught only by the skill, but the engine
   stays fast, portable, and regex-escaping-free (which also dodged a real bash-3.2 parser hazard).

## Notes for the reviewer (personal machine)

- This is for Noah's **personal** borg-collective. `gh` is the only external dep the reference adapter
  needs; `timeout` is optional (the engine falls back to running bare when absent — true on this Mac).
- zsh footguns handled during the build: never name a loop var `path` (it is tied to `$PATH`); avoid
  bare globs in engine code (unmatched globs are fatal in zsh — the engine uses quoted `find`); and
  jq's `//` treats `false` as empty, so `ok:false` needs `if has("ok")` not `.ok // true`.
