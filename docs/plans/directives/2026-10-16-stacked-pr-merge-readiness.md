# Directive: A stacked PR is not mergeable now
*Filed: 2026-10-16 · Status: Accepted 2026-10-16 · Owner: Noah*

**tl;dr** — `borg next` and `borg link` offer "merge ✔ now" (owner YOU) for a PR whose base branch is the head branch of another open PR, so following the advice merges into a feature branch and not the default branch. One PR fixes the one ranker both commands read: such a child now says `await #<parent>`, owner `—`, ready `… wait`, and every other PR row stays as it is today.

- Plan-slug: `2026-10-16-stacked-pr-merge-readiness`

## Problem

- **Wrong advice.** With `o/r#2` stacked on `o/r#1` (both open), `o/r#2` shows `merge #2`, `YOU`, `✔ now`. Merging it lands the change in the parent's branch, not in the default branch.
- **Cause.** `_pr_row` in `borg_core/nextpick/core.py` decides the row from draft, mergeable, checks and review decision. It never reads the base branch, although the GitHub recon adapter already emits `base_ref` and `head_ref` for every PR item.
- **One ranker.** `borg next` and `borg link` both build their rows with `nextpick_cli.item_rows`, which calls `core.work_items`, so the defect appears on both pages and has one fix.

## Solution

One PR, one rule, no adapter change.

1. In `core.work_items`, derive each open PR's parent from the raw items of the same repository: the open PR whose `head_ref` equals this PR's `base_ref`. With several candidates the lowest number wins.
2. `_pr_row` takes that parent and, when there is one, returns step `await #<parent>`, owner `—`, ready `… wait`, the same style as the REVIEW_REQUIRED row.
3. The rule sits after draft, conflicts, failing CI, pending CI and changes requested, and before REVIEW_REQUIRED. A stacked child that is a draft or conflicting still says so; one that is clean or approved never says "merge ✔ now".
4. A PR whose base is the default branch or matches no open PR, and an item with no `base_ref` (older cached data), behave exactly as before.

## Non-Goals

- No change to the adapter or its cached item shape.
- No cross-repository stack detection: a parent must be in the same repository.
- No new owner or ready symbol, and no reordering of existing rules.

## Alternatives Considered

- **Look the base up in the adapter.** The adapter would have to resolve the parent per PR, and older cached data would lack it. Deriving it from items already fetched needs no new data.
- **Put the rule first.** It would hide a stacked child's own draft, conflict or CI work behind a wait. Those rows stay actionable.
- **Compare the base to the default branch.** The adapter does not emit the default branch, so this needs a new field and still fails for a base that is a closed branch.

## Acceptance criteria

- [ ] A PR whose base is another open PR's head never reads "merge ✔ now".
  - Verify: `python3 -m pytest borg_core/nextpick/test_core.py -k stacked_child_waits -q` passes, and fails when the `parent is not None` branch in `_pr_row` is disabled.
- [ ] A stacked child that is a draft, conflicting, failing CI, pending CI or changes-requested keeps that row.
  - Verify: `python3 -m pytest borg_core/nextpick/test_core.py -k keeps_its_own_work -q` passes.
- [ ] A base that is the default branch, matches no open PR, matches only a closed PR, is empty or is absent behaves as today, and a parent in another repository is ignored.
  - Verify: `python3 -m pytest borg_core/nextpick/test_core.py -k "without_an_open_parent or same_repository" -q` passes.
- [ ] The tests feed raw items (`head_ref`, `base_ref`) through `core.work_items`, never a precomputed parent.
  - Verify: `git diff origin/main...HEAD -- borg_core/nextpick/test_core.py | grep -c '^+.*_pr_row('` prints 0, and `python3 -m pytest borg_core/nextpick/test_core.py -k stack -q` passes.
- [ ] The rest of the nextpick and link suites are unchanged.
  - Verify: `python3 -m pytest borg_core/nextpick borg_core/link -q` passes.
