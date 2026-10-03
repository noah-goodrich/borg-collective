# What "project management" is made of, and how well borg-collective does each part

*Filed: 2026-10-03 . Research phase 1 of a re-runnable evaluation . Sources in `sources/`*

**tl;dr** — Eight pillars cover what PMBOK, Scrum, Kanban, Shape Up, Lean/WSJF and DORA/SPACE jointly say a project
needs. borg is strong where it *gates* (planning with verifiable criteria, assimilate's shipping gates, the link
document) and weak in four places the literature treats as central: it ranks work by **session status, not value or
cost of delay**; it sets **no appetite and no circuit breaker**; it **computes no flow metric** (lead time, age,
throughput) even though the raw data exists; and it **has no retrospective loop**. Axis-A design score: 14 of 24.
The effectiveness half is mostly unmeasured, and the one instrument that would price it (token spend) has a capture
hole. First action: compute the six cheap metrics in section 4 on a schedule.

## 1. Method and evidence rules

- External claims cite a URL with access date in `sources/01-external-sources.md` and carry an evidence grade:
  S1 primary text fetched, S2 secondary summary of a primary I could not fetch, S3 practitioner or vendor opinion.
- PMI's own pages and the SPACE paper returned 403 and PMBOK is paywalled: **the PMI pillar basis is S2/S3.**
- "Documented best practice" = stated in an S1 source. "Opinion" = anything else, labelled as such.
- Local numbers are from commands recorded in `sources/02-local-measurements.md`. borg's own docs were treated as
  claims to test, not evidence. One example of why: CLAUDE.md lists ~16 skills as delivering behavior, while
  `docs/plans/directives/2026-10-03-evals-for-everything.md` records that only three have any eval.
