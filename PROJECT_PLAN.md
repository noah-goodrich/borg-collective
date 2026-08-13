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

- [ ] **A1 — Parity harness exists and is green against today's zsh, before any port work.**
      14-18 cases in `tests/cli_contract.bats` covering all four output modes, the deep dive's optional
      sections, aggregate directives/assimilated, cortex pause row, capacity warning, empty-registry hint,
      unknown-project die, and all three external consumers (`drone.zsh:963` `Status:` grep, `drone.zsh:1405`
      `drone link`, `borg.zsh:689` fzf preview).
  - Verify: `bats tests/cli_contract.bats` green on unmodified `main`; case count `>= 14`.
- [ ] **A2 — Config vars reach the Python child.**
      `BORG_MAX_ACTIVE`, `BORG_REAP_STALE_HOURS`, `BORG_TMUX_SESSION`, `BORG_CORTEX_WAKES` are all currently
      set *without* `export`, so a `python3 -m` child inherits none of them.
  - Verify: a contract test sets `BORG_MAX_ACTIVE=6` and asserts the Python path honors it identically to zsh.
- [ ] **A3 — `borg link --json` emits the full document and is not polluted by the zsh pre-pass.**
      `warn()` writes to **stdout** (borg.zsh:30), and the mandatory `borg_desktop_scan` pre-pass can emit
      "registry write blocked" there, breaking `jq`. Diagnostics must move to stderr on this path.
  - Verify: `borg link --json | jq -e '.projects and .generated_at and (.order | length) == (.projects | length)'`
    exits 0 — not the directive's `.projects and .generated_at`, which passes on an empty object. Plus a test
    that forces the registry-write warning and asserts stdout is still valid JSON.
- [ ] **A4 — Human output is byte-identical after the port.**
      All A1 assertions pass **unchanged** against the Python implementation. A modified assertion is not a
      parity proof.
  - Verify: `git stash` the test file, confirm no diff between its `main` and branch versions; suite green.
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
- **CI has no Python provisioning on either bats lane** (`test.yml:32-43` installs `zsh jq fzf`; `:64-77`
  installs `jq`; neither runs `setup-python`). `borg.zsh:15` hard-resets PATH, so the contract suite exercises
  whatever system python3 the runner ships — not the pinned 3.14. `recon` introduced this on a low-traffic
  arm; this puts the daily path on an unpinned interpreter.
- **Unknown-flag parity is self-contradictory as originally scoped.** Today `borg link --totally-bogus` and
  `borg link --help` both render the overview and exit 0 (`-*) shift ;;` at borg.zsh:226), and `cli_smoke.bats`
  already asserts it. A recon-shaped arm that `die`s on unknown flags is a user-facing change. Pick parity;
  note the deviation if not.
