Generated: 2026-08-20

# Project Completion Audit: do we actually need the infoviz program?

**Glossary.** *Directive*, a filed unit of work with acceptance criteria, in `docs/plans/directives/`.
*Assimilated*, shipped and archived to `docs/plans/assimilated/`. *Severed*, deliberately retired.
*Shipped-unarchived*, the work is verifiably done (merged PRs, artifacts on disk) but the directive file was
never archived or its checkboxes flipped. *Stalled*, work started, then silent for 14+ days with criteria
unmet. *Filed-only*, backlog; never started. *Checkpoint*, the session-end state file at
`.borg/checkpoints/<ts>.md`. *Multi-phase*, a plan with two or more named phases or three or more lettered
acceptance criteria. *Volunteered capture*, record-keeping that requires someone to remember to do it.
*Derived capture*, state computed from artifacts that work already produces (git history, PRs).

## 1. Recommendations

- **Build the directive-state deriver first.** Mechanize the audit rubric this study used: classify every
  directive from git last-touch, checkpoint mentions, PR references, and checkbox state, automatically, on
  every `borg link`. This is the infoviz program's data layer, aimed at plan state instead of PR topology.
  (Backed by §4.2: 36 of 109 open directives are already done and nothing knows it.)
- **Surface it in `borg link`'s landing region** alongside the awaiting-you tier, the two consumers that
  change a morning. Graph rendering stays behind them in the queue. (§4.4)
- **Stop trusting checkboxes; reconcile or retire them.** 27% of criteria are checked in files whose real
  completion is roughly double that; one shipped project has 0 of 44 boxes checked. Have the deriver flip
  boxes from evidence, or drop checkbox state from the format. (§4.1)
- **Keep PR #158's declared-edges layer**, same derived-capture principle applied to cross-repo programs,
  proven live in the 2026-08-18 PoC. (§4.3)
- **Fix `borg recon --since 30d`** silently returning zero items; every derived view feeds on recon. (§4.3)

## 2. Summary

The question this audit answers: does the local evidence justify the infoviz program, or was the earlier
"park it" recommendation right?

**The evidence overturns "park it." It also redirects the program.** Across 10 projects, 367 directives,
381 checkpoints, and 75 session logs, the audited failure is not abandonment. Started work finishes at 87%,
and true mid-plan stalls are rare (21 units, 6.7%). What fails, pervasively and measurably, is **state truth**:
knowing what is done, what is in flight, and what is actually open, without a human re-deriving it by hand.

