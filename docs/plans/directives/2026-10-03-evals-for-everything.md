# Directive: Evals for everything

*Filed: 2026-10-03 · Status: PROPOSAL — Phase 0 done 2026-10-03 (see Decision 1); Phase 1 awaits Noah's go*
*Requested-via: Noah, 2026-10-03: "we need evals for everything."*

**tl;dr** — "Everything" is smaller than it sounds. Of the 17 skills, 5 agents (plus ROUTING), 13 hooks and two CLIs,
only the skills and agents are model behavior, and only 3 skills have any eval at all (one behavior each). Hooks and
CLIs are deterministic and already have bats/pytest coverage; they need an audit, not a model eval. The 80/20 move is
not 20 hand-written evals. It is **one offline coverage ledger that fails CI when a skill or agent has neither an
eval nor a written waiver**, plus a three-eval first phase aimed at the places where silent failure costs most:
`borg-link-up`, the `borg-nanoprobe` scope gate, and `borg-verify`. Keep the existing shell-oracle harness style for
anything whose effect lands on disk; evaluate `claude plugin eval` as the runner for pure trigger/negative cases in a
one-case spike before committing to it.

## Problem

### What exists today

- `evals/lifecycle-manifests/run.sh` — three skills (`borg-plan`, `borg-link-up`, `borg-assimilate`), one behavior
  each: "does the skill author a manifest row by default". Six model cases in three positive/negative pairs plus one
  offline case (VERBS). The oracle is the manifest file on disk, never the model's prose.
- `evals/s4-k3/run.sh` — manifest round-trip (pytest), live ref resolution, gather integration. Not model behavior.
- `make eval` (offline: `--skip-model --skip-network`) and `make eval-live`. The Makefile's comment block records that
  `eval-live` no longer spends money in this repository: the only model cases that lived here relocated beside the
  surface they grade.
- `tests/eval_floor.bats` and `tests/eval_lifecycle_floor.bats` — oracles for the floors: a selection that picks no
  harness fails, an unknown or verify-nothing `EVAL_ARGS` is refused, a run in which no case executed fails, a
  requested mode that ran nothing fails. Each floor is tested firing and holding.
- A sibling checkout, `claude-plugins/evals/`, holds a Python harness (`harness/evaluate.py`, `stats.py`) and a
  model-calling harness for the built plugin. It reports rates with Wilson intervals over a provenance-recorded
  corpus. It is the stronger statistical design and the wrong shape for borg's pass/fail behavior checks: those want a
  handful of cases whose oracle is a file, not a population estimate.
- Claude Code ships `claude plugin eval`: it runs `<eval dir>/**/case.yaml` (or `prompt.md` + `graders/*.md`) against
  a plugin, runs each case several times (default 3), adds a no-plugin baseline arm, supports a cost ceiling
  (`--max-cost-usd`), a case filter, tags, a score threshold and `--json` output. Authoring helper:
  `claude plugin eval init`. Verified present on this machine on 2026-10-03; **not yet run**, so everything below that
  depends on its behavior is a Phase 0 question, not a finding.

### What is unevaluated

Coverage below is measured by naming the item in a test or harness (a grep), which proves a test *mentions* the item,
not that it *exercises* the behavior at issue. Phase 3 turns the second reading into a check. Counts are as of
2026-10-03.

- **Skill** `borg-plan` (model) — covered by: frontmatter + prose contracts; lifecycle eval (manifest); gap: trigger,
  plan-mode behavior, negative
- **Skill** `borg-link-up` (model) — covered by: prose contracts; lifecycle eval (manifest); gap: **checkpoint actually
  written**, none-to-flush
- **Skill** `borg-assimilate` (model) — covered by: prose contracts (Step 0.75 gate); lifecycle eval; gap: trigger,
  refusal when children open
- **Skill** `borg-verify` (model) — covered by: frontmatter only; gap: **does it ever return FAIL**
- **Skill** `borg-review` (model) — covered by: prose contracts; gap: one-action ending, loop detection
- **Skill** `borg-collective-review` (model) — covered by: frontmatter only; gap: personas run, dissent surfaces
- **Skill** `borg-resume` (model) — covered by: frontmatter only; gap: resumes paused workflow, declines otherwise
- **Skill** `break-glass` (model) — covered by: frontmatter only; gap: writes only the named exception; refuses scope
  creep
