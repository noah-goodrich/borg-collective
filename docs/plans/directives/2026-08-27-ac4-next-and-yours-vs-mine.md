# Directive: Binding Implementation Spec for AC4 — READY, and yours vs mine
*Parent plan: 2026-08-24-one-front-door-link-derived-fact-surface*
*Parent directive: 2026-08-26-ac2-topological-grid-renderer*
*Filed: 2026-08-27*

**tl;dr** — `borg link` gains one section, `▸ NEXT`, inserted between SHIPPED and SIGNALS. It renders the READY set —
open rows whose every parent has merged — split into three labelled groups: **yours** (a person must decide),
**mine** (anyone, including an agent, can run it) and **unsure** (the gate names a kind nobody recognizes). READY is
**three-state**: a populated set, an empty set, and *nobody looked* are three different sentences.

## 1. The decisions, and who made them

Three questions were open after AC2. All three are now answered; this section records the answers and the evidence,
because each one is a place where a plausible alternative is wrong in a way tests would not catch.

### D1 — READY is three-state, and declared states do not feed it

`manifest_core.ready_set` already refuses unknown parents ("Unknown is not merged"). But it takes `{ref: state}` with
PROVENANCE ERASED, so a hand-typed `"status": "merged"` parent is indistinguishable from a swept one. The question was
whether `grid.py` hands it declared states.

**Measured on the live `stillpoint/.borg/programs/ingle-t1-cutover.json`, both ways:**

| render | resolved | declared | unknown |
|---|---|---|---|
| real sweep | **14/14** (9 swept, 5 fetched) | 0 | 0 |
| `--local` | **0/14** | 12 | 2 |

**Provenance is a function of `--local`, not of manifest quality.** That collapses the decision: on a swept render
every state resolves, so excluding declared states costs nothing at all. It bites only under `--local`.

So: **`ready_set` receives resolved states only.** And because that makes READY empty on every `--local` render, the
section is three-state:

- **populated** — these rows are ready.
- **empty, and we looked** — nothing is ready right now.
- **unknown — nobody looked** — no state on this page was resolved.

An empty set and an unchecked set are different facts. Collapsing them is the same failure
`skills/borg-link/SKILL.md` already names for `order: []` versus `total_projects`: *"Those are two different sentences
and getting them backwards is the known trap."* `▸ SIGNALS` already prints `14 of 14 declared refs unresolved — nobody
looked` on exactly this render; `▸ NEXT` must agree with it rather than contradict it with a blank.

### D2 — routing, including a third list

`manifest_core.gates`' docstring already states the rule and this spec adopts it unchanged: *a `decision` blocks a
PERSON, a `verification` blocks nobody in particular because anyone can run it.* Across **every manifest that exists** —
`ingle-t1-cutover`, `viz-program`, `auth-hardening`, `warehouse-rollout` — those are the only two kinds ever written.

| group | rule |
|---|---|
| **yours** | ready, gated by `decision` |
| **mine** | ready, and either **ungated** or gated by `verification` |
| **unsure** | ready, gated by a kind that is neither |

**An unrecognized kind gets its own group rather than a default side.** Owner's call, and it is the right one: the
plan's own named risk is "a mis-set gate routing a human decision to an agent", and BOTH defaults are lies — routing it
to *mine* risks an agent acting on a decision, routing it to *yours* silently asserts the author meant a decision. A
third group says the true thing, which is that the router does not know. This is the third time this project has landed
on the same rule: an unknown is a state, not a default (cf. `?` for unverified provenance in AC4's precondition, and
*empty* vs *nobody looked* in D1 above).

**An ungated ready row is `mine`.** Nothing is blocking it, so nothing needs a human first.

**Rendered against live data today** (`ingle-t1-cutover`, real sweep, computed with `ready_set` + `gates`):

```
14 rows, 2 READY, 2 gated
  yours  (1): stillpoint-labs/stillpoint#48
  mine   (1): stillpoint-labs/stillpoint#57
  unsure (0): —
