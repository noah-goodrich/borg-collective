# What the test suite proves — and what it does not

Written 2026-08-11, after three bugs were found that had all been live for weeks behind a green suite. The point
of this file is that a green suite is not a claim of correctness unless you know what it measured.

## Two lanes

| Lane | Where | What runs | What it proves |
|---|---|---|---|
| **fast** | `ubuntu-latest`, and locally | all of `tests/*.bats` (~530 tests) | Unit behavior of portable-sh libs and hooks, under bash, on a GNU userland |
| **fidelity** | `macos-latest` | `tests/cli_contract.bats` only (~12 tests) | That `borg.zsh` works in its **real interpreter** on a **real BSD userland** |

The fidelity lane is deliberately tiny. macOS runners bill roughly 10x ubuntu minutes, so it runs the contract
suite rather than the full 530 — buying most of the fidelity for a small fraction of the cost.

## What neither lane can catch

**No coverage tooling exists for 4,242 lines of zsh.** `borg.zsh` alone is 2,717 lines. `kcov` and `bashcov`
instrument bash via its xtrace mechanism; neither claims zsh support, and no zsh-native coverage tool was found.
So roughly **54% of this codebase has no measurable coverage, by tooling absence rather than by choice.** The
portable-sh libs (1,553 lines) and the Python in `merge-tree/` (1,349 lines) are the reachable half.

**shellcheck cannot lint zsh.** Its maintainer has declined zsh support since 2016 — it needs a from-scratch
parser. Forcing `shellcheck -s bash` on a `.zsh` file is documented (SC1071) as **actively misleading**: it
applies bash's word-splitting assumptions to zsh code, which is precisely the assumption that caused #113. The
lint job therefore covers `hooks/*.sh` and `lib/*.sh` and deliberately stops there.

**The contract suite is black-box.** It asserts exit codes and output from a subprocess. When it fails it tells
you the contract broke, not which function broke it. Do not read its green as unit-level confidence.

**Mature mutation testing for shell does not exist.** In a typed language, mutation testing is what
automatically catches an assertion too weak to distinguish pass from fail. There is no shipping equivalent for
shell, so "verify the test fails before you apply the fix" remains **discipline, not tooling**. Do it by hand.

## Local runs are weaker than CI. Know how.

macOS ships **bash 3.2.57** (2007). Its `set -e` does not fire on a failing `[[ ]]` or `(( ))` unless that
expression is the **last command** in the test body — a documented bats-core gotcha, changed in bash 4.1. CI runs
bash 5, which enforces every assertion.

Before 2026-08-11 this meant **161 assertions in this suite did nothing on macOS**. They are now all written
`[[ ... ]] || false`, which forces a real non-zero exit that errexit catches on every bash version.

**If you add an assertion, write `[[ ... ]] || false` or use POSIX `[ ... ]`.** A bare `[[ ]]` that is not the
last line of the test is silently ignored on this machine. When all 161 were finally enforced, every one of them
passed — they were correct, just unchecked. Next time they might not be.

macOS also ships **BSD coreutils**. `stat -f %m` works here and fails on Linux; `stat -c %Y` is the reverse. A
Linux container does not help you find BSD bugs — it only gives GNU-vs-GNU. The macOS CI leg is the only place
that catches this class.

## Known-failing locally, green in CI

`tests/doctor.bats` has **4 failures on macOS** that are environment-dependent — they assert on `launchd` agent
state that varies per machine. They pass in CI. If you see exactly 4 doctor failures locally, that is the
baseline, not a regression. Confirm any suspected regression by stashing your change and re-running.

## Adding tests

- Testing a **portable-sh lib** (`lib/*.sh`)? Add to the matching `tests/<lib>.bats`. bats-under-bash executes
  those faithfully.
- Testing **CLI behavior** (`borg.zsh`, dispatch, a guard, output shape)? Add to `tests/cli_contract.bats` and
  invoke via an explicit `zsh`. A unit test cannot reach this.
- **Do not** set a config env var in `setup()` if that variable is the first branch of the function under test.
  That is how #113 hid: every `recon.bats` test set `BORG_RECON_ADAPTER_PATH`, which short-circuits
  `_recon_adapter_path()` on its first line, so the default-resolution path was never executed by any test.
  Test the override branch and the derivation branch in **separate** tests, and `unset` explicitly in the latter.
