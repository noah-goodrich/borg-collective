# Directive: Evals that run, and hillclimbing for descriptions
*Established: 2026-10-30*
*Status: Proposed. The criteria lock when Noah says "lock the evals plan"; the file then becomes `PROJECT_PLAN.md` (see Promotion Trigger).*
*Parent: `2026-10-03-evals-for-everything.md`*

- Plan-slug: `2026-10-30-evals-and-description-hillclimb`

Research behind it: `docs/research/2026-10-30-evals-hillclimbing/recommendation.md` (design-reviewed twice, citation check not passed, see its stamps). Doctrine: `docs/agents/testing-tiers.md`.

## The Collective Review

**Code owners summoned:** Ops Engineer (scheduled live runs, spend), Security Auditor (prompt capture, employer credits). **Rotating specialist:** The Devil's Advocate, because the research itself says the optimizer step may never pay off.

**The Scope Hawk:** "Steps 0 to 3 are about five sessions and deliver most of the value: honest live evals, declared tiers, no expiring waivers. borg's own skill and agent descriptions add about 1.9k tokens to a session's listing, so a 20% saving is roughly 380 tokens. Step 6 (the hillclimb) is the optional tail, not the point."

**The Craftsperson:** "The lifecycle harness could not pass against the October skills and nothing said so: its sandbox PATH had no `borg` and `--permission-mode acceptEdits` denied `PYTHONPATH=... python3 -m ...`. Both are now floor cases in `evals/lifecycle-manifests/floor-tests.sh`. Every Tier 2 harness gets an environment floor, and every new floor gets a mutation run."

**The Performance Engineer:** "A trigger suite is 20 queries x 3 runs x 2 modes = 120 `claude -p` runs per skill, about 1,920 for all 16. No source gives a cost per trigger check, and a lifecycle case costs $0.69 to $1.03 on Opus at xhigh. Step 0 shrinks the set to skills meant to fire on their own; measure one skill's cost, then set the sweep cap."

**The Readability Advocate:** "One page names the tiers (`docs/agents/testing-tiers.md`), one JSONL schema records a run, and the ledger carries a `tiers` field. A reader should not have to learn a third vocabulary."

**The User Advocate:** "Noah does not open a dashboard. A failed or skipped sweep has to arrive as a Waits-on-you row in `borg next`, or it is the same silent failure again."

**The Ops Engineer:** "A weekly sweep under launchd needs a per-case cap, a total cap, a pinned model and a visible failure. The personal Cortex trial is documented as 30 days, then it converts to a subscription and overage makes the CLI unavailable until the next billing period. Record the end date before any Cortex run is scheduled."

**The Security Auditor:** "Passive capture logs real prompts. On the employer machine that is employer data, and a headless run there spends employer credits. Neither happens without Noah's explicit approval; logs stay on the machine; only hand-labeled, sanitized cases are committed."

**The Devil's Advocate:** "One study found a single rewrite captures almost all of a description gain, another found an optimizer scoring 34% against a 62% starting prompt at 30 examples. Why build a loop? Because descriptions are cheap to revert and a 20-query suite is the one surface where the evidence supports it, and the loop is gated so that 'do not merge' is a valid result."

**The Adult:** "Do steps 0 to 3 now; they stand alone and fix a demonstrated failure. Step 4 follows once one skill's trigger cost is measured. Steps 5 and 6 are gated: a Cortex invocation probe first, and a gain outside the interval or at least 40 queries before any description changes. Skill bodies and agents are not hillclimbed."

## Objective

Make borg's live evals trustworthy, recorded and scheduled; put every skill and agent behind a declared tier with an eval or a renewed waiver; measure when skills fire; and hillclimb descriptions only where that measurement can carry it, on Claude Code first and Cortex Code second.

## Measured baseline (2026-10-30)

| Measure                  | Value                          |
| ------------------------ | ------------------------------ |
| Items in the ledger      | 22                             |
| With an eval             | 5                              |
| Waived                   | 17 (5 on 2026-12-15)           |
| Live lifecycle positives | 0 of 3 before the harness fix  |
| Live case cost (Opus)    | $0.69 to $1.03                 |
| borg listing tokens      | about 1.9k of about 9.9k        |
| Cases per skill          | 4 to 10                        |

