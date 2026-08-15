# Directive: Decommission cairn, ship the unconditional block

*Filed: 2026-08-08 · Status: PARTIAL — Phase 0 and Phase 2 (cairn decommission) shipped 2026-08-08 via
`~/dev/cairn/PROJECT_PLAN.md`, which superseded this directive's phasing with a single-sitting shutdown.
Phase 1 is PARTIALLY done: 1.1 and 1.3 shipped as part of the decommission's own hook cleanup; 1.2
(checkpoint truncation), 1.4 (junk purge), and 1.5 (enable 4 platform plugins) are still OPEN.
**Re-verified 2026-08-12:** 1.6's code (`bin/borg-memory-gate`,
`launchd/com.stillpoint-labs.borg.memory-gate.plist`) is committed to the repo, but the plist was never
copied to `~/Library/LaunchAgents/` and `launchctl list` shows no such job loaded — `~/.local/state/borg/`
has no `memory-gate.log` and no `memory-gate-state.json` exists. The 7-day unattended-proof clock has not
started; "shipped 2026-08-10" describes code landing in the repo, not deployment. Needs a `borg setup`
rerun to install the launchd job before Phase 1.6's proof obligation can even begin accumulating. Phase 3
correctly remains GATED — do not schedule it. This directive stays open; not ready to close.*
**Reconciled 2026-08-14:** PR #122 (ea2f5a0) and PR #123 (411333b) landed after the last edit above and
closed 1.2, 1.3's remaining bullet, and both true 1.4 bullets. 1.4's "16 drifted skill copies" bullet is
struck as a false premise (zero content drift found). 1.5's four plugins are enabled. 1.6 and Phase 3
remain OPEN/GATED — see the reconciled note under 1.6 for the current state of the gate's proof obligation
and three unresolved judgment calls. This directive is still not ready to close.*
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

- [x] `cairn backup --reason final-export` and a raw `pg_dump` of the `cairn` database, stored outside the
      cairn repo and outside Docker volumes. *(fresh `pg_dump` taken immediately before the drop; the 14
      pre-existing nightly encrypted backups + age identity preserved — see `docs/BACKUP_RESTORE.md` in cairn)*
- [x] Export all 4,232 atoms (decisions / patterns / observations / documents) to **per-repo markdown** under
      each project's `.borg/knowledge/`, so the content stays git-tracked and grep-reachable after teardown.
- [x] Verify: `rg` over the export returns the founding canonical query's record
      (`cairn-sqlalchemy-cast-named-param-conflict-2026-04-28`). If grep cannot find it, the export is wrong.
      *(re-verified against the real post-merge local filesystem, not just the DB or remote)*
- [x] Record the final `cairn eval-redundancy --json` output into the export directory as the closing measurement.
      *(ported as `scripts/eval_redundancy.py`, runs standalone against the export; last run: 19.3%
      same-project / 0.3% cross-project, NARROW verdict — consistent with the original audit)*

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

- [x] Either restore `_borg_cairn_health_line` into `~/.claude/lib/borg-hooks.sh`, or remove both call sites
      (they become moot after Phase 2 anyway). *(removed — the function and both call sites no longer exist
      after the decommission, so this failure mode is structurally eliminated, not just tested for)*
- [x] Add a smoke test that pipes a minimal SessionStart payload into the **repo** hook and asserts exit 0.
      The bats suite currently supplies its own lib and therefore cannot catch this. *(`tests/lifecycle.bats`
      invokes `hooks/borg-link-down.sh`/`borg-link-up.sh` directly by path with a minimal JSON payload; full
      suite green post-unwiring)*

### 1.2 — Fix checkpoint truncation (~0.5h)

**Verified:** `head -c 4000` at **line 321** truncates checkpoints mid-content, amputating the "Next Session"
section on **169 of 350** checkpoints. This is the single highest-value content in a checkpoint and it is
being cut off.

