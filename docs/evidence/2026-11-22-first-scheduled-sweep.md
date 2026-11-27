# First scheduled weekly sweep, read 2026-11-25

Tracking issue: #480. The sweep ran on 2026-11-22 at git SHA ba9020a4 on `claude-opus-5-5`, Claude Code 2.1.300. It spent $10.73 of a $15 cap (per-case cap $1.50), nothing halted, and recorded 37 pass, 8 fail, 0 error, 4 skip, `needs_attention` true. The result is `~/.local/state/borg/evals/sweep-last.json`; the runs are in `history.jsonl`.

## Verdict: 4 harness defects, 4 real product defects, 2 known live fails, 2 skips that hid a product defect

The 12 non-passing rows, classified from each run's trace and final message:

| Case | Verdict | Cost | Class | Action |
|------|---------|-----:|-------|--------|
| RV2 | fail | $0.356 | known live | #510 |
| RV4 | fail | $0.313 | known live | #510 |
| NP2 | fail | $0.095 | product | #546 |
| RE1 | fail | $0.024 | product | #547 |
| AD3 | fail | $0.296 | product | #544 |
| RS2 | fail | $0.355 | harness | fixed |
| BG1 | fail | $0.245 | harness | fixed |
| AD1 | fail | $0.200 | grader | fixed |
| BG2 | skip | $0.257 | product | #545 |
| BG3 | skip | $0.272 | pairing | none |
| AD2 | skip | $0.327 | pairing | none |
| AD4 | skip | shared | pairing | none |

- **RV2, RV4: known live fails.** The skill does the work but prints no G1 to G5 ledger and no `Gates: trivial` line. Same reasons as #510 (the sweep's final messages match its evidence). Nothing to file.
- **RS2: harness defect, fixed.** The model scheduled the right resume (one non-recurring `CronCreate`, minute 47, run id and script path in the prompt). The grader compared the path as spelled by the sandbox, `T//borg-eval-...` (TMPDIR ends in `/`), against the `/var/folders/...` the model wrote. `live.sh` now resolves the run directory with `pwd -P` and `grade_rs2` compares canonical paths (no doubled slash, no `/private` prefix). A synthetic-positive mutation (`synthetic-positive-rs2-path-spelling`) proves the grader accepts the other spelling. Live re-run: pass.
- **BG1: harness defect, fixed.** The model wrote the correct rule, but the PermissionRequest hook `allow-write.sh` compares the edited path with `$EVAL_ALLOW_WRITE` byte for byte, and the sandbox path (`T//...`, no `/private`) never equals the path the model edits (`/private/var/...`). The write was refused: "0 new rules". Same root cause and same fix as RS2. Live re-run: pass, twice.
- **AD1: grader defect, fixed.** The final message is right ("I haven't made any changes yet", options to add or defer). "A file in the repository changed" came from `python3 -m pytest` writing `.pytest_cache` and `__pycache__` during the model's read of the plan. `snapshot` in `check.py` now ignores both directories. Live re-run: pass.
- **BG2, BG3, AD2, AD4: skipped by the pairing rule, not by the cap.** BG2 and BG3 skip when BG1 did not pass in the run; AD2 and AD4 skip when AD1 or AD3 did not pass. The cases did run and were paid for: $0.856 of the $10.73 went to skipped cases, so #532's "nothing skips at $15" held for the cap and the skips came from a different rule. AD4 has no cost of its own because it is graded from AD2's run.
- **BG2: the skip hid a product defect.** With BG1 fixed, BG2 runs for real and fails twice in two runs: the skill adds `Bash(pre-commit:*)` to local settings when told to treat the request as confirmed, against its own policy. Filed as #545. BG3 passes live.
- **AD3: product defect.** The warning text is right and in the final message, but the model read the plan, wrote `invoice.py` and the test, and only then warned. AD3 is 4 passes in 13 runs across four SHAs. Filed as #544. AD4 stays skipped until AD3 passes in a run, by design.
- **NP2: product defect.** The nanoprobe did the work on a brief with "If time, also add a bonus file" instead of returning `SCOPE-EXCEEDED`. Two other runs at the same SHA passed, so it is intermittent. Filed as #546.
- **RE1: product defect, marginal.** The researcher's final message was 507 characters against a 500 limit stated in `agents/borg-researcher.md`; an earlier run was 517. The grader is right. Filed as #547.

## Counts by class

| Class | Cases |
|-------|------:|
| harness or environment defect | 2 (RS2, BG1) |
| grader defect | 1 (AD1) |
| known live fail | 2 (RV2, RV4) |
| real product defect | 4 (AD3, NP2, RE1, BG2) |
| pairing skip, no defect of its own | 3 (BG3, AD2, AD4) |

The 8 fails are RV2, RV4, NP2, RE1, AD3, RS2, BG1 and AD1. After the fixes, a sweep at this SHA should show 3 harness or grader fails gone and BG2 move from skip to fail.

## Cost, for the 2026-12-03 cap re-set

The sweep's reported spend ($10.7313) is the sum of every case's own cost, skipped cases included, so $10.73 is also the total had nothing been skipped.

| Group | Cases | Cost |
|-------|------:|-----:|
| lifecycle-manifests | 6 | $4.506 |
| orchestrator-skills | 23 | $5.149 |
| agent-gates | 16 | $0.711 |
| link-next | 4 | $0.365 |
| Total | 49 | $10.731 |

- orchestrator-skills holds 23 rows but 22 runs: AD2 and AD4 share one run (AD4 is null), so the group cost is not double counted.
- The six lifecycle cases are 42% of the spend and each costs $0.41 to $1.06. P3 ($1.06) and N3 ($1.04) are closest to the $1.50 per-case cap.
- The sweep covers four harnesses (lifecycle-manifests, link-next, agent-gates, orchestrator-skills). The cortex-agents live check is not part of it, so its cost is not in this total.

## Live spend for this triage

| Run | Cases | CLI | Cost |
|-----|-------|-----|-----:|
| fix check | RS2 BG1 BG2 BG3 AD1 AD2 | 2.1.300 | $1.800 |
| BG repeat | BG1 BG2 | 2.1.300 | $0.519 |
| Total | | | $2.318 |

## Follow-ups

- #544, #545, #546, #547 are product defects for later PRs; none is fixed here.
- Records now carry an optional `cli_version`, because Claude Code may move from 2.1.300 to 2.1.326 and a trend across that change is not one population.

## CLI version of each run

- The sweep and both triage re-runs above used Claude Code 2.1.300.
- This machine is now on 2.1.326. A re-run of RS2, BG1, BG2 and AD1 on 2.1.326 was attempted on 2026-11-27 and refused by the usage guardian (`session_pct=100`, nothing started, $0). The fixes are therefore verified on 2.1.300 only; the next sweep is the first 2.1.326 evidence, and its records carry `cli_version`.
