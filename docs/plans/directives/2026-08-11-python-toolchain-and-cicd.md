# Directive: Python Toolchain + CI/CD + Enforced Clean Architecture
*Filed: 2026-08-11*

Independent project, intended for execution on Noah's personal machine. **Supersedes the open language question in
`2026-08-11-python-core-migration-and-testable-core-rule.md`** — that directive left Python-vs-Go unresolved
pending Noah's decision. It is resolved: **Python + shell.** Everything else in that directive (the strangler
sequencing, the M0 gate, the parity-suite ordering, the ledger) still stands.

## The decision, and the reasoning that survives scrutiny

**Stay with Python + shell.** Go and Rust are both ruled out, for a reason that is about the maintainer rather
than the code and is none the worse for it: Noah is fluent in neither, idiomatic Go is a genuinely different
paradigm from Python/PHP, and a whole-language conversion is a time investment that does not exist. A tool the
maintainer edits reluctantly is worse than one they edit fluently. That is the deciding argument.

## Correcting the premise: compiling Python to a binary does NOT fix startup

This needs to be recorded plainly so it is never re-litigated. The single-binary route was attractive partly
because it looked like it might close the startup gap and let hooks migrate too. **It does not.**

Researched 2026-08-11 (`docs/research/2026-08-11-python-single-binary-startup-latency.md`):

- **Every packager still boots a full CPython interpreter.** Nuitka, PyInstaller, cx_Freeze, PyApp, Cython entry
  points — all inherit interpreter-init cost. Several make it *worse*: one measured benchmark had a
  Nuitka-compiled script at **257 ms vs 152 ms** for the plain script, and PyInstaller `--onefile` re-unpacks its
  archive to a temp dir on **every run**.
- **PyOxidizer is dormant** — last commit 2024-11-03, no releases in over a year. Not viable for new adoption.
- **The "transpiles to a Rust binary" tool is `py2many`**, and it is a source-to-source transpiler restricted to a
  statically-typeable subset of Python. Dynamic decorators and C extensions are out of scope, which means
  **`typer`/`click` are not transpilable targets.** That road is closed for a Typer CLI. (Not to be confused with
  PyOxidizer, which merely *packages* CPython using Rust's toolchain, or RustPython, which is a separate
  non-production interpreter.)

### Measured on this machine, Python 3.14.5

| Command | Startup |
|---|---|
| `zsh -c true` | 27.3 ms |
| `bash -c true` | 27.9 ms |
| `python3 -c pass` | 47.6 ms |
| `python3 -S -c pass` | 41.1 ms |
| `python3 -S -E -c pass` | 40.9 ms |
| `python3 -c 'import typer'` | 59.6 ms |

**Correcting the published guidance:** historical benchmarks (Python 2.7/3.7, 2017) show `-S` roughly halving
startup, and that ratio is widely repeated. On 3.14 it recovers only **6.5 ms** — because 3.11+ already ships
frozen stdlib modules and captured most of that saving. Do not plan around the old ratio.

**Consequence — the hook boundary is arithmetic, not preference.** Python's practical floor here is ~41 ms
*before any borg code runs*, against zsh's ~27 ms ceiling. No flag, packager, or compiler closes that. The two
`PostToolUse` hooks fire on **every agent tool call**; at ~250 calls a session that is ~5 s of pure added latency
at best, for zero benefit. **Hooks stay shell, permanently, and this is now verified rather than assumed.**

The one mechanism that would genuinely reopen the question is a **persistent daemon + thin socket client**
(~0.1 ms per round trip). That is a real, stateful architecture change, not a packaging swap. **Explicitly out of
scope here** — recorded so the option is remembered rather than rediscovered.

### What a binary would actually buy

Not speed. Its honest benefit is **no venv drift across two machines** — one artifact instead of a per-machine
environment. For a two-machine personal tool that is a modest convenience, and `uv` with a locked venv is likely
simpler than adopting a packager. **Deferred, not adopted.** Revisit only if venv drift becomes a real annoyance.

## Part 1 — Adopt Noah's own established toolchain

This is not a new pattern to invent. It already exists across `pytest-coverage-impact`, `snowfort`, and
`pylint-clean-architecture`. Copy it rather than reinventing it.