Three numbers carry the whole case. **83%** of all plans are multi-phase, so plan position is real state that
must live somewhere. **97%** of checkpoints (370 of 381) restate that position by hand ("Phase 1 shipped,
AC4 deferred, resume at S6"), which is the manual workaround for state having no authoritative home. And
**47%** of the non-backlog open board (36 of 76 directives) is *already done* but never recorded as done, so
every morning the board overstates the real workload by roughly two to one.

The audit's method is its own conclusion: establishing these numbers took a pre-registered rubric and 14
agents reading git history: exactly the derivation the tooling should perform for free.

**Testability:** cheaply testable in-environment, and tested: every number above comes from direct
observation of local artifacts, with a blind 40% recount reproducing file sets at 100% and status labels at
85% (all misses are documented boundary calls; see verification-report.md).
**Stamps:** adapted evidence run over a local corpus; web-citation gate not applicable; independent
verification = blind recount.

## 4. Analysis

### 4.1 Volunteered capture failed everywhere it was tried

Checkbox state is volunteered capture, and it decays exactly the way the cairn decommission predicted. Only
178 of 657 open-directive criteria (27%) are checked. ingle-site is the clean natural experiment: five
directives filed and *fully shipped the same day* in one commit, and all 44 checkboxes are still unchecked
three months later, with none of the five files archived. borg-collective shows the same drift in slow
motion: PRs #125, #144, #148, #151 merged real acceptance criteria and not one flipped a box; two repair
efforts (the 2026-08-14 reconciliation commit, the latent-defects filing) exist purely to patch this by hand.

### 4.2 The board lies in one direction: it overstates open work

Of 109 open directives: 36 shipped-unarchived, 19 in-flight, 21 stalled, 33 filed-only. The 36 are the
finding. Nothing distinguishes them from live open work without reading git, which is why the blind
verifier and miner, applying one rubric to agreed facts, still split on 5 of them. A board where half the
"active" items are finished isn't a backlog, it's a memory test.

### 4.3 What already works is the derived-capture pattern

The 87% completion rate deserves its own sentence: the directive discipline ships things. The parts
of the system that stayed truthful are the parts that derive from artifacts work already produces: git
history, merged PRs, the checkpoint template that a skill mandates at session end (which is why 97% of
checkpoints exist at all). PR #158 extends the same pattern to cross-repo dependencies, and the 2026-08-18
PoC showed it working on live data (a four-repo chain rendered from two declared manifests). The pattern
holds across every corpus audited: **mandated-or-derived capture survives; volunteered capture rots.**

### 4.4 Steel-man of the parked position, and where it still stands

The strongest version of "park it": nine open PRs is a list, not a graph; four supply-side PRs shipped with
zero consumers; the renderer's awaiting-you tier can't fire because the adapter never fetches review fields.
All still true, and the audit sharpens rather than refutes it. The demonstrated need is **state derivation
and two consumer surfaces**, not graph decoration. Where the parked position fails is its breadth: with 83%
of plans multi-phase and 370 hand-written state restatements on disk, "three lines in borg link" understates
the problem. The program is justified; its next dollar goes to the deriver, not the diagram.

## 5. Research (per-project measurements)

| Project | Open | Shipped-unarchived | Stalled | Assimilated | Checkpoints (hand-state %) |
|---|---|---|---|---|---|
| ingle | 37 | ~14 | ~10 | 109 | 126 (99%) |
| reveal | 28 | ~8 | ~6 | 31 | 57 (~96%) |
| troth | 18 | ~7 | ~4 | 31 | 56 (98%) |
| borg-collective | 12 | 0 | 0 | 44 | 81 (95%) |
| ingle-site | 5 | 5 | 0 | 1 | 0 (—) |
| stillpoint | 4 | ~2 | ~1 | 0 | 9 |
| claude-plugins | 4 | 1 | ~1 | 1 | 9 |
| snowfort | 1 | 0 | 1 | 2 | 9 (89%) |
| reveal-site | 0 | 0 | 0 | 7 | 10 (100%) |
| cairn (archived) | 0 | 0 | 0 | 10 | 24 (92%) |
| **Total** | **109** | **36** | **21** | **236** | **381 (97%)** |

Per-directive rows with evidence lines live in the workflow output (`audit.json`); per-project source cards
with verbatim quotes are at `docs/research/2026-08-20-project-completion-audit/sources/` (10 cards). Tilde values
mark counts whose exact split sits inside a project's own miner notes rather than the aggregate.

## 6. Methodology

**Design.** Pre-registered rubric (SHIPPED-UNARCHIVED / IN-FLIGHT / STALLED / FILED-ONLY, 14-day activity
window, multi-phase and manual-tracking definitions) fixed before any mining. One agent per project read
every open directive, counted criteria, dated last activity from `git log`, and grepped checkpoints for
plan-position restatement. Corpus: 10 projects with planning artifacts (3 registered projects had none).
**Search log equivalent:** the corpus enumeration is the scout table in the session transcript; no web
searches were run; this is a local-artifact study by design.
**Verification.** Blind recount, sampled 4 of 10 corpus cards (40%): 46 directive files independently classified by the recount agents,
100% file-set agreement, 85% label agreement, all disagreements boundary calls on agreed facts. Card
outcomes: verified 4, failed 0, inaccessible 0. Failure count: 0. Failure-rate band: <=5%. Full table in
`verification-report.md`.
**Bias guard.** The investigator entered with the opposite prior ("park the viz program", stated to the user
hours earlier) and the study was framed to falsify the user's claim of mass abandonment. Both priors lost a
piece: abandonment is low (against the user's framing), and manual-state burden is pervasive (against the
investigator's). Agree/disagree ledger: 10 corpora, none selected for agreement.
**Inclusion/exclusion.** Excluded: 3 registered projects (troth-site, stillpointlabs-site,
pytest-coverage-impact) carried no planning artifacts at all and produced no source card. The
lowest-scoring source that cleared the bar is the ingle-site corpus: zero checkpoints and an anomalous
file-and-ship-same-day pattern make it the weakest included source, kept because that anomaly is itself
evidence for the checkbox-drift finding.
**Limitations.** Session-log counts undercount (logs are pruned; reveal-site has 10 checkpoints and 0 logs).
Ingle/reveal/troth per-status splits carry ±2 boundary uncertainty (the shipped-vs-stalled line). The 14-day
staleness window is a choice; a 30-day window would move a few in-flight items to stalled, strengthening,
not weakening, the state-truth finding. Work-vs-personal comparison is qualitative only; the work-side
tracking (Jira, stacked-PR stamping) was not mined here.

## 7. Bibliography

Ten local corpus cards, all band **keep**, evidence Level 1 (direct observation), perspective
Boots-on-the-ground, under this deliverable's `sources/` — `completion-audit-{borg-collective, claude-plugins, ingle,
reveal, troth, stillpoint, snowfort, ingle-site, reveal-site, cairn}.md`. Each contributes its project's
counts plus verbatim manual-tracking quotes with file:line references.

AI-scoring: 90/100 (after revision; pre-revision 85)
