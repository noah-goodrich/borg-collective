# Project Plan: Port `borg link` to the Python Core (behavior unchanged)
*Established: 2026-08-12*

## Objective

Move `borg link` out of zsh and into `borg_core/link/`, following the established `recon`/`registry`
core/shell/cli convention, with **human-readable output byte-identical to today's**. Add `borg link --json`
as new additive surface and rewrite `/borg-link` to consume it. Layout redesign is explicitly deferred to a
second directive so this pass has a real parity harness.

## Why this shape

The owner's direction is that `link` belongs in the Python core, which correctly cut a circular deferral:
the recon-migration-ledger blocked `link` on the link-unification directive, and that directive assumed a
zsh implementation. Doing both at once means writing the logic twice.

But a scoping pass (5 agents, call graph + conventions + contract + adversarial challenge) surfaced a second
conflict underneath: **you cannot prove parity against a target you are simultaneously redesigning.** A port
needs contract tests written against today's zsh that pass *unchanged* on Python. L3/L4/L5 of
`2026-08-11-link-unification-and-layout.md` deliberately rewrite that exact output. The moment the layout
lands, every parity assertion must be edited — and an edited assertion proves nothing about what came before.

This plan resolves it by splitting on that seam: re-platform an unchanged command here, redesign a stable
Python target next.

## Corrections to the record (verified empirically, supersede the directive's text)