- Scoring scale for axis A: **0** absent; **1** prose or advisory only (model-discretionary, ~70-90% compliance band
  by borg's own account); **2** implemented as code or a gate with a known gap; **3** mechanised, tested, and
  closing its own loop. Anchors are names, never line numbers.

## 2. The pillars

Convergence logic: PMBOK 7 gives eight non-sequential domains, PMBOK 8 restores five lifecycle areas, Scrum gives
three artifacts-with-commitments, Kanban gives flow, Shape Up gives time-boxed bets, DORA/SPACE give outcome
measurement. Where all of them overlap I kept a pillar; where only one source speaks (PMI "Team", "Stakeholders") I
dropped it as out of scope for a solo operator whose "team" is agents. Eight pillars:

- **P1** — Pillar: Value framing and prioritization; Converging sources: PMBOK "Value" principle (S2); Scrum Product
  Goal (S1); Shape Up betting (S1); WSJF (S1)
- **P2** — Pillar: Planning and scoping; Converging sources: PMBOK "Planning" (S2); Scrum Sprint Goal + DoD (S1);
  Shape Up appetite (S1)
- **P3** — Pillar: Execution; Converging sources: PMBOK "Project Work" (S2); Kanban manage-flow and WIP limits (S1)
- **P4** — Pillar: Delivery; Converging sources: PMBOK "Delivery" (S2); Scrum Increment + DoD (S1); DORA throughput
  (S1)
- **P5** — Pillar: Monitoring and feedback; Converging sources: PMBOK "Measurement" (S2); Scrum
  Transparency/Inspection (S1); Kanban flow measures (S1)
- **P6** — Pillar: Risk and quality; Converging sources: PMBOK "Uncertainty", "Quality", "Risk" (S2); Shape Up circuit
  breaker (S1); DORA instability (S1)
- **P7** — Pillar: Sustainability and capacity; Converging sources: Agile "constant pace" (S1); Kanban
  WIP/context-switch (S1); SPACE well-being (S2); ADHD scaffolding (S3, thin)
- **P8** — Pillar: Learning and adaptation; Converging sources: Scrum Retrospective + Adaptation (S1); Agile
  reflection (S1); PMBOK "Adaptability" (S2)

Noah's two named pillars map to P3 (execution) and P4 (delivery). Delivery is kept separate because Scrum, DORA and
borg's own `borg-assimilate` all separate "work is being done" from "work is done, verified and released".

### Checkable best-practice statements per pillar

Each is something a script or a reviewer can answer yes/no about a project. IDs are stable so later runs can diff.

**P1 Value framing and prioritization**
- P1.1 Every unit of work states an outcome or goal, not only a task list (Scrum Product/Sprint Goal, S1).
- P1.2 Work is ordered by an economic or value rationale, not by arrival or status; cost of delay or equivalent is
  at least named (WSJF/Reinertsen, S1 for the method; its payoff is opinion).
- P1.3 The set of committed bets is small and explicit; unchosen ideas are not carried as an ever-growing backlog
  (Shape Up, S1; "no backlog" is one company's practice, opinion on efficacy).
- P1.4 Ranking is revisited on a cadence (SAFe caveat, S1).

**P2 Planning and scoping**
- P2.1 Work has an acceptance criterion that is objectively verifiable, with the check written down (Scrum DoD, S1).
- P2.2 A time or effort budget (appetite) is set **before** design, and scope flexes to it (Shape Up, S1).
- P2.3 Explicit non-goals and scope boundaries exist (PMBOK Planning, S2).
- P2.4 Changes to agreed scope are visible and deliberate (Scrum: Product Owner owns scope change, S1).

**P3 Execution**
- P3.1 Work in progress is limited and the limit is enforced, not merely displayed (Kanban Guide, S1).
- P3.2 Items are actively managed; aged items are surfaced (Kanban "Work Item Age", S1).
- P3.3 Quality is built in during work, not inspected at the end (PMBOK Quality, S2).
- P3.4 Units of work are small enough to finish in one flow (Kanban/Agile "maximize work not done", S1).

**P4 Delivery**
- P4.1 "Done" is a written Definition of Done, applied before work is declared shipped (Scrum, S1).
- P4.2 Working, verified output is the measure of progress (Agile principle, S1).
- P4.3 Delivery frequency and lead time are known, per unit (DORA throughput, S1).
- P4.4 Shipped state is recorded where it is read from (opinion; borg's own "state truth" finding).

**P5 Monitoring and feedback**
- P5.1 Work state is visible to everyone who needs it, without manual reconstruction (Scrum Transparency, S1).
- P5.2 Cycle time, WIP, throughput and work-item age are computed from the work system (Kanban, S1).
- P5.3 Progress is inspected against the goal at a regular cadence (Scrum Sprint Review, S1).
- P5.4 Multiple dimensions are tracked; activity counts alone are not read as productivity (SPACE, S2; METR, S1).

**P6 Risk and quality**
- P6.1 Known risks are written next to the plan (PMBOK Uncertainty, S2).
- P6.2 Work that overruns its budget stops by default rather than extending (Shape Up circuit breaker, S1).
- P6.3 An independent check gates release; the check can actually fail (DoD + DORA instability, S1).
- P6.4 Speed and stability are tracked together: throughput up with fail-rate up is not a win (DORA 2025, S1).

**P7 Sustainability and capacity**
- P7.1 Pace is sustainable "indefinitely" (Agile principle, S1).
- P7.2 Intake is capacity-gated: new work is pulled only when capacity exists (Kanban, S1).
- P7.3 Rest and boundaries are protected by mechanism rather than willpower (ADHD external-scaffolding, S3 thin).
- P7.4 Well-being is itself measured (SPACE Satisfaction, S2).

**P8 Learning and adaptation**
- P8.1 A retrospective happens at a cadence and yields a concrete change (Scrum Retrospective, S1).
- P8.2 Lessons persist where the next unit of work will read them (opinion; borg's cairn evidence supports it).
- P8.3 Estimates are compared with actuals (Reinertsen, S2; opinion for efficacy).
- P8.4 Whether a practice is read or used is measured, not assumed (borg's `memory-hits` instrument; opinion).

## 3. Two-axis rubric with first-pass scoring (this machine, 2026-10-03)

Axis A reads the code. Axis B lists the evidence that would show enforcement and value, which of it is measurable
today, and what the first reading is.

### P1 Value framing and prioritization — A = 1 / 3

- A, what exists: `borg-plan` proposes an objective and criteria; `borg next` (skill `borg-next`, borg.zsh sort) ranks
  projects by **pinned, then session status (waiting > active > idle > archived), then last activity**. That is an
  attention heuristic. Nothing in `skills/`, `borg_core/` or `lib/` mentions cost of delay, WSJF, value or appetite
  (a repo-wide grep for `appetite|circuit.breaker|cost.of.delay|WSJF|lead.time|cycle.time` over skills, hooks, agents,
  borg_core, lib and borg.zsh found none). 28 open directives are an unranked, ever-growing list (median age 41 d).
- B, evidence of effect: share of shipped directives that were the highest-ranked at the time (needs a recorded
  ranking: **new capture**); open-backlog growth rate (measurable); age of oldest open items (measurable, table).
- First reading: 28 open, 23 older than 30 days, which is the backlog shape Shape Up warns against.

### P2 Planning and scoping — A = 2 / 3

- A: `borg-plan` (objective, criteria each with a `Verify:` line, scope boundaries, ship definition, timeline in
  "sessions", risks) with a Lock Rule; `borg-plan-promote.sh` persists an approved plan; `adhd-guardrails` Plan
  Cross-Reference flags requests that map to no criterion; `borg-collective-review` challenges the plan. Gaps: the
  timeline is an *estimate* ("N sessions of ~N hours"), the exact thing Shape Up's appetite inverts; the lock rule
  and scope flagging are prose.
- B: criteria with a Verify line (crude 0.61 ratio, measurable); scope-change rate (1 of 60 plans admit growth; the
  true rate is **unmeasured** because capture is volunteered, and one shipped plan itself says "scope expanded
  mid-flight"); estimate-vs-actual (needs estimate captured as a number: new capture).

### P3 Execution — A = 2 / 3

- A: nanoprobes (`agents/borg-nanoprobe.md`) with a scope gate and self-managed worktrees; `agents/ROUTING.md`;
  `bash-guard.sh` and `borg-supabase-guard.sh` hard-block destructive actions; `borg-dispatch-guard.sh` vetoes new
  dispatch above 92% usage (default OFF); capacity warning at `BORG_MAX_ACTIVE` (default 3) is **a printed warning,
  not a gate**; `tool-count-nudge.sh`. Gap: WIP limit is advisory; nothing surfaces work-item age.
- B: WIP over time against the limit (needs the status history; today only the latest status is stored in
  `.borg/state.json`, so **new capture**); open-directive age (measurable); nanoprobe commit yield (`agents.jsonl`
  has `zero_commit` and `evidence_found`; 17 of 19 rows are `zero_commit`, but those are this session's helpers).

### P4 Delivery — A = 2 / 3

- A: `borg-assimilate` is the strongest mechanism in the repo: Step 0 `/simplify`, Step 0.5 tests and lint, Step
  0.75 blocks on unresolved child directives (bats-pinned), Step 4 collective review and verdict, shipping actions,
  closing the manifest row, archive, chained auto-promotion. `borg-verify` is an independent PASS/FAIL gate.
  `pre-commit-remind.sh` nudges. Gap: assimilate is invoked by the human, so shipped-but-unarchived drift is
  possible, and the audit measured it (47% of the open board). No delivery-frequency or lead-time number is produced.
- B: ship rate (60 assimilated; Sep 7, Aug 12 by `Shipped:` date), merged PRs/month (4 to 67, measurable), PR median
  0.74 h / p90 74 h (measurable), `fix`-titled share 28% (proxy), shipped-unarchived backlog (planstate deriver can
  compute; it exists but is not scheduled), lead time (half-captured, see above).

### P5 Monitoring and feedback — A = 2 / 3

- A: `borg link` is one seven-section document (single renderer, pinned by goldens); `borg-recon` and the recon
  engine reconcile checkpoints against live sources; `borg_core/planstate` derives criteria status from evidence;
  `bin/borg-pr-watch`, `bin/borg-notifyd`. This is the most engineered pillar. Gap: it shows **state**, not
  **flow**. No lead time, cycle time, throughput or age is computed; the only history is in git and checkpoints.
- B: derived-vs-declared agreement (planstate vs checkboxes: measurable, the audit did it by hand once); checkpoints
  that restate plan position by hand (97% in the audit; re-computable with a grep for state phrases).

### P6 Risk and quality — A = 2 / 3

- A: plans carry Risks; the Collective review; `borg-verify`; test pyramid with bats and pytest; usage guardian;
  clean-architecture linter in `pyproject.toml`. Gaps: no circuit breaker (nothing cancels an overrunning
  directive; 23 of 28 open directives are older than 30 d); `borg-verify` is frontmatter-only in tests and "does
  it ever return FAIL" is explicitly recorded as unevaluated in the evals directive.
- B: verify FAIL rate (needs the verdict logged: **new capture**); post-merge `fix` share (proxy, measurable);
  defects found after assimilate (needs linking a fix PR to a plan: new capture).

### P7 Sustainability and capacity — A = 2 / 3 (one point of that is a judgment call)

- A: `adhd-guardrails` (always-on prose: scope naming, 2-hour break suggestion, no-shame language, capacity
  language); `_borg_boundary_check` in borg.zsh is real code (a one-keystroke work/life confirmation on switch);
  `BORG_MAX_ACTIVE` warning; reaper corrects stale statuses. The guardrail skill is model-discretionary and, per
  the evals directive, has **no observable eval**: it is "observable only as absence of behavior". Scored 2 because
  one mechanism is code; the rest would score 1.
- B: sessions longer than 2 h and late-hour sessions (derivable from `token-spend.jsonl` ts + checkpoints; partly
  measurable); parallel-session count over time (usage-samples); boundary overrides (is the confirmation logged?
  unknown). SPACE Satisfaction needs a self-report prompt: new capture, and METR's result says to treat it as a
  perception signal, not a productivity fact.

### P8 Learning and adaptation — A = 1 / 3

- A: checkpoints (`borg-link-up`) carry a "Next Session" section; CLAUDE.md "Learned" is hand-curated and unusually
  honest; the cairn decommission is a model of evidence-driven retirement; `borg-memory-read-log.sh` plus
  `bin/memory-hits-report` instrument read use. Gaps: **0 of 60 assimilated plans have a retro or lessons
  section**; no cadence; the memory-hit gate currently reads FAIL (0.05 reads/session against < 0.2).
- B: reads of learned material per session (measurable now: `memory-hits.log`); repeat-defect rate (needs a defect
  taxonomy: new capture); plans citing a prior lesson (grep, partly measurable).

### Scorecard

- **P1 Value and prioritization** — A: 1; Strongest mechanism: `borg next` attention ordering; Biggest gap: no value /
  cost-of-delay ranking
- **P2 Planning and scoping** — A: 2; Strongest mechanism: `borg-plan` criteria with Verify; Biggest gap: no appetite;
  estimate not captured
- **P3 Execution** — A: 2; Strongest mechanism: nanoprobe scope gate, guards; Biggest gap: WIP is a warning; no age
  surfaced
- **P4 Delivery** — A: 2; Strongest mechanism: `borg-assimilate` gate sequence; Biggest gap: human-invoked; no
  lead-time/frequency
- **P5 Monitoring** — A: 2; Strongest mechanism: `borg link` + planstate; Biggest gap: shows state, computes no flow
- **P6 Risk and quality** — A: 2; Strongest mechanism: `borg-verify`, guards; Biggest gap: no circuit breaker; verify
  unevaluated
- **P7 Sustainability** — A: 2; Strongest mechanism: boundary check code; Biggest gap: guardrails unevaluated prose
- **P8 Learning** — A: 1; Strongest mechanism: checkpoints, cairn-style evidence; Biggest gap: no retrospective loop
- ****Total**** — A: **14 / 24**; Strongest mechanism: |

## 4. Axis B: what is measurable today vs needs capture

**Measurable today** (every item has a command in `sources/02-local-measurements.md`):

1. Open-directive count, age distribution, share older than 30 d (P1, P3, P6).
2. Ship : sever ratio and shipped-per-month from `docs/plans/{assimilated,severed}` (P4).
3. Directive lead time, Established to Shipped, **where recorded** (P4, P5). Half-captured today; report coverage
   (32 of 60) beside every value or the median lies.
4. Merged PRs per month, merge latency median and p90, closed-unmerged share, `fix`-titled share, via `gh` (P4, P6).
5. Criteria checkbox rate and Verify-line coverage in open vs assimilated plans; shipped-plan unchecked boxes (P2, P5).
6. Retro presence in assimilated plans, memory-hit ratio and gate verdict (P8).
7. Checkpoint cadence and "restates plan position" share (P5, P8).
8. Spend by project, with the caveat that **capture is currently unreliable** (September 10 records vs 56 PRs):
   fix before any cost-per-shipped-unit claim (P3, "least effort").

**Needs new capture** (each is a small, derived-from-an-artifact addition, per the cairn lesson; do not ask the
agent to volunteer it):
- Status history (append an event on each `borg-link-down/up` flip) to get WIP-over-capacity and time-in-state.
- A numeric appetite and estimate on each plan, so scope-creep and estimate-vs-actual exist.
- A recorded ranking snapshot at each `borg next`, to test P1.2.
- `borg-verify` verdict log, to get a FAIL rate and know the gate can fail.
- Fix-PR to plan linkage (a `Fixes-plan:` trailer) for post-ship defects.
- Boundary-override log; optional 1-question end-of-day well-being tick (labelled perception).

"Cost per shipped criterion" = spend attributable to a plan's window / criteria verified in that window. It needs
the spend fix plus plan windows from status history. It is the closest thing to "value for least effort" the
data can support, and it is **not computable today**.

### What the first reading says about effectiveness (adversarial)

- Throughput is high and rising (4 to 67 merged PRs/month) and PRs are small and fast. That is the Activity
  dimension of SPACE, the weakest one, and METR shows self-perception of AI speedup can be wrong in sign. It does
  not show value delivered.
- DORA 2025: faster delivery with an unchanged foundation raises instability. borg has no instability metric
  beyond a title proxy (28% `fix`), so it cannot say which side of that trade it is on.
- Started work finishes (87% in the prior audit) and stalls are rare (6.7%); the failure is **state truth**, and
  borg has been spending on exactly that (planstate, link). Axis B for P5 is therefore the best-evidenced story.
- The open backlog is the weakest: 23 of 28 older than 30 days with no ranking or kill rule.

## 5. Re-runnable design (sketch for a follow-up directive; not code)

**Goal.** One command per machine produces a pillar scorecard that can be compared across dates and across the two
machines, without any employer-private data entering the public repo.

**Split computation by where the inputs live.**
- *Axis A is repo-wide and machine-independent.* Express each A-check as an executable predicate over the checkout
  (does `skills/borg-plan/SKILL.md` contain a `Verify:` rule; does a hook with a `PreToolUse` registration for the
  dispatch guard exist; does a bats case pin it). Output is a per-check pass/fail plus the 0-3 score. It runs the
  same on both machines and may be fully committed.
- *Axis B is machine-local.* Computed from that machine's registry, checkpoints, plan dirs of every registered
  project, `gh`, `token-spend.jsonl` and the state-root logs.

**Modules (suggested names).** `borg_core/pmeval/core.py` pure: metric definitions and scoring, in/out dicts, no
I/O (same split as `planstate` and `link/picture.py`). `shell.py` owns `gh`, file reads and the clock. A `borg
pulse` verb (or a `borg eval pm` arm) dispatches through `_borg_py`, honoring the existing zsh-to-Python config
rule. Metric definitions carry an id, a pillar, a unit, a `rubric_version` and a coverage field (n of N).

**Where results live.**
- Raw per-machine results: `~/.local/state/borg/pm-eval/<UTC-date>/metrics.json` + `scorecard.md`, using the
  machine-local state root and existing retention (`borg_core/retention.py`). Per-project detail (names, PR titles,
  paths) stays here and only here.
- Public aggregates: `docs/research/pm-eval/aggregates/<label>-<date>.json` where `label` is one of two enum values
  (`personal`, `work`) from config, never a hostname. Contains only metric id, pillar, numeric value, n, coverage,
  `rubric_version`, model id and date.
- **Work-machine rule, hardwired not remembered** (this project's own lesson): a publish step validates the
  aggregate against an allowlist schema (numbers, enums, ISO dates only; no free strings), refuses cells with n < 5,
  and fails closed. A bats case feeds it a fixture containing a repo name and a PR title and requires rejection,
  and also requires it to fire in the real direction. The work machine runs the same code; its file is committed
  from that machine only after the validator passes, or kept state-root-only if Noah prefers.

**Comparing over time.** Metrics are time series keyed by `metric_id@rubric_version`; a rubric change bumps the
version and old values are not rewritten (expand, migrate, contract). The scorecard prints delta vs the prior run
and vs the other label, and flags any metric whose coverage dropped. Pre-register the null per metric, as
`memory-hits-report` does ("lead time median over 30 d"; "shipped-unarchived = 0"), and report FAIL/PASS against it.
Cadence: monthly by launchd (the same installer pattern as `borg.memory-gate`), plus on demand.

**Guards against self-deception** (from the evidence): report coverage next to every value; prefer derived over
volunteered capture; never present Activity counts as value; label perception data as perception; Goodhart
warning: a metric the agents can see becomes a target, so keep outcome metrics out of agent prompts.

**Decisions this needs from Noah before building.** (1) Do aggregates from the work machine enter the public repo at
all, or only the schema and the personal label? (2) Which of the new-capture items are worth the instrumentation
(recommendation: status history and a numeric appetite first; they unblock four metrics). (3) Fix the spend capture
gap first, or accept cost-per-unit as out of scope for v1. (4) Whether appetite and a circuit breaker are wanted at
all: the findings argue yes for P1/P2/P6, but that is a design stance, not a finding.

## 6. Decision-relevant findings (ranked)

1. **Prioritization is the weakest pillar and the only one with no mechanism at all.** `borg next` orders by
   session status; no value, cost-of-delay or kill rule exists, and 23 of 28 open directives are over 30 days old.
2. **borg's best machinery is state truth; its missing machinery is flow.** The data to compute lead time, age and
   throughput exists in git, plan files and checkpoints. Nothing computes it, and 45% of shipped plans lack a ship
   date, so even lead time is only half-captured.
3. **Effectiveness is not currently measurable at the "least effort" end**: token spend has a capture hole
   (September 10 records vs 56 PRs) and a subagent-share discrepancy (20.7% vs the skill's cited 4%).
4. **No loop closes learning**: 0 of 60 shipped plans carry a retrospective; the memory-hit gate reads FAIL.
5. **Throughput is real** (4 to 67 PRs/month, median merge 0.74 h) but is the weakest SPACE dimension; borg cannot
   yet say whether speed bought stability or cost it.

## 7. Evidence gaps and uncertainties

- PMI pillar justification is S2/S3 only; PMBOK 8's list is from two exam-prep vendors.
- ADHD-specific evidence supports external scaffolding generally; it does **not** show any PM method or WIP limit
  improves ADHD developers' delivery. That is borg's premise, not a finding.
- All local numbers are one machine, one repo for plan data (other projects unexamined here); lead-time median is
  survivor-biased by the 32-of-60 coverage; `fix` share is a title proxy; ages use filing date not last activity.
- The work machine has not been examined at all.
- Scores are one rater (an agent). A second blind rater on the A-checks would measure agreement; the 2026-08-20
  audit's 85% blind-recount label agreement is the precedent for how much to expect.

## 8. Paywalled / unreachable must-reads

- PMI, *PMBOK Guide* 7th and 8th editions and *The Standard for Project Management*: members/purchase
  (`https://www.pmi.org/standards/pmbok`); I could not read them.
- Forsgren et al., "The SPACE of Developer Productivity", ACM Queue 2021:
  `https://queue.acm.org/detail.cfm?id=3454124` (open access, but fetch returned 403 here; read it directly).
- Reinertsen, *The Principles of Product Development Flow* (2009): book, not read.