- **Skill** `simplify` (model) — covered by: frontmatter + mention in 2 tests; gap: touches only session-edited code
- **Skill** `fable-reviewer` (model) — covered by: frontmatter only; gap: gate discipline (scope, evidence)
- **Skill** `adhd-guardrails` (model, always-on) — covered by: frontmatter only; gap: observable only as absence of
  behavior
- **Skill** `no-unnecessary-read-perms` (model, always-on) — covered by: frontmatter only; gap: observable only as
  absence of prompts
- **Skill** `borg-recon` (model over a deterministic engine) — covered by: engine well covered (pytest/bats); gap:
  synthesis shape
- **Skill** `borg-next` (model, thin) — covered by: frontmatter only; gap: trigger
- **Skill** `borg-link` (thin wrapper) — covered by: heavily covered (renderer, wire, sweep); gap: trigger only
- **Skill** `borg-switch`, `pane` (thin wrappers) — covered by: bats over the CLI paths; gap: trigger only
- **Agent** `borg-nanoprobe` (model) — covered by: roster + nanoprobe bats (structure, log hook); gap: **scope gate**,
  return contract
- **Agent** `borg-grunt`, `borg-researcher` (model) — covered by: roster check only; gap: stay in lane, return contract
- **Agent** `borg-reviewer`, `borg-scout` (model) — covered by: roster + mention in 1-2 tests; gap: verdict shape,
  read-only lane
- **Agent** `ROUTING` (model decision) — covered by: roster check; gap: right agent for a task shape
- **Hook** all 13 (deterministic) — covered by: every hook is named in at least one bats file; gap: exercise audit
  (Phase 3)
- **CLI** `borg`, `drone` (deterministic) — covered by: cli_contract/cli_smoke, per-command bats, Python core pytest;
  gap: none by this directive
- **Path** `borg link --brief` narrative, debriefs (model, has fallback) — covered by: fallback path pinned; gap: does
  the narrative say true things

Counts: **skills** 17 — 3 with a partial eval, 14 with none (of which 5 are thin or deterministic-backed and need a
trigger case only). **Agents** 5 + ROUTING — 0 with an eval, 6 gaps. **Hooks** 13 — 13 named in a test, 0 known gaps,
exercise depth unaudited. **CLIs** 2 — covered; out of scope.

### Why silent failure is the real cost

Every item above can fail by doing nothing: a skill that never fires, a gate that always passes, an agent that returns
a code dump instead of a summary. None of those turn a unit test red, and the cairn decommission is the standing
evidence of what an unmeasured behavior is worth — four voluntary-write surfaces, one real row in five months — while
the lifecycle harness's first draft showed the other half: three positives were unreachable, so three "nothing
changed" negatives went green carrying no evidence. An eval program that cannot tell "declined" from "never ran" is
worse than none.

## Solution

### Decision 1 — Runner: a hybrid, with the choice of default deferred to a one-case spike

