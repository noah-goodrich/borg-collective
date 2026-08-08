# Directive: Decommission cairn, ship the unconditional block

*Filed: 2026-08-08 · Status: OPEN (nothing started) · Gated by: nothing for Phases 0–2; Phase 3 gated on the
unattended-gate proof in Phase 1.6*
*Source: `~/dev/cairn/docs/research/` — see `README.md` for the full arc; the operative documents are
`2026-08-04-cairn-original-goals-audit.md` and `2026-08-05-post-cairn-strategy.md`*
*Companion decision: `~/dev/cairn/docs/adr/0002-retire-belief-store.md`*

## Why this exists

A five-month strategic review measured cairn against its own founding goals and against the alternatives.
The short version:

- **The differentiating claim is falsified.** Cross-project restatement of decisions is **0.4%** —
  indistinguishable from the null baseline. Same-project restatement is **16.7%**, and every one of those
  hits lives inside a single repo's checkpoint files, which grep traverses in **55 ms**. Cairn was built to
  serve the 0.4%.
- **Retrieval was never the problem** (90%+ hit rate; the founding canonical query still returns the right
  record at 0.844 cosine). The capability works. The need does not arise.
- **The token thesis is false.** All file exploration is **2.2%** of a mean session. The entire always-loaded
  static prefix is **9.8%** of cache_read; the other **90.2% is the conversation accumulating on itself.**
  No retrieval layer, however good, can address more than ~1.5–3% of spend.
- **Voluntary agent writes fail at ~100%** across four shipped, tested, exposed surfaces. Derived capture
  (mining checkpoints) built the entire 4,232-atom corpus.

This directive does two things: it removes cairn without losing anything, and it ships the block of work that
is unconditionally worth doing regardless of what replaces it.

> ## Read this before scheduling anything with a review date
>
> Cairn ran **three** pre-registered keep-or-kill gates. All three produced **zero** kill decisions.
> Gate 2 (2026-05-26) had a cron, an owner, an email and a rubric — more machinery than anything in this
> directive — and cairn has a **29-day hole in its checkpoint record spanning the review date**; the next
> checkpoint announces eleven new MCP tools and a release. The deciding test finally ran **71 days late**,
> and only because a human forced it in an unrelated session.
>
> And the instrument was never missing: `~/.config/borg/cairn-hits.log` has **1,752 rows across 100 unbroken
> days**. The **second row ever written** (2026-05-13, 0 bytes) was already the verdict. It then reported the
> same failure 1,750 more times.
>
> **This fleet builds instruments and maintains them for months. It does not act on unambiguous verdicts.**
>
> Therefore Phase 1.6 is not optional garnish — it is the load-bearing step, and Phase 3 does not start until
> it has fired **once, unattended, with nobody remembering it**.

---

## Phase 0 — Zero-loss export (BLOCKING, ~1h)

Nothing in Phase 2 may start until this is done and verified. The corpus is 50 MB; there is no excuse for
losing it.

- [ ] `cairn backup --reason final-export` and a raw `pg_dump` of the `cairn` database, stored outside the
      cairn repo and outside Docker volumes.
- [ ] Export all 4,232 atoms (decisions / patterns / observations / documents) to **per-repo markdown** under
      each project's `.borg/knowledge/`, so the content stays git-tracked and grep-reachable after teardown.
- [ ] Verify: `rg` over the export returns the founding canonical query's record
      (`cairn-sqlalchemy-cast-named-param-conflict-2026-04-28`). If grep cannot find it, the export is wrong.
- [ ] Record the final `cairn eval-redundancy --json` output into the export directory as the closing measurement.

**Acceptance:** the export survives `docker compose down -v` on cairn. Test that assumption explicitly before
believing it.

---

## Phase 1 — The unconditional block (~4h)

Every item here is a deletion, a repair, a settings flag, or an instrument. **None has an adoption step, so
none can rot the way cairn rotted.** These are worth doing whether or not cairn is removed.

### 1.1 — Fix `borg-link-down.sh`: it currently exits 127 (~0.5h)

**Verified 2026-08-05:** the repo copy calls `_borg_cairn_health_line` at **lines 96 and 195**, and that
function is **absent from the deployed `~/.claude/lib/borg-hooks.sh`**. Running the repo hook directly exits
**127**. It works in sessions only because `scripts/build-plugin.sh` inlines the helpers into the plugin copy.

- [ ] Either restore `_borg_cairn_health_line` into `~/.claude/lib/borg-hooks.sh`, or remove both call sites
      (they become moot after Phase 2 anyway).
- [ ] Add a smoke test that pipes a minimal SessionStart payload into the **repo** hook and asserts exit 0.
      The bats suite currently supplies its own lib and therefore cannot catch this.

### 1.2 — Fix checkpoint truncation (~0.5h)

