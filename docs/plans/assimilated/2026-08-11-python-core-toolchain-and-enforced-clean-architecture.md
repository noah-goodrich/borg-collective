# Directive: Python Core + Toolchain + Enforced Clean Architecture
*Filed: 2026-08-11*
*Shipped: 2026-08-12 — PR #120 squash-merged to main as `c760514`*

Long-horizon architectural directive. **Intended for execution on Noah's personal machine**, which is why it ships
as a standalone branch and PR. Consolidates what were briefly two directives (the Option-C exploration and the
toolchain decision) into one, so there is a single source of truth rather than two documents restating the same
gate.

Derived from the 2026-08-11 testing-posture design study (options A–E), a blind adversarial review, and two
research passes recorded under `docs/research/2026-08-11-*`.

## Objective
Three deliverables, ordered by durability — each worth doing even if the next never happens:

1. **The toolchain** — `pyproject.toml`, a `Makefile`, ruff/mypy/pylint gating in CI, modeled on Noah's own
   established pattern rather than a new invention.
2. **The rule** — new code in *any* borg-managed project has a fully testable core: logic in importable units,
   shell reduced to a wrapper, tests in the same commit. Mechanically enforced, not documented and hoped for.
3. **The migration** — borg's CLI core from ~4,242 lines of zsh to Python + Typer, zsh retained as the wrapper,
   by strangler pattern rather than rewrite.

## The decision: Python + shell

**Go and Rust are ruled out.** The reason is about the maintainer rather than the code, and is none the worse for
it: Noah is fluent in neither, idiomatic Go is a genuinely different paradigm from Python/PHP, and a whole-language
conversion is a time investment that does not exist. A tool the maintainer edits reluctantly is worse than one they
edit fluently.

This was not a foregone conclusion. A blind review argued — correctly, on this directive's own stated criteria —
that a compiled single binary dominates: near-zero startup would mean the hook/CLI boundary below **would not need
to exist**, `go test`/`go vet`/`gremlins` cover the same tooling gap, and a static binary removes container
dependency fragility. That argument is recorded rather than buried. It lost to maintainer fluency, which is a
legitimate engineering input and is being applied knowingly.

## Why any of this — the evidence

borg grew from a small zsh script into a ~7,800-line application without acquiring the guardrails an application
needs. The 2026-08-11 session found **three bugs in one day**, each a shell-idiom failure:

| Bug | Root cause |
|---|---|
| #113a | `${BASH_SOURCE[0]:-$0}` resolved to `.` — `BASH_SOURCE` is a bash array, **empty in zsh** |
| #113b | `IFS=:; set -- $var` yielded 1 element, not 2 — **zsh does not word-split** unquoted expansions |
| #114 | `stat -f %m \|\| stat -c %Y` captured garbage — GNU `stat -f` prints to **stdout** before failing |

And the tooling gap is permanent, not incidental:

- **No coverage tool exists for zsh.** kcov/bashcov instrument bash's xtrace. **4,242 LOC — 54% of the codebase —
  is unmeasurable.**
- **shellcheck refuses zsh**, since 2016. Forcing `-s bash` is documented (SC1071) as giving *false safety on
  exactly the word-splitting class above*.
- **No mature shell mutation testing exists.** In Python, `mutmut` automates "would a broken implementation
  actually fail this test."
- **macOS ships bash 3.2.57 (2007).** Its `set -e` silently ignores non-final `[[ ]]`, which hid 161 assertions.

### What the migration actually prevents

Stated precisely, because "migrate to Python" does not uniformly imply "these bugs go away":

**#113a** — lived in `lib/recon.sh:30`. Migrates. **Prevented**; Python has no `BASH_SOURCE` analogue.
**#113b** — lived in `lib/recon.sh`. Migrates. **Prevented**; `str.split(":")` has one behavior.
**#114** — lived in `borg.zsh`, `lib/recon.sh`, **and `hooks/borg-link-up.sh`**. The first two migrate; the hook
does not, by design. **Partially prevented.**

