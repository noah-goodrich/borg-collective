# Directive: Migrate the Core to Python/Typer + Establish the Testable-Core Rule
*Filed: 2026-08-11*

Long-horizon architectural directive. Option **C** from the 2026-08-11 testing-posture design study. Independent
work — no parent plan. **Intended to be executed on Noah's personal machine**, which is why it ships as a
standalone branch and PR.

## Objective
Two deliverables, in this order of durability:

1. **The rule** — a standing, mechanically-enforced convention that new code in *any* borg-managed project is
   written with a **fully testable core**: logic in importable, unit-testable units; shell reduced to a thin
   invocation wrapper. This outlives any particular migration.
2. **The migration** — move borg's CLI core from ~4,242 lines of zsh to Python with
   [Typer](https://typer.tiangolo.com/), keeping zsh as the wrapper, by strangler pattern rather than rewrite.

## Why — the evidence, not a preference

borg grew from a small zsh script into a ~7,800-line application without acquiring any of the guardrails an
application needs. The 2026-08-11 session found **three separate bugs in one day**, and every one was a
shell-idiom failure that no test could have caught in the language it was written in:

| Bug | Root cause | Why untestable in shell |
|---|---|---|
| #113a | `${BASH_SOURCE[0]:-$0}` resolved to `.` | `BASH_SOURCE` is a bash array; **empty in zsh** |
| #113b | `IFS=:; set -- $var` yielded 1 element, not 2 | **zsh does not word-split** unquoted expansions |
| #114 | `stat -f %m \|\| stat -c %Y` captured garbage | GNU `stat -f` prints to **stdout** before failing |

Each was invisible to the test suite by construction, and the tooling gap is permanent, not incidental:

- **No coverage tool exists for zsh.** kcov and bashcov instrument bash's xtrace; neither claims zsh support and
  no zsh-native equivalent was found. **4,242 LOC — 54% of the codebase — is unmeasurable.**
- **shellcheck refuses zsh** and has since 2016; its maintainer judged the parser work too costly. Forcing
  `-s bash` is documented (SC1071) as giving *false safety on exactly the word-splitting class above*.
- **Mature shell mutation testing does not exist.** In Python, `mutmut` automates "would a broken
  implementation actually fail this test." There is no shell equivalent, so assertion strength stays discipline.
- **macOS ships bash 3.2.57 (2007).** Its `set -e` silently ignores non-final `[[ ]]`, which hid 161 assertions
  until 2026-08-11.

Python has mature answers to all four — `pytest`, `coverage`, `mypy`, `mutmut`, `ruff` — which exist and run
identically on every platform.

**But do not mistake available tooling for adopted tooling.** Corrected after blind review: `merge-tree/` contains
**1,349 lines of Python with zero tests, no `pyproject.toml`, and no `conftest.py`** — verified by repo inspection.
An earlier draft of this directive cited that as "the precedent and the toolchain are in-repo." That was **false**,
and the reviewer's reading of it is the more useful one: it is the same undisciplined-shipping problem restated in
a second language. The existing Python is evidence *for* Part 1 (the rule), not evidence that Part 2 is safe.

Which is why **M0 below tests that existing Python first.** If the rule cannot be made to hold on 1,349 lines that
already exist, it will not hold on 4,000 more.

### Which of the three motivating bugs this actually prevents

Stated precisely, because "migrate to Python" does not uniformly imply "these bugs go away":

**#113a — `BASH_SOURCE` empty in zsh.** Lived in `lib/recon.sh:30` (`_recon_lib_dir`). Migrates under M3.
**Prevented** — Python has no `BASH_SOURCE` analogue to get wrong.

**#113b — zsh does not word-split unquoted expansions.** Lived in `lib/recon.sh`
(`_recon_discover_adapters`). Migrates under M3. **Prevented** — `str.split(":")` has exactly one behavior.

**#114 — `stat` fallback captured stdout.** Lived in three places: `borg.zsh`, `lib/recon.sh`, **and
`hooks/borg-link-up.sh`**. The first two migrate; the hook does not, by design. **Partially prevented** —
`os.stat().st_mtime` fixes the migrated copies; the hook keeps its shell exposure permanently.

**Two of three fully, one partially.** The blind review argued bug (a) was structurally exempted because it lived
in the wrapper — that is incorrect on the specifics (it lived in a portable-sh lib, which migrates), but the
general concern is sound: any logic that stays in `borg.zsh` or the hooks keeps its shell-idiom exposure
permanently. The honest claim is "this removes the exposure from the migrated surface," not "this fixes shell bugs."

## The measured constraint that sets the migration boundary

Benchmarked on this machine (arm64 macOS, 20 runs each):

| Interpreter | Startup |
|---|---|
| `zsh -c true` | 23.2 ms |
| `bash -c true` | 22.0 ms |
| `python3 -c pass` | 48.4 ms |
| `python3 -c 'import typer'` | **57.1 ms** |

**+34 ms per invocation.** At 57 ms total, that sits under the ~100 ms threshold conventionally treated as
"instant" for direct manipulation, so it should be imperceptible for a human typing `borg link` — though note this
is a reference point, not a measurement of *this* CLI, and **looped or scripted invocation was not measured.**
Anything that calls `borg` in a loop would multiply it. It is **not** imperceptible for hooks:
`borg-memory-read-log.sh` and `tool-count-nudge.sh` are `PostToolUse` hooks that fire on **every tool call**. A
250-call session would pay ~17 extra seconds of pure latency, felt as sluggishness, for no benefit — the hooks are
small (the largest non-guard hook is 378 lines), already tested, and already shellcheck-clean.

**Therefore the boundary is: CLI logic → Python. Hooks stay shell.** This is a deliberate, measured split, not an
unfinished migration. Record it so nobody "completes" it later by porting the hooks.

## Blind adversarial review (D5) — verdict: **REVISE**

A reviewer was given the problem, the option set, and the chosen option, but **not** the reasoning for why it won.
Verdict: **REVISE** — Part 1 sound as written; Part 2's mechanics good *conditional on Python being the right
target*, a conditional never tested against the strongest competitor.

**Strongest objection, verbatim:**

> "the precedent and the toolchain are in-repo" is false — this repo currently has 1,349 lines of Python with zero
> tests and no `pyproject.toml`, which is the same undisciplined-shipping problem the directive exists to solve,
> restated in a second language.

**Accepted and acted on:** the false precedent claim is corrected above and converted into gate **M0**; the
`cli_contract.bats` tense error is corrected and the #115 dependency stated; `mypy`/`ruff` are now gating in M1;
the +34 ms claim is labelled as a reference point with the unmeasured looped case named; per-bug prevention is now
accounted for precisely.

**Rejected on the specifics:** the review argued bug (a) is "structurally exempted" because it lives in the
wrapper. It lives in `lib/recon.sh:30`, a portable-sh lib that migrates under M3. The general concern — that
anything staying in `borg.zsh` or the hooks keeps its shell-idiom exposure forever — is accepted and stated.

**Open, and Noah's call — the option the study genuinely missed:**

> A compiled single-binary language (Go/Rust) dominates C on every axis the directive itself uses.

This is the review's best point and it is not resolved here. On this directive's *own* stated criteria a compiled
binary wins: near-zero startup means the hook/CLI boundary — which this directive calls a permanent, load-bearing
split — **would not need to exist**, so hooks could migrate too and the "two languages forever" risk disappears;
`go test`/`go vet`/`gremlins` cover the same tooling gap; and a static binary removes the container
dependency-fragility risk named below entirely.

The counter-argument, which the reviewer could not see because it is about the maintainer rather than the code:
**Noah works in Python daily** (dbt, Snowflake, data engineering) and requested Typer explicitly. A Go binary he
edits reluctantly is worse than Python he edits fluently, and maintainability-by-the-actual-maintainer is the whole
justification for this directive. That is a real argument, but it is a *preference* argument, and it should be made
knowingly rather than by omission. **Decide this before M1.** M0 is language-agnostic and worth doing either way.

**Also recorded:** the review notes three bugs in one deliberately portability-focused day is a thin base rate for
a multi-month architecture bet, and no historical bug-frequency data is offered. True. This directive's honest
justification is Part 1's rule plus developer ergonomics — not a measured defect rate.

## Part 1 — The Testable-Core Rule (do this first; it is cheap and it compounds)

### Acceptance Criteria
- [ ] R1 — The rule is written once, canonically, covering: (a) logic lives in importable units with no side
      effects at import time; (b) shell is a wrapper that parses argv and calls one entry point; (c) any new
      module ships with tests in the same commit; (d) I/O and subprocess calls are injected or isolated so the
      logic is testable without them.
  - Verify: the document exists and CLAUDE.md links to it.
- [ ] R2 — The rule is **mechanically injected into every future plan**, not just documented. Ship a `borg-plan`
      skill extension at `~/.config/borg/extensions/skill-extensions/borg-plan/02-output.md` that requires every
      `PROJECT_PLAN.md` to carry a **Testability** section naming: what the testable core is, what the wrapper is,
      and which acceptance criterion proves the core is tested.
  - Verify: run `/borg-plan` on a throwaway objective; the emitted plan contains a Testability section.
  - Rationale: this is the mechanism the architecture already provides for exactly this (`borg-plan` reads
    `01-context` / `02-output` / `03-followup` from a machine path and a project path). Use it rather than hoping
    a CLAUDE.md line gets read.
- [ ] R3 — The rule is stated in `CLAUDE.md` under a new **Architecture Rules** heading, adjacent to Style Rules,
      with the one-line version: *"Logic goes in a testable core. Shell is a wrapper. New modules ship with tests
      in the same commit."*
  - Verify: `grep -A3 'Architecture Rules' CLAUDE.md`.
- [ ] R4 — The rule is portable to other projects: it does not name borg, Python, or Typer in its normative
      clauses, so it applies unchanged to a dbt repo, a Snowflake repo, or a TypeScript one.
  - Verify: read R1's document; the normative section mentions no specific language.

## Part 2 — The Python/Typer Migration (strangler, not rewrite)

### Non-negotiables
- **No rewrite.** A big-bang rewrite of a 2,717-line file whose safety net is the thing being fixed is how this
  goes wrong. Migrate command by command.
- **Behavior parity is proven by a suite, not asserted.** `tests/cli_contract.bats` — 12 black-box tests that
  invoke the real CLI and do not care what language implements it — is the parity harness. **It is not on `main`
  yet**; it lives in PR #115. Corrected after blind review, which rightly flagged that an earlier draft described
  it in the present tense as though it had landed. **Part 2 is therefore blocked on #115 merging.** Grow it before
  migrating, not after.
- **`borg` stays a zsh entry point.** `borg.zsh` keeps owning argv and delegates to `python -m borg_core …`.
  Existing muscle memory, tmux integration, and hook contracts are untouched.

### Acceptance Criteria
- [ ] **M0 — GATE. Test the Python that already exists, before writing any new Python.** Stand up
      `pyproject.toml` + `pytest` + `coverage` + `ruff` + `mypy` and bring `merge-tree/`'s existing 1,349 lines
      under test, starting with `curate.py` (pure transformation, the easiest honest win) and `render_graph.py`'s
      derivation helpers. **If this gate cannot be cleared, Part 2 does not begin** — a maintainer who cannot get
      tests onto 1,349 existing lines will not get them onto 4,000 new ones, and the migration would move
      untestable code into a language where that is no longer excusable.
  - Verify: `pytest` collects and passes ≥1 test per `merge-tree/*.py`; `coverage report` shows ≥60% on
    `curate.py`; `ruff check` and `mypy` both exit 0 in CI.
  - Rationale: this criterion exists because the blind review correctly refuted the claim that Python precedent
    made this safe. It converts the strongest objection into the plan's first deliverable.
- [ ] M1 — A `borg_core/` Python package exists with Typer as the CLI framework, reusing the toolchain M0 stood
      up. **`mypy` and `ruff` are gating in CI, not aspirational** — the review flagged that an earlier draft
      asserted them in prose while only verifying `pytest`/`coverage`.
  - Verify: `pytest` passes; `coverage report` emits a number; `ruff check` exits 0; `mypy borg_core` exits 0;
    all three run in a CI `python` job that blocks merge.
- [ ] M2 — The contract suite is grown to cover **every** command `borg.zsh` dispatches, before any command is
      migrated. This is the parity net.
  - Verify: every case in `borg.zsh`'s top-level `case` statement has at least one `cli_contract.bats` test.
- [ ] M3 — **One** command is migrated end to end as the pattern-setter, with its zsh implementation deleted (not
      left dormant). Recommend `borg recon` — it is already portable sh with a JSON contract, is the most
      recently bug-ridden, and has the clearest input/output boundary.
  - Verify: `grep -c 'cmd_recon' borg.zsh` returns 0; `borg recon --adapters` still passes its contract test;
    `coverage report` shows the migrated module ≥90%.
- [ ] M4 — A migration ledger records, per command: migrated / not-migrated / deliberately-staying-shell, with a
      one-line reason. Hooks are listed as **deliberately-staying-shell** with the latency measurement as the
      reason.
  - Verify: the ledger file exists and every `case` arm in `borg.zsh` appears in it.
- [ ] M5 — Regression: the full bats suite and the macOS contract leg stay green at every step.
  - Verify: `gh pr checks` green on each migration PR.

### Sequencing after M3
Migrate in this order, each its own PR: `recon` → `link` (the biggest win: `--json` + the skill contract) →
`next` → `scan`/`add`/`rm` (registry CRUD, pure logic) → `nanoprobes`/`spend`/`watch` → leave
`switch`/`focus`/`init` last (tmux-interactive, least benefit from porting, highest shell affinity).

## Scope Boundaries
- **NOT porting hooks.** Measured +34 ms × every tool call. Recorded as a permanent decision in M4.
- **NOT porting `drone.zsh`** in this directive. It is 1,044 lines of container/tmux orchestration — the layer
  with the least logic and the most shell affinity. Revisit only after `borg` is migrated.
- NOT adding coverage tooling to the remaining zsh. It does not exist; that is the premise of this directive.
- NOT changing user-facing command names or output in the migration. Parity first; improvements after.
- If done early: ship the pattern-setter and stop. Do not batch-migrate on momentum.

## Ship Definition
Part 1: rule document + `borg-plan` extension + CLAUDE.md entry, merged. Part 2: `borg_core/` scaffolded with CI
green, contract suite covering all commands, one command fully migrated, ledger committed.

## Timeline
Part 1: one session. Part 2: M1–M3 is 2–3 sessions; the full command surface is a multi-month background track,
deliberately unbounded. **Part 1 is worth doing even if Part 2 never happens.**

## Risks
- **The migration's safety net is the thing being fixed.** Mitigated by M2 ordering — grow the contract suite
  *before* migrating. If M2 is skipped, this directive becomes the most dangerous change in the repo's history.
- **Python startup could still bite in an unanticipated hot path.** Anything invoked in a loop, by a launchd
  agent on a short interval, or by tmux status-line refresh must be measured before porting, not assumed. The
  four launchd agents (`notifyd`, `cortex-wake` at 30s, `reap` hourly, `usage-watch`) are the ones to check —
  `cortex-wake` at a 30-second interval is the most exposed.
- **Dependency fragility in containers.** `borg` runs on the host, but drone containers bind-mount `~/.config/borg`
  and skills read those files. If any in-container path ends up needing `borg_core`, a missing venv breaks it in a
  way a zsh script never would. Keep the Python core host-only, or vendor/pin ruthlessly.
- **Two languages during migration is genuinely worse than one.** For the duration, a reader must know where the
  boundary is. The M4 ledger is the mitigation and is not optional.
- **This is a large bet justified partly by developer ergonomics, not only by defect data.** Three bugs in one
  day is real evidence; "maintainability would be infinitely better" is a judgment. Stated plainly so the
  judgment is visible rather than smuggled in as a finding.