- [x] Replace the byte cap with awk section extraction — take sections **4 (Blockers)** and **5 (Next
      Session)** verbatim rather than the first 4,000 bytes. *(shipped: `hooks/borg-link-down.sh:355-357` does
      awk section extraction, with a legacy byte-cap fallback at :360-362 for pre-template checkpoints.
      Commit 9551115, merged in ea2f5a0 (PR #122). The old unconditional `head -c 4000` is gone from the live
      path.)*

### 1.3 — Remove the cairn injection (~0.5h)

**Verified:** the injection is **zero-byte on 166 of 332** real-project fires, and `borg-link-down.sh:354`
passes `$PROJECT` as **both** the query string and the `--project` filter — so when it does return something,
relevance to the session's actual task is coincidental.

- [x] Delete the cairn search/injection block and its `CAIRN UNAVAILABLE` banner.
- [x] Replace with ~30 tokens of pointer in each project `CLAUDE.md`: *"prior decisions live in
      `.borg/checkpoints/`, `.borg/knowledge/` and `docs/plans/assimilated/` — grep them."* *(shipped in
      ea2f5a0 (PR #122): CLAUDE.md's "Architecture Rules" now reads "Prior decisions live in
      `.borg/checkpoints/`, `.borg/knowledge/`, and `docs/plans/assimilated/` — grep them before assuming
      something is undocumented.")*
- [x] Keep `cairn-hits.log` writing until Phase 2 completes, as the before/after control. *(moot — Phase 2 is
      complete and cairn-hits.log's job is done; it stopped writing when the containers/hooks were removed)*

### 1.4 — Purge accumulated junk (~0.5h)

- [x] `~/.claude/projects/-` holds **11,576 transcript files / 44 MB** from the old launchd `cwd="/"` poller.
      Delete. Confirm the poller itself is dead first — it has now polluted `call_log`, `token_spend` **and**
      `presence`. *(shipped in 411333b (PR #123): `bin/borg-usage-watch:288-300` `_prune_probe_transcripts`
      deletes probe transcripts older than `PROBE_RETAIN_MIN` (default 60, line 80) every poll. Correction to
      this bullet's own premise: the poller is `bin/borg-usage-watch` itself, and it is alive by design —
      `StartInterval` 120s — not dead. The fix bounded its transcript pile structurally instead of killing the
      poller.)*
- [~] STRUCK — **16 drifted skill copies** in `~/.claude/skills`, 2 already divergent. Collapse to one copy
      each. *(the premise is false: a recursive diff of `~/.claude/skills` against `skills/` in this repo
      shows ZERO content drift — the only deltas are a deliberate per-skill `.borg-managed` marker file and
      `ducky`, which exists only in the deployed tree. Collapsing is also actively forbidden: Cortex Code has
      no plugin loader and registers skills straight from source directories, so the two-copy layout is
      structurally required, not accidental drift. This is a correction of a false premise, not a deferral —
      do not re-open it as a TODO.)*
- [x] Stale artifacts: three 0-byte `registry.json.tmp` files (created 2026-03-29, still present),
      `plan-promote-debug.log` (36 KB, stopped writing 2026-07-31). *(re-verified live: no `*.tmp` and no
      `plan-promote-debug.log` remain under `~/.config/borg/` or `~/.claude/`.)*

### 1.5 — Enable the platform capability already on disk (~0.5h)

**Verified:** `enabledPlugins` has 8 entries; **7 are `@noah-local`** and exactly **1 of 37** official plugins
is enabled. These four have been sitting unenabled since **2026-07-08**:

| Plugin | What it already does |
|---|---|
| `hookify` | 313-line rule engine + `conversation-analyzer` subagent that finds corrections, frustrated reactions, reversions and repeated issues and converts them to rules. `action: warn` vs `action: block`. |
| `session-report` | Token/cost analysis over transcripts by project, subagent, skill, cache-break. |
| `claude-md-management` | `claude-md-improver` — audits and rewrites CLAUDE.md behind an approval gate. |
| `skill-creator` | Skill evals and benchmarking with variance analysis. |

- [x] Enable all four in `~/.claude/settings.json`. *(re-verified live: `hookify`, `session-report`,
      `claude-md-management`, and `skill-creator` are all `true` under `enabledPlugins`.)*
- [ ] **Caveat to hold honestly:** enabling is not adopting. 1-of-37 says platform capability does not become
      platform benefit automatically. Treat these as candidates to be *used*, and revisit in 30 days.

### 1.6 — Wire ONE unattended gate (~1h) ← the load-bearing step

**Verified:** ADR 0002 designates `cairn eval-redundancy` as a standing quarterly instrument. It has **no
scheduler**. `~/Library/LaunchAgents` contains `cairn-backup`, `cairn-extract`, `cairn-watch` — no review job.
That is gate #4 born unwired, on the same day as the audit that was supposed to teach this lesson.

- [x] Create one recurring job that **runs a check, evaluates it against a pre-registered threshold, and
      delivers a verdict through a channel that interrupts** (macOS notification and/or a file the SessionStart
      hook surfaces loudly). Printing to a log is not delivery — that is what the last three gates did.
      *(shipped: `bin/borg-memory-gate` — daily launchd job, `launchd/com.stillpoint-labs.borg.memory-gate.plist`,
      wired in `install.sh` with a `launchctl kickstart -k` on install. FAIL delivers via the same
      `_borg_osa_notify` helper `hooks/notify.sh` uses, plus a verdict file `hooks/borg-link-down.sh` surfaces
      as a loud `additionalContext` SessionStart block, mirroring the existing PROJECT_PLAN.md nudge pattern.)*
- [x] Its first job: the **auto-memory read instrument**. 283 files / 723,639 bytes and **no hit log exists**.
      Nobody has ever checked whether auto-memory is *read*. Pre-registered null:
      **< 0.2 reads/session ⇒ there is no working retrieval loop and it is a second write-only store** —
      exactly the hole cairn died in, sitting unexamined.
      *(shipped: `bin/borg-memory-gate` wraps the existing `bin/memory-hits-report`/`hooks/borg-memory-read-log.sh`
      instrument — no new measurement logic, just delivery.)*
- [ ] **The proof obligation:** the gate must fire once, unattended, and produce a verdict *without anyone
      remembering it exists*. Until that happens, Phase 3 is not scheduled.
      *(NOT YET PROVEN — the job creation above is wired and self-kickstarts once on install, but the actual
      proof requires real elapsed time: the daily `StartInterval` firing on its own, unprompted, days after
      this session ends. Re-check in 7+ days: confirm `~/.local/state/borg/memory-gate.log` has entries with
      no session/human triggering them, and that `$BORG_DIR/memory-gate-state.json` shows a `last_delivered_at`
      that nobody manually invoked. Only then does this item flip to `[x]` and Phase 3 unblock.)*
      **Reconciled 2026-08-14 — this stays OPEN.** `~/.local/state/borg/memory-gate.log` currently holds two
      distinct fires: `2026-08-12T23:47:46Z` (attended — delivered the first FAIL notification, transitioning
      from `last_verdict=none`) and `2026-08-13T23:52:07Z` (unattended by the daily `StartInterval`, but
      SUPPRESSED by the idempotency guard — "FAIL already delivered previously — not re-notifying"). Neither
      is the proof this criterion needs: the first was attended, the second was unattended but did not
      *deliver* anything new. Three open judgment calls for the owner, not resolved by this reconciliation:
      (a) whether a verdict that persists in `~/.config/borg/memory-gate-verdict.json` and is surfaced at
      `hooks/borg-link-down.sh:233-241` on every SessionStart counts as "delivery" on its own, independent of
      the notification channel; (b) how to rule on the standing FAIL (ratio 0.048 vs. the pre-registered 0.2
      threshold), including the honest counter-argument that the denominator (6 hits total) is too tiny to
      trust the ratio either way; (c) the re-nag policy — today a persisting FAIL notifies exactly once ever,
      so if the answer to (a) is "no," this gate may never fire the way 1.6 originally imagined without a
      policy change.

---

## Phase 2 — Cairn decommission (~4h, requires Phase 0 verified)

Unwire in this order. Each step is independently revertible; do not batch them.

- [x] **Hooks (4):** `borg-link-down.sh`, `borg-link-up.sh`, `borg-cairn-heartbeat.sh`, `bin/borg-usage-watch`.
- [x] **Skills (5):** `borg-search`, `borg-link`, `borg-link-up`, `borg-recon`, `fable-reviewer` — remove cairn
      calls, repoint at `.borg/knowledge/` + `.borg/checkpoints/` via grep.
- [x] **Host shim:** the 355-line `~/.config/dotfiles/zsh/bin/cairn`, plus the repo copy at `~/dev/cairn/cli/cairn`.
      *(dotfiles shim + `zsh/bin/cairn-extract` deleted; the cairn-repo CLI is moot — repo archived)*
- [x] **Rebuild the plugin** (`scripts/build-plugin.sh`) — note the dry-run currently shows **5 hooks** would
      change, i.e. there is pre-existing unrelated drift to review before shipping. *(rebuilt; reviewed
      separately from the unwire diff per the plan's own scope boundary)*
- [x] **Containers:** stop `cairn-api`, `cairn-api-dev` (a duplicate — ~384 MiB of pure waste),
      `cairn-cairn-app-1`. Reclaim ~2.6 GB of stale release tags.
- [x] **Databases:** drop `cairn` and `cairn_test` from dev-postgres — **only after** Phase 0's export is
      verified to survive volume teardown. *(dropped 2026-08-08, last and alone, after re-proving
      grep-reachability against the real post-merge local filesystem)*

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

- [x] The repo copy of `borg-link-down.sh` exits 0, proven by a test that does not supply its own lib.
- [ ] Checkpoints retain their "Next Session" section verbatim. *(1.2's truncation fix was not part of the
      cairn decommission's scope — still open)*
- [x] `grep` over `.borg/knowledge/` answers the founding canonical query after cairn is gone.
- [x] No cairn container is running; `cairn`/`cairn_test` databases dropped; export verified to survive.
- [x] Four platform plugins enabled. *(1.5 — shipped, see above.)*
- [ ] The auto-memory read instrument has produced ≥7 days of data **and a delivered verdict**. *(Reconciled
      2026-08-14. Two different clocks are in play here and must not be conflated. Hits-volume clock:
      `~/.config/borg/memory-hits.log` holds **6 rows on 3 distinct days** — 2026-08-10 (×3), 2026-08-13 (×2),
      2026-08-14 (×1) — a 5-calendar-day span with two gap days (08-11, 08-12), not "4 of 7 days." Delivery
      clock: the gate's own daily fire count, tracked separately in 1.6 above; counted from its first fire
      (2026-08-12), seven consecutive daily fires lands **2026-08-18**, not 08-17. Neither clock has completed;
      still OPEN.)*
- [ ] **One gate has fired unattended and delivered a verdict nobody had to remember.** *(not done — 1.6's
      actual proof obligation, and Phase 3 stays gated until it is; see the reconciled note under 1.6.)*

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