Two of three fully, one partially. The honest claim is "this removes the exposure from the migrated surface," not
"this fixes shell bugs." A blind review argued #113a was structurally exempted for living in the wrapper — wrong on
the specifics (it was a portable-sh lib), but the general concern stands: anything staying in `borg.zsh` or the
hooks keeps its shell-idiom exposure permanently.

## The measured boundary: hooks stay shell

Measured on this machine, **Python 3.14.5**:

| Command | Startup |
|---|---|
| `zsh -c true` | 27.3 ms |
| `bash -c true` | 27.9 ms |
| `python3 -c pass` | 47.6 ms |
| `python3 -S -c pass` | 41.1 ms |
| `python3 -S -E -c pass` | 40.9 ms |
| `python3 -c 'import typer'` | 59.6 ms |

Python's practical floor is **~41 ms before any borg code runs**, against zsh's ~27 ms. The two `PostToolUse` hooks
fire on **every agent tool call**; at ~250 calls a session that is seconds of pure added latency for zero benefit.
**Hooks stay shell — permanently, and this is arithmetic rather than preference.**

### Compiling Python to a binary does not change this

Recorded plainly so it is never re-litigated. Researched in
`docs/research/2026-08-11-python-single-binary-startup-latency.md`:

- **Every packager still boots a full CPython interpreter**, and several make it worse. One measured benchmark had
  **Nuitka at 257 ms vs 152 ms** for the plain script; PyInstaller `--onefile` re-unpacks its archive to a temp dir
  on **every run**.
