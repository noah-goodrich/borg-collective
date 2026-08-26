# Directive: Move the `recon` retirement gate to the artifact that implements the command
*Parent plan: PROJECT_PLAN.md — One Front Door (2026-08-24), AC1*
*Filed: 2026-08-26*

**tl;dr** — S4 retired `borg recon` as a human verb with a gate in `borg.zsh`'s dispatch arm, justified in a code
comment by the claim that a Python-side gate "breaks six pytest cases." **That claim is false for the placement anyone
would actually choose.** All 11 tests in `borg_core/recon/test_cli.py` call `_run()` directly; **zero** call `main()`.
A gate at `main()` — guarding the `_run()` call on `json_only or adapters`, both already parsed at `cli.py:152` —
touches none of them. The result is that the retirement invariant is enforced by exactly one caller instead of by the
module that implements the command, and `borg.zsh` hand-rolls a `_recon_machine` flag classification that `argparse`
already performs. Move the gate; delete the duplication.

## Problem

Three separate defects, one root cause.

1. **A checkable, false rationale is recorded in a comment.** `borg.zsh`'s `recon)` arm says a Python-side guard
   "breaks six pytest cases including `test_run_resolves_registry_from_borg_dir_when_env_override_absent`." That is
   true only if the gate is inserted *inside* `_run()`. It is false at the `main()` boundary. This codebase's Learned
   section is a catalogue of reassuring statements that were not true; a comment that fails its own check is the same
   failure in a new place.

2. **The invariant is not owned by its implementation.** `python3 -m borg_core.recon.cli` with no flags still renders
   the full human digest the retirement exists to remove. No real consumer reaches it — `/borg-recon`, `merge-tree/`
   and `evals/` all go through `borg recon` — so this is an altitude defect, not a live bug. But "works because every
   caller happens to go through the one gated path" is exactly the shape that stops being true silently.

3. **Flag classification is duplicated across languages.** `borg.zsh` sets `_recon_machine` in a hand-rolled parse
   loop to decide what `argparse` has already decided in `cli.py`. Two implementations of one predicate.

## Solution

Move the gate to `borg_core/recon/cli.py::main()`, guarding the `_run()` call on `args.json_only or args.adapters`.
Delete `_recon_machine` and its post-loop check from `borg.zsh`; the zsh arm keeps its parse loop only for the two
things argparse does not do — the `--list` alias for `--adapters`, and dying on an unknown flag.

Keep the retirement sentence identical so the existing bats assertions (which match the substrings `"was retired"` and
`"borg link"`, not the full literal) stay green without edits.

## Non-Goals

- Retiring the machine surface. `borg recon --json` and `borg recon --adapters` keep working; AC1 never asked for the
  engine to die, and four consumers depend on it.
- Changing the retirement wording, the `borg help` REMOVED block, or anything else S4 shipped.
- Making `_borg_link_dispatch`'s lenient `-*)` arm strict. Its no-semantics property is deliberately pinned.

## Alternatives Considered

- **Leave the gate in zsh, fix only the comment.** Cheapest, and honest. Rejected as the primary plan because it
  preserves both the cross-language duplication and the ungated module entry point — it fixes the record without
  fixing the thing the record was wrong about. Correcting the comment is being done immediately regardless; this
  directive is the rest.
- **Gate in both zsh and Python.** Gives a fast, colored `die` for humans and authoritative enforcement underneath.
  Rejected: it reintroduces the duplication this directive exists to remove, for ~50ms on an error path.
- **Gate inside `_run()`.** This is the placement the original comment assumed. Genuinely does break the six cases,
  including recon's own registry-derivation guard — which is the guard B8 extends. Correctly rejected.

## Acceptance Criteria

- [x] **AC1 — The gate lives in `borg_core/recon/cli.py::main()`** and `borg.zsh` no longer carries `_recon_machine`.
  - Verify: `grep -n _recon_machine borg.zsh` returns nothing; `make test` green at the 90% floor.
- [x] **AC2 — `python3 -m borg_core.recon.cli` with no flags is retired**, with the same sentence `borg recon` emits.
  - Verify: a new pytest case asserts the module entry point exits non-zero and names `borg link`; a bats case asserts
    `borg recon` and the bare module invocation agree.
- [x] **AC3 — Every surviving machine shape still works**, proven rather than assumed.
  - Verify: existing bats cases for `borg recon --json`, `--adapters`, `--list`, and the modifier-with-`--json` shapes
    stay green with no edits; `bats tests/` green at or above 741.
- [x] **AC4 — The false rationale is gone from the tree**, not merely superseded.
  - Verify: `grep -rn "breaks six pytest cases" borg.zsh` returns nothing.

**Shipped 2026-08-26.** Gate moved to `borg_core/recon/cli.py::main()`; `borg.zsh`'s `recon)` arm is a pure
pass-through plus the `--list` alias and unknown-flag `die`. New pytest cases `test_main_*` in `test_cli.py`
prove the gate placement (mutation-tested: removing the guard flips them red for the right reason — the
engine's own adapter-discovery `die` fires instead — restoring it flips them green). New bats case "bare module
invocation agrees with 'borg recon' (AC2)" in `cli_contract.bats`. `core.render_digest` declared (not deleted)
as an engine-only capability in `cli.py`'s module docstring; a mutation-tested pytest case in the AC2 block
proves no argv reaches it through `main()`. `_BORG_RECON_RETIRED_LEAD` had one remaining consumer
(`_borg_recon_retired`) once the zsh `die` path was removed, so it was inlined rather than kept as a
single-consumer indirection.

## Ship Definition

`make test` green (floor 90) + `make lint` clean + `bats tests/` green + one manual smoke of `borg recon`,
`borg recon --json`, `borg recon --adapters`, and `python3 -m borg_core.recon.cli`.

## Evidence

Measured 2026-08-26 on this machine:

| Claim | Method | Result |
|---|---|---|
| `test_cli.py` calls `_run()`, not `main()` | `grep -c '_run(' / 'main('` | **10** vs **0**, across 11 tests |
| `main()` has the flags already parsed | read `cli.py:146-152` | `args.json_only` / `args.adapters` in scope at `_run()` |
| `main()` is never executed under test | `coverage report` | `cli.py` misses 134-143, 151-153, 157 — the whole entry point |
| No consumer invokes the module directly | grep `skills/ evals/ merge-tree/ lib/ hooks/` | all reach it via `borg recon` |

A second defect falls out of the same placement and is in scope here: `core.render_digest` plus its five private
helpers (~19% of `recon/core.py`) became unreachable through `borg recon` the moment the gate landed, because
`json_only=False` is what reaches them. No gate notices — `test_run_digest_output` and the core suite call `_run()`
directly, so coverage stays green on code no user can reach. Moving the gate to `main()` is what makes that branch
visible at the layer that owns it; then either delete it or declare it.
