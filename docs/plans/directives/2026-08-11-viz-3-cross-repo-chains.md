# Directive: Viz 3 — Cross-Repo Chains + Three-Tier Ranking, on `borg link`
*Filed: 2026-08-11*
*Status: NOT STARTED, RE-SCOPED 2026-10-03 onto `borg link` only. 0 of 9 met (X1-X8 as filed, plus X9 carried
from viz-1). Reconciled 2026-09-29 against `2a62536`; rulings recorded 2026-10-03.*
*This is the directive `PROJECT_PLAN.md`'s `*Next:*` pointer names: it starts when State Hygiene ships.*

Third of three decomposed viz directives, now the only one left standing: viz-1 was folded into this file and
viz-2 severed (see "Rulings"). **Supersedes criteria C5–C7 of**
`2026-08-10-link-unification-and-attention-routing.md` — that directive conflated four concerns; the chain work
is carved out here, and its ranking model is corrected by the 2026-08-10 post-mortem.

**Sequencing:** State Hygiene (`2026-09-28-state-hygiene-reader-census`) is a PREDECESSOR GATE, not a parent: it
must ship first because a viz feature built on stores nothing reads would repeat the failure it is chartered to
end. It is deliberately NOT a `*Parent plan:*` — that line would make Step 0.75 block State Hygiene on its own
payoff. The relation is carried by `*Next:*` on `PROJECT_PLAN.md`. The viz-1 and viz-2 prerequisites this
section used to name are resolved: viz-1's built half shipped (#125) and its remainder is X9 below; viz-2's
generator fed a board that is retired.

## Objective
Answer "what should I work on next, across all repos" by surfacing dependency chains that span repositories, and
ranking with **three tiers rather than one score** — because a single score is what buried the right answer on
2026-08-10.

## Why the ranking model changed

My earlier draft of this work (in the superseded directive) proposed ranking by **downstream unblock count**,
with recency as the tiebreak. **The 2026-08-10 post-mortem falsified that.** On that day the orchestrator produced
two axes and chose between them:

> "Most things unblocked → push #2564. Highest stakes → the keypair e2e. They don't compete for the same hours."

Both axes missed `sme-self-service-pat`, which was three approved-and-green PRs behind a single human merge gate.
Four distinct reasons, each a design requirement here:

1. **It had few downstream dependents**, so unblock-count ranked it low.
2. **It had no Jira ticket at all** — the spine has an entire workstream titled *"Governance: no Jira ticket
   exists"* — so the stakes axis scored it **zero**. Untracked work is structurally invisible to deadline ranking.
3. **Effort was never an axis.** The recommendation was a stacked-branch restructure explicitly flagged as risky
   (*"a careless force-push has already cost you Kelly's fix once"*), chosen over merging three approved PRs —
   minutes at zero risk.
4. **Its blocker was Noah**, recorded as a `blocked_by` string, which any suppress-on-blocked logic inverts.

## Rulings — Noah, 2026-10-03

1. **The merge-tree browser board is RETIRED. `borg link` is the only place chains are drawn.** This was One Front
   Door's intent ("the single front door", `2026-08-24-one-front-door-link-derived-fact-surface`); its teardown
   was never filed. It is filed now: `2026-10-03-retire-the-merge-tree-browser-board`.
2. **The manifest grid is canonical.** There is one edge source, `.borg/chains/*.json`, feeding two derived views:
   `story.json` (persisted, via `gather.py` then `spine.py`, read only by the board) and the `borg link` grid
   (computed on every invocation). The first is retired, so the second is the only model. X7 is reworded to say
   so, and is satisfiable once the second edge derivation in `merge-tree/programs.py` is retired by
   `2026-08-31-retire-merge-tree-programs-into-borg-core`.