- **PyOxidizer is dormant** — last commit 2024-11-03, no releases in over a year.
- **The "transpiles to a Rust binary" tool is `py2many`** — a source-to-source transpiler limited to a
  statically-typeable subset. Dynamic decorators and C extensions are out of scope, so **`typer`/`click` are not
  transpilable targets.** That road is closed for a Typer CLI. Distinct from PyOxidizer (which *packages* CPython
  using Rust's toolchain) and RustPython (a separate, non-production interpreter).
- **Correcting widely-repeated guidance:** 2017-era benchmarks show `-S` roughly halving startup and that ratio is
  still quoted everywhere. On 3.14 it recovers **6.5 ms**, because 3.11+ already ships frozen stdlib modules and
  captured most of that saving. Do not plan around the old ratio.

What a binary *would* buy is **no venv drift across two machines** — a modest convenience, and `uv` with a locked
venv is likely simpler. **Deferred, not adopted.**

The only mechanism that would genuinely reopen the boundary is a **persistent daemon + thin socket client**
(~0.1 ms per round trip). That is a real, stateful architecture change, not a packaging swap. **Out of scope** —
recorded so the option is remembered rather than rediscovered.

## Part 1 — Adopt Noah's own toolchain (do this first; it pays for itself alone)

Not a new pattern to invent. It already exists across `pytest-coverage-impact`, `snowfort`, and
`pylint-clean-architecture`. Copy it.

- [x] **T1** — `pyproject.toml` at the repo root: `[tool.ruff]` with `line-length = 120`,
      `select = ["E", "F", "W", "C90"]`, `[tool.ruff.lint.mccabe] max-complexity = 10`; `[tool.mypy]` with
      `warn_return_any` and `warn_unused_configs`; `[tool.pytest.ini_options]` with `--strict-markers` and
      `unit`/`integration`/`functional` markers, slow tests excluded from default runs.
  - Verify: `ruff check`, `mypy`, `pytest` all run from config with no CLI flags.
  - `line-length = 120` matches the existing repo-wide 120-char rule for markdown and shell. One number for
    everything.
- [x] **T2** — A `Makefile` with `clean` / `test` / `lint` / `format`, and **CI invokes those same targets.**
  - Verify: `.github/workflows/` calls `make lint` and `make test`, not inline commands.
  - **The highest-leverage item in this directive, which is why it is T2 and not housekeeping.** The 2026-08-11
    session found 161 assertions silently ignored on macOS for weeks because local and CI ran the suite
    differently. A Makefile makes "run the tests" have exactly one definition — it fixes a class of bug, not a
    style inconsistency.
- [x] **T3** — `pylint-clean-architecture` (v1.5.2, PyPI, Python ≥3.9) as a dev dependency, gating in CI, with
      `[tool.pylint.main] load-plugins = ["clean_architecture_linter"]` and
      `[tool.clean-arch] visibility_enforcement = true`.
  - Verify: `make lint` runs pylint with the plugin loaded; CI fails on a deliberate violation.
  - **This is the answer to deliverable 2 — the rule — and Noah already built it.** Its **Silent Core Rule
    (W9013)**, requiring Domain and UseCase layers to be free of `print`, `logging`, and console I/O and to
    delegate to interfaces/adapters, *is* the testable-core rule mechanically enforced. Its dependency-injection
    checks, forbidding instantiation of infrastructure inside UseCases, are the other half. Nothing needs
    inventing; adopt the linter rather than writing a convention document.
- [x] **T4** — A `python` CI job on `ubuntu-latest` pinned to the Python version installed on **both** machines
      (this machine: 3.14.5). Single version, not a matrix — borg ships to nobody and runs on two known machines.
  - Verify: the job exists, runs `make lint` and `make test`, and blocks merge.
- [x] **T5** — Coverage reported, with **no threshold gate initially.** Record the starting number honestly.
  - Verify: `coverage report` runs in CI; the baseline percentage is written into the PR body.
  - A threshold set before a baseline exists gets set wrong and then disabled.
  - **Deviation, recorded 2026-08-12:** commit `488010d` set `--fail-under=90` in the Makefile's `test`
    target immediately, not after a baseline-only period, and no baseline number was ever written into a
    PR body (none opened yet on this branch). In practice this didn't bite — the migrated `recon` module
    landed at 96% — but the sequencing this item specifies was not followed. Flagging rather than silently
    checking this off as fully compliant.
- [x] **T6** — The rule is stated in `CLAUDE.md` under a new **Architecture Rules** heading, adjacent to Style
      Rules: *"Logic goes in a testable core. Shell is a wrapper. New modules ship with tests in the same
      commit."* Plus a `borg-plan` skill extension at
      `~/.config/borg/extensions/skill-extensions/borg-plan/02-output.md` requiring a **Testability** section in
      every generated `PROJECT_PLAN.md`.
  - Verify: `grep -A3 'Architecture Rules' CLAUDE.md`; run `/borg-plan` on a throwaway objective and confirm the
    emitted plan contains a Testability section.
  - The extension point already exists for exactly this. Use it rather than hoping a CLAUDE.md line gets read. The
    normative wording must name no language, so it ports unchanged to dbt/Snowflake/TS repos.

**Re-verified 2026-08-12** (checkboxes above were never ticked despite the work landing across commits
`86e29e9`/`488010d` and prior sessions — corrected here, no new work performed except T5's deviation note):
T1 `pyproject.toml` has all three sections scoped to `borg_core/`. T2 `Makefile` has all four targets; CI's
`python` job calls `make lint`/`make test`, not inline commands. T3 `pylint-clean-architecture==1.5.2` is
pinned with `visibility_enforcement = true`. T4 the `python` CI job pins 3.14, runs alongside the other
three jobs with nothing marking it non-blocking. T6 both the `CLAUDE.md` Architecture Rules heading and the
`borg-plan` `02-output.md` Testability extension exist verbatim as specified.

## Part 2 — GATE: bring the existing Python under test

**`merge-tree/` has 1,349 lines of Python with zero tests, no `pyproject.toml`, and no `conftest.py`.** An earlier
draft cited that as precedent for Python being safe; a blind review correctly refuted it — it is the same
undisciplined-shipping problem in a second language, and therefore evidence *for* Part 1, not for Part 3.

- [x] **P1** — `curate.py` under test first: pure transformation, no I/O, the easiest honest win. ≥80% on that
      module.
  - Verify: `coverage report --include='merge-tree/curate.py'` ≥ 80%.
- [x] **P2** — `numeric_urgency`, `chain_refs`, and `bucket_for` have tests covering **edge cases**, not happy
      paths: `urgency` absent, `urgency` already numeric (the pass-through branch), an unrecognised urgency word,
      `state` absent.
  - Verify: those cases exist as named tests.
  - **Found while reading this code on 2026-08-11:** `bucket_for` reads `urgency` as a *string* while
    `numeric_urgency` writes it as a *number*, and `curate()` is correct only because it passes the raw `it`
    (line 108) before overwriting `cur["urgency"]` (line 109). Pass `cur` instead, or swap those two lines, and
    **`needs-you` silently stops firing forever** — no error, no type complaint, green suite. A test asserting
    `needs-you` is assigned for `urgency: "now"` is the guard, and it does not exist. Once `mypy` gates, consider
    modelling the two pipeline stages as **distinct types** so the transition is unrepresentable rather than
    merely tested.
- [x] **P3** — `render_graph.py`'s derivation helpers (`derive_project`, the meter computation) under test.
      Rendering/HTML output is explicitly **not** in scope — assert on derived data, not markup.
  - Verify: tests exist for the derivation functions; no test asserts on HTML strings.
- [x] **P4 — GATE.** If P1–P3 cannot be completed, **Part 3 does not begin.** A maintainer who cannot get tests
      onto 1,349 existing lines will not get them onto 4,000 new ones, and the migration would relocate untestable
      code into a language where that is no longer excusable.
  - **Re-verified 2026-08-12** (P1–P4 boxes were never ticked despite the work existing — corrected here):
    `test_curate.py` (56 tests) covers `curate.py` at **99%** (107 stmts, 1 miss), well past the 80% bar,
    including the exact edge cases P2 names — `test_urgency_absent_falls_back_to_fyi_base`,
    `test_urgency_already_numeric_is_passthrough`, `test_unrecognised_urgency_word_falls_back_to_fyi_base`,
    and critically `test_numeric_urgency_never_equals_now_string_no_crash` /
    `test_item_with_urgency_now_is_assigned_needs_you_bucket`, which is the regression guard for the exact
    `bucket_for`-reads-string / `numeric_urgency`-writes-number bug this section documented finding.
    `test_render_graph.py` (46 tests) covers `derive_project`/entry-selection/meter-count derivation
    functions; the one assertion resembling markup (`esc("<script>")`) tests HTML-escaping logic, not
    rendered output, so P3's "no test asserts on HTML strings" holds. Full merge-tree suite: 102/102 passing.
    The gate was in fact satisfied before Part 3 began — it was just never marked as such, which read as
    if Part 3 had started with the gate unchecked. It hadn't; the paperwork was just behind the work.

## Part 3 — The migration (strangler, not rewrite)

### Non-negotiables
- **No rewrite.** Big-bang rewriting a 2,700-line file whose safety net is the thing being fixed is how this goes
  wrong. Command by command.
- **Parity is proven by a suite, not asserted.** `tests/cli_contract.bats` — 12 black-box tests invoking the real
  CLI, language-agnostic by design — is the parity harness. **It lands in PR #115; Part 3 is blocked on that
  merging.** Grow it before migrating, not after.
- **`borg` stays a zsh entry point.** `borg.zsh` keeps owning argv and delegates. Muscle memory, tmux integration,
  and hook contracts are untouched.

### Criteria
- [x] **C1** — `borg_core/` laid out in the layers `pylint-clean-architecture` understands — domain / usecase /
      infrastructure — so the Silent Core Rule and DI checks apply from the first commit rather than being
      retrofitted.
  - Verify: the package tree has those layers; `make lint` passes with `visibility_enforcement = true`.
  - **Superseded 2026-08-12:** a same-day research pass (`docs/research/2026-08-12-clean-architecture-
    for-ai-agents/`, three rounds of independent blind review, one empirical spike against real code)
    found the 4-directory layout carries a measured AI-agent correctness penalty. Shipped instead: one
    `borg_core/<command>/` folder per command, `core.py` (pure logic, `module_map`-tagged Domain layer)
    + `shell.py` (all I/O), colocated tests — same Silent Core Rule enforcement (`W9004` fires on raw
    I/O in `core.py`, confirmed zero findings), same DI-in-spirit boundary, without the forced
    directory depth. See `recommendation.md` in that research directory for the full option analysis.
  - Verify (revised): `make lint` passes with `visibility_enforcement = true`; `pylint
    --load-plugins=clean_architecture_linter borg_core/recon/core.py` shows zero `W9004` findings.
- [x] **C2** — Infrastructure adapters wrap every external call (`git`, `gh`, `tmux`, `docker`, `jq`, filesystem)
      behind an interface the domain depends on abstractly. This is what makes the core testable without
      subprocesses.
  - Verify: `grep -rn 'subprocess' borg_core/domain borg_core/usecase` returns nothing.
  - **Superseded 2026-08-12:** same architecture pivot as C1 — no `domain`/`usecase` directories exist.
    The boundary is `core.py` (zero I/O) vs. `shell.py` (all I/O — subprocess, filesystem, adapter
    discovery), enforced by `module_map` + `allowed_prefixes`, not by directory-scoped DI.
  - Verify (revised): `grep -n '^import subprocess\|^from subprocess'
    borg_core/recon/core.py` returns nothing (the module's own docstring and comments legitimately
    discuss subprocess-avoidance in prose, so a bare-word grep false-positives; check for an actual
    import statement instead). `pylint --load-plugins=clean_architecture_linter
    borg_core/recon/core.py` showing zero `W9004` findings is the authoritative check either way.
- [x] **C3** — `typer` is **lazily imported**, never at module top level in any path a hook could reach.
  - Verify: `python3 -c "import borg_core"` does not pull typer into `sys.modules`.
  - Measured at 12.0 ms of the 59.6 ms figure above. Free to recover.
  - **Superseded 2026-08-12:** `typer` was declared dev-only and never provisioned by `install.sh`,
    so `cmd_recon`'s unconditional dispatch would `ModuleNotFoundError` on a real install. Replaced
    with stdlib `argparse` — no CLI framework import at all, so this criterion is vacuously
    satisfied. See the migration ledger.
- [x] **C4** — The contract suite covers **every** command `borg.zsh` dispatches, before any command is migrated.
  - Verify: every arm of `borg.zsh`'s top-level `case` has at least one `cli_contract.bats` test.
  - Done (commit `7fdaf79`, prior session): checkbox was never ticked at the time despite the work
    landing — corrected here, no new work performed.
- [x] **C5** — **One** command migrated end to end as the pattern-setter, its zsh implementation **deleted** (not
      left dormant). Recommend `borg recon`: already portable sh, has a JSON contract, most recently bug-ridden,
      clearest input/output boundary.
  - Verify: `grep -c 'cmd_recon' borg.zsh` returns 0; `borg recon --adapters` still passes its contract test;
    `coverage report` shows the migrated module ≥90%.
  - Done 2026-08-12: `lib/recon.sh`, `lib/recon.zsh`, and `tests/recon.bats` deleted (both bats suites had
    already passed unchanged against the Python port — the testing-discipline gate); `cmd_recon` inlined into
    the `recon)` case arm so no dormant/duplicate function name remains; coverage 96%.
  - **Extended 2026-08-12: `add`/`rm` migrated as the second command** (`borg_core/registry/{core,shell,cli}.py`,
    97% coverage). `cmd_add`/`cmd_rm` deleted from `borg.zsh`. Sequenced ahead of `link` (blocked on the
    independent link-unification directive landing in zsh first) and ahead of `scan` (not actually "registry
    CRUD, pure logic" as the sequencing note below assumed — it's a multi-source discovery engine wrapping
    unported `claude.zsh`/`coco.zsh`/`desktop.zsh` and an LLM-summarizer subprocess; deserves its own pass).
    Went through the same adversarial-review discipline as `recon`: an independent 3-lens review found 7
    distinct real issues (1 blocker — a timezone bug that silently changed stored data — plus 6 real-but-
    minor/nitpick items), 6 fixed, 1 accepted as an existing track-wide precedent. Full record in
    `docs/plans/assimilated/2026-08-12-recon-migration-ledger.md`'s "`add`/`rm` migration" section.
- [x] **C6** — A migration ledger records, per command: migrated / not-migrated / deliberately-staying-shell, with
      a one-line reason. Hooks are listed as **deliberately-staying-shell** with the latency measurement as the
      reason.
  - Verify: the ledger exists and every `case` arm in `borg.zsh` appears in it.
  - `docs/plans/assimilated/2026-08-12-recon-migration-ledger.md`.
- [x] **C7** — Regression: the full bats suite and the macOS contract leg stay green at every step.
  - CI confirmed on PR #120: `lint`, `python`, and `contract-macos` jobs all green. The ubuntu `test`
    job (full bats suite) failed on 6 tests (`nanoprobes`/`nanoprobe-log`/`regenerate` fixtures) —
    confirmed pre-existing and unrelated: the identical 6 tests failed on `main`'s prior CI run
    (commit `7fdaf79`, before this branch's work started). Local macOS: `bats tests/*.bats` 585/585
    green. Checked off on CI evidence, not local-only, per this item's own instruction — the failing
    leg is a known, pre-existing gap this work didn't introduce or worsen.

### Sequencing after C5

**Revised 2026-08-12.** Originally: `recon` → `link` → `next` → `scan`/`add`/`rm` (as one bundled
"registry CRUD, pure logic" item) → `nanoprobes`/`spend`/`watch` → `switch`/`focus`/`init` last.
Two corrections found while starting the `link` step:

- **`link` is blocked, not next.** A separate, independent, unstarted directive
  (`docs/plans/directives/2026-08-11-link-unification-and-layout.md`) redesigns `cmd_link`'s
  output contract (`--json`, bottom-anchored layout, idle collapse) while it's still in zsh.
  Porting today's `cmd_link` to Python now would likely be thrown away once that directive lands.
  Revisit `link`'s Python port only after that directive ships.
- **`scan` isn't "registry CRUD, pure logic."** It's a multi-source discovery engine (Claude/CoCo/
  Desktop session scanning) that shells out to an LLM summarizer and depends on
  `claude.zsh`/`coco.zsh`/`desktop.zsh`, none of which are ported. It deserves its own migration
  pass, not a bundled third item alongside `add`/`rm`.

**Current order:** `recon` → `add`/`rm` (done 2026-08-12) → `next` → `scan` (own pass) →
`nanoprobes`/`spend`/`watch` → `link` (once link-unification ships) → `switch`/`focus`/`init` last
— tmux-interactive, least benefit, highest shell affinity.

## Scope Boundaries
- **NOT porting hooks.** Verified arithmetic. Recorded permanently in C6.
- **NOT adopting a Python packager/binary.** No startup benefit. Revisit only for venv-drift convenience.
- **NOT building a daemon + thin client.** The only thing that would change the arithmetic; deliberately deferred.
- **NOT porting `drone.zsh`.** 1,044 lines of container/tmux orchestration — least logic, most shell affinity.
- NOT adding coverage tooling to the remaining zsh. It does not exist; that is the premise.
- NOT setting a coverage threshold before a baseline exists.
- NOT a Python version matrix. Two known machines.
- NOT changing user-facing command names or output during migration. Parity first, improvements after.
- If done early: ship Part 1 and stop. Do not batch-migrate on momentum.

## Ship Definition
**Part 1:** `pyproject.toml` + `Makefile` + `python` CI job green + CLAUDE.md entry + borg-plan extension;
coverage baseline in the PR body.
**Part 2:** `curate.py` ≥80%, the `needs-you` guard test present, gate cleared.
**Part 3:** `borg_core/` scaffolded in enforced layers, contract suite complete, `recon` migrated, ledger committed.

## Timeline
Part 1: one session, and worth doing even if nothing else follows. Part 2: one to two sessions. Part 3: C1–C5 is
2–3 sessions; the full command surface is an open-ended background track.

## Risks
- **Part 1 without Parts 2–3 is still a win; the reverse is not.** If time runs short, the toolchain and the
  Makefile are the durable half.
- **The migration's safety net is the thing being fixed.** Mitigated by C4's ordering — grow the contract suite
  *before* migrating. Skip it and this becomes the most dangerous change in the repo's history.
- **`pylint-clean-architecture` is single-maintainer (Noah's own).** Fine for a personal tool, worth naming: if it
  breaks against a future pylint, Noah is the one who fixes it. Pin the version.
- **The layered structure could become ceremony on a small codebase.** Three layers for a CLI that mostly shells
  out to `gh` can read as over-engineering. The honest test is whether the domain layer ends up holding real
  logic; if after `recon` and `link` it is a pass-through, collapse it rather than defending it.
- **Python startup could bite in an unanticipated hot path.** Anything invoked in a loop, by a launchd agent on a
  short interval, or by a tmux status-line refresh must be measured before porting. The four launchd agents are
  the ones to check — `cortex-wake` at a 30-second interval is the most exposed.
- **Dependency fragility in containers.** borg runs on the host, but drone containers bind-mount `~/.config/borg`.
  If any in-container path needs `borg_core`, a missing venv breaks it in a way a zsh script never would. Keep the
  Python core host-only, or vendor/pin ruthlessly.
- **Two languages, permanently.** Shell hooks plus a Python core is the settled end state, not a waypoint. C6's
  ledger is the mitigation and is not optional.
- **Python 3.14 is recent.** Pinning CI to it assumes dependency support. If `typer`/`pylint`/`ruff` lag, pin to
  the highest version both machines and the dependency set agree on, and record which constraint bound.
- **The base rate is thin.** Three bugs in one deliberately portability-focused day is not a measured defect rate.
  This directive's honest justification is Part 1's rule plus maintainer ergonomics — stated so the judgment is
  visible rather than smuggled in as a finding.

## Additional Work Shipped (beyond the acceptance criteria)

- **`add`/`rm` migrated as a second command**, beyond C5's one-command minimum. Chosen over the
  originally-sequenced `link` (blocked on an independent, unstarted link-unification directive
  that will redesign its output contract) and `scan` (miscategorized in the original sequencing
  note as "registry CRUD, pure logic" — it's actually a multi-source discovery engine with real,
  unported dependencies). `borg_core/registry/{core,shell,cli}.py`, 97% coverage.
- **Independent 3-lens adversarial review** (parity/bugs/scope, each finding separately
  re-verified) of the `add`/`rm` migration found 7 distinct real issues, including a blocker: the
  first draft's `file_mtime_iso` computed genuine UTC where zsh's `stat -f %Sm` actually wrote
  local time mislabeled as UTC — and the reaper's own `-u`-forced read-side mis-parse had been
  silently cancelling that out. Fixed 6 issues; left one (bare/unstyled CLI output) as an accepted
  precedent already set by the `recon` migration. Full record in the migration ledger.
- **PROJECT_PLAN.md accuracy pass:** Part 1 (T1-T6) and Part 2 (P1-P4) were substantively complete
  but never checked off — corrected with inline verification evidence. T5's coverage-threshold
  deviation (a threshold was set before a baseline existed, contrary to the item's own instruction)
  is documented rather than silently passed.
- **Unrelated fix:** corrected a stale status claim in the cairn-decommission directive's header —
  a memory-gate job the header said had "shipped" was never actually deployed via `borg setup`
  (plist/script exist in the repo but were never installed into launchd).
- **The Collective Review** (borg-collective-review) ran before shipping. Summary: work quality
  praised as exemplary by The Craftsperson (97% coverage, adversarial review caught a real
  blocker); The Scope Hawk flagged that migrating a second command exceeds C5's stated minimum,
  mitigated by an explicit user check-in (AskUserQuestion) before proceeding rather than
  unprompted momentum; The Back-End Architect flagged `borg_dir()` now duplicated verbatim between
  `borg_core/recon/shell.py` and `borg_core/registry/shell.py` — correctly left unextracted per
  rule-of-three, but should trigger extraction if a third command duplicates it. The Adult's
  verdict: ship.
- **Known follow-ups, not blockers:**
  1. If a third `borg_core/<command>` needs `borg_dir()`, extract it to a shared module instead of
     copying a third time.
  2. `borg add -h`/`borg rm -h` no longer print help text (reverted to zsh's literal-data
     treatment for parity). If help output is wanted, that should be a deliberate, tested,
     separately-shipped change — not folded back in as a side effect of touching this code again.
  3. C7's ubuntu `test` CI leg has 6 pre-existing, unrelated failures (confirmed present on `main`
     before this work started) — a real gap, not introduced or worsened here, but still open.
