# borg-collective test and eval audit, 2026-10-18

Base: origin/main 1c9fc52d. Scratch worktree test-audit-2026-10-18 (removed at the end). No `.devcontainer/` exists, so everything ran on the host (macOS arm64, Python 3.14.7, bats 1.13.0, system bash 3.2.57). `uv` is absent; a plain venv plus `pip install --group dev` was used, which is exactly what CI does.

## Numbers

- Python (borg_core): 2303 tests pass in 73.5 s. Coverage 95.06% combined (line 95.4%: 6683 of 7004; branch 94.1%: 2359 of 2508). `make test` floor is 90, so it passes.
- Python (merge-tree/coordinator.py, `make test-viz`): 88 tests pass, 95%, floor 85.
- Bats: 127 files, 2434 `@test`. Full `bats tests/*.bats` took 12m11s on this Mac. Result 2433 ok, 1 not ok, 5 skip. The 1 failure is my environment, not the repo (see below).
- Offline `make eval`: 4 PASS, 0 FAIL, 8 SKIP. All 6 lifecycle model cases skip. Zero model-behavior cases execute in CI.
- Mutation spot-check: 17 of 20 killed (85% raw). The 3 survivors: 2 are equivalent mutants and 1 is a real gap. Excluding the equivalents it is 17 of 18.
- Shell function-name reference (approximation): 173 of 517 functions (33.5%) are named in any test. Indirect black-box coverage is far higher; see below.

## 1. Inventory

