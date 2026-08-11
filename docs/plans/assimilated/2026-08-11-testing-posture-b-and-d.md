# Project Plan: Testing Posture — Trustworthy Signal + Real-Runtime Coverage
*Established: 2026-08-11*
Shipped: 2026-08-11 — PR #115, squash-merged as `a90469b`

*Verified on main after merge. D1: 0 unenforced assertions remain (a lone flagged line in
`scaffold_supabase_shared.bats` is a heredoc body writing a mock `docker` binary, not an assertion;
confirmed the transform touched no heredoc body anywhere). D2: `shellcheck hooks/*.sh lib/*.sh`.
D3: `bats-core/bats-action@4.0.0`. D4: `on: schedule` cron present. B1: 12 contract tests. B3:
`contract-macos` job green on main in 27s. H1: `tests/README.md` present. B4/C6: main CI green on
all three jobs.*

***D5 is NOT done and was never mine to do.*** Branch protection needs repo-admin auth: required
checks `lint` + `test` + `contract-macos`, require-branches-up-to-date, and an **empty bypass list**
so it binds on Noah's own pushes and on any agent credential. Handed off deliberately — giving an
agent admin-bypass would defeat the rule. It will need updating again when the `python` job from
`2026-08-11-python-core-and-toolchain.md` Part 1 lands.

## Objective
Make the test suite tell the truth. Close the two failure modes that let three separate bugs live for weeks
behind a green suite: **local feedback that silently ignores assertions**, and **a harness that never executes
the shell the CLI actually runs in**. Combines options B (CLI contract smoke layer) and D (guardrails, no new
tests) from the 2026-08-11 design study.

**Not design-reviewed.** The council (D4) and blind adversarial review (D5) of the option set did not run —
Noah selected B+D directly. The option set itself is recorded in
`docs/research/2026-08-11-testing-posture/recommendation.md`.

## Why these two, and why together
D fixes the *signal*: 62 assertions currently do nothing on macOS, `lib/*.sh` is unlinted, the bats harness is
unpinned, and main can go red unnoticed. B fixes the *coverage gap that matters most*: no test ever runs
`borg.zsh` under zsh, which is exactly where both #113 bugs lived. Neither alone is sufficient — D makes the
existing suite honest, B makes it reach the real runtime.