### Acceptance Criteria

- [ ] T1 — `pyproject.toml` at the repo root, matching the established convention:
      `[tool.ruff]` with `line-length = 120`, `select = ["E", "F", "W", "C90"]`, and
      `[tool.ruff.lint.mccabe] max-complexity = 10`; `[tool.mypy]` with `warn_return_any` and
      `warn_unused_configs`; `[tool.pytest.ini_options]` with `--strict-markers` and the
      `unit`/`integration`/`functional` markers, slow tests excluded from default runs.
  - Verify: `ruff check`, `mypy`, and `pytest` all run from config with no CLI flags.
  - Note: `line-length = 120` matches the existing repo-wide 120-char rule for markdown and shell. One number
    for everything.
- [ ] T2 — A `Makefile` with `clean` / `test` / `lint` / `format`, and **CI invokes those same targets.**
  - Verify: `.github/workflows/` calls `make lint` and `make test`, not inline commands.
  - **This is the highest-leverage item in the directive and the reason it is T2 rather than an afterthought.**
    The 2026-08-11 session found 161 assertions that had been silently ignored on macOS for weeks because local
    and CI ran the suite differently. A Makefile makes "run the tests" have exactly one definition. Adopting it
    fixes a class of bug, not just a style inconsistency.
- [ ] T3 — `pylint-clean-architecture` (v1.5.2, PyPI, Python ≥3.9) is a dev dependency and gates in CI, with
      `[tool.pylint.main] load-plugins = ["clean_architecture_linter"]` and
      `[tool.clean-arch] visibility_enforcement = true`.
  - Verify: `make lint` runs pylint with the plugin loaded; CI fails on a deliberate violation.
  - **This is the answer to "how do we bake in the testable-core rule."** It is already built and published. Its
    **Silent Core Rule (W9013)** — Domain and UseCase layers must be free of `print`, `logging`, and console I/O,
    forcing delegation to interfaces/adapters — *is* the testable-core rule, mechanically enforced. Its
    dependency-injection checks forbid instantiating infrastructure inside UseCases, which is the other half.
    No new convention needs inventing; adopt the linter Noah already wrote.
- [ ] T4 — A `python` CI job on `ubuntu-latest` pinned to the Python version installed on **both** of Noah's
      machines (this machine: 3.14.5). Single version, not a matrix — borg ships to nobody and runs on two known
      machines, so a 3.10–3.13 matrix would buy nothing and cost minutes.
  - Verify: the job exists, runs `make lint` and `make test`, and blocks merge.
- [ ] T5 — Coverage is reported, with **no threshold gate initially.** Record the starting number honestly.
  - Verify: `coverage report` runs in CI and the baseline percentage is written into the PR body.
  - Rationale: a threshold set before a baseline exists gets set wrong and then disabled. Establish the number,
    then ratchet.

## Part 2 — Bring the existing Python under test (the M0 gate, restated)

Unchanged from the superseded directive, and still the gate: **`merge-tree/` currently has 1,349 lines of Python
with zero tests, no `pyproject.toml`, and no `conftest.py`.** A blind review correctly identified that citing it
as precedent was backwards — it is the same undisciplined-shipping problem in a second language.

- [ ] P1 — `curate.py` is brought under test first: pure transformation, no I/O, the easiest honest win. Target
      ≥80% on that module specifically.
  - Verify: `coverage report --include='merge-tree/curate.py'` ≥ 80%.
- [ ] P2 — The three functions with real branching logic — `numeric_urgency`, `chain_refs`, `bucket_for` — have
      tests covering their **edge cases**, not just their happy paths: `urgency` absent, `urgency` already
      numeric (the pass-through branch), an unrecognised urgency word, and `state` absent.
  - Verify: those cases exist as named tests.
  - **Found while reading this code on 2026-08-11:** `bucket_for` reads `urgency` as a *string* while
    `numeric_urgency` writes it as a *number*, and `curate()` is correct only because it passes the raw `it`
    (line 108) before overwriting `cur["urgency"]` (line 109). Pass `cur` instead, or swap those two lines, and
    `needs-you` silently stops firing forever — no error, no type complaint. **A test asserting `needs-you` is
    assigned for `urgency: "now"` is the guard, and it does not currently exist.** Consider modelling the two
    pipeline stages as distinct types once `mypy` is gating, so the transition is unrepresentable rather than
    merely tested.
