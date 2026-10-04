# Project Plan: State Hygiene and the Reader Census
*Established: 2026-09-28*
*Next: 2026-08-11-viz-3-cross-repo-chains*

- Plan-slug: `2026-09-28-state-hygiene-reader-census`

## Objective

Make every borg state store have a mandatory code-path reader and a collision-proof key, and
collapse the two machine-local roots into one with retention — so that the failure the cairn
decommission and the currently-failing auto-memory gate both measured (a store nothing reads) cannot
recur unnoticed. No new storage engine.

## Acceptance Criteria

- [x] **AC1 — The checkpoint name comes from CODE, not from prose.** A helper returns a
  collision-proof checkpoint filename (second resolution plus a short session-id suffix);
  `skills/borg-link-up/SKILL.md` calls it instead of composing `date +%Y-%m-%d-%H%M` itself, and
  no skill composes a checkpoint timestamp anywhere. Two concurrent writers in two worktrees of one
  clone cannot produce the same name — the collision is unrepresentable, not discouraged.
  - Verify: `grep -rn 'date +%Y-%m-%d-%H%M' skills/` returns nothing; a new test asserts N
    invocations yield N distinct names, and a second asserts two different `.borg/checkpoints`
    directories under one repo cannot collide. Mutation: remove the suffix and the test goes red.
  - Evidence, 2026-10-03: shipped in #235. The grep returns nothing; `python3 -m pytest borg_core/checkpoint
    borg_core/census` passes (43); `bats tests/prose_contracts.bats` passes. Mutation re-run: making
    `short_suffix` return `""` turns 5 tests red, including
    `test_two_sessions_in_the_same_second_get_different_stems` (two sessions, not N invocations).

- [x] **AC2 — A reader census contract test exists and DISCRIMINATES.** It fails when a
  `.borg/<name>` is written by any code path, or named in `CLAUDE.md`, but read by none. It names
  three states explicitly, because two is what makes it either toothless or self-contradictory:
  written-by-code-no-reader → FAIL; named-in-docs-no-reader → FAIL;
  on-disk-only-no-writer-no-reader → PASS (inert historical data, which is what `.borg/knowledge/`
  becomes under AC3). Shipped with a known-bad fixture proving it fires, per
  `tests/prose_contracts.bats`' own rule that every case is paired with the direction that proves it
  discriminates.
  - Verify: the new bats case list includes both directions; deleting the known-bad fixture's reader
    turns it red. `bats tests/<new>.bats`.
  - Evidence, 2026-10-03: shipped in #236. `bats tests/state_census.bats` passes (10 cases), covering state 1
    (written, no reader: FAIL), state 2 (docs promise, no reader: FAIL), state 3 (inert on disk: PASS), and the
    stale-reader and missing-reader fixtures, so both directions discriminate.

- [ ] **AC3 — The ten write-only stores are resolved, and `knowledge/` keeps its files.**
  `CLAUDE.md` no longer names `.borg/knowledge/` as a place to grep for prior decisions; its 1106
  tracked files are UNTOUCHED. Cairn's machine-local leftovers (`cairn-hits.log`, `cairn-inbox/`,
  `cairn-heartbeat-last`, `.cairn-last-write`, `.cairn-write-failed`) are deleted. Every remaining
  `.borg/<name>` either has a reader or appears in neither code nor `CLAUDE.md`.
  - Verify: AC2's census passes on a clean tree; `git ls-files .borg/knowledge | wc -l` is still
    1106; `ls ~/.config/borg ~/.local/state/borg | grep -c cairn` is 0.
  - Evidence, 2026-10-03 (pre-merge half only; the box stays open): the census passes on a clean tree,
    `git ls-files .borg/knowledge | wc -l` is 1106, and all ten stores are resolved as inert on-disk data
    (table in `docs/state-census.md`). `borg tidy --cairn-leftovers [--dry-run]` backs up then deletes the
    five cairn files, tested against a sandboxed HOME, XDG_CONFIG_HOME and XDG_STATE_HOME. PENDING: the
    operator runs it once on the live machine; the `grep -c cairn` clause is checked after that run.

- [ ] **AC4 — One machine-local root, with retention.** Operational state lives under one root;
  `${XDG_CONFIG_HOME}/borg` keeps only what a human edits. Logs rotate (`plan-promote-debug.log` is
  33 KB unrotated today) and the `data.json.bak.<timestamp>` manual-backup pattern is replaced by
  the retention policy. `borg doctor` reports the single root.
  - Verify: `borg doctor`; `ls ~/.config/borg` contains no `.log`/`.jsonl` operational files; a test
    pins the resolver so the default cannot drift (the lesson of the reaper's hardcoded home).

- [ ] **AC5 — `.borg/state.json` is machine-local, keyed by repo, via expand → migrate → contract.**
  Both readers converge on one location — bash (`hooks/borg-link-{down,up}.sh`,
  `hooks/borg-notify.sh`, `lib/borg-hooks.sh`, `lib/registry.zsh`, `borg.zsh`) and Python
  (`borg_core/link/{cli,core,shell}.py`). The 27 live per-directory copies are migrated. During
  expand, BOTH locations are accepted; the old one is refused only after migration.
  - Verify: a test proving the legacy per-directory location is still read during expand; a second
    proving both readers resolve the same path; `find ~/dev -path '*/.borg/state.json' | wc -l`
    reaches 0 after contract.
  - Status (step d):  is BUILT and tested
    (); the live run on the operator machine is PENDING.

- [ ] **AC6 — Nothing breaks.** Full suite green. `borg link` output is byte-identical for a project
  with a single checkpoint store, and the three live repo groups
  (`snowflake-permissions`+`-olf`+`-wt-e2e`, `borg-collective`+`-shim`, `dbt`+`-csm_...`) still
  render their bylines correctly — the only user-visible surface this plan can disturb.
  - Verify: `make test && make test-bats && make lint`; `borg link --json --local <single-store>`
    diffed against a pre-change capture; `borg link --json --local snowflake-permissions-olf`
    still equals the same call for `snowflake-permissions`.

## Scope Boundaries

- NOT building: Postgres, or any daemon. Cairn's lesson is about capture and readers, not engines;
  a hook that cannot reach a daemon and therefore blocks a session is worse than any state problem.
- NOT building: SQLite. Deferred until AC1–AC5 are shown insufficient. Two independent analyses
  expect they will not be.
- NOT building: Obsidian or a second markdown vault. Its one good idea — dangle-tolerant
  `[[links]]` resolved at read time — is already in auto-memory.
- NOT moving: `.borg/checkpoints/`. The collision is a writer-key defect (AC1), and borg-collective
  and dotfiles genuinely track theirs.
- NOT moving: `.borg/{skill,agent}-extensions/` or `.borg/programs/`. `docs/extensions.md`'s
  two-layer precedence requires a per-project layer; moving it deletes the mechanism.
- If done early: ship, don't expand. The viz directives are the payoff and they are a separate plan.

## Ship Definition

Per criterion: PR opened → 5/5 CI green → `/borg-verify` PASS → merged. AC3 and AC5 additionally
require their migration to have been RUN against live state, with a backup taken first, because a
merged migration that nobody runs is inert — the finding the #233 gate surfaced.

## Timeline

Target: 2–3 sessions of ~2 hours. AC1–AC4 are one session; AC5 is its own, because it is a
two-reader migration across bash and Python with 27 live files.

## Risks

- **AC1 written as prose because prose is faster.** The single risk that would make this plan
  certify the failure it was chartered to end. The criterion is deliberately written so a prose-only
  fix cannot satisfy it.
- **AC5 is a two-reader migration** — bash and Python reading one field is the divergence AC7 exists
  to end. Expand must genuinely accept both locations, and the hooks are fail-open and run on every
  session start and stop, so a partial migration is silent.
- **AC4's default could drift like the reaper's did.** The resolver needs a test that does NOT
  pre-set the variable it is meant to derive; this repo has three recorded instances of that bug.
- **The reaper is now live for the first time** (PR #232, merged today). Unrelated to this plan, but
  newly true, and it will start removing stale worktrees hourly.