```

Two rows out of fourteen. The other twelve are merged or waiting on a parent and appear in neither list. That ratio IS
the feature: the section is small because it is answering "what can be picked up right now", not "what exists".

### D3 — one section, three groups. Not three sections.

AC2's directive already rejected the adjacent design: *"reserving an eighth, always-empty section slot for AC4's
yours-vs-mine so its diff is a pure append. A section that renders only a placeholder in every context for a whole
release is the exact 'reads as broken' failure Q10 exists to prevent."*

`unsure` is `0` on every manifest that exists. As its own section it would render empty on every page for the whole
release — precisely what was rejected. As a **group inside `▸ NEXT`** it simply does not appear until something lands
in it.

**The spine goes 7 → 8 and `SECTIONS` gains one entry.** The spine test goes red, deliberately, and that red is the
reviewable event. Headers stay byte-identical in both contexts, which is the AC2 invariant this must not break.

## 2. What renders

`▸ NEXT` sits between `▸ SHIPPED` and `▸ SIGNALS`. Group labels are lowercase and indented, so they read as groups
rather than as sections:

```
▸ NEXT  2 ready of 14

  yours — a decision only you can make
    ● n12  stillpoint#48   Kelly must sign off on the maintenance window
  mine — no decision needed first, so anyone can pick these up
    ● n11  stillpoint#57   needs a live-prod confirmation run against all four contracts
```

> **`mine`'s HEADING WAS CORRECTED 2026-08-28.** As shipped it read *"nothing is blocking these"*, which was
> written for the ungated half of the group and is a false statement about the other half — D2 below routes
> `verification` gates here too, and `_next_row` prints the gate's `blocked_by` on the same line. The live render
> above is the actual reproduction: the heading denied a blocker printed directly under it, on the single most
> decision-relevant line of the front door. **The routing did not change** and must not; D2's rule is correct. The
> heading now names the axis the routing actually splits on — whose hands the row needs — which is true of both
> members. Pinned by
> `test_render.py::test_the_mine_heading_is_true_of_a_verification_gated_row_and_not_only_an_ungated_one`,
> and `tests/fixtures/link/manifests/auth-hardening.json`'s `acme/infra#12` now carries a `verification` gate so
> both grid goldens render the populated form. Before that fixture row, every `mine` row in every golden was
> ungated and the goldens were blind to this input entirely.

`unsure` renders only when non-empty, and names the kind it could not route:

```
  unsure — the gate says "review", which does not route
    ● n4   platform#420
```

The two non-populated states:

```
▸ NEXT  nothing is ready
▸ NEXT  unknown — nobody looked (run without --local to resolve)
```

**The glyph is `●` and it is provenance-marked like every other cell** (`●?`), reusing AC4's precondition. `ready` is
exactly the field whose `●` branch the precondition was filed to protect: the moment this ships, a `●` off hand-typed
parents would read "start this now". D1 makes that unreachable by construction — `ready_set` never sees a declared
state — and the mark is the belt to that braces.

## 3. Function decomposition

| where | what |
|---|---|
| `grid.py` | `ready_refs(manifest, nodes)` — builds `{ref: state}` from RESOLVED nodes only, calls `manifest_core.ready_set`, returns `{"state": "known"\|"unlooked", "refs": [...]}`. Emits `ready: true` on each node in the set. |
| `grid.py` | emit `draft` from `isDraft`, which `_FETCH_NODE` already selects (`grid.py:323`) — folded in from AC2's follow-up list, because a draft PR must not be announced as ready. |
| `picture.py` | unchanged except that `state_glyph`'s `●` branch becomes reachable. No new function. |
| `render.py` | `_next_section` + one `SECTIONS` entry. Routing lives here: it reads `gate.kind` off the wire and never re-derives a gate. |

**Routing belongs in `render.py`, not `grid.py`.** `gates()` is already on the wire and its docstring warns that
reaching for `unmapped_gates` as the routing source "silently drops exactly the decisions that were careful enough to
name their blocker". The renderer reads `gates`, full stop.

## 4. Tests — every one with the mutation that turns it red

| id | case | mutation |
|---|---|---|
| A1 | a declared-merged parent does NOT make its child ready | pass declared states into `ready_set` |
| A2 | `--local` renders `unknown — nobody looked`, not an empty list | collapse the two states into one |
| A3 | zero ready rows on a swept render says `nothing is ready` | same collapse, other direction |
| A4 | a `decision` gate routes to yours, `verification` to mine | swap the two arms |
| A5 | an ungated ready row routes to mine | default ungated to yours |
| A6 | `kind: "review"` routes to unsure and names the kind | default an unknown kind to either side |
| A7 | `unsure` renders no group header when empty | render it unconditionally |
| A8 | a draft PR is never ready | drop the `draft` emission |
| A9 | the spine is eight sections, headers byte-identical in both contexts | insert NEXT in one context only |
| A10 | `●` carries `?` when provenance is unresolved | skip the mark on the ready branch |