3. **viz-1 and viz-3 are re-scoped onto `borg link` only**; criteria that serve only the board are dropped. viz-2
   is closed (its built criteria shipped in #144; the rest is severed with the board). viz-1 is **folded into this
   file** rather than kept: its one surviving criterion (V4, now X9) targets the same surface as X1, whose tier 1
   IS the awaiting-you tier, so two directives would otherwise specify one surface.
4. **State Hygiene is a predecessor gate to this work, not its parent** (see Sequencing).

## Status — reconciled 2026-09-29, re-read through the rulings

Measured against the tree at `2a62536`. **No X criterion has been implemented.** Five weeks of `borg link` work
landed between the filing and now and answered several of these questions in a different place, so the criteria
below were rewritten to ask only for what `borg link` does not already do.

**Partly answered already — X1, X5, X6.**

- **X1's tier 1 exists on the retired board and, as a different mechanism, on `borg link`.** The awaiting-you
  derivation shipped into `merge-tree/curate.py` (#125) and dies with the board. On the surviving surface,
  `▸ NEXT` routes ready rows into `yours` / `mine` / `unsure` — a decision-vs-not split rather than a score, which
  is what X1 asked tier 1 to be. Tiers 2 and 3 have no home anywhere.
- **X5's distinction is derived but not rendered.** The retired spine separated chain edges (`stacked`/`apex`,
  which group into one workstream) from `blocks` edges (which must not group, because merging on them collapses a
  blocker into its own victim). The manifest grid carries edge kinds too; what X5 asks for that does not exist is
  the *rendering* difference in `borg link`'s picture.
- **X6 is partly met, on the wrong surface.** `merge-tree/gather.py` stamps every edge `source: derived|declared`
  (#158), so the board pipeline has per-edge provenance without a timestamp. `grid.py` and `picture.py` carry
  provenance for a ref's **state** (`swept | fetched | declared | unknown`), a different claim. `borg link --json`
  carries neither a source nor a timestamp per edge, which is what X6 asks for, so X6 stays open on its re-scoped
  surface.

**Blocked on the GitHub adapter, not on this directive — X2, part of X3, and X9's derivation.**

X2's whole effort signal is `open + APPROVED + MERGEABLE` as a machine-detectable proxy for "minutes".
`recon-adapter-github` gathers neither review state nor mergeability, and the selection line alone would not fix
it: the adapter's jq builds an explicit item and drops any field it does not name, so the fields must be projected
too. Nor is `APPROVED` the right test for this repo — one shared account cannot self-approve, so `reviewDecision`
is empty on every recent PR here, and `watch/core.py::prior_stamp` already calls an `APPROVED` gate one that can
never fire. For this repo the honest condition is a valid stamp at the current head. That adapter work is its own
additive PR and is not part of this directive. X3's picture half exists — `borg_core/link/picture.py` renders
cross-repo chains with membership and ordering — but not which end Noah owns nor a downstream-idle count.

**Still genuinely open and uncovered — X4.** No `untracked` marker exists anywhere in the tree. The case that
motivated it is unaddressed: a workstream titled *"Governance: no Jira ticket exists"* scores zero on a stakes
axis and vanishes. It depends on neither ruling nor the adapter.

**Premise broken, now repaired by ruling — X7.** X7 said chain data derives from the spine. `borg link`'s CHAINS
derives from `.borg/chains/*.json` manifests, never from `story.json` (`grep -rn story.json borg_core/` is empty).
Ruling 2 settles which is canonical, and X7 below says so.

## Acceptance Criteria

- [ ] X1 — **Three tiers, presented in order, never collapsed into one score.** Tier 1: awaiting you (X9
      — a filter, not a rank). Tier 2: unblocks the most downstream work. Tier 3: nearest hard deadline weighted
      by remaining work. Where tiers disagree, show all three and say they do not compete for the same hours.
  - Verify: with a fixture where A unblocks 4 items, B has a P0 due in 3 weeks at 0%, and C is approved+mergeable,
    `borg link` surfaces **C first**, then A, then B — each labeled with which tier it came from.
- [ ] X2 — Within a tier, rank by **value ÷ effort**, not value alone. `open + APPROVED + MERGEABLE` is a
      machine-detectable proxy for "minutes"; a stacked-branch restructure or a multi-PR rebase is not.
  - Verify: with two tier-2 items of equal unblock count, the one whose items are all approved+mergeable ranks
    first, and the output states why.
- [ ] X3 — Cross-repo chains render with membership in order, which end Noah owns, and how many downstream items
      are idle because of it.
  - Verify: a fixture with an A→B→C chain spanning three repos renders one line with correct membership and a
    correct downstream-idle count.
- [ ] X4 — **Untracked work is flagged, not scored zero.** An item or workstream with no linked ticket carries an
      explicit `untracked` marker and is never silently demoted on the stakes axis.
  - Verify: a fixture workstream with no ticket appears with the marker and retains its tier-2 position.
- [ ] X5 — The edge model distinguishes **stacked-branch** from **blocked-by**. `#2566` rebased onto `#2564`
      implies a rebase-order constraint, which is a different relationship from "A blocks B" and is expensive to
      get wrong.
  - Verify: a fixture with a stacked pair renders differently from a blocking pair.
- [ ] X6 — Edges carry **provenance** — which source asserted them, and when — so a wrong edge is falsifiable.
      Partly met on the retired board's pipeline only: `gather.py` stamps `source: derived|declared` (#158), with no
      timestamp. Open on `borg link`.
  - Verify: `borg link --json` includes a source and timestamp per edge.
  - Rationale: on 2026-08-10 the orchestrator had to retract an edge it had asserted: *"I told you the missing
    ontra-dms-AdministratorAccess profile was step 0 and gated everything. That was wrong."* An unattributed edge
    is folklore.
- [ ] X7 — Chain data derives from `.borg/chains/*.json` manifests plus the live sweep. No new persisted file.
      Nothing under `borg_core/` reads `story.json`, and merge-tree derives edges through `borg_core/manifest`
      rather than a copy. *(Reworded 2026-10-03 per ruling 2; filed as "derives from the spine's
      `blocked_by`/`edges`".)*
  - Verify: `grep -rn story.json borg_core/` is empty (true today). The second half — `grep -rn 'import programs'
    merge-tree/` is empty — is NOT true today (`coordinator.py` and two test files import it) and becomes true
    when `2026-08-31-retire-merge-tree-programs-into-borg-core` lands; X7 is not ticked before then.
- [ ] X8 — Regression: full bats suite and macOS contract leg green.
- [ ] X9 — *(carried from viz-1's V4, re-scoped 2026-10-03)* `borg link` surfaces the awaiting-you tier in the
      landing region — the last lines before the prompt (terminal output auto-scrolls; the eye lands at the
      bottom). When nothing is awaiting Noah the tier is **absent, not empty**: an empty labeled section trains
      the eye to skip that region. `▸ NEXT`'s `yours` group serves the outcome today from manifest gates; this
      criterion is the wiring and the derivation. The derivation is the open question viz-1's V2 left behind: on
      this repo it needs a valid stamp at the current head rather than `APPROVED` (see Status), and it needs the
      adapter PR first.
  - Verify: `borg link | tail -6` contains the awaiting-you items when any exist, and contains no tier header
    against a fixture with none.

## Scope Boundaries
- NOT the merge-tree browser board or the Frozen Atlas (Option E in
  `docs/research/2026-07-28-dependency-graph-tool/recommendation.md`). The board is retired (ruling 1); this is
  the CLI/terminal layer, and it adds no `story.json` reader.
- NOT the spine generator (viz 2, severed) or the GitHub adapter enrichment (`reviewDecision`, `mergeable`,
  `headRefOid`), which is its own additive PR.
- NOT the hook/attention-routing work still described in the superseded directive.
- NOT auto-executing recommended actions. This ranks and displays; the human decides.
- If done early: ship, don't expand.

## Ship Definition
PR against main, CI green, and the fixture from X1 recorded in the PR body showing all three tiers with the
approved-and-mergeable item surfacing first.

## Timeline
Two sessions, after State Hygiene ships.

## Risks
- **Three tiers could become three things to ignore.** The failure mode of the two-axis version was choice
  paralysis dressed as analysis. Tier 1 must be short or absent; if all three tiers are routinely long, the
  display has reproduced the original problem with more structure.
- **Value ÷ effort invites a fake precision.** There is no honest way to score "effort" in general; the only
  effort signal proposed here is the machine-detectable approved+mergeable case. Do not extend it to estimated
  hours or story points — an invented denominator is worse than no denominator.
- **Deadline data mostly does not exist.** Only Jira-linked items carry dates, and X4 exists precisely because
  much of the real work has no ticket. Tier 3 will be sparse; that is honest, not a bug to paper over.
- **This directive is where terminal output stops being the right medium.** Chains across three repos with typed
  edges and provenance are a graph, and the Frozen Atlas exists because a terminal cannot render one well. If X3
  starts wanting ASCII graph layout, that is the signal to stop and re-open the question with Noah — the board is
  retired, so "build Option E" is no longer a default fallback; it would be a new decision.