## Measured baseline (2026-08-11)
| Fact | Value |
|---|---|
| Test blocks | 533 |
| Non-final `[[ ]]` assertions with no `\|\| false` — **silently skipped on macOS bash 3.2** | **62**, across 33 blocks |
| Non-final POSIX `[ ]` assertions — correctly enforced | 279 |
| CI platforms | `ubuntu-latest` only |
| shellcheck scope | `hooks/*.sh` only (`lib/*.sh` unlinted, incl. `recon.sh` where both #113 bugs lived) |
| bats-core in CI | `git clone --depth 1 … master` — unpinned |
| zsh LOC with no possible coverage tooling | 4,242 (`borg.zsh` alone: 2,717) |

Root cause of the 62: a **documented bats-core gotcha** — "`set -e` handling of `[[ ]]` and `(( ))` changed in
Bash 4.1. Older versions, like 3.2 on macOS, don't abort the test unless [it is] the last command." Verified
locally: `[[ ]]` alone is ignored; POSIX `[ ]` and `[[ ]] || false` both fail correctly.

## Acceptance Criteria

### D — trustworthy signal
- [x] D1 — All 62 silently-skipped assertions are enforced on macOS. Convert non-final `[[ ]]` to POSIX `[ ]`
      where semantics allow, else append `|| false`.
  - Verify: the counting script in this plan's commit reports `0` silently-skipped assertions; and
    `bats tests/*.bats` on macOS produces the same pass/fail counts as the Linux container run.
- [x] D2 — shellcheck covers every `.sh` file, not just `hooks/`. `lib/*.sh` and `bin/*` (those with a sh/bash
      shebang) are linted.
  - Verify: `.github/workflows/test.yml` lint job includes `lib/*.sh`; CI lint job passes.
- [x] D3 — The bats harness is pinned. No `clone … master`.
  - Verify: `grep -n 'bats' .github/workflows/test.yml` shows a pinned tag/SHA or
    `bats-core/bats-action@<version>`; CI test job passes.
- [x] D4 — A scheduled workflow re-runs lint+test against `main` independently of PR activity, so a red main
      surfaces without anyone looking.
  - Verify: a workflow with `on: schedule` exists and its first run appears in the Actions tab.
- [ ] D5 — **(HANDED TO NOAH — needs repo-admin auth)** Branch protection on `main`: required status checks (`lint`, `test`), require branches up to date
      before merging, **empty bypass list** so it binds on Noah's own pushes and on any agent credential.
  - Verify: `gh api repos/:owner/:repo/branches/main/protection` returns the required checks and an empty
    bypass/enforce-admins-true configuration. **Noah applies this** — it needs repo-admin auth.

### B — real-runtime coverage
- [x] B1 — A `tests/cli_contract.bats` suite invokes the real `borg.zsh` as a subprocess under **zsh** and
      asserts observable behavior. Minimum 12 tests covering: command dispatch, each of the 3 blocking guards,
      the removed aliases, `--json` output validity where it exists, and `recon --adapters` discovery.
  - Verify: `bats tests/cli_contract.bats` passes; every test shells out via `zsh`, asserted by
    `grep -c 'zsh' tests/cli_contract.bats`.
- [x] B2 — At least one contract test would have caught each of this session's three bug classes. Documented
      inline per test with the bug it guards.
  - Verify: comments in `cli_contract.bats` name `#113` (adapter discovery), the alias removal, and the
    zsh-word-splitting class.
- [x] B3 — The contract suite runs on a **`macos-latest`** CI leg. Only the contract suite runs there, not the
      full 533-test suite, so 10x macOS runner cost applies to ~12 tests.
  - Verify: `test.yml` has a `contract-macos` job running only `tests/cli_contract.bats`; it passes.
- [x] B4 — Regression: full suite still green in CI, and the macOS leg green.
  - Verify: `gh pr checks` shows all jobs pass.

### Honesty
- [x] H1 — `tests/README.md` (new) states plainly what each lane proves and does not prove: the bash lane
      cannot catch zsh-specific or BSD-specific bugs; the contract lane is black-box and will not localize
      faults; no coverage tooling exists for 4,242 LOC of zsh.
  - Verify: file exists and names all three limitations.

## Scope Boundaries
- NOT adding coverage tooling (kcov/bashcov). It reaches ≤46% of the code and not the CLI core; deferred to the
  Option C directive.
- NOT testing `merge-tree/*.py` (1,349 LOC) or `bin/*` (694 LOC). Real gaps, but they belong to the Python
  migration directive, not here.
- NOT a second harness (ZUnit/ShellSpec). B gets zsh execution via subprocess without one.
- NOT refactoring `borg.zsh`. That is Option C.
- If done early: ship, don't expand.

## Ship Definition
PR opened against main, all CI legs green (lint, test, contract-macos, scheduled-main present), `tests/README.md`
committed. D5 handed to Noah as a manual step with the exact settings.

## Timeline
Target: this session. D1–D4 and B1–B2 are mechanical; B3 is a small CI edit.

## Risks
- **D1 is a 62-site mechanical edit on test files.** A careless conversion could weaken an assertion rather
  than strengthen it (e.g. `[[ $x == pat* ]]` glob semantics do not survive naive translation to `[ ]`).
  Where the pattern uses glob matching, `|| false` is the correct conversion, not `[ ]`. Re-run the suite on
  BOTH macOS and Linux after converting and require identical counts.
- **B3 costs real money on every PR.** macOS runners bill ~10x. Mitigated by scoping the leg to ~12 tests; if
  it still drags, gate it to `push: main` rather than `pull_request`.
- **D5 cannot be done by an agent** — it needs repo-admin auth, and per the research, giving an agent
  admin-bypass would defeat the point of the rule. Hand it over explicitly rather than silently skipping it.
- **B is black-box.** It proves the contract holds, not that the internals are right. Do not let its green
  imply unit-level confidence.