- The 0 of 3 predates the context trim: the previous release's skills fail the same cases. Causes found and fixed in the harness: no `borg` on the sandbox PATH, and no allow rule for env-prefixed commands in headless mode.
- A 10 of 10 result has a 95% Wilson lower bound of about 72%.
- The Cortex stream recordings under `evals/cortex-agents/recorded/` contain task calls and a model-usage result but no skill-invocation event.

## Acceptance Criteria

- [ ] **AC1: The live evals are trustworthy, recorded and scheduled.** The lifecycle sweep passes against the build under review. Every live run appends one JSONL record (git SHA, model id, cost, turns, tokens, verdict) and a stdlib script reports Wilson intervals and per-SHA trends. A weekly sweep runs on the personal machine under launchd with a pinned model, a per-case cap and a total cap, and a skipped or errored case raises a `borg next` row. A Cortex load check fails the build on a folded or literal `description:` block, and `borg setup` no longer discards `cortex skill add` errors.
  - Verify: `EVAL_PLUGIN_DIR=<build> bash evals/lifecycle-manifests/run.sh` prints `RESULT: 7 pass, 0 fail`; `bash evals/lifecycle-manifests/floor-tests.sh` prints `0 failed`; `python3 -m borg_core.evals.history --report` prints an interval per case; `launchctl list` shows the sweep label; `bats tests/cortex_skill_load.bats` is green and turns red on a folded description.
- [ ] **AC2: Every harness declares its tier.** `evals/ledger.json` carries `tiers` on each `evals/*` entry, optional first, filled, then required (expand, migrate, contract).
  - Verify: `jq '[.evals[] | has("tiers")] | all' evals/ledger.json` prints `true`; `bats tests/eval_ledger.bats` fails on an entry without it.
- [ ] **AC3: No waiver expires without a case.** Each of the 17 waived items has an eval (with a known-good and a known-bad transcript graded offline) or a renewed waiver whose reason says why no observable output exists. `llm` graders are allowed for the three items the ledger says need a judge, with a calibration note.
  - Verify: `bats tests/eval_ledger.bats` is green; `jq '[.items[] | select(.waiver) | .review_by] | min' evals/ledger.json` is `2027-01-31` or later, or the waivers are gone.
- [ ] **AC4: Skills are sorted, and the self-firing ones have trigger suites.** A triage table records each skill's invocation mode; slash-command-only skills carry `disable-model-invocation: true`; each self-firing skill has at least 20 labeled queries with at least 40% near-misses, run isolated and in situ. The in-situ runner reads the plugin list from the `system/init` event and aborts on a mismatch.
  - Verify: `jq 'length' evals/triggers/<skill>.json` is 20 or more per self-firing skill; a floor case feeds the runner a wrong plugin list and requires an abort; the listing size before and after is recorded in the PR.
- [ ] **AC5: The Cortex question is answered, not assumed.** One recorded probe says whether a skill invocation can be detected in Cortex's stream or hook payloads. If it can, the Cortex trigger check is built under a ceiling below the monthly allowance; if not, the check stays advisory. No employer-account run or passive capture happens without Noah's recorded approval.
  - Verify: `docs/evidence/2026-11-cortex-skill-trigger.md` states the finding and the trial end date; `rg -n "employer" docs/evidence/2026-11-cortex-skill-trigger.md` shows the approval line or the words "not approved".
- [ ] **AC6: The first description hillclimb reports honestly.** For at least one skill: one rewrite from the misfire cases on the 60% train split; held-out never read by the rewrite; accuracy and tokens reported separately; a paired comparison. The change merges only if the held-out gain is outside the interval or the suite has at least 40 queries; otherwise the report says "do not merge".
  - Verify: the report file under `docs/evidence/` carries the paired interval and the token counts; the PR links it.
- [ ] **AC7: Nothing breaks.** `make test`, `make test-bats`, `make lint` and `make eval` are green; `tests/context_budget.bats` is green.
  - Verify: the four make targets and the bats file.

## Testability