**Verified:** `head -c 4000` at **line 321** truncates checkpoints mid-content, amputating the "Next Session"
section on **169 of 350** checkpoints. This is the single highest-value content in a checkpoint and it is
being cut off.

- [ ] Replace the byte cap with awk section extraction — take sections **4 (Blockers)** and **5 (Next
      Session)** verbatim rather than the first 4,000 bytes.

### 1.3 — Remove the cairn injection (~0.5h)

**Verified:** the injection is **zero-byte on 166 of 332** real-project fires, and `borg-link-down.sh:354`
passes `$PROJECT` as **both** the query string and the `--project` filter — so when it does return something,
relevance to the session's actual task is coincidental.

- [ ] Delete the cairn search/injection block and its `CAIRN UNAVAILABLE` banner.
- [ ] Replace with ~30 tokens of pointer in each project `CLAUDE.md`: *"prior decisions live in
      `.borg/checkpoints/`, `.borg/knowledge/` and `docs/plans/assimilated/` — grep them."*
- [ ] Keep `cairn-hits.log` writing until Phase 2 completes, as the before/after control.

### 1.4 — Purge accumulated junk (~0.5h)

- [ ] `~/.claude/projects/-` holds **11,576 transcript files / 44 MB** from the old launchd `cwd="/"` poller.
      Delete. Confirm the poller itself is dead first — it has now polluted `call_log`, `token_spend` **and**
      `presence`.
- [ ] **16 drifted skill copies** in `~/.claude/skills`, 2 already divergent. Collapse to one copy each.
- [ ] Stale artifacts: three 0-byte `registry.json.tmp` files (created 2026-03-29, still present),
      `plan-promote-debug.log` (36 KB, stopped writing 2026-07-31).

### 1.5 — Enable the platform capability already on disk (~0.5h)

**Verified:** `enabledPlugins` has 8 entries; **7 are `@noah-local`** and exactly **1 of 37** official plugins
is enabled. These four have been sitting unenabled since **2026-07-08**:

| Plugin | What it already does |
|---|---|
| `hookify` | 313-line rule engine + `conversation-analyzer` subagent that finds corrections, frustrated reactions, reversions and repeated issues and converts them to rules. `action: warn` vs `action: block`. |
| `session-report` | Token/cost analysis over transcripts by project, subagent, skill, cache-break. |
| `claude-md-management` | `claude-md-improver` — audits and rewrites CLAUDE.md behind an approval gate. |
| `skill-creator` | Skill evals and benchmarking with variance analysis. |

- [ ] Enable all four in `~/.claude/settings.json`.
- [ ] **Caveat to hold honestly:** enabling is not adopting. 1-of-37 says platform capability does not become
      platform benefit automatically. Treat these as candidates to be *used*, and revisit in 30 days.

### 1.6 — Wire ONE unattended gate (~1h) ← the load-bearing step

**Verified:** ADR 0002 designates `cairn eval-redundancy` as a standing quarterly instrument. It has **no
scheduler**. `~/Library/LaunchAgents` contains `cairn-backup`, `cairn-extract`, `cairn-watch` — no review job.
That is gate #4 born unwired, on the same day as the audit that was supposed to teach this lesson.

- [ ] Create one recurring job that **runs a check, evaluates it against a pre-registered threshold, and
      delivers a verdict through a channel that interrupts** (macOS notification and/or a file the SessionStart
      hook surfaces loudly). Printing to a log is not delivery — that is what the last three gates did.
- [ ] Its first job: the **auto-memory read instrument**. 283 files / 723,639 bytes and **no hit log exists**.
      Nobody has ever checked whether auto-memory is *read*. Pre-registered null:
      **< 0.2 reads/session ⇒ there is no working retrieval loop and it is a second write-only store** —
      exactly the hole cairn died in, sitting unexamined.
- [ ] **The proof obligation:** the gate must fire once, unattended, and produce a verdict *without anyone
      remembering it exists*. Until that happens, Phase 3 is not scheduled.

---

## Phase 2 — Cairn decommission (~4h, requires Phase 0 verified)

Unwire in this order. Each step is independently revertible; do not batch them.

- [ ] **Hooks (4):** `borg-link-down.sh`, `borg-link-up.sh`, `borg-cairn-heartbeat.sh`, `bin/borg-usage-watch`.
- [ ] **Skills (5):** `borg-search`, `borg-link`, `borg-link-up`, `borg-recon`, `fable-reviewer` — remove cairn
      calls, repoint at `.borg/knowledge/` + `.borg/checkpoints/` via grep.
- [ ] **Host shim:** the 355-line `~/.config/dotfiles/zsh/bin/cairn`, plus the repo copy at `~/dev/cairn/cli/cairn`.
- [ ] **Rebuild the plugin** (`scripts/build-plugin.sh`) — note the dry-run currently shows **5 hooks** would
      change, i.e. there is pre-existing unrelated drift to review before shipping.
