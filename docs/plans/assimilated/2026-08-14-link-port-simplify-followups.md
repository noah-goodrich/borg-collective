# Directive: Simplify Follow-Ups from the `borg link` Python Port

*Filed: 2026-08-14*

Independent finding from a `/simplify` pass over the just-completed `borg link` Python port (PR
[#138](https://github.com/noah-goodrich/borg-collective/pull/138)). None of these produce wrong output —
that is exactly why they were deferred rather than fixed during the ship. Not a child of the (now-shipped,
about-to-be-archived) link port plan; an independent follow-up.

## Why this exists

The port left several dead-but-harmless spots and a handful of duplications behind. All were re-verified
against the current worktree before filing; two line ranges had drifted from the original simplify notes and
are corrected below.

## Verified findings

- **`borg.zsh:203-263`** — `cmd_ls`'s entire human-table half (~60 lines: ASCII cube banner, PROJECT/SRC/
  STATUS/LAST ACTIVE/SUMMARY table, capacity warning) is unreachable in practice. `cmd_ls` has exactly one
  caller, `cmd_switch:316` (`cmd_ls --porcelain | ...`), which always sets `--porcelain` and returns before
  line 203. The bare `ls` CLI dispatch arm (`borg.zsh:2725`) does reach the human branch, but every bats call
  site (`cli_contract.bats`) exercises `cmd_ls --porcelain` only, so the human half ships with zero test
  coverage and no in-repo caller ever asks for it.
- **`borg.zsh:2920-2964`** — inside `_borg_link_dispatch`, `cmd_scan --llm` for `--refresh` is written five
  times (lines 2921, 2935, 2950, 2958, 2964 — one per dispatch arm: `--json`, `--porcelain`, deep-dive,
  `--brief`, overview). The function it replaced ran the refresh once before branching. The `_link_py_args`
  preamble (`typeset -a _link_py_args; _link_py_args=(...)`) is similarly written three times (2926-2927,
  2942-2943, 2966-2967 — json, porcelain, overview; the deep-dive arm calls `_borg_py` directly and doesn't
  use the pattern).
- **`borg_core/link/render.py:348-360`** (with siblings `_overview_directives_block:207` and
  `_overview_assimilated_block:225`) — the Directives and Recently-assimilated blocks exist twice: once as
  overview helpers, once inlined in `deep()` (`render.py:299-363`). The header lines
  (`f"  {CYAN}Directives:{NC} {len(directives)} pending\n"` / `f"  {GREEN}Recently assimilated:{NC}\n"`) are
  byte-identical between the two copies; only the per-item bullet differs by one token (the overview bullet
  carries a `[project]` tag the deep-dive one omits, since deep-dive is already scoped to one project).
- **`borg_core/link/render.py:299`** — `# pylint: disable=too-many-branches,too-many-locals` on `deep()`.
  The `too-many-locals` half is live (the function's own docstring-declared design keeps ~13 locals for a
  golden zsh transcription). The `too-many-branches` half is a useless suppression: `deep()` has 9 branches
  against pylint's default max-branches of 12, so removing that clause changes nothing and
  `pylint --enable=useless-suppression` should flag it (`I0021`) if pylint is run with that check enabled —
  not currently the case in this repo's default invocation, which is itself worth noting for AC2 below.
- **`borg_core/link/cli.py:73-107`** (`_document`) — gathers every block (`projects`, `order`, `focus`,
  directives, assimilated, capacity, etc.) regardless of which renderer the caller will invoke.
  `render.porcelain` (`render.py:121-138`) reads only `order`/`projects`; `render.deep` (`render.py:299`)
  reads only `focus`. Every other field `_document` assembles is discarded unread by those two callers,
  including for `--porcelain`, which feeds the fzf preview and re-runs on every cursor move. Not yet measured
  against the current registry size in this worktree — the original note cited 40 directory globs / 123
  markdown reads at 20 projects; that figure should be re-measured, not assumed, before AC1 below.
- **`borg_core/link/shell.py:65-77`** (`live_windows`) duplicates `borg_core/registry/shell.py:171-191`
  (`tmux_window_exists`) line for line: same `tmux list-windows -t <session> -F "#W"` argv, same
  `except (OSError, subprocess.SubprocessError)` guard, same `if result.returncode != 0` guard, same
  `# pylint: disable=clean-arch-demeter` comment on the final line — differing only in return type
  (`live_windows` returns the full window list; `tmux_window_exists` returns a single membership bool).
  *(Corrected from the original `registry/shell.py:180-191` — the duplicated block actually starts at the
  function's own `session = tmux_session_name()` / `try:` open, line 171.)*
- **`borg_core/link/shell.py:232-256`** (`read_assimilated`) calls `_read_text(Path(e["path"]))` twice per
  entry — once for `title` (line 252), once for `ship_date` (line 253) — where its sibling
  `collect_all_assimilated:274-301` binds `text = _read_text(...)` once (line 293) and feeds both
  `core.heading_title(text)` and `core.ship_date(text)` from the same read.
- **`borg_core/link/core.py:415`** (`format_iso`) duplicates `borg_core/recon/core.py:27`
  (`epoch_to_iso`); `borg_core/recon/cli.py:71` inlines the same
  `datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")` literal a third time. `borg_core/paths.py`'s
  own module docstring (lines 3-5) states the repo's rule explicitly: two copies were tolerated
  (`borg_dir`/`registry_path` in `registry/shell.py` and `recon/shell.py`), but "the third ...  would not
  have been" — pylint's duplicate-code check is what forced that consolidation. `format_iso` /
  `epoch_to_iso` / the `recon/cli.py:71` inline are now at that same third-copy threshold.
- **`borg_core/link/core.py:247`** — `reap_overlay`'s TSV-sentinel normalization
  (`if last_activity == TSV_EMPTY_SENTINEL: last_activity = ""`) changes which branch of `should_reap`
  (`core.py:147-179`) fires but not its return value: an un-normalized `"-"` is truthy, so it skips
  `should_reap`'s falsy-check REAP (step 3) and instead fails `iso_to_epoch("-")`'s strict grammar, landing on
  the unparseable-input REAP (step 4) — same outcome, different step. The normalized local *is* passed
  forward into the `should_reap` call two lines below, so "never read again" (the original note's phrasing)
  overstates it slightly; the accurate claim is that the normalization is behaviorally inert — deleting it
  changes which `should_reap` branch a `"-"` sentinel takes, not whether the project gets reaped.

## Objective

Work through the findings above in one focused pass: delete or consolidate what's genuinely dead/duplicated,
leave anything that turns out to have a live caller or a real behavioral dependency once you dig in.

## Acceptance Criteria

- [x] **AC1** — `borg.zsh` `cmd_ls`'s human-table half is either deleted (if truly unreachable — confirm no
      caller outside `--porcelain` exists, including in `drone.zsh`) or given a real caller/test; the
      `--refresh` `cmd_scan --llm` call in `_borg_link_dispatch` runs once before the branch instead of five
      times; the `_link_py_args` preamble is factored into one place.
  - Verify: `bats tests/cli_contract.bats` stays green; `borg link`, `borg link --json`, `borg link
    --porcelain`, `borg link --refresh` all still behave identically (manual smoke, since these are zsh
    dispatch paths without direct unit coverage).
  - **Evidence (2026-08-16)**: re-verified, did not assume. `grep -rn "cmd_ls" borg.zsh drone.zsh
    tests/cli_contract.bats` finds exactly two live references — the definition (`borg.zsh:141`) and its
    one caller, `cmd_switch:316` (`cmd_ls --porcelain | ...`), which always passes `--porcelain`. `drone.zsh`
    has zero references. The bare `ls` CLI dispatch arm this directive's own note cited as reaching the
    human branch turned out to be stale: `borg.zsh:3089-3090` shows `ls|status|hail|brief) die ...` — that
    arm was already converted to a `die` stub by the 2026-08-10 alias removal, so no CLI path calls
    `cmd_ls` without `--porcelain` any more. Confirmed truly unreachable; deleted the human-table body (was
    `borg.zsh:203-262`), leaving a comment recording the evidence in place of the code. Hoisted the
    `cmd_scan --llm` refresh call in `_borg_link_dispatch` to one call site before the branch (preserving
    the `--json` arm's `1>&2` redirect via an `if (( _link_json ))` inside that single call, so no output
    changed) and moved the `typeset -a _link_py_args` declaration to the top of the function, shared by all
    three branches that build the array. `bats tests/cli_contract.bats` 121/121 green;
    `bats tests/*.bats` 686/686 green; `pytest -q` 413/413 green.
- [x] **AC2** — `render.py`'s Directives/Recently-assimilated blocks are shared between `deep()` and the
      overview helpers (parameterize on the `[project]` tag); the useless `too-many-branches` pylint
      suppression on `deep()` is removed, `too-many-locals` stays.
  - Verify: `pytest borg_core/link/test_render.py -q` green; `pylint borg_core/link/render.py` clean (no new
    warnings from removing the suppression).
  - **Evidence**: Directives/Recently-assimilated render blocks (`_overview_directives_block`,
    `_overview_assimilated_block`) are shared between `deep()` and the overview.
- [x] **AC3** — `_document` in `cli.py` either narrows what it gathers per-renderer, or (simpler, lower risk)
      the porcelain/deep call paths skip the unread work `_document` currently does unconditionally. Re-measure
      the directory-glob / markdown-read counts before and after on a representative registry.
  - Verify: `pytest borg_core/link/test_cli.py -q` green; before/after glob and read counts recorded in the PR.
  - **Evidence**: `_document` (`cli.py:73`) made mode-aware (`need_aggregate`, `need_focus`); porcelain and
    deep went from **20 globs / 154 reads to 0 / 21**.
- [x] **AC4** — `shell.py`'s `live_windows` delegates to (or is merged with) `registry/shell.py`'s
      `tmux_window_exists`, or the duplication is otherwise resolved so one function owns the tmux subprocess
      call; `read_assimilated` reads each file once, matching `collect_all_assimilated`'s pattern.
  - Verify: `pytest borg_core/link/test_shell.py borg_core/registry/test_shell.py -q` green.
  - **Evidence**: `live_windows` merged into `registry.shell.list_tmux_windows` — no longer duplicated in
    `link/shell.py`.
- [x] **AC5** — `format_iso` / `epoch_to_iso` / the `recon/cli.py:71` inline collapse to one shared
      definition (a natural home is `borg_core/paths.py` or a new small shared time-utility module, following
      the precedent `paths.py`'s own docstring sets for exactly this situation).
  - Verify: `pytest borg_core/link/test_core.py borg_core/recon/test_core.py borg_core/recon/test_cli.py -q`
    green.
  - **Evidence**: `format_iso` / `epoch_to_iso` / the `recon/cli.py` inline collapsed into
    `borg_core/timefmt.py`.
- [x] **AC6** — `reap_overlay`'s TSV-sentinel normalization in `core.py` is either deleted (if AC-verification
      confirms it changes no observable output) or a test is added that actually pins the branch it selects,
      so the line stops being untested dead weight either way.
  - Verify: `pytest borg_core/link/test_core.py -q` green; if deleted, confirm via `coverage run --branch`
    that no branch coverage regresses.
  - **Evidence**: the inert TSV normalization was deleted; `core.py` now documents (`:244-249`) that
    `reap_overlay` deliberately does not normalize the sentinel, with no observable-output change.
- [x] **AC7** — Regression: full suite stays green.
  - Verify: `bats tests/*.bats` and `pytest -q` (or repo's combined test entrypoint) both exit 0.
  - **Evidence**: 686 bats, 413 pytest, `pylint` 10.00/10, all four goldens byte-identical.

## Scope Boundaries

- NOT changing any renderer's *output* — every AC above is a structural/dead-code cleanup; if any change would
  alter a single byte of `borg link`'s JSON, human, porcelain, or deep-dive output, that's out of scope for
  this directive and needs its own review.
- NOT touching `skills/borg-link/SKILL.md` or its bats pins — that's the companion documentation fix, filed
  and shipped separately.
- NOT expanding into a broader `borg_core` refactor — stick to the nine findings listed above.
- If a finding turns out to have a caller or dependency not visible from static reading (e.g. a test that
  actually exercises `cmd_ls`'s human table via some path this filing missed), leave it and note why in the
  PR rather than deleting something live.

## Ship Definition

PR against `main`. Each AC's verify command run and pasted (or summarized with pass/fail) into the PR
description. No output-changing diffs — reviewers should be able to confirm every hunk is either a pure
deletion of dead code or a mechanical de-duplication.

## Timeline

Small — one focused session. All nine findings are either straight deletions or single-function
consolidations; none requires new design.

## Risks

- **A "dead" branch that isn't** — `cmd_ls`'s human table and the `too-many-branches` pylint suppression are
  the two likeliest candidates for a surprise live caller (external tooling, a forgotten cron, a doc that
  tells someone to run `borg ls` bare). Confirm via grep across the whole repo (not just `borg.zsh`) before
  deleting, and check `drone.zsh` specifically since it also shells into `borg`.
- **`format_iso`/`epoch_to_iso` consolidation touches two packages (`link` and `recon`) that are otherwise
  independently owned per CLAUDE.md's per-project directive discipline** — keep the shared function's home
  genuinely neutral (`paths.py` or a new module) rather than importing one package's internals into the
  other.

*Shipped: 2026-08-16 — PR #153 (AC2-AC7) and PR #155 (AC1) merged to main*
