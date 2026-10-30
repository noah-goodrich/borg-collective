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
7. **Prove the environment before the model.** A Tier 2 harness has a Tier 1 case that runs inside its sandbox PATH and checks that every command the skill names resolves there. The lifecycle harness went red on all three positives for weeks because its allowlist had no `borg`, and the model's answer ("`borg` isn't on PATH") was read as the skill declining.
8. **A live eval nobody runs is a stale eval.** CI runs only Tier 1, so a Tier 2 or 3 harness needs a schedule (or a recorded last-green date that something checks). Not enforced yet; the plan adds a scheduled sweep.

## Tier 1

- Runs in CI on every PR (`make test`, `make eval` with its offline defaults `--skip-model --skip-network`, `make eval-changed`).
- Hermetic: temp dirs, a fixed git identity, no reads of the real `~/.claude` or `~/.config/borg`. See `tests/CLAUDE.md`.
- Record live sessions, then replay them. A recording is sanitized before it is committed (ids, home paths, hosts rewritten consistently) and the sanitizer refuses to write when anything real survives. `evals/cortex-agents/` is the model.
- Mutation-check a new test: break the code on purpose and see the test go red. A test that stays green is decoration.

## Tier 2

- **Pin the model and effort in the harness; never inherit them.** Record the model id, cost, turns and tokens with every result. The `claude plugin eval` runner reports cost, turns and seconds but not the model id or token counts, so record the id the harness passed. Use `--output-format json` where the CLI offers it.
- **The plugin under test is the build under review.** `evals/link-next` builds a throwaway plugin from this checkout. `evals/lifecycle-manifests` loads the plugin the CLI resolves unless `EVAL_PLUGIN_DIR` names a build (`PLUGIN_DIR_OVERRIDE=<dir> scripts/build-plugin.sh`). A run against the installed copy after a skill change grades the previous release.
- **Cost ceiling on every case** (`--max-cost-usd`, `--max-budget-usd`) and a total printed at the end. A live run is a developer command or a scheduled job, never a required CI check.
- **Repeat, then report a rate with an interval.** One pass is an anecdote. At n=10 a 10/10 result has a 95% Wilson lower bound of about 72%, so it cannot show that a case is solved; report `k/n` and the interval (Wilson or Bayesian, not a normal approximation), and compare two variants on the same cases with a paired method, not by checking whether two intervals overlap.
- **pass^k for regression, pass@k for capability.** A regression case should pass every one of k runs; a capability case is credited when at least one of k passes. A case saturated on the production model graduates into the regression suite and stops guiding improvement. When a baseline is already at 95% or more, the thing to improve is cost or latency, not quality.
- **Trigger cases come in pairs and in two modes.** About half should-fire, the rest near-miss should-not-fire (a competing skill's request, not an obviously irrelevant one); one-sided cases give one-sided optimization. Run them isolated (`claude plugin eval` loads no other installed plugin) and in situ (`claude -p` with the real plugin set), because only the second measures competition between skills.
- **Separate sandbox failures from model failures.** A missing binary, an unauthenticated CLI or a hit cost cap is a SKIP or an ERROR with its cause, not a failing skill.
- **No hints in the prompt.** The prompt must not name the thing under test (the lifecycle harness refuses a prompt containing `manifest`, `scaffold` and the like).
- **Keep the run's raw output.** A case that fails with its transcript discarded cannot be diagnosed; the first diagnosis step is a rerun that costs the same again.

## Tier 3

- **Only for what a script cannot state.** One property per judge, a binary rubric, and a reason on record why Tier 2 cannot decide it.
- **The judge is not the model under test**, and a pairwise judge sees the answers in randomized order. Known biases: position, verbosity, self-preference.
- **Calibrate the judge against human labels** on a set the judge was not tuned on. Report true-positive and true-negative rate per class, not percent agreement; a judge with high agreement can still be several points off. Practitioner guidance is 100 to 200 labeled examples per failure mode, split into train, dev and test with 30 to 50 passes and 30 to 50 fails in each. Pin and record the judge model and rubric version; a changed judge is a new baseline.
- **Never the only gate for a behavior that has a Tier 2 check.** The judge adds a verdict; it does not replace the script.
- **Keep a sealed held-out split** when the judge or the thing judged is being tuned. The optimizer or the author never reads it. `claude-plugins/evals/` (the ai-scoring harness) is the working example, with recorded provenance and Wilson intervals.

## Where the evals sit today

Audited 2026-10-30. Tier 1 is the offline face; Tier 2 and 3 are the live face.

| Harness | Tier 1 face | Live tier | Judge |
|---------|-------------|-----------|-------|
| lifecycle-manifests | VERBS, floors | 2 (was stale) | none |
| link-next | transcripts | 2 | none |
| cortex-agents | replay, 6 bad | 2 | none |
| session-load | checker | 2 | none |
| s4-k3 | all cases | none | none |
| plugin-eval/linkup-writes | none | 2 + 3 | 1 grader |

- Only `evals/plugin-eval/linkup-writes` uses a judge (`graders/criteria.md`, type `llm`), and it has no Tier 1 shadow: nothing proves that grader can fail. Its second claim (the summary names the retry-loop fix and the open items) is a candidate for a Tier 2 regex.
- No harness records the model id or tokens of a live run, and no harness stores results, so a trend cannot be read.
- The ledger names harnesses and what they cover; it does not declare tiers yet.
- The lifecycle-manifests live sweep is only trustworthy against the build under review when `EVAL_PLUGIN_DIR` is set. On 2026-10-30 all three of its positive cases failed against both the trimmed skills and the previous release's, because the sandbox PATH had no `borg`; rule 7 now has a floor case for it.

## Hillclimbing

Hillclimbing is automated search over a prompt, a skill description, a skill body or an agent definition, scored by an eval. It is a Tier 2 or 3 activity with its own rules, from the 2026-10-30 research (`docs/research/2026-10-30-evals-hillclimbing/`).

- **Measure the noise first.** If the eval's run-to-run noise is larger than the smallest gain you would act on, add cases or repeat runs; do not climb. At 4 to 10 cases per skill an eval cannot see whether a skill body improved, and one reported optimizer scored far below its own starting prompt at 30 training examples.
- **The optimizer never reads the held-out split**, and failure content is not pasted into the prompt. Keep a change only if train and held-out both improve; revert it if held-out is flat while train rises or anything regresses.
- **Descriptions are the safe surface:** cheap to change, cheap to revert, measurable with 20 or more labeled trigger queries. One rewrite from the misfire cases captured almost all of the gain in the one study found; extra rounds added under half a point.
- **Tokens and accuracy are reported separately** (a Pareto view), never folded into one score, and a human reads the diff: optimizers that favor brevity drop detail the eval never measures.
- **Per CLI:** a description tuned on one model can do worse on another, so a change is scored on each CLI and one SKILL.md stays; any Cortex-only difference is an install-time rewrite justified by eval evidence, never a forked description.

Follow-up work is tracked in `docs/plans/directives/2026-10-30-evals-hillclimbing.md`.
