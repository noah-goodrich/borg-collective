# Directive: Viz 3 — Cross-Repo Chains + Three-Tier Ranking
*Filed: 2026-08-11*

Independent project. Third of three decomposed viz directives. **Supersedes criteria C5–C7 of**
`2026-08-10-link-unification-and-attention-routing.md` — that directive conflated four concerns; the chain work
is carved out here, and its ranking model is corrected by the 2026-08-10 post-mortem.

**Sequencing:** do viz 1 and viz 2 first. This directive's ranking is only as good as the spine's freshness
(viz 2), and its tier 1 *is* viz 1.

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

## Acceptance Criteria

- [ ] X1 — **Three tiers, presented in order, never collapsed into one score.** Tier 1: awaiting you (from viz 1
      — a filter, not a rank). Tier 2: unblocks the most downstream work. Tier 3: nearest hard deadline weighted
      by remaining work. Where tiers disagree, show all three and say they do not compete for the same hours.
  - Verify: with a fixture where A unblocks 4 items, B has a P0 due in 3 weeks at 0%, and C is approved+mergeable,
    output surfaces **C first**, then A, then B — each labeled with which tier it came from.
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
  - Verify: `borg link --json` includes a source and timestamp per edge.
  - Rationale: on 2026-08-10 the orchestrator had to retract an edge it had asserted: *"I told you the missing
    ontra-dms-AdministratorAccess profile was step 0 and gated everything. That was wrong."* An unattributed edge
    is folklore.
- [ ] X7 — Chain data derives from the spine's `blocked_by`/`edges`. No new schema, no second source of truth.
  - Verify: no new persisted file; the chain builder reads the spine.
- [ ] X8 — Regression: full bats suite and macOS contract leg green.

## Scope Boundaries
- NOT the Frozen Atlas (Option E in `docs/research/2026-07-28-dependency-graph-tool/recommendation.md`). This is
  the CLI/terminal layer. It must stay **compatible** with that design — same spine, same edge model, same
  unblock-rank concept — and must not preempt it.
- NOT the awaiting-you tier itself (viz 1) or the spine generator (viz 2). This consumes both.
- NOT the hook/attention-routing work still described in the superseded directive.
- NOT auto-executing recommended actions. This ranks and displays; the human decides.
- If done early: ship, don't expand.

## Ship Definition
PR against main, CI green, and the fixture from X1 recorded in the PR body showing all three tiers with the
approved-and-mergeable item surfacing first.

## Timeline
Two sessions, after viz 1 and viz 2.

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
  starts wanting ASCII graph layout, that is the signal to stop and build Option E rather than approximate it.
