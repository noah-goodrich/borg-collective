# Directive: Python Core + Toolchain + Enforced Clean Architecture
*Filed: 2026-08-11*

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

- [ ] **T1** — `pyproject.toml` at the repo root: `[tool.ruff]` with `line-length = 120`,
      `select = ["E", "F", "W", "C90"]`, `[tool.ruff.lint.mccabe] max-complexity = 10`; `[tool.mypy]` with
      `warn_return_any` and `warn_unused_configs`; `[tool.pytest.ini_options]` with `--strict-markers` and
      `unit`/`integration`/`functional` markers, slow tests excluded from default runs.
  - Verify: `ruff check`, `mypy`, `pytest` all run from config with no CLI flags.
  - `line-length = 120` matches the existing repo-wide 120-char rule for markdown and shell. One number for
    everything.
- [ ] **T2** — A `Makefile` with `clean` / `test` / `lint` / `format`, and **CI invokes those same targets.**
  - Verify: `.github/workflows/` calls `make lint` and `make test`, not inline commands.
  - **The highest-leverage item in this directive, which is why it is T2 and not housekeeping.** The 2026-08-11
    session found 161 assertions silently ignored on macOS for weeks because local and CI ran the suite
    differently. A Makefile makes "run the tests" have exactly one definition — it fixes a class of bug, not a
    style inconsistency.
- [ ] **T3** — `pylint-clean-architecture` (v1.5.2, PyPI, Python ≥3.9) as a dev dependency, gating in CI, with
      `[tool.pylint.main] load-plugins = ["clean_architecture_linter"]` and
      `[tool.clean-arch] visibility_enforcement = true`.
  - Verify: `make lint` runs pylint with the plugin loaded; CI fails on a deliberate violation.
  - **This is the answer to deliverable 2 — the rule — and Noah already built it.** Its **Silent Core Rule
    (W9013)**, requiring Domain and UseCase layers to be free of `print`, `logging`, and console I/O and to
    delegate to interfaces/adapters, *is* the testable-core rule mechanically enforced. Its dependency-injection
    checks, forbidding instantiation of infrastructure inside UseCases, are the other half. Nothing needs
    inventing; adopt the linter rather than writing a convention document.
- [ ] **T4** — A `python` CI job on `ubuntu-latest` pinned to the Python version installed on **both** machines
      (this machine: 3.14.5). Single version, not a matrix — borg ships to nobody and runs on two known machines.
  - Verify: the job exists, runs `make lint` and `make test`, and blocks merge.
- [ ] **T5** — Coverage reported, with **no threshold gate initially.** Record the starting number honestly.
  - Verify: `coverage report` runs in CI; the baseline percentage is written into the PR body.
  - A threshold set before a baseline exists gets set wrong and then disabled.
- [ ] **T6** — The rule is stated in `CLAUDE.md` under a new **Architecture Rules** heading, adjacent to Style
      Rules: *"Logic goes in a testable core. Shell is a wrapper. New modules ship with tests in the same
      commit."* Plus a `borg-plan` skill extension at
      `~/.config/borg/extensions/skill-extensions/borg-plan/02-output.md` requiring a **Testability** section in
      every generated `PROJECT_PLAN.md`.
  - Verify: `grep -A3 'Architecture Rules' CLAUDE.md`; run `/borg-plan` on a throwaway objective and confirm the
    emitted plan contains a Testability section.
  - The extension point already exists for exactly this. Use it rather than hoping a CLAUDE.md line gets read. The
    normative wording must name no language, so it ports unchanged to dbt/Snowflake/TS repos.

## Part 2 — GATE: bring the existing Python under test

**`merge-tree/` has 1,349 lines of Python with zero tests, no `pyproject.toml`, and no `conftest.py`.** An earlier
draft cited that as precedent for Python being safe; a blind review correctly refuted it — it is the same
undisciplined-shipping problem in a second language, and therefore evidence *for* Part 1, not for Part 3.

- [ ] **P1** — `curate.py` under test first: pure transformation, no I/O, the easiest honest win. ≥80% on that
      module.
  - Verify: `coverage report --include='merge-tree/curate.py'` ≥ 80%.
- [ ] **P2** — `numeric_urgency`, `chain_refs`, and `bucket_for` have tests covering **edge cases**, not happy
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
- [ ] **P3** — `render_graph.py`'s derivation helpers (`derive_project`, the meter computation) under test.
      Rendering/HTML output is explicitly **not** in scope — assert on derived data, not markup.
  - Verify: tests exist for the derivation functions; no test asserts on HTML strings.
- [ ] **P4 — GATE.** If P1–P3 cannot be completed, **Part 3 does not begin.** A maintainer who cannot get tests
      onto 1,349 existing lines will not get them onto 4,000 new ones, and the migration would relocate untestable
      code into a language where that is no longer excusable.

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
- [ ] **C1** — `borg_core/` laid out in the layers `pylint-clean-architecture` understands — domain / usecase /
      infrastructure — so the Silent Core Rule and DI checks apply from the first commit rather than being
      retrofitted.
  - Verify: the package tree has those layers; `make lint` passes with `visibility_enforcement = true`.
- [ ] **C2** — Infrastructure adapters wrap every external call (`git`, `gh`, `tmux`, `docker`, `jq`, filesystem)
      behind an interface the domain depends on abstractly. This is what makes the core testable without
      subprocesses.
  - Verify: `grep -rn 'subprocess' borg_core/domain borg_core/usecase` returns nothing.
- [ ] **C3** — `typer` is **lazily imported**, never at module top level in any path a hook could reach.
  - Verify: `python3 -c "import borg_core"` does not pull typer into `sys.modules`.
  - Measured at 12.0 ms of the 59.6 ms figure above. Free to recover.
- [ ] **C4** — The contract suite covers **every** command `borg.zsh` dispatches, before any command is migrated.
  - Verify: every arm of `borg.zsh`'s top-level `case` has at least one `cli_contract.bats` test.
- [ ] **C5** — **One** command migrated end to end as the pattern-setter, its zsh implementation **deleted** (not
      left dormant). Recommend `borg recon`: already portable sh, has a JSON contract, most recently bug-ridden,
      clearest input/output boundary.
  - Verify: `grep -c 'cmd_recon' borg.zsh` returns 0; `borg recon --adapters` still passes its contract test;
    `coverage report` shows the migrated module ≥90%.
- [ ] **C6** — A migration ledger records, per command: migrated / not-migrated / deliberately-staying-shell, with
      a one-line reason. Hooks are listed as **deliberately-staying-shell** with the latency measurement as the
      reason.
  - Verify: the ledger exists and every `case` arm in `borg.zsh` appears in it.
- [ ] **C7** — Regression: the full bats suite and the macOS contract leg stay green at every step.

### Sequencing after C5
Each its own PR: `recon` → `link` (biggest win: `--json` + the skill contract) → `next` → `scan`/`add`/`rm`
(registry CRUD, pure logic) → `nanoprobes`/`spend`/`watch`. Leave `switch`/`focus`/`init` last — tmux-interactive,
least benefit, highest shell affinity.

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
