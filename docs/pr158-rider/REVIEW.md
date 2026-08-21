# Rider: independent review of PR #158

*2026-08-20 · branch `rider/pr-158-review`, based on `feat/program-manifests` (0a59078) · for a second
opinion from another machine*

**tl;dr** — The declaration mechanism is sound and is the only possible source of cross-repo edges (135 of
136 live PRs target `main`, so topology derives nothing). But as filed the PR yields **zero** cross-repo
workstreams on the production path, and `backfill.py` corrupts the judgment it recovers. This rider adds the
one fix that makes the payoff real (proven live: 0 → 2 cross-repo workstreams) and carries the full findings.

## What this branch adds on top of the PR

| Commit | Content |
|---|---|
| fix | `apply_program_projects()` in `merge-tree/gather.py` + 6 tests (293 pass, ruff clean) |
| docs | this review + two real-world manifests under `docs/pr158-rider/manifests/` as evidence |

Diff against the PR: `git diff feat/program-manifests..rider/pr-158-review`

## The one fix, and why it is load-bearing

`spine.py` groups by `items[].project` before computing components, and recon assigns one registry project
per repo. So a declared cross-repo edge is also a cross-project edge, and the spine severs the chain at the
project boundary — the exact case the manifest exists to express. Measured on live recon data (2026-08-20),
same manifests, same pipeline:

| | cross-repo workstreams |
|---|---|
| PR as filed | **0** (4-repo program severed into 4 projects) |
| with `apply_program_projects` | **2** (incl. one genuine 4-repo chain: ingle, reveal, stillpoint, troth) |

The fix re-keys manifest members' `project` to the declaring program id. ~35 lines, additive, no golden
churn. The PR's own test for this claim (`test_..._makes_one_workstream_across_repos`) hard-codes
`project="P"` on both items — supplying the value production must derive, so it proved nothing; the new
`TestApplyProgramProjects` end-to-end test drives the production shape.

## Confirmed findings (all reproduced by execution; severity after adversarial verification)

**Merge blockers as filed:**

1. `backfill.py` silently overwrites manifests on program-id collision while its stats report full
   preservation ("blocks: 1 of 1 preserved" with the edge absent from disk) — the exact failure its own
   comment claims to have fixed, one layer down.
2. A MERGED item mid-chain inverts recorded topology on round-trip: source `[1→2, 2→3]` re-derives as
   `[2→1, 1→3]`; `validate()` passes it clean; declared-beats-derived then deletes the correct edge.
3. `backfill.py` fabricates `declared` stacked edges between rows sharing no recorded order (apex siblings
   get an invented merge order from ref-sort).
4. Non-dict rows pass validation: `{"rows": ["a#1", "b#1"]}` loads with zero warnings and zero edges.
5. `discover()` swallows directory-level `OSError` silently — an unreadable/mistyped `--programs-dir` is
   indistinguishable from "no manifests".
6. `.borg/programs/` is gitignored here (`.gitignore:14`, carve-outs exist for checkpoints/knowledge/
   skill-extensions but not programs) — the artifact cannot be committed in 4 of 7 repos probed.

**Material but not blocking:** `--programs-dir` has no caller (the directive's ship command emits zero
declared edges); `unmapped_gates()` has no production caller and counts mapped gates too (PM4 unmet);
PM8's independence grep scans 2 of 4 new files (backfill.py unscanned); `merge_edges` misattributes a
declared-vs-declared reversal as "topology says the reverse" even with no derived edges; `curate.py:177`
strips `source`, so provenance never reaches `data.json` or the renderers.

## Recommendation

Split the PR: **merge** `programs.py` + `SCHEMA.md` + the `gather.py` provenance work + this rider's fix,
after adding a `--programs-dir` caller and the `.gitignore` carve-out. **Hold** `backfill.py` for rework
(findings 1–3 live there; it recovers exactly 1 cross-repo edge of 72 by its own measurement and cannot run
on machines without the historical `data.json`). Rewrite viz-3's X6/X7 before scheduling that directive —
X7 ("no new persisted file") forbids the only mechanism that can produce cross-repo edges, and this PR is
the proof.

## Evidence trail

- `docs/pr158-rider/manifests/` — the two hand-authored manifests used for the live measurements
  (`ingle-t1-cutover`: 14 rows, 4 repos, from verified PR relationships; `viz-program`: 3 rows).
- Live numbers: 136 items swept, 15 edges (1 derived + 14 declared), 0 dangling endpoints across 13
  hand-typed refs — the "rows key on `ref`, no normalization" design validated itself.
- Full adversarial review: 15-agent verify pass; every finding above survived a dedicated refutation
  attempt. Ask the borg-collective session of 2026-08-18/20 for transcripts if needed.


## Addendum 2026-08-20 — the communication program rides along

Since the original review, Noah accepted a communication program that this PR's edge data feeds. Added to
this branch for your review:

- **Directives at their real paths**: `docs/plans/directives/2026-08-20-communication-program.md`
  (accepted, decisions locked) and `2026-08-20-comms-delivery-surfaces.md` (S1-S5). The claude-plugins
  half is `docs/pr158-rider/claude-plugins-directive-copy.md` (canonical copy lives in that repo; its
  drone is building K1-K3).
- **Rendering decision — one visual grammar for every status surface**: the topological grid, picture
  first, always vertical; a linear chain is a one-column DAG. Node ids appear exactly twice so vim `*`
  toggles picture <-> detail; refs are full `owner/repo#num` (self-addressing; a `gp` keymap opens the
  PR — lives in dotfiles). See `docs/pr158-rider/rendered/chains.md` (live data through the unified
  renderer) and `rendered/chains-dag-mock.md` (the fork/join treatment, approved).
- **Runnable prototypes**: `docs/pr158-rider/prototypes/`. Regenerate: `borg recon --json --since <ISO>`
  piped to `merge-tree/gather.py --programs-dir <proj>`, then `build_chains.py` + `render_chains_md.py`.
  Pass an ISO date; the relative form (`--since 30d`) silently returns zero items (known bug, unfixed).
- **Manifests now carry `desc`** (one plain sentence, rendered under the program heading) — not yet in
  SCHEMA.md; flag for the split-merge. Planned next field: row-level `after: [refs]` for true forks
  (lanes only express linear tracks).
- **Known lag**: `render_chains_ansi.py` still renders the pre-grid rail form; the md renderer is the
  reference implementation of the spec.
