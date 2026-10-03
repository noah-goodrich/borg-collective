# Directive: Viz 1 — The Awaiting-You Tier
*Filed: 2026-08-11*
*Severed: 2026-10-03 — CLOSED BY FOLD. The built half shipped in PR
[#125](https://github.com/noah-goodrich/borg-collective/pull/125) (2026-08-14); the OPEN remainder is re-scoped
onto `borg link` and carried by `2026-08-11-viz-3-cross-repo-chains` as its X9.*
*Status at severing (reconciled 2026-09-29 against `2a62536`): three met (V5, V6, V7), one met-with-deviation
(V2), one half met (V3), two open (V1, V4).*

> **Ruling, Noah, 2026-10-03.** The merge-tree browser board is RETIRED; `borg link` is the only place chains are
> drawn. viz-1's OPEN criteria are re-scoped onto `borg link` only, and criteria that serve only the board are
> dropped: V3 (port the tier into `render_graph.py`, delete `render.py`'s copy) is a board criterion and goes to
> `2026-10-03-retire-the-merge-tree-browser-board`; V1 (a structured `blocked_by` in the spine's SCHEMA) is a
> spine shape and is dropped, its intent being served on `borg link` by `gate.kind`. **Why folded rather than kept
> as its own directive:** what is left of viz-1 is one small criterion (V4) on the SAME surface viz-3's X1
> already targets (`borg link`'s landing region and `▸ NEXT`), and X1's tier 1 *is* the awaiting-you tier. Two
> directives specifying one surface is the divergence both warn about. Everything below is the record of what
> #125 built.

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

## Status — reconciled 2026-09-29

Measured against the tree at `2a62536`, not read off the PR body. `#125` shipped the derivation this directive
assumed already existed — the remedy was NOT "already built into the wrong file", only the rendering half was —
and its commit message records two deviations. Both are restated here so neither is lost with the PR.

**MET — V5, V6, V7. MET WITH DEVIATION — V2.**

- **V2**, met with a recorded deviation, and its checkbox is deliberately UNTICKED: the criterion text still requires
  `open + APPROVED + mergeable: MERGEABLE` and the `kind: human` resolution that depends on V1, and neither is met. The
  tick also held only on the fixture: `curate.awaits_you()` is False for every item `borg recon --json` can emit,
  because the adapter's `owner` is `you`, `agent` or `unknown` and never a login, so `is_noah()` never matches a live
  item. The tier works end to end only on data that carries a login. `curate.py` grew `is_noah()`, `awaits_you()` and
  `REVIEW_BUCKET`, and `bucket_for()` ranks the tier below `needs-you` and above `active-chains`. The directive's
  `open + APPROVED + MERGEABLE` is **not derivable**: `recon-adapter-github` selects only
  number/title/state/isDraft/updatedAt/url/headRefName/baseRefName/author, so review state and mergeability are
  never gathered. The shipped condition is `state == OPEN` + non-empty `action_needed` + owner resolving to Noah. The
  non-empty clause is load-bearing — 6 of 13 golden items carry `action_needed: ""`, so dropping it sweeps every open PR
  Noah authored into the tier and reproduces the overload the tier exists to cut through.
- **V5.** The `AWAITING YOU` L0 band renders only when the tier is non-empty. Absent, not empty, as specified.
- **V6.** Falsification recorded manually, as the criterion requires: the new tests do not merely fail against
  pre-fix `curate.py`, they fail to *import* — `REVIEW_BUCKET`, `awaits_you` and `is_noah` did not exist. The
  note survives in the comment block above `TestAwaitingYouTier` in `merge-tree/test_curate.py`. Regenerating the
  golden moved four items `active-chains → review-queue`, three of them `warehouse-permissions#339/#340/#341` —
  the fixture's anonymised names for the three-PR stack this directive was written about.
- **V7.** 134 tests, ruff clean, 93% coverage on the live modules at the time.

**HALF MET — V3, and its own verify clause fails today.**

`grep -c 'awaiting' merge-tree/render_graph.py` returns 9 ✓, but `grep -c 'REVIEW_BUCKET' merge-tree/render.py` returns
**4, not 0** ✗ (re-measured 2026-10-03; the first reconciliation said 3). This is deliberate and argued in #125: the
tier was never functional in `render.py`, so deleting it would remove something that had just started working, and both
renderers now read ONE derivation in `curate.py` — convergence, not the divergence V3 feared. The comment above
`VIZ_COVERED` in the Makefile already marks `render.py` for deletion. The remaining half of V3 is really "retire
`render.py`", which the 2026-10-03 ruling decides: it is retired with the board.

**OPEN — V1 and V4, and for both the question has moved rather than stayed still.**

- **V1** asked for structured `blocked_by` as `{who, what, kind}` with `kind` in `human | technical`. No such
  shape exists in `merge-tree/`. But the distinction it wanted **does** exist, one tree over: `gate.kind`
  (`decision | verification`) in `borg_core/manifest/`, which `link/render.py::_route` uses to split `▸ NEXT`
  into "a decision only you can make" and "anyone can pick these up". Same idea, different noun, different
  substrate. Either V1 is satisfied by that and should say so, or it is still wanted spine-side.
- **V4** asked `borg link` to surface the tier in the landing region. It does not: `render.SECTIONS` is
  header / IN FOCUS / REPOSITORIES / CHAINS / QUEUED / SHIPPED / NEXT / SIGNALS, with no awaiting-you tier, and
  `▸ SIGNALS` now occupies the landing region. But `▸ NEXT`'s `yours` group gives the reader the same answer
  from a different source — manifest gates rather than the spine. V4's *outcome* is served; V4's *wiring* is not.

**What remained was three rulings, not three builds, and 2026-10-03 made them:** `render.py` is retired (V3
leaves with the board); V1 is dropped as a spine-only shape, its intent served by `gate.kind`; V4 survives, as
viz-3's X9, because `▸ NEXT`'s `yours` group serves its outcome but not its wiring or its derivation.

## Acceptance Criteria

- [ ] V1 — *(DROPPED 2026-10-03: spine-only)*
      `blocked_by` entries become structured: `{who, what, kind}` where `kind` is `human` or `technical`.
      Bare strings are still accepted and default to `kind: technical`, `who: unknown` so nothing breaks.
  - Verify: `merge-tree/SCHEMA.md` documents the shape; the renderer handles both forms against a fixture
    containing one of each.
- [ ] V2 — *(MET WITH DEVIATION; deliberately unticked, see Status)*
      `awaiting-you` is derived, not hand-authored. An item in state `open` with review `APPROVED` and
      `mergeable: MERGEABLE` is classified `awaiting-you` automatically; so is any workstream whose only
      `blocked_by` entries are `kind: human` **and** `who` resolves to Noah.
  - Verify: a fixture reproducing `#340`/`#341` (open + APPROVED + MERGEABLE) classifies as `awaiting-you`
    with no manual annotation.
- [ ] V3 — *(MOVED to the board-retirement directive)*
      `render_graph.py` renders `awaiting-you` as its own top tier, ported from `render.py`'s
      `REVIEW_BUCKET`. `render.py`'s copy is then deleted, not left to diverge again.
  - Verify: `grep -c 'awaiting' merge-tree/render_graph.py` > 0; `grep -c 'REVIEW_BUCKET' merge-tree/render.py`
    returns 0.
- [ ] V4 — *(CARRIED to viz-3 as X9)*
      `borg link` surfaces the tier **in the landing region** — the last lines before the prompt, per the
      corrected D2 rule (terminal output auto-scrolls; the eye lands at the bottom, not the top).
  - Verify: `borg link | tail -6` contains the awaiting-you items when any exist.
- [x] V5 — When nothing is awaiting Noah, the tier is **absent, not empty**. An empty labeled section in the
      landing region trains the eye to skip that region (D3: a row that says the same thing as every other row
      costs space and returns nothing).
  - Verify: with a fixture containing no awaiting-you items, `borg link` output contains no tier header.
- [x] V6 — Regression test built from the real case. A fixture derived from `sme-self-service-pat` as it stood on
      2026-08-10 must surface as tier-1. This is the falsification test: it must fail against the pre-fix code.
  - Verify: the test exists, passes after the change, and **is confirmed to fail before it** — record that
    confirmation in the PR body. No mutation tooling exists for this codebase, so this check is manual and
    mandatory.
- [x] V7 — Regression: full bats suite and the macOS contract leg stay green.

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