- Python: 69 source modules in borg_core (16 packages + 4 top-level), 58 test files with 1840 test defs (2303 with parametrization). Also merge-tree/coordinator.py, summarize.py (309 lines), scripts/resume-skeleton.py, evals/session-load/check.py.
- Shell: borg.zsh (4225 lines, 78 functions), drone.zsh (1572, 67), lib/ 33 files (15 under lib/borg/), hooks/*.sh 18, bin/ 10 scripts (2 python-shebang), lib/recon/adapters 1.
- Skills 16. Agents 6. launchd/ 7 plists. scripts/ 6.

## 2. Python coverage

Per package (line+branch combined): link 99.4, manifest 98.9, registry 98.9, nextpick 98.8, evals 99.1, checkpoint 97.3, compass 97.2, tidy 97.5, statemigrate 96.4, reconcile 96.2, recon 96.0, planstate 95.9, gh 89.8, census 82.6, extensions 64.1, watch 52.2.

Modules under 60%: borg_core/census/cli.py 0%, checkpoint/cli.py 0%, extensions/cli.py 0%, watch/cli.py 0%, watch/shell.py 0%. Under 85%: extensions/shell.py 81.6, gh/shell.py 83.3. These CLI entry points and the whole watch I/O half are only reachable through bats subprocesses, which coverage.py cannot see. Not measured at all: summarize.py, scripts/resume-skeleton.py, evals/session-load/check.py (coverage `source` is borg_core only).

## 3. Bats and shell

- 5 skips, all legitimate gates: BORG_LINK_PERF latency, three "no active plan" cases (they skip whenever PROJECT_PLAN.md is absent, as now), and an informational RESUME_REQUIRE_CAPTURED provenance gate. Python has 15 skip markers, mostly `geteuid()==0` and a `fold` binary check.
- The 1 failure: tests/eval_lifecycle_floor.bats case 712. Cause: the lifecycle harness looks for `$REPO/.venv/bin/python` or a system pytest, and my venv was named `.venv-audit`. After symlinking `.venv`, it passed. It is still a fragile premise: the test fails on any machine where pytest is not at those two places. CI avoids it by pip-installing globally.
- Function-name approximation (labelled approximate, it understates): drone.zsh 16 of 67, resume-* libs mostly 0, hooks/bash-guard.sh 1 of 17. Those are exercised as black boxes (bash_guard.bats has 134 cases that run the hook). A file-level check is more honest: only 9 files are never named by any test (lib/resume-doctor.sh, lib/borg-sync.zsh, lib/colors.zsh, lib/borg/resume-close.sh, resume-probe.sh, resume-verbs.sh, scripts/sync-plugin.sh, launchd/borg.cortex-wake.plist, borg.memory-gate.plist). Some of these are likely covered through other test names (resume_verbs.bats, resume_probe.bats, resume_mark_closed.bats exist), so the real orphans are about 5: doctor, sync, colors, sync-plugin, two plists.
- Largest unreferenced function clusters: drone.zsh lifecycle (cmd_up, cmd_exec, cmd_rebuild, cmd_scaffold, devcontainer hash) and borg.zsh work-hours and boundary helpers (_borg_is_work_hours, _borg_boundary_check, _borg_is_work_day). The boundary helpers are the ADHD-protection core.

## 4. Evals

- evals/ledger.json: 3 evals (lifecycle-manifests, session-load, s4-k3) with `covers` globs, and 22 items (16 skills + 6 agents). 3 items have an eval (borg-plan, borg-link-up, borg-assimilate, all via lifecycle-manifests). 19 are waivers with review dates.
- lifecycle-manifests: 6 model cases (3 positive/negative pairs) + 1 offline VERBS case; oracle is the manifest on disk; floor-tests.sh asserts the floors (19 pass). session-load: offline checker + a live headless session count. s4-k3: manifest round trip + live ref resolution. plugin-eval/linkup-writes: one `claude plugin eval` case (prompt + 3 graders) that nothing references: not in Makefile, not in any run.sh, not in the ledger.
- eval-changed CI job (PRs only): `make eval-changed`, selecting evals via ledger `covers` against the merge-base diff. A ledger, harness or Makefile change selects all; no match is a clean no-op. It forces `--skip-model --skip-network`, so it can never reach a model. Eight bats cases in tests/eval_changed.bats pin it, including that the workflow never names a live target.
- Local hook that runs evals on edit or commit: none. grep of hooks/, .claude/settings.json and .git/hooks found no eval invocation; `.claude/settings.json` has no hooks. hooks/pre-commit-remind.sh is a reminder only.
- `claude plugin eval` is used nowhere in code. It appears only in docs/plans and research. The one case is an unwired spike.

Directive 2026-10-03-evals-for-everything, acceptance criteria:

1. Runner settled by measurement: MET (Phase 0 result paragraph, about $0.24 a case).
2. Ledger exists and closed: MET (tests/eval_ledger.bats, 22 of 22 items, passes).
3. Ledger has teeth both directions: MET (unlisted, missing path, expired waiver, stale row cases).
4. Negatives skip not pass: PARTIAL. Met for lifecycle-manifests (floor-tests.sh). No equivalent for plugin-eval, which has no negatives.
5. Graders discriminate offline (recorded passing and mutated transcript): NOT MET. No recorded transcripts exist. Only session-load's checker has a planted-defect case.
6. Phase 1 evals pass live once (link-up, nanoprobe scope gate, borg-verify): NOT MET. Link-up is one unwired case, nanoprobe and verify do not exist. Their waivers expire 2026-11-15, after which eval_ledger.bats goes red on main unless renewed.
7. Existing floors hold: MET (eval_floor 10 cases and lifecycle floor pass; the one failure is explained above).
8. No leakage and wrap: MET as far as tests go (prose_contracts and state_census pass in the full run).
9. Hook exercise audit (13 hooks, two named tests each, table in tests/README.md): NOT MET. No table; tests/README.md still says "~530 tests" against 2434 real. There are now 18 hooks, not 13.

Net: 3 of 16 skills and 0 of 6 agents have an executable model eval, and none of those runs in CI.

## 5. Quality

- MUTATION_DECISION.md says no bash mutation testing, rely on bats and shellcheck. It cites "248/248 passing", which is stale by a factor of ten, and it says nothing about Python, where mutation testing is available and cheap. docs/research/2026-08-11-tests-passing-for-wrong-reasons.md concludes no mature shell mutation tool exists and recommends the manual break-the-fix discipline plus bats-assert. The repo uses zero bats-assert references. It uses raw `[ ]` and `[[ ]]`.
- Spot-check results (hand mutations, pytest per package, reverted after each):
  - nextpick/core.py: 7 of 7 killed (min_rows boundary, threshold `>=` to `>`, status weights, `limit` boundary, drop agent count, a CI-pending branch).
  - link/worktree.py: 6 of 7 killed. Survivor `len(members[key]) == 1` to `== 0` is an equivalent mutant (the elif path yields the same group of one).
  - manifest/refs.py: 4 of 6 killed. Survivors: dropping `"/" in ref` is equivalent (`repo != stem` still catches it). Dropping `number.isdigit()` in `suggest_full_ref` survives, so `repo#abc` would get a suggestion: a real but minor test gap.
  - Python unit tests are strong where the logic is pure. Numbers match the coverage story.
- Anti-patterns:
  - Fixture supplies the derived value: the repo knows this one (memory note on borg recon shipping dead). Not re-audited in full here. Best current mitigation is the tests/CLAUDE.md platform-premise rules.
  - No assertions: a heuristic scan found 73 bats cases that call only helper assertions (`_assert_blocked`, `_agree`) and 1 pytest (`test_render_reads_no_clock`, which asserts by raising inside a monkeypatched clock). None is truly assertion-free.
  - Bare `[[ ]]` on bash 3.2: 211 bare `[[ ]]` lines in bats files. The research doc and eval_lifecycle_floor.bats's own header name the bash 3.2 bug where a mid-test failing `[[ ]]` does not abort. The author uses `|| false` in newer files but older ones do not. CI runs bash 5 on ubuntu so it aborts there; a local macOS run could pass where CI fails. This is the likeliest "passes for the wrong reason" class remaining.
  - Skips: 5 bats of 2434 and 15 pytest markers, all environmental. Healthy.
  - Single-platform: the repo is aware of it and handles stat BSD/GNU with `||` chains; the macOS lane runs only tests/cli_contract.bats (209 of 2434 cases, 9%). Platform bugs outside that file are caught only on ubuntu.
  - Flaky: tests/checkpoint_prepare.bats line 288 (a whole-`$top` `find` diff) failed once on main push run 38960710220 and passed on the identical SHA in the next scheduled run.

## 6. CI (.github/workflows/test.yml, plus release.yml)

Triggers: push to main, pull_request, and a daily 13:17 UTC schedule. Jobs: lint (shellcheck on hooks, lib, evals; 9-11 s), test (ubuntu, full bats, 402-490 s), python (`make lint` ruff+mypy+pylint clean-arch, `make test` coverage floor 90; 65-76 s), viz (ruff + coordinator floor 85; 19-20 s), contract-macos (cli_contract.bats only; 87-95 s), eval-changed (PRs only; skipped otherwise). Last 40 Test runs: 37 success, 3 failure (2 viz failures on PRs where a new manifest used an invalid ref, which is the gate working; 1 bats flake).

Required checks: none. The main branch has no protection (API 404) and there are no rulesets. Nothing makes any job a merge gate; it relies on Noah and the borg-verify convention.

## Gaps ranked by risk

1. No required status checks and no branch protection. Every test described above is advisory.
2. Skill and agent behavior is unevaluated in CI. 19 of 22 items are waivers; the 3 with evals run only live. Offline `make eval` is 4 pass, 8 skip. The nanoprobe scope gate and borg-verify (a gate that always says PASS is the costliest silent failure per the directive) have no eval. The Phase 1 waivers expire 2026-11-15 and will turn main red.
3. The zsh entry points have no measured coverage: drone.zsh lifecycle, borg.zsh work-hours and boundary checks, resume-* libs. Only an approximation is possible, and it says 33.5% by name and roughly 5 files never referenced.
4. The macOS lane covers one file. zsh and BSD-specific regressions outside cli_contract.bats ship green.
5. 211 bare `[[ ]]` in bats under bash 3.2 semantics, and zero bats-assert: assertions can pass for the wrong reason locally.
6. Python gaps are small: watch (52%) and extensions (64%) I/O halves, 4 cli.py at 0% from pytest's view, summarize.py unmeasured, and the `isdigit` suggest_full_ref gap.
7. Stale quality docs: MUTATION_DECISION.md (248 tests), tests/README.md (~530 tests, 13 hooks). Misleads the next agent about the bar.
8. One known flaky bats case and an environment-fragile eval floor test.
9. No local eval trigger. The `claude plugin eval` spike is orphaned and the directive's AC5, AC6 and AC9 are open.
