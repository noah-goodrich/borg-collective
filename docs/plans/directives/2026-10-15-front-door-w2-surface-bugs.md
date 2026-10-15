# Directive: front-door W2, three surface bugs
*Established: 2026-10-15*

- Plan-slug: `2026-10-15-front-door-w2`

Filed as a directive because `PROJECT_PLAN.md` holds another plan; see Promotion Trigger. One PR fixes three defects in what `borg next`, `/borg-link` and `borg link` show, and carries this plan of record.

## Problem

The front door tells the owner what to do next. Three surfaces mislead:

- A PR that GitHub blocks pending a review is routed as `merge #N · YOU · ✔ now`, because the router never reads `reviewDecision` for `REVIEW_REQUIRED`. Such rows also fill the five-row cap and push real decisions into "+N more". (Issue #378.)
- `/borg-link`'s WAITING ON YOU rows name a PR but carry no link. The GitHub sweep fetches each PR's `url` and the adapter drops it. (Issue #377.)
- `borg link` counts each registered worktree of a repository as its own repository in the directive and ship aggregates, so one directive title shows once per worktree. A worktree is a view of a repository (the registry `repo` key), so aggregates must group by repository.

## The change

- `_pr_row` routes a `REVIEW_REQUIRED` PR as waiting on a review (`await review #N`, owner `—`, ready `… wait`), after the CI and conflict rules and before the merge rule. The owner `—` is the existing "nobody to act" value, so the row is counted in the hidden summary and not as a decision.
- The GitHub adapter emits `url`; the nextpick row carries it; `.waiting.rows[]` exposes it; the borg-link skill renders the PR ref as a markdown link.
- The directive and ship aggregates in `borg link` group by the registry `repo` key. The per-directory repository page is unchanged.

## Non-Goals

- No change to how registry keys are read (another branch removes the old `projects` key).
- No change to the per-directory repository page.
- No release in this PR.

## Acceptance criteria

- [ ] **AC1: A PR awaiting a required review is not routed as a merge you can do now.** It becomes a non-YOU row and no longer fills the YOU cap. (Issue #378)
  - Verify: `python3 -m pytest borg_core/nextpick/test_core.py -k review_required`.
- [ ] **AC2: `.waiting.rows[]` carries each PR's URL and the borg-link skill renders it as a link.** The context-diet byte caps still hold. (Issue #377)
  - Verify: `bats tests/recon_adapter_github.bats tests/context_budget.bats` and the pytest cases for the row.
- [ ] **AC3: `borg link` aggregates by repository, not by registered directory.** Three linked worktrees of one repository show each directive title once. (parking-lot item)
  - Verify: `python3 -m pytest borg_core/link -k repository_groups` and `borg link --json` on a registry holding worktrees.
- [ ] **AC4: 0.9.9 is cut with these fixes and the registry contract step, and the plugin mirror is rebuilt.** A separate release PR after this one merges.
  - Verify: the release and the mirror commit exist.

## Scope Boundaries

- If any one bug needs a design call or grows past about 200 changed lines, it leaves this PR and is reported.
- If done early: ship, don't expand.

## Promotion Trigger

`PROJECT_PLAN.md` holds another plan. This directive is executed in place from `docs/plans/directives/` and is assimilated on its own when AC1 to AC4 are ticked.