- [ ] P3 — `render_graph.py`'s derivation helpers (`numeric_urgency`-adjacent logic, `derive_project`, the meter
      computation) are under test. Rendering/HTML output is explicitly **not** in scope — assert on derived data,
      not markup.
  - Verify: tests exist for the derivation functions; no test asserts on HTML strings.
- [ ] P4 — **Gate.** If P1–P3 cannot be completed, Part 3 does not begin.
  - Rationale: a maintainer who cannot get tests onto 1,349 existing lines will not get them onto 4,000 new ones.

## Part 3 — Structure `borg_core` for the linter to enforce

- [ ] C1 — `borg_core/` is laid out in the layers `pylint-clean-architecture` understands — domain / usecase /
      infrastructure — so the Silent Core Rule and the DI checks apply from the first commit rather than being
      retrofitted.
  - Verify: the package tree has those layers; `make lint` passes with `visibility_enforcement = true`.
- [ ] C2 — Infrastructure adapters wrap every external call — `git`, `gh`, `tmux`, `docker`, `jq`, filesystem —
      behind an interface the domain depends on abstractly. This is what makes the core testable without
      subprocesses.
  - Verify: `grep -rn 'subprocess' borg_core/domain borg_core/usecase` returns nothing.
- [ ] C3 — `typer` is **lazily imported**, not imported at module top level in any path a hook could reach.
  - Verify: `python3 -c "import borg_core"` does not pull in typer (check `sys.modules`).
  - Rationale: measured at 12.0 ms of the 59.6 ms figure above. Free to recover, and it keeps the option open of
    a Python entry point that is merely slow rather than unusable.
- [ ] C4 — Migration proceeds command-by-command per the superseded directive's sequencing (`recon` first), with
      `tests/cli_contract.bats` (PR #115) grown to cover every dispatched command **before** any migration. That
      suite is language-agnostic by design and is the parity net.

## Scope Boundaries
- **NOT porting hooks to Python.** Verified arithmetic, not preference. Recorded permanently.
- **NOT adopting a Python packager/binary.** No startup benefit; revisit only for venv-drift convenience.
- **NOT building a daemon + thin client.** The only thing that would change the startup arithmetic, and a real
  architecture change. Recorded as a known option, deliberately deferred.
- **NOT porting `drone.zsh`.** 1,044 lines of container/tmux orchestration — least logic, most shell affinity.
- NOT setting a coverage threshold before a baseline exists.
- NOT a Python version matrix. Two known machines.
- If done early: ship Part 1 and stop. Part 1 pays for itself independent of any migration.

## Ship Definition
Part 1: `pyproject.toml` + `Makefile` + `python` CI job green, coverage baseline recorded in the PR body.
Part 2: `curate.py` ≥80%, the `bucket_for`/`needs-you` guard test present, gate cleared.
Part 3: `borg_core/` scaffolded in enforced layers with `recon` migrated.

## Timeline
Part 1: one session, and it is worth doing even if nothing else follows. Part 2: one to two sessions. Part 3:
open-ended background track.

## Risks
- **Part 1 without Parts 2–3 is still a win; the reverse is not.** If time runs short, the toolchain and the
  Makefile are the durable half. Do them first and resist starting `borg_core` early.
- **`pylint-clean-architecture` is single-maintainer (Noah's own).** That is fine for a personal tool and worth
  naming: if it breaks against a future pylint, Noah is the one who fixes it. Pin the version.
- **The layered structure could become ceremony on a small codebase.** Three layers for a CLI that mostly shells
  out to `gh` can read as over-engineering. The honest test is whether the domain layer ends up with real logic
  in it; if after `recon` and `link` it is a pass-through, collapse it rather than defending it.
- **Two languages remain, permanently.** Shell hooks plus a Python core is the settled end state, not a waypoint.
  A reader must know where the boundary is; the superseded directive's migration ledger is the mitigation and
  still applies.
- **Python 3.14 is recent.** Pinning CI to it assumes dependency support. If `typer`/`pylint`/`ruff` lag, pin to
  the highest version both machines and the dependency set agree on, and record which constraint bound.
