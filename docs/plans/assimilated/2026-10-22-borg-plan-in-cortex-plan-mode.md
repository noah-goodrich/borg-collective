# Directive: borg-plan in Cortex plan mode
*Established: 2026-10-22*
*Shipped: 2026-10-22, PR #461 merged to main; live check 2026-10-23*

- Plan-slug: `2026-10-22-borg-plan-in-cortex-plan-mode`
- Status: Assimilated

Filed as a directive because no `PROJECT_PLAN.md` exists to hold it and the parent work, `2026-10-15-borg-in-cortex.md`, is executed in place. One slice, one PR.

## Objective

Cortex plan mode produces borg-plan-shaped plans that land in `PROJECT_PLAN.md`, and the Cortex hooks the battery found dead are repaired. A live battery of Cortex Code CLI on 2026-10-22 (versions 1.2.14, then 1.2.18 after an update mid-run) found that plan promotion is a silent no-op in Cortex (`borg-plan-promote.sh` gate 5 reads a Claude `.jsonl` transcript that Cortex does not write, so the debug log says "JSONL not found"), that SessionStart `additionalContext` never reaches Cortex's model (so the arrival brief and the "run /borg-plan" nudge are invisible there), and that Cortex's native plan (Context, Steps, Verification, Critical Files) ignores the borg-plan template. Three small hooks hanging off the plan-mode tool names fixed all of it end to end, solo on 1.2.18 and team mode on 1.2.14.

## Decision

Hang everything off tool names, which is the only signal Cortex gives: `permission_mode` stays `default` in plan mode, so no hook branches on it.

