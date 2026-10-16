# Directive: a leaner Queen startup
*Established: 2026-10-16*

- Plan-slug: `2026-10-16-queen-startup-context`

Filed as a directive because `PROJECT_PLAN.md` holds another plan; see Promotion Trigger. One slice, one PR (issue 429). It ships in 0.9.9.

## Objective

A Queen session starts at about 42.5k of its 200k-token window, measured with `/context` on 2026-10-16. Part of that comes from this repository and is waste: the full repository roster loads twice, every `borg-collective` skill description is longer than its trigger needs, the built-in `simplify` and a borg `simplify` both load, and the "Latest checkpoints" excerpts come from whichever repositories sit first in the registry rather than the ones that need attention (on that day, a 27-day-old checkpoint and one from 2026-07-21). The Queen should start with each repository named once, excerpts from the repositories touched most recently, and descriptions that cost what a trigger costs.

## Decision

- **The roster lives in the SessionStart hook only.** `hooks/borg-link-down.sh` already carries each repository's next action, so `_borg_orchestrator_context` stops printing a `Repository registry:` list. With the list gone, the function no longer needs the per-repository checkpoint-summary overlay, so that Python call goes too.
- **Recency breaks ties.** The top three checkpoint excerpts are chosen by status (waiting, active, idle) and then `last_activity`, newest first, never-active last. jq's `sort_by` is stable, so the date sort runs first and the status sort second.
- **Long-idle repositories are counted, not listed.** The hook lists a repository when it is waiting or active, or was active within `BORG_QUEEN_IDLE_DAYS` days (default 30, named `BORG_QUEEN_IDLE_DAYS_DEFAULT` in the hook; a non-numeric value falls back to the default). The rest become one line, `+ N idle 30+ days (borg link for all)`. The header still counts every repository.
- **Descriptions are triggers, not manuals.** Each `skills/*/SKILL.md` description stays at or under 320 characters (about 80 tokens) and keeps the phrases users type. Detail the body already holds is dropped.
- **Retire the borg `simplify`.** The built-in `simplify` covers the same job (reuse, quality, efficiency, then fix) and adds altitude cleanups; the borg skill added nothing the built-in lacks, only a narrower file-selection step. Every bare `/simplify` in skills, hooks and docs already reads as the built-in once the duplicate is gone.

## Acceptance Criteria

- [x] **AC1: Excerpts follow recency.** With every repository idle, the three most recently active supply the "Latest checkpoints" excerpts; a never-active repository sorts last; a waiting repository still comes first. (this PR)
  - Verify: `bats tests/queen_startup_context.bats`.
  - Evidence 2026-10-16: merged as 71be981 (https://github.com/noah-goodrich/borg-collective/pull/431), green on main at 62df38d: `bats:tests/queen_startup_context.bats`.
- [x] **AC2: The roster prints once.** `_borg_orchestrator_context` carries no `Repository registry:` list and runs no summary overlay; the hook names each repository exactly once with its next action. (this PR)
  - Verify: `bats tests/queen_startup_context.bats tests/checkpoint_summary_readers.bats`.
  - Evidence 2026-10-16: merged as 71be981 (https://github.com/noah-goodrich/borg-collective/pull/431), green on main at 62df38d: `bats:tests/queen_startup_context.bats`.
- [x] **AC3: Long-idle repositories are counted.** The hook hides idle repositories older than the cutoff behind one count line, always shows waiting and active ones, and honours `BORG_QUEEN_IDLE_DAYS`. (this PR)
  - Verify: `bats tests/queen_startup_context.bats`.
  - Evidence 2026-10-16: merged as 71be981 (https://github.com/noah-goodrich/borg-collective/pull/431), green on main at 62df38d: `bats:tests/queen_startup_context.bats`.
- [x] **AC4: Skill descriptions are capped.** Every description is at most 320 characters and the trimmed ones keep their trigger phrases; `skills/borg-link/SKILL.md` stays under its 8,192-byte cap. (this PR)
  - Verify: `bats tests/skill_frontmatter.bats tests/context_budget.bats`.
  - Evidence 2026-10-16: merged as 71be981 (https://github.com/noah-goodrich/borg-collective/pull/431), green on main at 62df38d: `bats:tests/skill_frontmatter.bats`.
- [x] **AC5: One `simplify`.** `skills/simplify` is gone and no skill, hook, doc, test or ledger row refers to it as a borg skill. (this PR)
  - Verify: `bats tests/skill_frontmatter.bats tests/eval_ledger.bats`.
  - Evidence 2026-10-16: merged as 71be981 (https://github.com/noah-goodrich/borg-collective/pull/431), green on main at 62df38d: `bats:tests/skill_frontmatter.bats`.
- [x] **AC6: The Queen docs warn about `/context`.** `docs/orchestration-architecture.md` says `/context` costs about 15k tokens in the transcript and belongs in a throwaway session. (this PR)
  - Verify: the line exists under "The Queen".
  - Evidence 2026-10-16: merged as 71be981 (https://github.com/noah-goodrich/borg-collective/pull/431), green on main at 62df38d: `path:docs/orchestration-architecture.md`.

## Testability

- `_borg_orchestrator_context` is called after sourcing `borg.zsh`, as `tests/checkpoint_summary_readers.bats` already does, with a registry whose repositories carry only a `last_activity` and a checkpoint naming them. The reaper downgrades a stale waiting row to idle, so the status-order case sets `BORG_NO_REAP=1`.
- The hook runs as a script against a sandboxed `HOME`, with per-repository state files holding status and `last_activity`.
- Every repository name in the fixtures is a placeholder.

## Scope Boundaries

- NOT building: anything outside this repository (duplicate skills across marketplaces, other plugins' trigger lists, global instruction imports, unauthenticated connectors). Those stay in the issue's "Outside this repo" list.
- NOT building: a change to `borg link`, `cmd_ls` or `borg next` ordering. They do not feed the Queen's startup context.
- NOT building: a version bump.
- If done early: ship, don't expand.

## Ship Definition

PR opened with `Closes #429`, CI green, the owner's word, squash-merged. The measured before and after bytes of both startup producers go in the PR body.

## Timeline

Target: 2026-10-16, released in 0.9.9.

## Risks

- Two other PRs touch `borg.zsh` and neighbouring files (the usage probe and the GitHub recon adapter). This PR stays inside `_borg_orchestrator_context`; whichever merges second rebases.
- A repository the user opens rarely and expects in the roster now needs `borg link` or a lower `BORG_QUEEN_IDLE_DAYS`. The count line says so.

## Promotion Trigger

`PROJECT_PLAN.md` holds another plan. This directive is executed in place from `docs/plans/directives/` and is assimilated on its own when AC1 to AC6 are ticked; it does not displace that plan.