- [ ] **Containers:** stop `cairn-api`, `cairn-api-dev` (a duplicate — ~384 MiB of pure waste),
      `cairn-cairn-app-1`. Reclaim ~2.6 GB of stale release tags.
- [ ] **Databases:** drop `cairn` and `cairn_test` from dev-postgres — **only after** Phase 0's export is
      verified to survive volume teardown.

### Dispositions that must be decided, not defaulted

| Thing | Current reality | Recommendation |
|---|---|---|
| Checkpoint document mirror | 163 calls, 147 docs in July — genuinely automatic and healthy | **Safe to drop.** It mirrored `.borg/checkpoints/`, which is the primary and stays. |
| Session registration (`record_session`) | 1,186 calls, hook-driven | **Drop.** It fed `sessions`, used only by cairn's own stats. |
| `presence` (multi-drone coordination) | **92% pollution** (1,218 of 1,318 rows are project `/`); 89 real rows in 5 weeks; only 68 rows ever closed; zero `call_log` instrumentation | **Drop.** If multi-drone collision is a real need, reimplement as a file lock under `~/.local/state/borg/` — it does not need Postgres. |
| `cairn eval-redundancy` | The one instrument worth keeping | **Port the query** into the export directory as a standalone script so it can be re-run against the markdown export. |

---

## Phase 3 — GATED (do not schedule until 1.6 has fired unattended)

- [ ] **Lifecycle layer on `hookify` (~2h).** A grep of hookify's `core/` and `hooks/` for
      `precision|promote|retire|shadow|override|logg|stats|count` returns **one unrelated hit**. It has no
      outcome logging, no precision tracking, no auto-retirement, and its analyzer reads only the *current*
      conversation. Add: **shadow → promote at ≥10 matches / ≥90% precision → auto-retire on 0 fires in 60
      days or <70% precision.**
      This is the whole thesis: *a guard that gets overridden three times is provably wrong and demotes
      itself; a prose atom can never be contradicted by usage.* A `PreToolUse` deny also cannot be declined by
      the agent, which satisfies ADR 0002's derived-capture rule structurally rather than hopefully.
- [ ] **Session length (~2h).** Carries the largest projected number (~$8,751, ~35% of spend — **modelled, not
      measured**). It **must be a hard mechanism**, not a nudge: `~/.claude/CLAUDE.md` has said *"Prefer
      built-in tools (Grep, Glob, Read) over Bash equivalents"* for months, and measured behavior is
      **Grep+Glob 10 tokens/session against Bash 64.6 calls/session**. Standing instruction runs at ~0%
      compliance in this fleet. Use a hook that blocks or auto-compacts past N turns, or do not do it.

---

## Acceptance criteria

- [ ] The repo copy of `borg-link-down.sh` exits 0, proven by a test that does not supply its own lib.
- [ ] Checkpoints retain their "Next Session" section verbatim.
- [ ] `grep` over `.borg/knowledge/` answers the founding canonical query after cairn is gone.
- [ ] No cairn container is running; `cairn`/`cairn_test` databases dropped; export verified to survive.
- [ ] Four platform plugins enabled.
- [ ] The auto-memory read instrument has produced ≥7 days of data **and a delivered verdict**.
- [ ] **One gate has fired unattended and delivered a verdict nobody had to remember.**

## Non-goals

- Do **not** adopt Graphify, build an AST/code graph, or build a replacement retrieval service. See
  `2026-08-04-graphify-vs-cairn-build-vs-buy.md` and `2026-08-05-kg-steelman.md`.
- Do **not** promise a token saving from anything knowledge-related. Verified ceiling across all
  retrieval/prefix work is **$370–750 of $24,712 (1.5–3%)**.
- Do **not** build a fifth prose store. Standing preference order for any future learning artifact:
  **guard rule > test/lint rule > path-scoped rule > DROP.**

## Risks

- **Phase 2 is irreversible in practice** once volumes are dropped. Phase 0 exists precisely for this; do not
  compress it.
- **This becomes project #5** on a fleet already flagged over capacity at 4 concurrent projects. Phases 0–1
  are ~5h of deletions and flags and should be done in one sitting; Phase 2 can wait indefinitely without cost.
- **The sunk-cost ratchet.** Every cairn plan shipped green acceptance criteria that became the next plan's
  unexamined premise. If Phase 3 starts before 1.6 proves out, this directive has reproduced the arc it was
  written to break.
- **Enabling ≠ adopting.** Phase 1.5 could fail exactly the way cairn's write surfaces failed: installed,
  exposed, unused.

## Open questions

- Does `~/.claude/lib/borg-hooks.sh` need restoring, or is it obsolete now that the plugin build inlines
  helpers? Answering this determines whether 1.1 is a restore or a delete.
- `~/dev/cairn/cli/cairn` (v0.2.0) has **no `presence` subcommand** while its header instructs putting it on
  PATH — which would break `borg-link-down.sh:385-400`. Moot after Phase 2, live until then.