- **History and statistics (AC1).** Logic lives in a new `borg_core/evals/history.py` (append, Wilson interval, per-SHA trend), a testable core with pytest in `borg_core/evals/test_history.py`. The shell harnesses only call it. Passing test before any refactor: an empty file reports nothing and exits 0; ten identical passes report a lower bound near 0.72.
- **Ledger tiers (AC2, AC3).** The check lives in `borg_core/evals/` with `tests/eval_ledger.bats` already covering the waiver rules; add cases for a missing `tiers` and an expired waiver. Untested today: nothing in the ledger check names a tier.
- **Cortex load check (AC1).** A new `tests/cortex_skill_load.bats` over `skills/*/SKILL.md` and `agents/*.md`, Tier 1. `borg.zsh` `cmd_setup` runs `cortex skill add ... 2>/dev/null` and has no test for what it reports on failure; that gap is flagged here and fixed in AC1, not refactored silently.
- **Trigger suites (AC4).** Case data under `evals/triggers/`, a runner under `evals/`, and a floor case per rule (wrong plugin list aborts; `--bare` default loads no plugin). The runner is a thin wrapper over `claude -p`; counting and grading live in the Python core.
- **Hillclimb (AC6).** `borg_core/evals/hillclimb.py` holds the split, the paired comparison and the accept rule, pure functions with pytest, including a case where the gain sits inside the interval and the answer is "do not merge". The `claude -p` calls sit in a thin shell.
- **Docs-only deliverables** (the triage table, the evidence files) have no code; their checks are the `jq` and `rg` lines above.

## Scope Boundaries

- NOT building: an evaluation platform or any of the hosted tools the research ruled out (Braintrust, LangSmith, Langfuse, OpenAI Evals, Ragas, DeepEval, Harbor, Inspect AI's agent bridge); promptfoo unless a Claude-and-Cortex matrix becomes necessary.
- NOT building: hillclimbing of skill bodies or agent definitions. They wait for a passing noise check, more than 30 train cases and a baseline under 95%.
- NOT building: live evals as a required CI check, or any run on the employer's Cortex account.
- NOT building: a forked description per CLI. One SKILL.md stays; a Cortex-only difference is an install-time rewrite justified by eval evidence.
- If done early: ship, don't expand.

## Ship Definition

Each step is its own PR through the required checks (lint, test, python, eval-changed, viz, contract-macos), merged with the head SHA pinned. The step 1 sweep lands first; its first scheduled run is read before step 4 begins. A release follows when AC1 to AC3 are green, with the context numbers in the notes.

## Timeline

Target: AC1 to AC3 by 2026-12-10, so no waiver expires on 2026-12-15 unprotected; AC4 by 2027-01-15; AC5 and AC6 as the gates allow.
Estimated effort: about 8 sessions of 2 to 3 hours (Option A estimate; the Cortex runner is the least certain part).

## Risks

- The personal Cortex trial is documented as 30 days, then converts to a subscription; overage makes the CLI unavailable until the next billing period. A recorded 4-turn session read about 360k cached tokens, so a large replay could lock the owner out. Mitigation: record the end date, set a ceiling below the allowance, keep the Cortex check advisory until the probe passes.
- Plain `-p` is documented to become `--bare` by default, which loads no plugins, so every should-not-fire case would pass at 50%. Mitigation: name the plugin with `--plugin-dir` and abort on a wrong `system/init` plugin list.
- Evals go stale again because CI runs only Tier 1. Mitigation: the scheduled sweep and a `borg next` row on a skipped or failed case; a staleness check is a follow-up.
- At 20 queries a flip moves the score 5 points on the full set and 12 on an 8-query hold-out, so a single gain can be noise. Mitigation: the accept rule needs a gain outside the interval or 40 queries.

## Promotion Trigger

Noah says "lock the evals plan". Then: copy this file to `PROJECT_PLAN.md` unchanged, the acceptance criteria become locked, and a PR row is added to the stack manifest `.stacks/2026-10-30-evals-and-description-hillclimb.json` for each step as its PR opens.

## Decisions requested

- Is the personal Cortex trial still active, and when does it end? It sets the ceiling for AC5.
- Is the weekly live sweep's dollar total acceptable? A first estimate from the measured case cost: 6 lifecycle cases about $5, plus the link and next cases, so about $8 a week before trigger suites.
- Do you want the employer-account Cortex probe and passive prompt capture? Default: no, until you say so.