- **Inject (soft).** A PostToolUse hook on `EnterPlanMode` prints `additionalContext` telling the model to load the borg-plan skill and write the plan in the PROJECT_PLAN.md template. PostToolUse `additionalContext` reaches Cortex's model (observed: it loaded the skill unprompted).
- **Gate (hard).** A PreToolUse hook on `ExitPlanMode` exits 2 with a borg-plan message unless the plan has Acceptance Criteria, Scope Boundaries (or a "NOT building" line) and a `- Plan-slug:` line. The model sees `[Hook] Blocked: <message>` and (observed) loads the skill and retries.
- **Promote.** `borg-plan-promote.sh` gains a Cortex branch on PostToolUse `ExitPlanMode`: it reads the accepted plan from `tool_input.plan`, writes `docs/plans/PROJECT_PLAN.md`, and in team mode also overwrites `.cortex/plans/plan-<task-id>.md` (the file Cortex's workers implement from, which otherwise keeps the native plan while the approved plan is borg-shaped). The response text names that file after "Plan saved to" in backticks. A rejected or "keep planning" exit has no "Plan mode has ended" in the response, and nothing is promoted.
- The inject and gate share one new Cortex-only script, `hooks/borg-cortex-plan.sh`, which the plugin build does not ship. `borg setup` already copies every `hooks/*.sh` to `~/.snowflake/cortex/hooks/`; only the registration changes, in `_borg_register_cortex_hooks`, where an entry may now carry a tool-name matcher. Existing entries keep the empty matcher (expand, not replace).
- The scoping mirrors the Claude hooks: repository sessions only, and only while no `PROJECT_PLAN.md` exists. `BORG_PLAN_GATE=off` is the escape hatch for trivial plans.

Evidence base: the 2026-10-22 battery, Cortex 1.2.14 and 1.2.18; the dated notes under `docs/evidence/` record what was and was not observed.

## Acceptance Criteria

- [x] **AC1: Promote works in Cortex.** Shipped in #461: held by `tests/plan_promote.bats` and the green CI of #461. After the user accepts a plan, `hooks/borg-plan-promote.sh` writes it to `docs/plans/PROJECT_PLAN.md` (the location the Claude hook already uses), and also overwrites the team plan file `plan-<task-id>.md` when the response names one. The underscore `plan_<timestamp>.md` files are never touched. Claude Code behaviour of the same script stays unchanged.
  - Verify: `bats tests/plan_promote.bats` (Cortex cases built from synthetic payloads sit after the Claude ones).
  - Evidence: `bats:tests/plan_promote.bats`
- [x] **AC2: Gate.** Shipped in #461: held by `tests/cortex_plan_hook.bats` and the green CI of #461. A PreToolUse hook on `ExitPlanMode` exits 2 with a borg-plan message when the plan lacks any of: Acceptance Criteria; Scope Boundaries (or a "NOT building" line); a `- Plan-slug:` line (case-insensitive). It passes when all are present. It is a no-op in the Queen/orchestrator session, when `docs/plans/PROJECT_PLAN.md` or the root `PROJECT_PLAN.md` already exists, outside a git repo, and when `BORG_PLAN_GATE=off`.
  - Verify: `bats tests/cortex_plan_hook.bats` (a case for each path).
  - Evidence: `bats:tests/cortex_plan_hook.bats`
- [x] **AC3: Inject.** Shipped in #461: held by `tests/cortex_plan_hook.bats` and the green CI of #461. A PostToolUse hook on `EnterPlanMode` prints the `additionalContext` JSON telling the model to load the borg-plan skill and write the plan in the PROJECT_PLAN.md template (Objective, Acceptance Criteria each with a Verify line, Scope Boundaries as "NOT building:" lines, Ship Definition, Timeline, Risks, a `- Plan-slug: \`<date>-<short-slug>\`` line; Cortex's Context and Critical Files may stay; PROJECT_PLAN.md itself is written by the promote hook). Same scoping gates and `BORG_PLAN_GATE=off` as the gate.
  - Verify: `bats tests/cortex_plan_hook.bats`.
  - Evidence: `bats:tests/cortex_plan_hook.bats`
- [x] **AC4: `borg setup` registers all three in `hooks.json`, idempotently.** Shipped in #461: held by `tests/cortex_hooks.bats` and the green CI of #461. PostToolUse `EnterPlanMode|enter_plan_mode`, PreToolUse `ExitPlanMode|exit_plan_mode`, PostToolUse `ExitPlanMode|exit_plan_mode` (promote). A second run is byte-identical; a user's own entries survive; nothing is registered into `~/.claude/settings.json`; the stale-entry scrub keeps working.
  - Verify: `bats tests/cortex_hooks.bats` (expected pair list and counts updated).
  - Evidence: `bats:tests/cortex_hooks.bats`
- [x] **AC5: Replay layer.** Shipped in #461: held by `tests/cortex_payload_replay.bats` and the green CI of #461. `tests/cortex_payload_replay.bats` feeds synthetic Cortex payloads (SessionStart, Stop, Notification, PreToolUse Bash/Read/Write, EnterPlanMode, ExitPlanMode) to every hook registered for Cortex and asserts exit 0 with stdout empty or valid JSON, plus the guard's deny (a force-push to main exits 2 with its message) and allow (a read-only command prints permissionDecision allow). HOME and the XDG directories are sandboxed.
  - Verify: `bats tests/cortex_payload_replay.bats`.
  - Evidence: `bats:tests/cortex_payload_replay.bats`
- [x] **AC6: Evidence notes.** Held by the two evidence files existing and the parent AC6 tick. `docs/evidence/2026-10-cortex-live-session.md` (AC5 of the parent directive) and `docs/evidence/2026-10-cortex-session-start-context.md` (AC6 of the parent directive) exist, each dated 2026-10-22 and naming Cortex 1.2.14 and 1.2.18. The first records only what was observed and states that appearance on the board was not; the second settles that SessionStart `additionalContext` does not reach the model. Parent AC6 is ticked, with a dated correction under the parent's Decision section; parent AC1 to AC5 are not.
  - Verify: both files exist and name both versions; `grep -c '\[x\] \*\*AC6' docs/plans/directives/2026-10-15-borg-in-cortex.md` prints 1.
  - Evidence: `path:docs/evidence/2026-10-cortex-live-session.md`, `path:docs/evidence/2026-10-cortex-session-start-context.md`
- [x] **AC7: Nothing breaks.** Held by the green CI of #461 (all six required checks passed on head 160ca50e) and the existing plan-promote cases staying green. `make test`, `make test-bats` and `make lint` pass; the existing plan-promote cases stay green.
  - Verify: `make test && make test-bats && make lint`.

## Testability

- Registration is a function in `borg.zsh`, so `tests/cortex_hooks.bats` calls it with `HOME` and `XDG_CONFIG_HOME` in a temporary directory. `borg setup` is never run by a test, and nothing here touches `~/.snowflake`, `~/.claude` or `~/.config`.
- Payload fixtures are synthetic: Cortex's recorded field names and tool names, invented values (cwd `/work/acme-widgets`, session id `00000000-0000-4000-8000-000000000001`). The recorded originals carry real local paths and ids and are not committed.
- The live checks (the model loading the skill, the block-and-retry, team mode) are manual: headless Cortex (`-p`) is blocked on trial accounts and `exec` disables plan mode. The battery's Tier A checks are the repeatable part and are what the bats files encode.

## Scope Boundaries

- NOT building: a replacement for the dead SessionStart nudge in Cortex.
- NOT building: detection of unprompted plan mode (not reproduced in two tries and 47 saved sessions).
- NOT building: a fix for the two stale paths in `~/.snowflake/cortex/skills.json`.
- NOT building: manifest scaffolding from the hook.
- NOT building: any change to Claude Code hook registration.
- If done early: ship, don't expand.

## Ship Definition

PR opened, CI green, the owner's word, squash-merged. After it merges, run `borg setup` once on a machine with Cortex installed and confirm `~/.snowflake/cortex/hooks.json` carries the three new entries; that real run is the one thing the tests deliberately do not do. Then enter plan mode in Cortex once, in a repository with no `PROJECT_PLAN.md`, and confirm the skill loads and the accepted plan lands in `docs/plans/PROJECT_PLAN.md`.

**Ship Definition result (2026-10-23).** Met on the owner's machine.

- `borg setup` was run on 2026-10-22 after the merge of #461. `~/.snowflake/cortex/hooks.json` carries PostToolUse `EnterPlanMode|enter_plan_mode` (`borg-cortex-plan.sh`), PreToolUse `ExitPlanMode|exit_plan_mode` (`borg-cortex-plan.sh`) and PostToolUse `ExitPlanMode|exit_plan_mode` (`borg-plan-promote.sh`). The installed copies are byte-identical to `hooks/`.
- The owner then ran one real interactive Cortex plan-mode session (real account, fresh session, throwaway git repository with no `PROJECT_PLAN.md`; the task was a Streamlit-in-Snowflake query-performance app). The installed Cortex reads v1.2.18 on 2026-10-23; the session's conversation file records no version, so the version of that exact session is not independently recorded.
- The hook logs show `inject emitted` at 2026-10-22T22:00:29Z and `PASS` (the gate passed) at 2026-10-23T03:07:32Z in `cortex-plan-debug.log`, then `cortex: promoted plan to .../docs/plans/PROJECT_PLAN.md` at 2026-10-23T03:36:33Z in `plan-promote-debug.log`, after the owner accepted the plan.
- The promoted file starts with the auto-promoted header comment and carries a Plan-slug line, Acceptance Criteria with Verify lines, and Scope Boundaries as NOT building lines.
- The logs show only inject, gate PASS and promote. They do not show the model loading the skill, and no block-and-retry happened in this run.

## Timeline

Target: 2026-10-22, single slice.

## Risks

- Cortex ships fast. Re-run the battery on each Cortex update; the Tier A checks in the battery report are the tripwire, and the replay bats file is their repeatable form.
- The gate could annoy on a trivial plan. The escape hatch is `BORG_PLAN_GATE=off`, and the gate is a no-op once a `PROJECT_PLAN.md` exists.
- The team-mode plan-file overwrite depends on parsing "Plan saved to" in the response text. If Cortex rewords it, `docs/plans/PROJECT_PLAN.md` is still written and only the team file keeps the native plan.
- Headless Cortex is blocked on trial accounts, so the live checks stay manual.

## Promotion Trigger

No `PROJECT_PLAN.md` exists. This directive is executed in place from `docs/plans/directives/` and is assimilated on its own when AC1 to AC7 are ticked.
