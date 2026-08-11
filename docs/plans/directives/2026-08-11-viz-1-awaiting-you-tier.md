# Directive: Viz 1 — The Awaiting-You Tier
*Filed: 2026-08-11*

Independent project. First of three decomposed viz directives (see also `viz-2-spine-generator` and
`viz-3-cross-repo-chains`). **Do this one first** — it is the cheapest, it is already designed, and on its own it
would have prevented the 2026-08-10 failure.

## Objective
Surface work that is **blocked on Noah** as its own labeled tier, ahead of all ranking, in both the live
renderer and `borg link`. Distinguish *blocked-on-you* from *blocked-on-others* in the data model, because
collapsing them is what hid the most actionable work on the board.

## Why — the 2026-08-10 failure, traced

Noah returned from a week away and spent most of a day reconstructing context. The most pressing project —
`sme-self-service-pat` — was never surfaced. The spine already described it, in prose:

> "Decided and APPROVED, but not shipped… The three implementation PRs are all reviewed + APPROVED and green,
> **sitting open behind one manual review-first merge gate**."

Its workstream was recorded as:

```json
"state": "ready-to-start",
"blocked_by": ["manual review-first PR merge/approval gate (human decision, not a technical/code blocker)"]
```

**The author annotated the blocker as non-technical and it still got suppressed.** Any ranking that treats a
non-empty `blocked_by` as a demotion inverts the signal: when the blocker *is the person being briefed*, that is
the most actionable item in the system, not the least.

Verified live on 2026-08-11: `#333`/`#338`/`#339` merged; **`#340` and `#341` are still OPEN, APPROVED, and
MERGEABLE.** Minutes of work, zero risk, still sitting there.

**And the remedy was already built — into the wrong file.** Commit `914c7e2` (2026-07-30) added:

```python
REVIEW_BUCKET = "review-queue"  # Awaiting-Noah review queue -> its own labeled tier
```

…to `merge-tree/render.py` — the renderer being *replaced*. `merge-tree/render_graph.py` (the Story-Lens, now
canonical after #104) has no such tier. The fix shipped twelve days before the failure it would have prevented,
into a dead code path.

## Acceptance Criteria

- [ ] V1 — `blocked_by` entries become structured: `{who, what, kind}` where `kind` is `human` or `technical`.
      Bare strings are still accepted and default to `kind: technical`, `who: unknown` so nothing breaks.
  - Verify: `merge-tree/SCHEMA.md` documents the shape; the renderer handles both forms against a fixture
    containing one of each.
- [ ] V2 — `awaiting-you` is derived, not hand-authored. An item in state `open` with review `APPROVED` and
      `mergeable: MERGEABLE` is classified `awaiting-you` automatically; so is any workstream whose only
      `blocked_by` entries are `kind: human` **and** `who` resolves to Noah.
  - Verify: a fixture reproducing `#340`/`#341` (open + APPROVED + MERGEABLE) classifies as `awaiting-you`
    with no manual annotation.
- [ ] V3 — `render_graph.py` renders `awaiting-you` as its own top tier, ported from `render.py`'s
      `REVIEW_BUCKET`. `render.py`'s copy is then deleted, not left to diverge again.
  - Verify: `grep -c 'awaiting' merge-tree/render_graph.py` > 0; `grep -c 'REVIEW_BUCKET' merge-tree/render.py`
    returns 0.
- [ ] V4 — `borg link` surfaces the tier **in the landing region** — the last lines before the prompt, per the
      corrected D2 rule (terminal output auto-scrolls; the eye lands at the bottom, not the top).
  - Verify: `borg link | tail -6` contains the awaiting-you items when any exist.
- [ ] V5 — When nothing is awaiting Noah, the tier is **absent, not empty**. An empty labeled section in the
      landing region trains the eye to skip that region (D3: a row that says the same thing as every other row
      costs space and returns nothing).
  - Verify: with a fixture containing no awaiting-you items, `borg link` output contains no tier header.
- [ ] V6 — Regression test built from the real case. A fixture derived from `sme-self-service-pat` as it stood on
      2026-08-10 must surface as tier-1. This is the falsification test: it must fail against the pre-fix code.
  - Verify: the test exists, passes after the change, and **is confirmed to fail before it** — record that
    confirmation in the PR body. No mutation tooling exists for this codebase, so this check is manual and
    mandatory.
- [ ] V7 — Regression: full bats suite and the macOS contract leg stay green.

## Scope Boundaries
- NOT building the cross-repo chain view (viz 3) or the spine generator (viz 2). This tier works on whatever data
  the spine currently holds, stale or not — that is the point of doing it first.
- NOT adding a ranking algorithm. `awaiting-you` is a **filter**, not a score. Resist the urge to rank within it
  before there is evidence the tier gets crowded.
- NOT touching the hook/interrupt layer.
- If done early: ship, don't expand.

## Ship Definition
PR against main, CI green including the macOS contract leg, V6's before/after falsification recorded in the PR
body.

## Timeline
One session. The renderer change is a port of existing code; the `borg link` change is a new section in the
landing region.

## Risks
- **`who` resolution is fuzzy.** `render.py` already hardcodes a set of Noah aliases
  (`{"noah-goodrich", "noah goodrich", "noahgoodrich", "noah", "ngoodrich"}`). Reuse it rather than inventing a
  second identity notion, and put it in one place this time.
- **V2's `APPROVED + MERGEABLE` heuristic will over-fire on PRs Noah approved for someone else.** Mitigate by
  requiring the item's `owner` to resolve to Noah as well. If it still over-fires, tighten on evidence, not
  anticipation.
- **Tier-1 could become the new noise.** If everything lands in `awaiting-you`, it stops meaning anything. Watch
  the count; if it routinely exceeds ~5, that is a signal to split it, and a signal that the real problem is a
  merge-review backlog rather than a display defect.