- borg `evals/<name>/run.sh` shell harness (today's) — strength: Oracle is a file on disk; floors and their bats oracles
  already exist; works for Cortex Code too; weakness: Hand-rolled per harness; no run-N-times or baseline arm
- claude-plugins Python harness — strength: Wilson intervals, provenance, held-out split; weakness: Built for scoring a
  population; borg cases are few and binary; lives in a different repo
- `claude plugin eval` — strength: Runs each case N times, no-plugin baseline arm (does the skill add anything), cost
  ceiling, HTML/JSON report, maintained by the platform; weakness: Targets a *plugin*; this repository is not one
  (claude-plugins is build output, the dependency direction is one-way); grader semantics for "file on disk" unverified

Recommendation: **keep the shell-harness shape for effect-on-disk cases** (checkpoint written, manifest row added,
file byte-identical) because that oracle is already proven here, and **trial `claude plugin eval` for trigger and
negative cases** where the grader is a rubric over the transcript, because the baseline arm answers a question the
shell harness cannot ("would the model have done this without the skill?"). The one open mechanical question is how a
non-plugin repository supplies the skills to the runner (point it at the built plugin, or at a skills dir). That is
Phase 0, and its answer may collapse the hybrid to one runner. The claude-plugins harness stays where it is.

**Phase 0 result (2026-10-03).** Runner: `claude plugin eval` (v2.1.288), with a throwaway plugin wrapper. A non-plugin
repo supplies skills by copying `skills/<name>/` into a sandbox dir that has `.claude-plugin/plugin.json`; the runner
takes that dir as its target and the case lives at `<sandbox>/evals/<case>/{prompt.md,graders/*.md}` (reusable copy:
`evals/plugin-eval/linkup-writes/`). This answers the open question and it **collapses the hybrid for skills**: the
runner has a `file_exists` grader (glob under the run's cwd, so "checkpoint written" is an on-disk oracle after all), a
`tool_used: Skill` grader (the trigger), and an `llm` grader (Haiku by default). Effect-on-disk cases do not need the
shell harness. The shell harness stays only where the real `borg` CLI must run. Hard gotchas: Write/Edit/Bash must be
in the case's `allowed_tools` AND granted with `--allow-tools` or the file grader can never pass; the run is hermetic
(fresh HOME, empty cwd, no `git`), so `borg checkpoint-name` is not on PATH and the skill refuses to invent a name
(a plugin `bin/` stub was not put on PATH; a Phase 1 case needs a `--scaffold` script or a different fixture); the
runner reports USD, turns and seconds per run but **not** token counts or the model id, so those cannot be recorded
from it. Measured, 3 live runs (the cap), 1 case x 1 run each, total about $0.98 against a $2.00 ceiling
(`--max-cost-usd` works and is checked before each run):

- with skill: $0.228 / $0.245 / $0.240 per run (mean about **$0.24**), 7 turns, 35-39 s; Haiku judge about $0.002
- no-plugin baseline arm (one run): $0.139, 5 turns, 22 s; the arm roughly adds 0.6x to a case's cost
- outcomes: skill fired 3 of 3; checkpoint file written 1 of 3 (the failures were the missing `borg` binary, not the
  model declining), so the case is a working fixture but not yet a stable positive

Full-suite estimate, from the inventory above: about 10 full skills x 3 cases + 5 thin skills x 1 + 2 always-on x 1
+ 5 agents x 2 + 8 ROUTING rows = **about 55 cases**. Assumption: the child model is whatever the CLI defaults to
(unreported); the figures scale linearly with its price.

- low: 45 cases (waivers taken) x 1 run x $0.15 (trigger/negative cases are shorter) = **about $7**
- mid: 55 cases x 3 runs (the runner default) x $0.24, no baseline arm = **about $40**; with the baseline arm
  (+$0.14 per run) about **$63**
- high: 55 cases x 3 runs x $0.60 (agent and `borg-verify` cases run longer, 2.5x) with the baseline arm = **about
  $160**
- Phase 1 alone (6 model cases): about **$4** without the baseline arm, **$7** with it

Grader model: the Haiku judge is under 1% of a run ($0.002 of $0.24). An Opus judge would cost roughly 5-10x that,
about $0.01-0.02 per run, still under 10% of the run, so judge choice is not the lever; `--runs` and the baseline arm
are. Per PR once evals are selected by changed files (1-3 skills x 3 cases x 3 runs x $0.24): about **$2-7**, or
**$3-10** with the baseline arm. Suggested policy for Open Question 2: `--max-cost-usd 10` per invocation and
`--ablation none` by default, baseline arm on demand.

### Decision 2 — One eval shape per category

Every shape is a positive/negative pair, and **a negative reports SKIP, never PASS, when its positive did not fire**.

- **Skill** — three cases: *trigger* (a natural prompt that should invoke it does, shown by the Skill tool call),
  *effect* (the artifact it exists to produce is on disk and valid), *negative* (a near-miss prompt, or a state where
  it must decline, produces no artifact and no invocation). The prompt never names the behavior under test, so the
  behavior is shown to be default rather than requested.
- **Agent** — *contract* (given a brief that should pass its gate, it does the work and its final message obeys the
  return contract: bounded length, no code blocks, file references) and *refusal* (given a brief that violates the
  gate — more than two deliverables, an "optional" step — it replies with the scope-exceeded form and touches
  nothing). Oracle for refusal is the worktree list and `git status`, not the reply text.
- **Always-on skill** (`adhd-guardrails`, `no-unnecessary-read-perms`) — only a *negative-space* case is honest:
  a seeded session where the guarded behavior would normally occur, graded on its absence. Where no observable
  exists, the ledger records a waiver rather than a toothless eval.
- **ROUTING** — a table of task shapes with the expected agent; the model chooses, the oracle is the dispatched
  `agent_type`. Includes a "do it inline, spawn nothing" row.
- **Hook** — no model eval. Deterministic; bats with a firing and a holding direction. Phase 3 audits that each hook
  has both.
- **CLI** — no change.

### Decision 3 — Offline in CI, live on demand, and what live costs

- **Offline (CI, `make eval`)**: the coverage ledger; fixture validity; every grader run against *recorded*
  transcripts — a known-good one must pass and a mutated one must fail, so a grader that passes everything is caught
  with no model call. The recordings are committed, hand-checked, and never regenerated by the thing they oracle.
  This is the AC6 floor extended: zero cases executed is a failure.
- **Live (`make eval-live`, never in CI)**: the model cases. Cost is **not yet measured**. It scales as cases × runs ×
  per-run context, with the runner's default of 3 runs per case, so Phase 0 records a per-case dollar figure and the
  harness always passes a `--max-cost-usd` ceiling. Until that figure exists no phase may claim a total.
- A live result is evidence about one model on one date. Reports carry model id and date, and a score below
  threshold on a *negative* is treated as a finding about the skill, not a flake, only after the positive is shown to
  have fired in the same run.

### Decision 4 — "Everything" is enforced by a ledger, not by memory

A manifest, `evals/COVERAGE.md` or a small JSON beside it, lists every `skills/*/SKILL.md` and `agents/*.md`, and for
each either an eval path or a waiver with a reason and a review date. A bats case globs the directories and fails on
an item in neither list, and on a ledger row naming a path that does not exist. This is the guard that makes the next
skill arrive with its eval, and it is the only part of the directive that runs on every PR at zero cost.

## Acceptance criteria

1. **[DONE 2026-10-03] Runner settled by measurement.** One skill case is authored in the trial runner's format and run once, live,
   with a cost ceiling; the per-case cost, the run count, and how skills are supplied are written into this file's
   Decision 1 as a dated result.
   *Verify:* `grep -n "Phase 0 result" docs/plans/directives/2026-10-03-evals-for-everything.md` finds a dated
   paragraph naming a dollar figure per case.
2. **Ledger exists and is closed.** Every skill and agent is in the ledger as an eval or a waiver.
   *Verify:* `bats tests/eval_ledger.bats` passes; adding an empty `skills/zz-test/SKILL.md` in a scratch copy makes
   it fail naming `zz-test`.
3. **Ledger has teeth in both directions.** A row pointing at a missing eval path fails, and an unlisted item fails.
   *Verify:* both are cases in `tests/eval_ledger.bats` run against a sandboxed tree; deleting either makes the
   suite lose a case.
4. **Negatives skip, not pass.** In every harness added here a negative whose positive did not fire reports SKIP.
   *Verify:* the harness's floor script (the `floor-tests.sh` pattern) forces each positive unreachable and asserts the
   paired negative prints SKIP and the run does not exit 0 on all-skips.
5. **Graders discriminate offline.** Each model case has a recorded passing transcript and a mutated failing one.
   *Verify:* `make eval` runs both and the mutated one is graded FAIL; blanking a grader's assertion turns `make eval`
   red.
6. **Phase 1 evals exist and pass live once.** `borg-link-up` (checkpoint file written; none when there is nothing to
   flush), `borg-nanoprobe` scope gate (three deliverables refused; one accepted), `borg-verify` (a diff with a seeded
   defect gets FAIL; a clean one PASS).
   *Verify:* `make eval-live` reports 6 executed model cases, 0 failed, with the model id and date in the report.
7. **The existing floors still hold.** *Verify:* `bats tests/eval_floor.bats tests/eval_lifecycle_floor.bats` passes
   unchanged.
8. **No public-repo leakage and wrap.** *Verify:* `bats tests/prose_contracts.bats tests/state_census.bats` passes
   and no line in the new files exceeds 120 columns.
9. **Hook exercise audit.** Each of the 13 hooks has one bats case driving its firing path and one its holding path,
   or a listed exception.
   *Verify:* a table in `tests/README.md` (or the ledger) lists all 13 with two test names each.

## Non-goals

- Model evals for hooks or CLIs. They are deterministic; a model eval there is slower, dearer and weaker than the
  bats it would duplicate.
- A statistical accuracy program (held-out splits, intervals) for skills. That belongs to claude-plugins' harness for
  the scoring problem it was built for; a skill either does its one thing or it does not.
- Building the runner. No harness code is in this directive; Phase 0 is a spike and Phase 1 uses what the spike
  selects.
- Running evals in CI against a live model. CI stays offline; live is a developer command with a cost ceiling.
- Cross-model comparison (Cortex Code vs Claude). Reports record the model; comparison is a later question.

## Alternatives considered

- **Write an eval for every item now.** Rejected: 20-odd model cases at unmeasured cost, mostly for thin wrappers and
  always-on skills with no observable. The ledger gets the same "no item escapes" guarantee for the price of one bats
  file, and lets a waiver be an honest answer.
- **Adopt `claude plugin eval` wholesale.** Attractive (baseline arm, reporting, maintained). Deferred, not rejected:
  borg-collective is canonical and claude-plugins is build output, so pointing the runner at the built artifact risks
  inverting that direction, and the grader's ability to assert on a file's bytes is unverified.
- **Extend claude-plugins' Python harness.** Rejected: wrong shape (population statistics for binary behavior) and
  wrong repository for borg's own surface.
- **Rely on checkpoints and review to notice regressions.** This is the cairn lesson: capture that depends on someone
  noticing is the failure being fixed.
- **Prose contracts as the eval.** They already guard that the sentence exists. They cannot say the model obeys it;
  that is exactly the 70-90% band the extension docs describe.

## Phased order

Ranked by how often the thing runs times how bad it is when it silently fails.

0. **Spike (runner + cost).** One case, one live run, ceiling set. Closes AC1. Everything else waits on its answer.
1. **Ledger + three evals** (AC2-AC7). Chosen because: `borg-link-up` runs at the end of nearly every session and a
   silent skip loses the session's state; the `borg-nanoprobe` scope gate guards every dispatch and its failure
   (empty branch, code pasted into the orchestrator's context) is invisible until paid for; `borg-verify` is a gate,
   and a gate that always says PASS is the most expensive silent failure in the list. The ledger ships first because
   it makes every later phase visible and costs nothing per run.
2. **Orchestrator-facing:** `ROUTING` table, then `borg-plan` and `borg-assimilate` trigger and refusal cases
   (assimilate must refuse when child directives are open), then `break-glass` (negative-heavy: a permission mutation
   that fires unprompted is the worst outcome), `borg-review`, `borg-resume`.
3. **Hook exercise audit** (AC9) — deterministic, can run in parallel with Phase 2.
4. **Long tail by waiver review:** remaining agents, `simplify`, `fable-reviewer`, `borg-collective-review`, and the
   thin-wrapper trigger cases. Waivers carry a review date; the ledger fails on an expired one.

## Open questions for Noah

1. Is a waiver an acceptable answer for `adhd-guardrails` and `no-unnecessary-read-perms`, or do you want an eval
   even where the only observable is absence? (Recommendation: waive with a review date.)
2. Per-case spend ceiling for `make eval-live` — the spike will produce the number, but the policy is yours.
