# Testing in three tiers

*Filed: 2026-10-30. Applies to every test, eval and grader in this repository and, by pointer, to claude-plugins.*

Every test or eval belongs to exactly one tier. Pick the cheapest tier that can decide the question, and never let a higher tier stand in for a lower one.

| Tier | Needs | Graded by | Runs |
|------|-------|-----------|------|
| 1 | no model | a script, exactly | every PR |
| 2 | one agent call | a script, on the result | on demand |
| 3 | agent + judge | an LLM, by rubric | on demand |

- **Tier 1: deterministic, fully scripted.** No model, no network, no credentials. The same input gives the same verdict on every machine. bats, pytest, shell floor suites, recorded sessions replayed offline, known-bad transcripts a grader must reject.
- **Tier 2: deterministic grading, requires an agent call.** The agent or CLI runs for real (`claude -p`, `claude plugin eval`, headless Cortex). The run is non-deterministic, but the verdict is a script over the result: a file exists, a tool was used, a regex over the final message, a canonical hash of a manifest, a hook decision.
- **Tier 3: non-deterministic, requires an LLM judge.** The property cannot be stated as a script (is this summary faithful, is this plan coherent). A model grades the transcript or the file against a rubric.

## Rules for every tier

1. **Cheapest tier that can decide.** A Tier 3 grader must say why no script can state the property. A regex over the final message beats a judge; an exact file check beats a regex.
2. **Every Tier 2 or 3 grader has a Tier 1 shadow.** Run the grader offline against a known-good and a known-bad transcript or fixture. A grader that has never failed proves nothing. Examples in this repository: the known-good and known-bad transcripts under `evals/link-next/transcripts/`, and the six known-bad variants `evals/cortex-agents/run.sh` requires to be rejected.
3. **Pair every positive with a negative.** "Fires when it should" and "stays quiet when it should" are different claims; a positive alone is satisfied by a skill that does the thing unconditionally. A negative must SKIP, not pass, when its positive did not reach the output step, or "nothing changed" reads as "declined" (the lifecycle-manifests harness header records the measurement).
4. **SKIP is not PASS.** No `claude`, no login, no Cortex account is a SKIP with the reason named, never a FAIL and never a PASS. Every harness also runs at least one case with the model off, so a green offline run is never a run of nothing; `tests/eval_floor.bats` holds every harness to that floor.
5. **A fixture that supplies the derived value proves nothing.** Build the input the way production does, then assert on what the code derived.
6. **Name the tier.** A harness with two faces declares both. Until `evals/ledger.json` carries a `tiers` field (the plan below adds it), the table under "Where the evals sit today" is the record, and a change to a harness updates that table in the same PR.

## Tier 1

- Runs in CI on every PR (`make test`, `make eval` with its offline defaults `--skip-model --skip-network`, `make eval-changed`).
- Hermetic: temp dirs, a fixed git identity, no reads of the real `~/.claude` or `~/.config/borg`. See `tests/CLAUDE.md`.
- Record live sessions, then replay them. A recording is sanitized before it is committed (ids, home paths, hosts rewritten consistently) and the sanitizer refuses to write when anything real survives. `evals/cortex-agents/` is the model.
- Mutation-check a new test: break the code on purpose and see the test go red. A test that stays green is decoration.

## Tier 2

- **Pin the model and effort in the harness; never inherit them.** Record the model id, cost, turns and tokens with every result. The `claude plugin eval` runner reports cost, turns and seconds but not the model id or token counts, so record the id the harness passed. Use `--output-format json` where the CLI offers it.
- **The plugin under test is the build under review.** `evals/link-next` builds a throwaway plugin from this checkout. `evals/lifecycle-manifests` loads the plugin the CLI resolves unless `EVAL_PLUGIN_DIR` names a build (`PLUGIN_DIR_OVERRIDE=<dir> scripts/build-plugin.sh`). A run against the installed copy after a skill change grades the previous release.
- **Cost ceiling on every case** (`--max-cost-usd`, `--max-budget-usd`) and a total printed at the end. A live run is a developer command or a scheduled job, never a required CI check.
- **Repeat, then report a rate with an interval.** One pass is an anecdote. At n=10 a 10/10 result has a 95% Wilson lower bound of about 72%, so it cannot show that a case is solved; report `k/n` and the interval, and treat a drop as a regression only when the intervals separate. Retire a case that is saturated on the production model; it guards against regression and cannot guide improvement.
- **Separate sandbox failures from model failures.** A missing binary, an unauthenticated CLI or a hit cost cap is a SKIP or an ERROR with its cause, not a failing skill.
- **No hints in the prompt.** The prompt must not name the thing under test (the lifecycle harness refuses a prompt containing `manifest`, `scaffold` and the like).
- **Keep the run's raw output.** A case that fails with its transcript discarded cannot be diagnosed; the first diagnosis step is a rerun that costs the same again.

## Tier 3

- **Only for what a script cannot state.** One property per judge, a binary rubric, and a reason on record why Tier 2 cannot decide it.
- **Calibrate the judge against human labels** on a set the judge was not tuned on, and record the agreement. Pin and record the judge model and rubric version; a changed judge is a new baseline.
- **Never the only gate for a behavior that has a Tier 2 check.** The judge adds a verdict; it does not replace the script.
- **Keep a sealed held-out split** when the judge or the thing judged is being tuned. The optimizer or the author never reads it. `claude-plugins/evals/` (the ai-scoring harness) is the working example, with recorded provenance and Wilson intervals.

## Where the evals sit today

Audited 2026-10-30. Tier 1 is the offline face; Tier 2 and 3 are the live face.

| Harness | Tier 1 face | Live tier | Judge |
|---------|-------------|-----------|-------|
| lifecycle-manifests | VERBS, floors | 2 | none |
| link-next | transcripts | 2 | none |
| cortex-agents | replay, 6 bad | 2 | none |
| session-load | checker | 2 | none |
| s4-k3 | all cases | none | none |
| plugin-eval/linkup-writes | none | 2 + 3 | 1 grader |

- Only `evals/plugin-eval/linkup-writes` uses a judge (`graders/criteria.md`, type `llm`), and it has no Tier 1 shadow: nothing proves that grader can fail. Its second claim (the summary names the retry-loop fix and the open items) is a candidate for a Tier 2 regex.
- No harness records the model id or tokens of a live run, and no harness stores results, so a trend cannot be read.
- The ledger names harnesses and what they cover; it does not declare tiers yet.
- The lifecycle-manifests live sweep is only trustworthy against the build under review when `EVAL_PLUGIN_DIR` is set.

Follow-up work is tracked in `docs/plans/directives/2026-10-30-evals-hillclimbing.md`.