- **L4's `---` defect does not reproduce.** `borg link | sed 's/\x1b\[[0-9;]*m//g' | grep -c -- '---$'`
  returns **0**, and **0 of 118** directive files across `~/dev` begin with `---`. The `head -1 | sed` title
  extraction is theoretically fragile but no real data triggers it. L4 is not carried here or in the layout
  directive as written.
- **L5's baseline is stale.** The directive says 83 lines; actual is **160**.
- **`_borg_read_assimilated:147` is a real bug.** `(NOm)` — in zsh `Om` *reverses* to oldest-first, so
  `borg link <project>` lists the three **oldest** assimilated plans under "Recently assimilated". It also
  disagrees with `_borg_collect_all_assimilated`, which sorts filename DESC. Must be fixed here because the
  JSON contract requires one ordering; recorded as an intentional deviation with a pinning test.

## Acceptance Criteria

- [x] **A1 — Parity harness exists and is green against today's zsh, before any port work.**
      14-18 cases in `tests/cli_contract.bats` covering all four output modes, the deep dive's optional
      sections, aggregate directives/assimilated, cortex pause row, capacity warning, empty-registry hint,
      unknown-project die, and all three external consumers (`drone.zsh:963` `Status:` grep, `drone.zsh:1405`
      `drone link`, `borg.zsh:689` fzf preview).
  - Verify: `bats tests/cli_contract.bats` green on unmodified `main`; case count `>= 14`.
  - **Done 2026-08-13.** 25 cases; suite 98/98, full `bats tests/*.bats` 620/620, and the whole contract
    file green on GNU/Linux (ubuntu:24.04 container) as well as macOS — the goldens byte-match on both.
    Four renderers are pinned by byte-exact golden files under `tests/fixtures/link/` (ANSI escapes and
    column padding included), not substrings: a substring harness passes against a renderer that changes
    padding or drops a color, which is the drift this port produces.
  - **Hardened after a blind adversarial pass** (3 lenses: reuse, vacuity, portability). The first draft
    was green and still under-constrained in ways that mattered:
    - The **tertiary sort key** (`last_activity` ASC) was invisible — no fixture put two projects in the
      same (pinned, status) bucket, so reversing it, the change a porter is most likely to make since
      oldest-first reads as a bug, rendered byte-identically. Three projects now tie that bucket.
    - The **human `--all` path** was never rendered at all; `--all` was only exercised via `--porcelain`.
      Added `link-overview-all.golden`.
    - `display_name`, the checkpoint `head -3`/`head -20` caps, name-vs-mtime checkpoint ordering, the
      `never` relative-time bucket, the deep dive's `(never)`/`(none)`/`(unknown)` defaults, the
      `fold -s -w 70` wrap and its continuation indent, the `--llm` alias, and the reap overlay's
      downgrade direction were all unpinned. Each now has a case.
    - The claimed external consumer at `borg.zsh:689` was **wrong**: fzf reads `cmd_ls --porcelain`
      (`borg.zsh:685`), not `link --porcelain`, and the two already diverge on an empty registry. Both
      halves are now pinned against the producer that actually feeds each.
  - **A second known deviation surfaced and is now pinned**: `criteria_done=$(grep -c … || echo 0)`
    (`borg.zsh:459`) captures *both* grep's `0` and the `|| echo 0` fallback when nothing matches, so a
    plan with no completed criteria renders `Progress: 0` / `0/2 criteria met` across two lines. Every
    fresh plan hits it. The port will "fix" it merely by being Python, so it must land as a deliberate
    deviation, not a silent change. The `(NOm)` oldest-first assimilated bug is likewise pinned — and
    deliberately kept OUT of the deep-dive golden, so fixing it flips one substring test instead of
    forcing a golden regeneration that A4 rules out as a parity proof.
  - Non-vacuity verified by **six mutations**, each caught by exactly the goldens that should see it:
    dropping the tertiary sort key (porcelain + both overviews red, deep green), widening the checkpoint
    caps (deep only), making `--all` ineffective (overview-all only), dropping `display_name` (both
    overviews), removing the `--llm` alias, and disabling the reap overlay.
- [x] **A2 — Config vars reach the Python child.**
      `BORG_MAX_ACTIVE`, `BORG_REAP_STALE_HOURS`, `BORG_TMUX_SESSION`, `BORG_CORTEX_WAKES` are all currently
      set *without* `export`, so a `python3 -m` child inherits none of them.
  - Verify: a contract test sets `BORG_MAX_ACTIVE=6` and asserts the Python path honors it identically to zsh.
  - **Done 2026-08-13** via `_borg_py` (`borg.zsh`, just above the `case` block), which hands the child
    `BORG_DIR`, `BORG_REGISTRY`, `BORG_MAX_ACTIVE`, `BORG_REAP_STALE_HOURS`, `BORG_TMUX_SESSION`,
    `BORG_CORTEX_WAKES` and `PYTHONPATH`, with defaults applied *in the wrapper* (an exported-empty
    `BORG_REAP_STALE_HOURS` makes `int("")` raise). This was not hypothetical: `borg recon` had been
    dying with `no registry at ` on every real invocation since its migration, because it read
    `BORG_REGISTRY` from an environment that never had it. Contract test mocks `python3` and asserts
    the **child's** environment, including that a caller-supplied value is carried through.
- [x] **A3 — `borg link --json` emits the full document and is not polluted by the zsh pre-pass.**
      `warn()` writes to **stdout** (borg.zsh:30), and the mandatory `borg_desktop_scan` pre-pass can emit
      "registry write blocked" there, breaking `jq`. Diagnostics must move to stderr on this path.
  - Verify: `borg link --json | jq -e '.projects and .generated_at and (.order | length) == (.projects | length)'`
    exits 0 — not the directive's `.projects and .generated_at`, which passes on an empty object. Plus a test
    that forces the registry-write warning and asserts stdout is still valid JSON.
  - **Done 2026-08-13**, merged as `358f0aa` ([#134](https://github.com/noah-goodrich/borg-collective/pull/134)).
    Verified by an independent evaluator that re-ran the gate live (exit 0) rather than restating it, plus five
    green CI lanes: `make lint` 10.00/10, 346 pytest, `bats tests/cli_contract.bats` 112/112, `bats tests/*.bats`
    636/636. Diagnostics move to stderr via `1>&2 2>/dev/null` on the pre-pass (`borg.zsh:3275-3321`).
  - **Non-vacuity measured by 8 mutations, not assumed: 7 killed, 1 survived.** Killed — reversing the
    `last_activity` tie-break, `pinned` truthiness vs `is True`, swapping the waiting/active rank, leaking
    `_`-prefixed keys, ignoring `--all`, a second wall-clock read, and ungating `borg_desktop_scan` on the focus
    path. Most died at BOTH tiers independently. Also proven: 7 of the 9 new bats tests really cross the
    zsh→python3 boundary (replacing `cli.py:93` with `print("{}")` turned exactly those 7 red).
  - **Branch coverage confirmed honest**: with `branch = true` the new code is 149/150 arcs — `core.py` 74/74,
    `shell.py` 68/68, zero partials; the only miss is `cli.py:116→117`, the `if __name__` guard, which is
    structurally uncoverable under pytest. Statement→branch moves the PR by 0.11pp.
  - **The one survivor is carried to Phase 3, not silently dropped**: `core.capacity()`'s `active > limit` can be
    changed to `>=` with 346 pytest + 112 bats still green. Current code is correct and matches `borg.zsh:407`;
    what is missing is a discriminating assertion. See "Phase 3 entry gate" below.
- [ ] **A4 — Human output is byte-identical after the port.** *(AMENDED 2026-08-13 — owner signed off; the
      original text is preserved below.)*
      All four goldens byte-match with **ZERO regeneration**. 23 of the 25 A1 assertions pass unchanged;
      exactly **two** flip to their documented post-fix values — the `(NOm)` assimilated-ordering test
      (`cli_contract.bats:2112`, lines 2112/2118/2121/2122) and the two-line Progress test (`:2078`, lines
      2078/2089). One Phase-2 assertion also moves: the `.version` literal at `:2333`, `1` -> `2`. Nothing
      else in `tests/cli_contract.bats` is modified, deleted, **skipped, or neutered**.
  - Verify (three mechanical commands, all must hold):
    1. `git diff 9257c3b..HEAD --stat -- tests/fixtures/link/` prints **nothing**.
    2. `git diff 9257c3b..HEAD -- tests/cli_contract.bats | grep '^-' | grep -v '^---'` prints **only**
       lines belonging to those three enumerated locations.
    3. `grep -c '^\s*skip ' tests/cli_contract.bats` equals **1** (the pre-existing uid-0 guard at `:2366`),
       and the bats TAP run reports zero `# skip` results beyond that one.
  - **Why amended.** The original — "all A1 assertions pass unchanged" — was in direct contradiction with
    this plan's own signed-off Phase 1 deviations. Two of the 25 A1 tests exist *specifically* to pin the
    `(NOm)` ordering bug and the two-line `Progress` artefact, and their in-file comments say they are
    designed to flip when those are fixed. One of the two had to move; keeping A4 verbatim would have meant
    reverting already-shipped, already-tested Python (`shell.py:232-256`, `core.py:357`). The original verify
    recipe was independently defective: `git stash` + "no diff" forbids *adding* tests, which Phases 2 and 3
    have already done 12 times.
  - **Why check 3 is not decoration.** Checks 1-2 only catch REMOVED or MODIFIED lines. An assertion can be
    neutered by a pure ADDITION — a `skip`, an early `return`, an `if false; then` wrap — and both checks
    still pass, while `bats … exits 0` counts a skip as a pass. Check 3 closes that hole, which sits exactly
    where the pressure will be.
  - **Verified before amending, not asserted**: `git diff 9257c3b..HEAD --stat -- tests/fixtures/link/` is
    empty at `ad99612`; `link-deep.golden:50` carries exactly one assimilated line (so oldest-first vs
    filename-DESC is unobservable there); `link-deep.golden:16` renders `Progress: 1/3 criteria met` on one
    line because the fixture plan leads with `- [x]`, so the `|| echo 0` fallback never fires. **No golden
    moves. `BORG_UPDATE_GOLDEN=1` must never be run during Phase 3.**
  - *Original text, superseded:* "All A1 assertions pass **unchanged** against the Python implementation. A
    modified assertion is not a parity proof. Verify: `git stash` the test file, confirm no diff between its
    `main` and branch versions; suite green."
- [ ] **A5 — `cmd_link` and its helpers are deleted, not shadowed.**
      `cmd_link`, `_borg_link_porcelain`, `_borg_link_overview`, `_borg_link_deep`, `_borg_cortex_pending`,
      `_borg_cortex_countdown`, `_borg_collect_all_directives`, `_borg_collect_all_assimilated`,
      `_borg_read_assimilated` removed; `cmd_watch` rewired.
  - Verify: `grep -c 'cmd_link' borg.zsh` returns 0.
- [ ] **A6 — `/borg-link` consumes `borg link --json`.**
      Rewritten as a synthesis layer matching `/borg-recon`'s shape. The direct-file-read path survives only
      as the drone-container fallback, with its trigger condition stated verbatim, `has_live_window: null`,
      and **no** staleness downgrade (no-tmux is indistinguishable from no-window; a naive fallback marks
      every project stale inside a drone).
  - Verify: SKILL.md runs `borg link --json` first; fallback section states its trigger. Redeployed via
    `install.sh` and the **deployed** copy re-read to confirm.
- [ ] **A7 — Regression.** Full bats suite + macOS contract leg green; per-module coverage `>= 90%` checked
      by hand on `coverage report -m`, not inferred from the global `--fail-under=90` (which is a total over
      `borg_core` and currently masks `recon/cli.py` at 82%).
  - Verify: `bats tests/*.bats` exits 0; `coverage report -m` shows every `borg_core/link/*.py` at `>= 90%`.

## Phase log

**Phase 0 — parity harness. Done 2026-08-13.** See A1.

**Phase 1 — pure leaves + chokepoint. Done 2026-08-13.** `borg_core/link/{core,shell}.py` plus colocated
tests, and `borg_core/paths.py` extracted (third caller triggered pylint's duplicate-code). **Zero tracked
files modified** — pure addition, so every A1 golden passes unchanged, which is what A4 will later need.
`core.py` 100%, `shell.py` 100% on `coverage report -m` (per-module, not inferred from the global gate);
`make lint` 10.00/10; 328 pytest; `bats tests/*.bats` 627/627.

The shared case table the Risks section demands is `tests/fixtures/reaper-cases.tsv`: 22 rows read by
**both** `tests/reaper_cases.bats` (against live `lib/reaper.sh` under zsh) and
`borg_core/link/test_core.py` (against `core.should_reap`), asserting the same expected column. A second
5-row block covers `borg_reap_overlay`'s window resolution — the half an earlier draft missed, and the half
the Risks section actually names.

Three bugs were found while specifying this phase and fixed **outside** it, so Phase 1 stayed zsh-free:
`borg recon` dying on an unexported `BORG_REGISTRY`; one malformed `state.json` blanking the whole registry;
and `grep -qx` matching window names as regexes (`troth.site` matched a live `troth-site`), which would have
made zsh and Python disagree about liveness forever.

### Deviations, signed off 2026-08-13

- **`iso_to_epoch` uses one strict grammar.** BSD `date -j -u -f` accepts trailing garbage and normalizes
  `2026-02-30`; GNU `date -d` accepts a far larger grammar still. The two platforms already disagree, so one
  strict grammar normalizes an existing split rather than adding a third behavior. No value borg itself
  writes is affected — every writer uses `date -u +%Y-%m-%dT%H:%M:%SZ`.
- **`read_assimilated` sorts filename-DESC.** The `(NOm)` glob lists the three *oldest* plans and disagrees
  with the overview's aggregate, which already sorts by filename. One ordering for the JSON contract, and it
  survives a fresh clone where every file shares the checkout mtime.
- **`plan_progress` returns ints.** `grep -c … || echo 0` captures `0\n0`, rendering `Progress:` across two
  lines on every fresh plan.
- **`cortex_pending` emits no `cd=` noise.** zsh's `local cd` inside its loop prints the parameter from
  iteration two onward. `_borg_cortex_pending` is deleted by A5, so the fix has no surviving twin.
- **`registry_with_state` computes one snapshot.** zsh runs the whole pipeline twice per `borg link` (once
  for the table, once inside the capacity warning), so a hook writing between them can make the two
  disagree. Unobservable until Phase 3.
- **`live_windows` is one fork.** Collapses `tmux has-session` + `list-windows`; tmux resolves a `-t` target
  identically for both subcommands.

**Phase 2 — the `--json` seam. Done 2026-08-13.** See A3. Adds `borg_core/link/cli.py` (new file, `--json`
only) plus additive `core.py`/`shell.py` primitives (`project_sort_key`, `visible_projects`,
`order_projects`, `capacity`, `assemble`, `max_active`, `registry_with_state(now=...)`) and wires the
`link)` arm in `borg.zsh` through `_borg_py`. **Zero renderer touched** — every existing golden
(`link-porcelain`, `link-overview`, `link-overview-all`, `link-deep`) still passes byte-identical, and
`git diff main -- tests/cli_contract.bats | grep '^-' | grep -v '^---'` prints nothing. Interpreter pinning
and a `borg doctor` python3 check are DEFERRED to Phase 3, when human rendering starts depending on Python;
see the corrected CI risk bullet above.

### Phase 3 entry gate — three tests, from the post-merge depth audit

These close gaps that a 12-agent audit *measured* on the merged Phase 2 code. All three are latent today
because nothing consumes the document yet; **all three become user-visible the instant Phase 3 flips the
renderers onto it**, which is why they gate Phase 3 rather than having blocked #134. Roughly one commit.

1. **Capacity boundary discriminator.** `core.capacity()`'s `active > limit` survives mutation to `>=` with
   the entire suite green. `grep -rn over_limit tests/` matches nothing; its only exercise is `capacity(0, 3)`
   passed as an argument, and 0-vs-3 is mutation-blind by construction. The 4-vs-4 case *is* tested — at
   `cli_contract.bats:1943`, without `--json`, so it never reaches `core.py`. Fix: a parametrized assert on
   `capacity(4,4)` and `capacity(5,4)`, plus a bats assertion on `.capacity.over_limit`.
2. **`.order` vs golden row order must be derived, not re-typed.** Nothing asserts the two agree. Proven in
   both directions: swapping `_STATUS_RANK` fails only the `--json` test while all four goldens stay green;
   swapping the jq ranks at `borg.zsh:305-306` fails the goldens while all 7 real-boundary `--json` tests stay
   green. `link-porcelain.golden` column 1 and the literal at `cli_contract.bats:2341` are identical text with
   no derivation between them. Fix: parse the golden's first column and diff it against `jq -r '.order[]'`
   over the *same* fixture. **This one must land before the flip** — a refactor touching both sides can move
   them together into a state no assertion covers.
3. **Reap overlay end-to-end on the JSON path.** Forcing `BORG_NO_REAP="${BORG_NO_REAP:-1}"` in `_borg_py` —
   permanently disabling the overlay for every Python child — leaves the contract suite at 112/112. The
   link-path test at `bats:2452` only greps the variable *name* from a **mocked** python3's env dump; no value
   assertion, no `borg_core` execution, unlike the A2 test at `:2298-2304` which does pin a value. `status` is
   the field this tool exists to report. Fix: a stale active row asserting `.status == "idle"` without the var
   and `"active"` with it.

Also carried, lower priority and each cheap: `cli.py:111` catches only `ValueError`, so nine malformed-registry
shapes produce a raw traceback with zero bytes on stdout; EACCES is silent wrong data (an unreadable
`PROJECT_PLAN.md` renders a real 1-of-3 plan as 0-of-0); `relative_activity` has no wire type contract
(`last_activity: 12345` emits a JSON number on a `str | None` field); the A3 force test still skips on any
uid-0 runner, and it is the sole assertion covering the pre-pass gate.

**Coverage-gate defect found in passing (repo-wide, not this plan's):** `omit = ["**/tests/**"]` matches
nothing, because tests are colocated as `borg_core/<pkg>/test_*.py`. 1407 of 2331 measured statements (60.4%)
are test files grading themselves; real production coverage is **96%, not 98%**. One-line fix —
`omit = ["*/test_*.py"]` plus `branch = true` — and the 90% gate still passes with 8 points of headroom
(verified, not assumed).

## Scope Boundaries

- **NOT L3/L4/L5** (bottom-anchored layout, idle collapse, line-count re-measure) — second directive, against
  the stable Python target. This is the whole point of the split.
- **NOT `--brief` / `_borg_print_briefing`.** It stays zsh this pass. The open
  `2026-08-10-briefing-fallback-and-summary-provenance.md` directive targets the same 144 lines and its
  criteria *require* changing `briefing.bats`, contradicting "briefing.bats passes unchanged." Two owners,
  same code. That directive ships first or they merge — either way, not here.
- **NOT `borg scan` / `--refresh`.** `_borg_scan_source` passes function names as strings and mutates a
  caller-scope array via zsh dynamic scoping; no mechanical port survives it. The arm runs `cmd_scan --llm`
  in zsh before dispatching.
- **NOT `borg_desktop_scan`.** Stays a zsh pre-pass in the case arm — it is a non-atomic registry
  read-modify-write shared by scan/next/init/switch/watch. Consequence to document in `cli.py`'s docstring:
  invoking the module directly differs from `borg link`, so the skill must call the CLI, never the module.
- **NOT `cmd_ls` / `cmd_status` / `cmd_next`.** They keep their zsh copies (kept alive by `cmd_switch`). The
  port temporarily *increases* duplication across the zsh/Python line until those migrate — accepted and
  recorded, not hidden.
- **NOT fixing `borg_coco_latest_session_id:34`**, which has the identical `(NOm[1])` bug but sits in the
  out-of-scope scan surface.
- If done early: ship, don't expand.

## Ship Definition

PR against `main`; full bats suite + macOS contract leg green; per-module coverage recorded in the PR body;
independent 3-lens adversarial review (parity / bugs / scope) as with the `add`/`rm` migration; ledger row
added to `docs/plans/assimilated/2026-08-12-recon-migration-ledger.md` recording that porting `link` ahead of
`next`/`scan` is a deliberate owner-cut deviation from the controlling plan's stated order.

## Timeline

Target: 4-6 sessions, ~16-22h.

Phase 0 parity harness ~3-4h · Phase 1 pure leaves + chokepoint ~3-4h · Phase 2 `--json` seam ~3-4h ·
Phase 3 render flip (atomic across porcelain/overview/deep) ~4-6h · Phase 4 L2 skill + gate ~2-3h.

The seam is `--json`: a new flag with zero existing consumers, so the entire document builder ships while
every byte of human output is still produced by untouched zsh renderers. Phases 0-2 alone leave the command
fully coherent — the natural stopping point if budget runs out.

## Risks

- **Shared-helper divergence is the crux.** `borg_registry_with_state` has 9 call sites across
  link/next/switch/init/reap/watch, with `borg_reap_overlay` inside each. Python must reimplement both while
  the zsh copies stay live. Divergence shows up as `borg link` saying idle while `borg next` says waiting —
  a plausible-looking wrong answer with no crash, the exact failure mode this repo has been bitten by three
  times. Mitigation: one shared case table (status x last_activity x live_window x threshold) exercised by
  **both** a bats test against zsh and a pytest against Python, with identical expected values.
- **`_borg_should_reap` becomes triple-implemented** across sh (hooks), zsh (CLI), and Python. Routing the
  SessionStart hook through `python3` would add interpreter startup to every session start — not worth it.
  Explicit recorded decision, not a mid-implementation discovery.
- **`drone.zsh:963` greps `Status:` out of the human deep dive.** That text format is an undeclared cross-CLI
  API with no test anywhere; breaking it yields a silently blank column. A1 must pin it.
- **`cmd_watch` pays interpreter startup every redraw** (~40-60ms) where zsh paid an in-process call. Net
  should still win (current path spends 3 + 8N jq spawns per redraw) but it is the one repeated constant.
- **CORRECTED 2026-08-13 (Phase 2): the interpreter is unpinned, not absent.** The original bullet's
  premise was wrong and its citation was stale. `test.yml:64-77` is now the `viz` job (commit
  5876951 inserted it); the macOS contract lane moved to `test.yml:89-102`. And both bats lanes
  already execute borg_core through `_borg_py` today with zero `setup-python`: `borg add`, `borg rm`
  and `borg recon` all dispatch to Python, and their contract tests pass on ubuntu-latest and
  macos-latest. `borg.zsh:15` rebuilds PATH from a fixed list that excludes the hosted toolcache, so
  `actions/setup-python` alone would change nothing — routing to it requires symlinking into a
  directory on that fixed list, and ~34 tests overwrite `BORG_PATH_PREFIX`. What is genuinely
  unpinned is the interpreter VERSION: ubuntu-24.04 runs `/usr/bin/python3` 3.12.3 and macos-26 runs
  `/opt/homebrew/bin/python3` 3.14.x, while the dedicated `python` lane lints and tests on 3.14.7 —
  and 3.12 is the declared target (ruff `target-version = py312`, mypy `python_version = 3.12`), so
  the ubuntu bats lane is currently the ONLY place that target is ever exercised. Pinning ubuntu to
  3.14 would remove that. Interpreter pinning and a `borg doctor` python3 check are therefore
  DEFERRED to Phase 3, when human rendering starts depending on Python and the risk becomes real.
- **Unknown-flag parity is self-contradictory as originally scoped.** Today `borg link --totally-bogus` and
  `borg link --help` both render the overview and exit 0 (`-*) shift ;;` at borg.zsh:226), and `cli_smoke.bats`
  already asserts it. A recon-shaped arm that `die`s on unknown flags is a user-facing change. Pick parity;
  note the deviation if not.