**THE FIXTURES ARE BLIND TO THREE OF AC4'S INPUTS AND MUST NOT STAY THAT WAY.** This is now a pattern, not a one-off —
AC4's precondition hit the identical gap on `status` and closed it by adding `acme/warehouse#75`. Measured across all
four manifests that exist:

| input | rows carrying it, live | rows carrying it, fixtures |
|---|---|---|
| `next: true` | 1 per live manifest | **0** |
| an unrecognized `gate.kind` | 0 | **0** |
| `draft` / `isDraft` | not emitted at all | **0** |

Each renders identically whether the code works or not. **A4/A6/A8 are not satisfiable without new fixture rows**, and
adding them is part of this work rather than a follow-up.

## 5. Files that change

| path | change |
|---|---|
| `borg_core/link/grid.py` | `ready_refs`; `ready` on nodes; emit `draft` from `isDraft` |
| `borg_core/link/render.py` | `_next_section`; one `SECTIONS` entry between SHIPPED and SIGNALS |
| `borg_core/link/test_grid.py` | A1, A2, A3, A8 |
| `borg_core/link/test_render.py` | A4, A5, A6, A7, A10 |
| `borg_core/link/test_picture.py` | the `●` branch stops being dead |
| `tests/cli_contract.bats` | A9; the spine case goes 7 → 8 |
| `tests/fixtures/link/manifests/*.json` | a `next: true` row, an unrecognized-kind gate, a draft row |
| `tests/fixtures/link/fetch-acme.json` | an `isDraft` answer |
| `tests/fixtures/link/link-grid-*.golden` | **both regenerate** |
| `skills/borg-link/SKILL.md` | additive: `ready`, `draft`, and the three-group routing |
| `CLAUDE.md` | the spine is now eight sections |

**`DOCUMENT_VERSION` stays 2.** `ready` and `draft` are additive keys and no existing key narrows — the same shape
`scope`, `grid` and AC2's topology keys all took.

## 6. Sequencing

**S1 — the wire.** `ready_refs`, `ready`, `draft`, plus the fixture rows. Additive; goldens do not move because
`render.py` prints none of it yet. A1/A2/A3/A8 land here.

> **AMENDED 2026-08-27 (S1), by execution. "GOLDENS DO NOT MOVE" IS FALSE, AND `render.py` IS NOT WHAT MOVES THEM.**
> `picture.state_glyph`'s `●` arm reads `node.get("ready")` and has shipped **dead but tested** since AC2. The moment
> `grid.py` emits the field, every ready node's glyph changes from `○` to `●` — with zero edits to `render.py`, which
> is the module this step's additivity claim was reasoning about. The wire is not additive when a renderer is already
> reading the key it adds.
>
> **Both grid goldens therefore regenerate in S1, and again in S2 for the section.** The AC2 spec's
> "regenerate exactly once" rule is not violated: it forbids repeated regeneration *within* a step, and each of these
> is one predicted diff in one reviewed commit. The S1 diff is `○` → `●` and nothing else, on exactly the node set
> AC2's own "golden blast radius" paragraph named in advance — `n2/n3/n4` in `link-grid-repository`, those plus `n9` in
> `link-grid-orchestrator`. A diff containing anything more than those glyphs means S1 changed something it should not
> have.
>
> **The two hand-authored `.expected` oracles move for the same reason and are hand-edited, not regenerated.**
> `BORG_UPDATE_GOLDEN` does not write them by design. The rule applied by hand: a node whose every parent has merged
> becomes `●`. In both files that is exactly the three second-level nodes under the merged trunk.

**S2 — the section.** `_next_section`, the `SECTIONS` entry, A4–A7, A9, A10. **Both goldens regenerate, once.** The
spine test goes red and is updated in the same diff, which is the reviewable event.

**S3 — documentation.** `SKILL.md` and `CLAUDE.md`, last, describing what shipped.

## 7. Residual risk, stated

**`unsure` ships with zero live instances.** Its fixture row is authored, so it is tested, but no real manifest has ever
produced one. If a year passes with it still empty, the honest move is to delete the group rather than keep a branch
alive on a hypothetical.

**READY is empty on the three `--local` surfaces**, which is correct but means the section's populated form is only
ever seen on a swept render. Note that `docs/plans/directives/2026-08-27-retire-unused-link-surfaces.md` proposes
deleting two of those three; if it lands first, this risk mostly evaporates.

**`ready_set` is not re-implemented and not modified.** It is already tested in its own suite. Every decision above is
about what is HANDED to it, which is the seam AC2's `grid_manifest` docstring identified when it deferred `ready` in
the first place.
