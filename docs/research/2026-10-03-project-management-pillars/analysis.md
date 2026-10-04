Generated: 2026-10-03

# Project Management Pillars and borg-collective: what the evidence says, and how borg scores

*Conducted: 2026-10-03 | Methodology: deep-research (full tier, independently verified) | AI-scoring: 80/100*

---

## Glossary: read this first

Every term is also defined inline where it first appears. This block is for skimmers.

- **Pillar**: one of eight load-bearing parts of managing a project: value, planning, execution, delivery,
  monitoring, risk and quality, sustainability, learning. The list is my synthesis (section 4.1), not a standard.
- **Axis A (design score)**: does borg's design contain this pillar, scored 0 to 3. Steel means code that runs;
  plaster means a prose instruction a model may or may not follow.
- **Axis B (measured effect)**: what borg's own files show about whether the pillar works. Every Axis B number in
  this document is labelled LOCAL MEASUREMENT, which means borg's own data, not literature.
- **Evidence level (L1 to L9)**: how strong a source's design is. L1 is a meta-analysis, L2 a randomized trial, L3
  large observational data, L4 a professional standard, L5 a case study with data, L6 qualitative work, L7 expert
  opinion, L8 personal experience, L9 marketing.
- **Meta-analysis**: a study that pools many earlier studies into one estimate.
- **WIP (work in progress)**: items started and not finished. A WIP limit caps that number.
- **Lead time**: days from starting (here: filing) a piece of work to shipping it.
- **Cost of delay**: what one more week of waiting costs, in money or value. It is the basis of ordering work by
  economics.
- **Appetite and circuit breaker**: two ideas from Shape Up (Basecamp's six-week-cycle method). Appetite is a time
  budget set before design. A circuit breaker means an unfinished project stops by default instead of getting an
  extension.
- **Goodhart's law**: when a measure becomes a target, it stops measuring what you cared about, because people (and
  agents) start serving the number.
- **DORA** (DevOps Research and Assessment, a Google research group): publisher of the yearly delivery-performance
  reports and the "four keys" delivery metrics.

---

## 1. Recommendations

Ordered by effort, cheapest first (the 80/20 cut). Each names the section that backs it.

1. **Compute six derived numbers on a schedule, with coverage printed beside each**: open-directive age (a directive is
   a work item filed as a markdown plan), lead time, ship-to-sever ratio, pull-request (PR) merge latency, share of
   merged PRs titled `fix`, and plans shipped but not recorded. All six come from files borg already has, so none needs
   the agent to volunteer anything (sections 3.2 to 3.9, 3.12 and 4.3).
2. **Put an appetite number and a review date on every directive when it is filed, and stop at that date by default.**
   23 of 28 open directives are older than 30 days and nothing in borg can end one. The strongest evidence in the run
   says people keep funding failing work even when they know the theory (sections 3.2, 3.3, 3.7 and 4.2).
3. **Record a ranking snapshot at each `borg next` and write the ranking rule down in terms of value and urgency.**
   Today the order is session status, which is attention, not value. A snapshot is what lets a later run test whether
   the top item shipped first (sections 3.2 and 4.2).
4. **Do not adopt a scoring formula such as WSJF (weighted shortest job first, from the Scaled Agile Framework), ICE
   (impact, confidence, ease) or RICE (reach, impact, confidence, effort) on faith.** The only outcome base rate in the
   corpus says well-designed ideas improve their key metric about one time in three, and no source shows a scored order
   beats a plain one (sections 4.2 and 5.2).
5. **Add a debrief to `borg-assimilate` (the shipping-checklist skill), fed by repository facts** (estimate against
   actual, fix PRs after ship), and track each resulting action until it closes. 0 of 60 shipped plans carry any
   retrospective, and the best outcome evidence in the run is for facilitated debriefs (sections 3.9 and 4.2).
6. **Append a status-history event whenever a session flips between active, idle and waiting.** Without it, WIP
   against capacity and time in state cannot be computed after the fact (sections 3.4 and 3.8).
7. **Log every `borg-verify` (the independent-reviewer skill) verdict.** Nobody can say whether the gate ever returns
   FAIL, and a gate never seen to fail is unproven (sections 3.7 and 4.3).
8. **Repair token-spend capture before quoting any cost-per-shipped-unit number.** September has 10 records against 56
   merged PRs, and one day in July holds 316 records (sections 3.4 and 6.9).
9. **Show speed next to stability and next to a perception reading, never alone.** PR counts rose from 4 to 67 a month,
   which is the Activity dimension that the SPACE framework (a five-dimension scheme for measuring developer
   productivity) says never to use alone; the AI randomized trial shows self-perceived speed can be wrong in sign
   (sections 4.3 and 5.6).
10. **Keep the scorecard outside the agents' reach**: not in prompts, not in agent-writable files. A scorer that is also
    rewarded by the score is the adversarial case of Goodhart's law (sections 4.3 and 5.6).
11. **Test the ADHD (attention-deficit/hyperactivity disorder) guardrails by alternating, not by how they feel.** Run
    two weeks with the break prompt and two without, and compare an objective signal. No source shows any
    project-management (PM) method improves delivery for developers with ADHD (sections 3.8 and 4.2).
12. **Build the scorecard as a pure core plus a fail-closed publish validator, personal machine first.** Work-machine
    data never enters the public repo; only allow-listed numeric aggregates do (section 3.11).
13. **Re-run in 90 days, with the pass and fail thresholds written down first**, the way the memory gate pre-registers
    its null (sections 3.11 and 3.12).

---

## 2. Summary

I was asked two questions at once. What do the major project-management frameworks say a project is made of, and how
well does borg-collective, a solo developer's tool for coordinating parallel Claude Code sessions, measure up? The
picture I kept in mind is a building inspector with two tests: the blueprint check (Axis A) asks whether each pillar is
in borg's design, and whether it is steel or plaster, while the load test (Axis B) asks what the building has actually
carried, using only borg's own files.

The frameworks agree on the rooms but not on how many pillars hold the roof up. PMBOK (the Project Management Body of
Knowledge, the Project Management Institute's guide) listed 12 principles and 8 domains in its 7th edition in 2021, then
cut to 6 principles and 7 domains in November 2025 and brought back about 40 processes. PRINCE2 (a UK project method)
kept 7 principles, Scrum (a team method built on short fixed-length sprints) names 3 pillars, and the list for Lean (a
value-flow philosophy that came out of manufacturing) grew from 4 principles to 7 in four years. The concepts overlap
heavily and the counts do not, so the eight pillars used here are a synthesis I built from them, and no standard names
exactly these eight.

The evidence is lopsided in an interesting way. The practices with the strongest support are about how people fail, not
about project artifacts. People escalate commitment to failing work (a meta-analysis of 166 samples), a sunk-cost effect
of about half a standard deviation survives knowing the theory, switching tasks and being interrupted cost measurable
speed or stress, output per hour falls at long hours, and structured debriefs lift performance by about d = 0.67 across
46 samples (d is an effect-size score where 0.2 is small, 0.5 medium and 0.8 large). The artifacts frameworks are built
around fare worse. The one real-case study of WIP limits, 8,505 work items across five teams, found no support for a
productivity benefit, and its lead-time link disappeared at the quarterly level. Nothing in the 62 included sources
shows a scoring model beats ordering work by hand. Ten of the 62 sources sit at evidence level 1 or 2, but each tests
something adjacent (sunk cost, debriefs, task switching, AI-assisted open-source work, children with ADHD), not project
management for a solo developer.

Measurement is the trap. Goodhart's law is documented in public health targets, and DORA, the metric owner, lists
"setting metrics as a goal" as a pitfall. The randomized controlled trial (RCT, where people are assigned to conditions
by chance) of AI assistance is the sharpest warning for a tool like borg: 16 experienced developers expected to be 24%
faster, were 19% slower, and still believed they were 20% faster. Anything borg reports from self-perception needs that
discount, and anything the agents can see may become their target.

On the blueprint check borg scores 14 of 24. It is steel where it gates: the `borg-assimilate` shipping sequence, the
single `borg link` document, the destructive-command guards. It is plaster, or absent, in the places the evidence
cares about most. Value ordering scores 1 because `borg next` ranks by session status, which is attention and not
worth. Learning scores 1 because no step debriefs a finished plan. Nothing in borg's code mentions appetite, a circuit
breaker, cost of delay, lead time or cycle time.

On the load test the picture is mixed and I will not dress it up. Merged PRs rose from 4 a month in March to 67 in
August, with a median merge time of 0.77 hours. That is a lot of Activity and no evidence of value. Lead time for
shipped directives is a median of 2 days, but only 39 of 60 shipped plans record both dates. Of 28 open directives, 23
are older than 30 days, none has a stop date, and 0 of 60 shipped plans carry a retrospective. The memory gate (borg's
check on whether Claude Code's project memory is ever read) reads FAIL (0.050 reads per session against a threshold of
0.2 written down in advance). Token spend cannot price any of this yet.

One surprise came from my own re-check. Re-running the earlier draft's measurements moved a long list of numbers, and
the biggest correction was the agent-completion log, which looked like 19 rows until I found a rotated file holding
16,907 more. A figure from a single file is a claim about that file.

**Testability.** The Axis B numbers are cheaply testable on this machine and were re-run for this document. Whether any
PM practice improves a solo ADHD developer's long-run outcomes is declared untestable in this session: it needs weeks
of alternating-condition observation, and no source in the corpus has done it.

**The one thing to remember:** borg is good at saying where work stands and has almost nothing that says whether to
start it, stop it, or learn from it; the cheapest repair is derived numbers plus a stop date on every directive.

---

## 3. The pillar rubric and borg's score

### 3.1 How to read this section

Each pillar below gets three things: the practices the literature documents, written as statements a script or a
reviewer can answer yes or no about; borg's Axis A design score with the files where the pillar lives; and Axis B, split
into what is measured today and what needs new capture. Source IDs (S01 to S62) point to section 7.

**Strength labels** say how well a practice is backed, not how popular it is. *Strong* means level 1 or 2 evidence for
the practice or its mechanism, though often in an adjacent population, which I mark "adjacent". *Moderate* means level 3
to 5 outcome data, or level 1 to 2 evidence one step removed. *Weak* means levels 6 to 8 only. *Defined only* means a
standard or guide states it and nobody has tested whether it works.

**Axis A scoring rule** (applied the same way to every pillar). 0: none of the pillar's statements is present. 1: at
least one is met, by prose or advice only. 2: a core statement is met by code or a gate, and at least half of the
statements are at least partly present, with a known gap. 3: every statement is met by tested code that closes its own
loop. Anchors are file, skill and hook names (a hook is a script Claude Code runs on an event), never line numbers.
Borg's own docs were treated as claims to test: the project instructions list 16 skills as delivering behaviour, while
the evals directive records that only three skills have any eval at all.

**Adversarial stance.** Self-reports are unreliable (S33: the trial's developers believed the opposite of what the
stopwatch showed), reported status drifts from reality (S48), and targets get gamed (S39). So Axis A is scored from
what the repository contains, and Axis B from what its files record, never from what borg's documents say it does.
The scorer is a single agent, so no inter-rater agreement exists; a second blind rater on the Axis A checks is the
obvious next control.

### 3.2 P1: Value and prioritization (what is worth doing, in what order, and when to stop)

| ID | Checkable statement | Strength | Sources |
|----|---------------------|----------|---------|
| P1.1 | Each unit of work names the outcome it serves | Defined only | S10, S11 |
| P1.2 | Work is ordered by an economic reason, and every score is treated as an estimate that is often wrong | Moderate that estimates are noisy; Weak that a scored order beats an unscored one | S17, S14, S23, S15, S16 |
| P1.3 | The committed set is small and explicit; ideas are not hoarded in an unbounded backlog | Weak | S21, S11, S03 |
| P1.4 | Stop conditions and one decision-owner are fixed before starting | Strong (adjacent) for the hazard; Weak for the practice | S22, S20, S18, S21 |

**Axis A: 1 of 3.** Lives in the `borg-plan` skill (an Objective section: prose), the `borg-next` skill and the sort in
`borg.zsh` behind `borg next` (pinned first, then session status waiting, active, idle, archived, then last activity),
and the QUEUED section of `borg link`. That ordering is an attention heuristic. A search of skills, hooks, agents,
`borg_core`, `lib`, `borg.zsh` and `drone.zsh` for appetite, circuit breaker, cost of delay, WSJF, lead time and cycle
time returns no hits (re-run 2026-10-03). P1.1 is met by prose; P1.2 to P1.4 are absent.

**Axis B, measured today (LOCAL MEASUREMENT).** 28 open directives; 23 older than 30 days; median age 41 days, maximum
87 (age from the filename date, not last activity). Acceptance-criteria boxes checked: 35 of 156 (22%) in open
directives, 266 of 349 (76%) in shipped plans. Closed directives split 60 shipped to 8 severed.
**Needs capture:** a ranking snapshot per `borg next`, and a numeric appetite on each directive.

### 3.3 P2: Planning and scoping

| ID | Checkable statement | Strength | Sources |
|----|---------------------|----------|---------|
| P2.1 | Acceptance criteria are written so a named check can fail | Defined only | S10, S46 |
| P2.2 | A time budget is fixed before design and scope flexes to it | Weak | S21, S11, S03 |
| P2.3 | Scope boundaries and non-goals are written down | Defined only | S06, S10 |
| P2.4 | Estimates are compared with actuals before the next estimate is trusted | Moderate | S43, S17 |
| P2.5 | Plan success is not defined only as on time, on budget and in scope | Moderate | S02, S06, S09 |

**Axis A: 2 of 3.** Lives in the `borg-plan` skill (objective, criteria each with a `Verify:` line, Scope Boundaries,
Risks, a Lock Rule: all prose), the `borg-plan-promote.sh` hook (code: persists an approved plan to
`docs/plans/PROJECT_PLAN.md`), `borg_core/planstate` (code: derives criteria status from evidence) and the Plan
Cross-Reference in `adhd-guardrails` (prose). Known gap: `planstate` reads `Evidence` sub-bullets, not the prose
`Verify:` line, so whether a criterion can fail is enforced only by the skill. The timeline is an estimate in
"sessions", which is exactly what an appetite replaces.

**Axis B, measured today (LOCAL MEASUREMENT).** `Verify:` lines against checkbox criteria: 306 to 505 across open and
shipped plans (ratio 0.61; 335 to 551 when severed plans are included). The count is crude: it counts lines and does not
pair them. Shipped plans that say scope grew: 1 of 60, a single shipped line reading "scope expanded mid-flight". A grep
finds only plans that say so in those words, and volunteered prose is not a rate. **Needs capture:** a numeric appetite
and a numeric estimate on each plan, so scope creep and estimate error exist as numbers.

### 3.4 P3: Execution

| ID | Checkable statement | Strength | Sources |
|----|---------------------|----------|---------|
| P3.1 | WIP is limited and the limit is enforced, not just displayed | Defined only for the practice; the one field study found no productivity benefit | S31, S05, S35, S24 |
| P3.2 | The age of in-flight items is surfaced | Defined only | S05, S31 |
| P3.3 | Work moves in small batches merged at least daily | Moderate | S26, S29, S32 |
| P3.4 | Switches and interruptions are cut, and each switch has a cue | Strong (adjacent, lab) | S57, S55 |
| P3.5 | When agents write the code, verification capacity is treated as the limit | Weak to Moderate | S30, S33, S37 |

**Axis A: 2 of 3.** Lives in `agents/borg-nanoprobe.md` (a nanoprobe is a short-lived subagent given one task: scope
gate, one discrete unit of work, self-managed git worktree, which is a second checkout of the repo: prose),
`agents/ROUTING.md`, `bash-guard.sh` and `borg-supabase-guard.sh` (code: hard-block destructive commands),
`borg-dispatch-guard.sh` (code, default OFF), and the `BORG_MAX_ACTIVE` capacity check in `borg.zsh`. That check is a
printed warning, not a gate, and it counts sessions needing attention, not work items. Gaps: no work-item age is
computed, and the `Ctrl+Space >` hotkey makes switching cheaper, which pulls against P3.4 unless the injected checkpoint
(a saved end-of-session note) works as the cue that S57 says shrinks switch cost. That is a hypothesis, not a finding.

**Axis B, measured today (LOCAL MEASUREMENT).** Merged PRs: 233 of 245 total, 11 closed unmerged, 1 open. Median merge
latency 0.77 hours, 90th percentile 68.7 hours. Merges per month: March 4, April 15, May 17, June 20, July 36, August
67, September 56. Agent-completion log: 9,724 of 17,250 rows carry a `zero_commit` field (56% coverage); 3,560 of those
(37%) are true. Rows typed as nanoprobe: 228 of 968 (24%) are zero-commit. A zero-commit run is not a defect for a
research or review agent, so read this as "about three quarters of nanoprobe runs left a commit", not as a failure rate.
**Needs capture:** status history. The registry holds no status field (status lives in each project's
`.borg/state.json`, latest value only), so WIP over capacity cannot be reconstructed.

### 3.5 P4: Delivery

| ID | Checkable statement | Strength | Sources |
|----|---------------------|----------|---------|
| P4.1 | "Done" is a written, binary gate checked before anything is called shipped | Defined only | S10, S34, S46 |
| P4.2 | Speed and stability are tracked together; faster with less stable is not a win | Moderate (survey, self-reported) | S26, S27, S28, S32 |
| P4.3 | With AI help, tests, small batches and fast feedback come before more agents | Moderate | S27, S37 |
| P4.4 | Delivered value is judged by outcome, not by the on-time triple alone | Moderate | S02, S06, S09 |
| P4.5 | Shipped state is recorded where it is read from | Moderate (status drifts) | S48 |

**Axis A: 2 of 3.** Lives in `borg-assimilate` (Step 0 simplify, 0.5 tests and lint, 0.75 blocks on unresolved child
directives, with its gate sentence pinned by prose-contract tests in bats (a shell-script test framework) that check the
skill text, not the model's behaviour; Step 4 Collective review (an adversarial multi-persona review) and verdict;
archive), `borg-verify` (an independent PASS or FAIL reviewer), `pre-commit-remind.sh` (a nudge), `borg_core/planstate`
(derives shipped state from evidence) and `borg_core/reconcile` (code that reports declared state contradicting resolved
state, and never repairs it). Gap: assimilate is invoked by the human, so shipped-but-unrecorded drift is possible, and
no delivery-frequency or lead-time number is produced anywhere.

**Axis B, measured today (LOCAL MEASUREMENT).** Shipped plans 60, severed 8 (88% to 12%). Lead time, filing to shipping,
for the 39 plans that record both dates: median 2 days, mean 6.7, 90th percentile 17, 10 same-day. 20 of 60 shipped
plans (33%) have no ship date at all, so the median is survivor-biased toward plans that remembered to record it.
Unchecked boxes inside plans filed as shipped: 83. Merged PRs titled `fix`: 65 of 233 (28%), a title proxy for
instability, not DORA's change-fail rate; zero PR titles contain "revert". **Prior internal audit, not re-run now**
(`docs/research/2026-08-20-project-completion-audit`): started work finishes 87% of the time, mid-plan stalls are 6.7%,
and 47% of the non-backlog open board (36 of 76 directives) was already shipped but unrecorded. **Needs capture:** a
`Fixes-plan:` trailer linking fix PRs to plans, and a verdict log from `borg-verify`.

### 3.6 P5: Monitoring and feedback

| ID | Checkable statement | Strength | Sources |
|----|---------------------|----------|---------|
| P5.1 | State is visible without manual reconstruction and inspected against the goal on a cadence | Defined only; Moderate for feedback loops mattering | S10, S12 |
| P5.2 | Flow measures (cycle time, WIP, age, throughput) are computed from the work system | Defined only | S05, S31 |
| P5.3 | Several dimensions are tracked, one of them perceptual, and used as diagnostics, not targets | Weak | S36, S28, S25 |
| P5.4 | Self-reported status and self-perceived speed are distrusted | Strong for speed (n=16); Moderate for status (modelled) | S33, S48 |
| P5.5 | Any single number is expected to be gamed once it is a target | Moderate | S39, S19, S28, S38 |

**Axis A: 2 of 3.** This is the most engineered pillar. Lives in `borg link` (one renderer, `render.document()`, with a
fixed seven-section spine pinned by golden files: code), `borg-recon` and `borg_core/recon` (adapter sweep, plus
detection of a checkpoint that contradicts a live source), `borg_core/planstate`, `bin/borg-pr-watch`,
`bin/borg-notifyd` and the morning briefing from `borg init`. Gap: it shows state, not flow. No lead time, cycle time,
throughput or age is computed; P5.2 and P5.3 are absent.

**Axis B, measured today (LOCAL MEASUREMENT).** 129 checkpoints in this repo (April 24, May 21, June 9, July 14,
August 37, September 22, October 2); the `## Criteria Reconciled` section appears in 5 of them. **Prior internal audit,
not re-run now:** 97% of checkpoints (370 of 381) restate plan position by hand, and 27% of open-directive criteria were
checked against roughly double the real completion. That is status drift in S48's sense, and it is what `planstate` was
built to repair. **Needs capture:** the derived-versus-declared agreement rate as a standing number.

### 3.7 P6: Risk and quality

| ID | Checkable statement | Strength | Sources |
|----|---------------------|----------|---------|
| P6.1 | At planning, failure is imagined and the reasons written down (premortem or risk narrative) | Weak | S42, S47 |
| P6.2 | Risk practice is proportionate; practice associates with success but a heavy register is not shown to be the active ingredient | Moderate to Weak | S45, S47 |
| P6.3 | An independent check gates release, and it can fail | Defined only | S46, S34 |
| P6.4 | An overrunning item stops by default (circuit breaker) | Weak for the practice; Strong (adjacent) for the mechanism | S21, S22, S20 |

**Axis A: 2 of 3.** Lives in the Risks section of `borg-plan` (prose), `borg-collective-review` (adversarial persona
review: a skill), `borg-verify`, the bats and pytest suites with the clean-architecture lint in `pyproject.toml`, and
`bash-guard.sh`. Gaps: no circuit breaker exists; `borg-verify` is advisory when a plan has no criteria and reports
"unverifiable" rather than FAIL when a check is missing, and whether it has ever returned FAIL is not logged, so the
gate is unproven.

**Axis B, measured today (LOCAL MEASUREMENT).** 23 of 28 open directives are older than 30 days with no kill rule.
`fix`-titled PRs 28% (proxy). The evals directive records that only three skills have any behaviour eval.
**Needs capture:** the `borg-verify` verdict log and post-ship defects linked to their plans.

### 3.8 P7: Sustainability and capacity

| ID | Checkable statement | Strength | Sources |
|----|---------------------|----------|---------|
| P7.1 | Sustained hours are capped; output per hour falls at long hours | Moderate (adjacent) | S56, S52 |
| P7.2 | Burnout is tracked as a risk | Weak (abstract read; causes not read) | S61 |
| P7.3 | Task state is externalized, switches get cues, and hard starts get if-then plans | Moderate (adjacent) | S60, S53, S57, S54, S62, S59 |
| P7.4 | Well-being is measured as perception, with the perception caveat attached | Weak | S36, S58, S33, S55 |
| P7.5 | Pace is sustainable indefinitely for everyone involved | Defined only | S51 |

No source shows that a PM method or a WIP limit improves delivery for developers with ADHD. That is borg's premise, not
an evidence finding. The nearest results are an adult-ADHD work trial of 46 people with a clinician-delivered
intervention (S62), a meta-analysis that if-then plans help clinical samples in lab goal tasks (S60), and interviews in
which developers with ADHD describe lists, reminders and pairing as help (S54).

**Axis A: 2 of 3 (one point is a judgment call).** Lives in `adhd-guardrails` (always-on prose: scope naming, a break
suggestion after two hours, capacity language, shame-free wording), `_borg_boundary_check` in `borg.zsh` (code: a
one-keystroke work and life confirmation when switching), the `BORG_MAX_ACTIVE` warning, and the reaper that corrects
stale statuses. Scoring the code alone gives 2; scoring the prose alone gives 1. The guardrail skill has no observable
eval, because per the evals directive it is "observable only as absence of behavior", and boundary overrides are not
logged.

**Axis B, measured today (LOCAL MEASUREMENT).** The only proxy I could build is unusable. Sessions ending between 22:00
and 05:00 local time are 240 of 694 non-backfill spend records (35%), but 22 of 174 (13%) once July is excluded, because
one day, 2026-07-09, holds 316 records. A signal that swings from 13% to 35% on one bulk event measures the logger, not
the person. **Needs capture:** a boundary-override log, status history for parallel-session counts, and an optional
one-question end-of-day well-being tick labelled as perception.

### 3.9 P8: Learning and adaptation

| ID | Checkable statement | Strength | Sources |
|----|---------------------|----------|---------|
| P8.1 | A structured, facilitated debrief follows each unit of work | Strong (adjacent) | S49, S50 |
| P8.2 | The debrief is fed repository facts, such as estimates against actuals and defects | Moderate | S43 |
| P8.3 | Actions are tracked to closure and recurrence is watched | Weak | S50, S44, S38, S40 |
| P8.4 | Lessons persist where the next unit of work will read them | Weak | S41 |

**Axis A: 1 of 3.** Lives in `borg-link-up` (a checkpoint flush with a "Next Session" section: state, not a debrief),
`borg-link-down.sh` (code: injects the latest checkpoint at session start, which is P8.4), the hand-curated "Learned"
section of the project instructions, and the read instrumentation `borg-memory-read-log.sh`, `bin/memory-hits-report`
and `bin/borg-memory-gate`. Only P8.4 is met by code. No step debriefs a finished plan, feeds one with facts, or tracks
an action to closure.

**Axis B, measured today (LOCAL MEASUREMENT).** 0 of 60 shipped plans carry a Retro, Lessons or Learned heading. The
memory gate's last verdict is FAIL: 0.050 reads per session against a pre-registered threshold of under 0.2 (25 lines
in `memory-hits.log`, checked 2026-10-02). The gate is doing its job; what it reports is that Claude Code project
memory is barely read. **Needs capture:** estimate against actual as numbers, and a taxonomy to count repeat defects.

### 3.10 Scorecard

| Pillar | Axis A | Strongest mechanism | Biggest gap | Axis B first reading |
|--------|--------|---------------------|-------------|----------------------|
| P1 Value and prioritization | 1 | `borg next` attention ordering | No value rule, no stop rule | 23 of 28 open directives older than 30 days |
| P2 Planning and scoping | 2 | `borg-plan` criteria with `Verify:` | No appetite; estimate not a number | Verify coverage 0.61 (crude) |
| P3 Execution | 2 | Nanoprobe scope gate, destructive-command guards | WIP is a warning; no item age | Median merge 0.77 h; 24% of nanoprobe runs left no commit |
| P4 Delivery | 2 | `borg-assimilate` gate sequence | Human-invoked; no frequency or lead-time metric | Lead time median 2 d (n=39 of 60) |
| P5 Monitoring and feedback | 2 | `borg link` plus `planstate` | Shows state, computes no flow | Prior audit: 97% of checkpoints restate position by hand |
| P6 Risk and quality | 2 | `borg-verify`, guards, tests | No circuit breaker; verify never seen to fail | `fix` PR share 28% (proxy) |
| P7 Sustainability and capacity | 2 | `_borg_boundary_check` | Guardrails are unobserved prose | Only proxy unusable (13% to 35%) |
| P8 Learning and adaptation | 1 | Checkpoint injection | No debrief, no closure tracking | 0 of 60 plans with a retro; memory gate FAIL |
| **Total** | **14 of 24** | | | |

If P7 is scored on its prose alone the total is 13. A second rater might move a pillar by a point either way, and the
total should be read as 14 plus or minus 2.

**What the first reading says about effectiveness, adversarially.** Throughput is high and rising, and it is the
Activity dimension of SPACE (S36), which that paper says never to use alone. S33 shows self-perception of AI speed can
be wrong in sign, and S26 and S27 show that faster delivery with an unchanged foundation can mean less stability. Borg
has no instability metric beyond a title proxy, so it cannot say which side of that trade it is on. The best-evidenced
story is state truth: started work finishes and stalls are rare, while recording that fact is where drift lives, and
borg has been spending on exactly that repair. The weakest story is the open backlog, with no ranking rule and no kill
rule.

### 3.11 The re-runnable, two-machine design

This is a sketch for a follow-up directive, not code. The goal is one command per machine that produces a pillar
scorecard comparable across dates and across machines, without any employer-private data entering the public repo.

**Split by where the inputs live.** Axis A is repo-wide and machine-independent: each check becomes an executable
predicate over the checkout (does `skills/borg-plan/SKILL.md` carry a `Verify:` rule; does a `PreToolUse` hook (one that
runs before a tool call) for the dispatch guard exist; does a bats case pin it). Its output is a pass or fail per check
plus the 0 to 3 score, and it runs identically on both machines. Axis B is machine-local: it reads that machine's
registry, checkpoints, plan directories for every registered project, `gh`, `token-spend.jsonl` and the state-root logs.

**Modules.** A pure `borg_core/pmeval/core.py` holds metric definitions and scoring with no I/O (the split `planstate`
and `link/picture.py` already use). A `shell.py` owns `gh`, file reads and the clock. A `borg pulse` verb or an
`eval pm` arm dispatches through `_borg_py`, which honours the project's zsh-to-Python config rule. Each metric carries
an id, a pillar, a unit, a `rubric_version` and a coverage field (n of N).

**Where results live.** Raw per-machine results go to `~/.local/state/borg/pm-eval/<UTC-date>/` with the existing
retention policy; project names, PR titles and paths stay there and only there. Public aggregates go to
`docs/research/pm-eval/aggregates/<label>-<date>.json`, where `label` is one of two enum values (`personal`, `work`)
from config, never a hostname. A public file contains only metric id, pillar, a number, n, coverage, `rubric_version`,
model id and an ISO date.

**The work-machine rule is hardwired, not remembered.** A publish step validates every aggregate against an allow-list
schema (numbers, enums and ISO dates only, no free strings), refuses any cell with n under 5, and fails closed. A bats
case feeds it a fixture containing a repo name and a PR title and requires rejection, and a paired case requires the
validator to fire in the real direction (a clean fixture passes, a dirty one fails), so the test cannot pass by
measuring nothing. The work machine runs the same code; its file is committed from that machine only after the
validator passes, or stays in the state root if you prefer.

**Comparing over time.** Metrics are time series keyed by `metric_id@rubric_version`. A rubric change bumps the version
and old values are never rewritten, which is the project's expand, migrate, contract rule. The scorecard prints the
delta against the prior run and against the other label, and flags any metric whose coverage dropped. Each metric gets a
pre-registered null (the result you would see if nothing were working) written before the first reading (for example
"lead time median over 30 days" or "shipped but unrecorded equals zero"). Cadence: monthly by launchd (the macOS
scheduler), using the installer pattern of `borg.memory-gate`, plus on demand.

**Guards against self-deception.** Print coverage beside every value. Prefer derived over volunteered capture. Never
present Activity counts as value. Label perception data as perception. Keep outcome metrics out of agent prompts.

**Decisions needed from you before building.** First, whether aggregates from the work machine enter the public repo at
all, or only the schema and the personal label. Second, which new-capture items earn their instrumentation; I
recommend status history and a numeric appetite first, since together they unblock four metrics. Third, whether to fix
spend capture first or leave cost per unit out of version 1. Fourth, whether appetite and a circuit breaker are wanted
at all: the evidence argues yes for P1, P2 and P6, but that is a design stance, not a finding. The work machine has not
been examined for this document.

### 3.12 Re-measurement and re-run commands

Every local number reused from the earlier draft was re-run on 2026-10-03 on this machine (main checkout at commit
`a4bd1c1`). The table lists what changed. Numbers not listed reproduced exactly.

| Measure (LOCAL MEASUREMENT) | Earlier draft | Re-run | Why it moved |
|-----------------------------|---------------|--------|--------------|
| Shipped plans with both filing and ship dates | 32 | 39 | Draft regex was narrower; two of three regex variants here give 39, a looser one gives 41 |
| Shipped plans with no ship date | 27 (45%) | 20 (33%) | Same |
| Lead time median / mean / same-day | 1.5 d / 5.8 d / 9 | 2 d / 6.7 d / 10 | Same (90th percentile 17 d unchanged) |
| PRs total / merged | 239 / 227 | 245 / 233 | Repo kept moving |
| October merged PRs (partial month) | 12 | 18 | Same |
| Merge latency median / 90th percentile | 0.74 h / 74 h | 0.77 h / 68.7 h | Same |
| `fix`-titled merged PRs | 63 of 227 | 65 of 233 (28% both) | Same |
| Commits | 673 | 688 | Same |
| Checkpoints / with Criteria Reconciled | 128 / 4 | 129 / 5 | Same |
| Agent-completion log rows | 19 (17 zero-commit) | 343 in the live file plus 16,907 in the rotated `agents.jsonl.1` | Draft read only the live file after a rotation |
| `Verify:` to criteria lines | 335 to 551 | 335 to 551 with severed plans; 306 to 505 open and shipped only | Draft's scope was "all plans"; ratio 0.61 either way |

Unchanged on re-run: 28 open directives, 60 shipped, 8 severed, median open age 41 days with 23 older than 30 and a
maximum of 87, criteria boxes 35 of 156 open and 266 of 349 shipped, 0 of 60 retros, 1 of 60 scope-grew, 817 spend
records totalling about $95.3k with $15.6k across 81 borg-collective sessions and a 20.7% subagent share (the token-cost
skill's "about 4%" figure disagrees with this and neither is explained yet), memory gate FAIL at 0.050, 20 registered
projects, and `prefer-tool.jsonl` absent (not instrumented, or no bypass logged).

The commands, chained so one block runs the cheap ones (the longer Python bodies are summarized, not pasted, and the
follow-up directive should turn each into a tested function):

```
cd /Users/noah/dev/borg-collective &&
    ls docs/plans/directives/20*.md | wc -l &&
    ls docs/plans/assimilated | wc -l &&
    ls docs/plans/severed | wc -l &&
    gh pr list --state all --limit 1000 --json number,state,mergedAt,createdAt,title | jq 'length' &&
    jq -s 'length, (map(.est_cost_usd)|add)' ~/.claude/token-spend.jsonl &&
    cat ~/.local/state/borg/agents.jsonl.1 ~/.local/state/borg/agents.jsonl |
    jq -s '[.[]|select(.zero_commit!=null)]|length' &&
    cat ~/.local/state/borg/memory-gate-verdict.json
```

Lead time, open-directive age, checkbox rates and the PR percentiles are short Python reductions over the plan files
and the `gh` JSON. The agent-log reduction must read both the live file and the rotated one, or it undercounts by a
factor of fifty.

---

## 4. Analysis

Three research questions drove the run. RQ1: do the major frameworks agree on what a project is made of? RQ2: which
documented practices have outcome evidence, and how strong is it? RQ3: how should project health be measured, and what
does Goodhart's law do to the measures? Source IDs point to section 7; evidence levels and bands are in section 5.

### 4.1 RQ1: Do the frameworks agree on the pillars?

**What the evidence says.** They agree on the rooms and disagree on the count of pillars. PMBOK 7 (2021) stated 12
principles and 8 performance domains and moved "from processes to principles" (S07). PMBOK 8 (November 2025) cut to 6
principles and 7 domains and revived about 40 processes in five focus areas (S06). PRINCE2 7 (2023) kept 7 principles
and recast its themes as 7 practices (S09). Scrum names three empirical pillars (S10), Kanban (a flow method that limits
work in progress) three practices and four flow measures (S05, S31), Shape Up three phases (S11), and the Lean list grew
from four principles in 2002 to seven in 2006 (S08). When one family of authors changes the number of pillars in four
years, the count is a framing choice and the concepts are the stable part.

The eight pillars in this document are therefore my synthesis, not a standard, and the table shows where each is
named. A blank means the source text I could read is silent, not that the framework forbids it.

| Pillar | Named by | Silent |
|--------|----------|--------|
| P1 Value and prioritization | PMBOK 8 "focus on value" (S06); PRINCE2 "continued business justification" (S09); Scrum Product Goal (S10); Shape Up betting (S11, S21); Lean "eliminate waste" (S08) | Kanban |
| P2 Planning and scoping | PMBOK 8 Scope, Schedule, Finance domains (S06); PRINCE2 plans practice (S09); Scrum sprint planning (S10); Shape Up shaping and appetite (S11) | Kanban |
| P3 Execution | PMBOK 8 Executing area and Resources domain (S06); Scrum Sprint (S10); Kanban "actively manage items" (S05) | |
| P4 Delivery | PMBOK 8 Closing area (S06); Scrum Increment and Definition of Done (the written bar every piece of work must clear) (S10); Lean "deliver fast" (S08) | |
| P5 Monitoring and feedback | PMBOK 8 Monitoring and Controlling (S06); PRINCE2 progress practice (S09); Scrum inspection and adaptation (S10); Kanban flow measures (S05) | |
| P6 Risk and quality | PMBOK 8 Risk domain and "embed quality" (S06); PRINCE2 quality and risk practices (S09); Lean "build quality in" (S08); Shape Up circuit breaker (S11) | |
| P7 Sustainability and capacity | PMBOK 8 "integrate sustainability" (S06); PRINCE2 7 sustainability and people (S09); Agile principle 8 (S51) | Scrum, Kanban |
| P8 Learning and adaptation | PRINCE2 "learn from experience" (S09); Scrum's events (S10); Lean "create knowledge" (S08) | PMBOK 8 as described by S06 |

PMBOK 7's own principle and domain names (Delivery, Measurement, Uncertainty, Adaptability and Resiliency) come from a
trade page that scored reject and was read but not carded, so I left them out of the table. Only PMI's counts (S07) are
carded.

**Where sources agree.** Value, planning, quality, risk, feedback and tailoring appear in every framework that covers
them. The mainstream is also widening "value" past the triple constraint: PMBOK 8 adds quality, stakeholder
satisfaction, benefits and sustainability (S06), PRINCE2 7 adds sustainability as a seventh performance target (S09),
and the data-based test of the on-time, on-budget, in-scope definition of success found the best-known statistics
misleading across 5,457 forecasts of 1,211 projects (S02). Tailoring is a stated principle in PMBOK and PRINCE2 (S06,
S09), and Lean says copying practices without their principles "has a long history of mediocre results" (S08).

**Where sources disagree.** Scrum says it "exists only in its entirety" (S10) while Kanban's 2025 edition deleted its
own immutability claim (S05). PMBOK swung from processes to principles to processes in about four years, and the
trainer account says practitioners found the 7th edition "too conceptual" (S06). An academic network in 2006 already
argued for the directions the mainstream later absorbed (S13), a recent preprint says PMBOK under-serves data-heavy
iterative AI work (S01), and an Agile signatory argues ceremonies survive while the intent, developer autonomy and
learning, is lost (S04).

**What is missing.** No neutral study maps the frameworks against each other (search T1 #13 found only trainer
comparisons). PMI's standard and the PRINCE2 manual are paywalled, so S06 and S09 rest on trainers and S07 on a
pre-release PDF. Nothing decomposes project management for a solo developer, and nothing shows any decomposition
outperforms another.

**Institutional versus ground truth.** The frameworks assume a team, a sponsor and a budget. The one large-sample result
that bears on a one-person setting says the load-bearing parts of Scrum are the feedback loops, responsiveness,
stakeholder concern and continuous improvement, more than roles or ceremonies (S12). A year of Shape Up in a small team
found that appetite does not remove the need to estimate, and that copying a practice because it works for another
team is no guarantee it will work for yours (S03). The Hacker News solo-developer threads, which I excluded as anecdote,
are thin but consistent: one top-level reply in the planning thread named "building the wrong thing" as the solo risk,
and the task-management thread named switching objectives, over-polishing and changing priorities. I treat that only as
a reason to keep P1 on the list, not as evidence.

### 4.2 RQ2: Which practices have outcome evidence?

**What the evidence says.** The strongest support attaches to how people fail, and the weakest to the artifacts that
frameworks are built around. Think of the inspection report as a list of which beams were load-tested and which were
only drawn.

| Practice | Best evidence | Level | Verdict |
|----------|---------------|-------|---------|
| Structured, facilitated debriefs | 46 samples, d = .67; facilitated .75 against unfacilitated .25 (S49) | 1 | Strong, adjacent: mostly non-software, quasi-experimental, few unfacilitated studies |
| Pre-committed stop rules against escalation | 166 samples (S22); sunk-cost d = .50, progress decisions .44, knowing the theory does not help (S20) | 1 | Strong for the hazard; Weak for any particular kill rule (S18, S21) |
| Cutting task switches and interruptions | Switch cost grows with rule complexity, shrinks with a cue (S57); interrupted work is faster and more stressful (S55) | 2 | Strong in the lab; field transfer untested |
| If-then plans | Large effect on goal attainment in clinical samples (S60); ADHD inhibition task (S53) | 1, 2 | Strong, adjacent; lab goals are short, so likely optimistic |
| Capping hours | Output rises at a decreasing rate past a threshold (S56); longer days raise handling time (S52) | 3 | Moderate, adjacent: munitions workers and call-centre staff |
| Small batches, tests, trunk-based work (small changes merged to the main branch at least daily) | DORA 2024 and 2025 surveys (S26, S27); definition (S29) | 3, 4 | Moderate; self-reported cross-sectional data (S32) |
| Feedback loops in Scrum teams | About 2,000 teams, model-fit score CFI 0.959 (1.0 is perfect) (S12) | 3 | Moderate; self-selected survey |
| Risk-management practice | 415 projects, positive association (S45) | 3 | Moderate to Weak; perception-based, not about registers |
| WIP limits | 8,505 items, five teams: no support for a productivity benefit; lead-time link vanished at quarterly level (S35) | 3 | Contested; the practice is defined (S31) but unproven |
| Scoring models (WSJF, ICE, RICE) | None tests a scored order against an unscored one; ideas improve the key metric about one time in three (S17) | 5 | Weak |
| Appetite, betting, no backlog, circuit breaker | Method text and field reports (S21, S11, S03) | 7, 8 | Weak |
| Retrospectives in software | They discuss opinions; estimation accuracy did not improve; data went unused (S43) | 5 | Weak: no outcome test |
| Blameless postmortems, premortems | Practice descriptions; the 30% premortem claim is cited, not verified (S41, S42) | 4, 7 | Weak |
| Definition of Done | Guide text only (S10, S34, S46) | 4 | Defined only |

**Where sources agree.** Nobody disputes that estimates are noisy: one informal exercise got one-month delay costs from
0 to $16 million on the same project (S23), and the large experimentation platform found a third of well-designed ideas
move the key metric (S17). Value is also heavy-tailed in the one case with data: the top quarter of requirements was
worth about three orders of magnitude more than the bottom quarter, though the figures are author-reported from one firm
(S14). Both findings point the same way, toward spending effort on finding the few big items and on stopping the flat
ones, not on polishing a score.

**Where sources disagree.** Five disputes matter. First, WIP limits: the Kanban guides define control of WIP, often with
limits (S31), the one field study found no support for a productivity benefit and cautions that its WIP-productivity
correlation is partly arithmetic through Little's Law (average WIP equals throughput times lead time) (S35), and a
Kanban vendor's explainer says the law holds only when five assumptions hold (S24). Second, scores against experiments:
a product-management author defends ICE as a way to shorten opinion fights while admitting the numbers are estimates
(S16), cost-of-delay practitioners argue relative scoring hides absolute magnitudes (S15), and the experimentation team
says to test cheaply and stop what is flat (S17), with the caveat that a solo developer cannot run web-scale
randomization. Third, retrospectives: the meta-analysis says debriefs work (S49) while two sources describe software
retros that change little (S40, S44) and the one measured case found estimation talk recurring without improvement
(S43). Fourth, AI and productivity: the randomized trial found 19% slower (S33), DORA 2024 found throughput down 1.5%
and stability down 7.2% per 25% more AI adoption (S26), DORA 2025 found throughput up and stability still down (S27), a
vendor found 98% more PRs and 91% longer reviews (S30), and a case study reports half the planned time (S37). The signs
differ, and METR (the nonprofit that ran the trial) itself now marks its result out of date. Fifth, whether DORA's
causal claims hold, given they rest on cross-sectional surveys (S28 against S32).

**What is missing.** No outcome study of backlog age or size; no study of estimate accuracy beyond one organisation's
retros (S43); one solo-plus-agents case with self-reported outcomes (S37); no study of any PM method on developers with
ADHD; and nothing on whether freezing scope before building (planning pillar P2) helps a solo developer.

**Institutional versus ground truth.** Institutions state their practices as norms. Google's SRE (site reliability
engineering) book says postmortems prevent recurrence (S41); a practitioner who surveyed the field concedes there is no
rigorous study of action-item completion (S44), an incident-analysis consultancy's keynote says incident counts say
nothing reliable about learning (S38), and the one measured case found recurring statements kept recurring (S43). The
same gap shows up in Scrum: the Guide specifies the Definition of Done in detail and offers no evidence on how strict it
should be (S46).

### 4.3 RQ3: How should health be measured, and what does Goodhart do to it?

**What the evidence says.** Measurement advice has converged on three rules. Use more than one dimension, include at
least one perceptual measure, and expect the measures to pull against each other (S36). Treat delivery metrics as
team-owned diagnostics, not goals: DORA's own pitfall list names "setting metrics as a goal" and cites Goodhart's law
(S28). And separate effort and output from outcome and impact, because measuring early in the chain breeds perverse
incentives (S25). Targets also do real work. The public-health evidence shows targets produced documented successes and
were gamed, and that once a target is met a controller cannot tell success from gaming (S39). Goodhart's law is a family
of four failure modes, not one, so a mitigation must be matched to the mode (S19).

**Where sources agree.** Activity counts must not stand alone (S36). Self-reports of speed and of status are unreliable:
the trial's developers believed they were faster while the clock said slower (S33), a modelled study finds reported
status differs from true status through perception error and bias (S48), and interrupted workers finished faster while
paying in stress, so output alone hid the cost (S55). Incident counts and PR counts both fail as proxies for learning
and for value (S38).

**Where sources disagree.** DORA and SPACE endorse metrics used well (S28, S36); Beck and Orosz argue McKinsey's
effort-and-output framework will do "far more harm than good" (S25); and a reviewer says the survey method cannot carry
the causal words used (S32). Perception data is endorsed as a leading indicator of burnout (S36) and impeached by the
randomized trial (S33). I resolve it this way: perception is useful as perception, and the label must travel with it.

**What is missing.** No empirical study of Goodhart effects on software-team metrics turned up (search T3 #21 returned
only blogs), and no pre-registered test of any developer-productivity metric.

**Institutional versus ground truth.** The advice says do not set metrics as goals. In an AI orchestration tool the
agents can read the plan, and the plan's checkboxes are the target. Borg's own record shows what that looks like in
practice. Criteria boxes drift low rather than high: 76% checked in shipped plans with 83 unchecked boxes inside them,
and the prior audit found 27% checked against roughly double the real completion. That is status drift (S48), not
gaming, but it shows a declared number can diverge from fact with nobody lying. The adversarial case is the one to
design against: a scorer who is also rewarded by the score (S19), which is why recommendation 10 keeps the scorecard out
of the agents' reach.

### 4.4 Steel-man the contrarian

The Bias-Guard Summary in section 6.3 shows 17 sources I agreed with against 2 I disagreed with, a ratio above 3:1, so
this subsection states the strongest contrary position on its own terms. The search plan carried 18
falsification queries (section 6.2), and the contrary sources used below came from those queries or from the contrarian
category.

The contrarian says: **a one-person project does not need a project-management system, and building a scorecard for one
is the most expensive kind of procrastination.** The evidence does not contradict it. The best base rate in the corpus
says a third of well-designed ideas work (S17), so planning precision is largely wasted; the one field study of WIP
found no productivity benefit (S35); the frameworks' own success statistics are unreliable (S02); retrospectives mostly
recycle opinion (S43); and scoring formulas rank noise (S15, S19). On top of that, the only trial of AI-assisted work
found developers felt 20% faster while being 19% slower (S33), so a developer who feels the system helps has the weakest
possible evidence that it does. For a person with ADHD, time spent instrumenting is time spent not shipping, and a new
dashboard is a new place to hyperfocus. Borg itself learned this once: its retired cairn service (a knowledge-graph
memory store) built four voluntary-write surfaces that produced one real row in five months.

Weighing it: the contrarian wins on three points and loses on two. Formulas and heavyweight scoring are unsupported, as
it says, which is why recommendation 4 says do not adopt them; volunteered capture does fail, which is why
recommendation 1 uses only derived numbers; and effort is scarce, so the scorecard should be time-boxed to the six cheap
numbers before anything else. Where it loses is on stop rules and debriefs, where the strongest evidence in the whole
run sits (S22, S20, S49) and where borg has nothing, and it loses on the claim that nothing is knowable: the local
numbers are cheap to compute and already show 23 of 28 directives past 30 days. The surviving position is that borg
should measure less than the draft proposed and add exactly two mechanisms, a stop date and a debrief.

---

## 5. Research

Findings are grouped by the pillar each source bears on most; a source used in several places has its row in one home
and is cited by ID elsewhere. Every row shows the score band (keep or borderline; reject sources were excluded), the
evidence level (L1 to L9), and the finding used. All 62 included sources appear exactly once as a row below.

### 5.1 The pillars themselves (RQ1)

Thirteen sources describe how the frameworks carve up the work. The primary texts for Scrum, Kanban and Shape Up are
free and current; PMBOK 8 and PRINCE2 7 reach me only through trainers, because the standards are paywalled and PMI's
pages refuse automated fetches. The two data-bearing sources here cut against the frameworks. One tests the success
statistics PM advocacy leans on and finds them wanting (S02). The other validates a model of Scrum team effectiveness on
about 2,000 teams and finds that feedback loops, not roles, carry the weight (S12).

| Source | Band | Level | Finding used |
|---|---|---|---|
| Burdakov and Ahn 2025 (S01) | borderline | L6 | PMBOK 7 gaps for AI projects: limited data management, weak iteration support, no ethics guidance; recommends adding, not discarding. Preprint, respondent ranking. |
| Eveleens and Verhoef 2010 (S02) | keep | L3 | Standish success definitions are "misleading, one-sided"; tested on 5,457 forecasts of 1,211 projects. |
| Nunez Alberro 2020 (S03) | borderline | L8 | A year of Shape Up in a small team: no-backlog and cool-down liked; appetite does not remove estimation; team split from the main team is a confound. |
| Jeffries 2018 (S04) | borderline | L7 | Opinion, no data: poorly applied Agile adds pressure; ceremonies survive while developer autonomy erodes. |
| Kanban Guide 2025 (S05) | keep | L4 | Three practices, four flow measures (WIP, throughput, work item age, cycle time); the 2025 edition deleted its immutability claim. |
| PM Academy (Aldridge) 2025 (S06) | borderline | L7 | PMBOK 8: 6 principles, 7 domains, about 40 processes in five focus areas; value widened past scope, schedule and cost; PMI text unchecked. |
| PMI PMBOK 7 facts 2021 (S07) | borderline | L4 | PMBOK 7: 12 principles and 8 domains, "from processes to principles"; tailoring section added; tool detail moved behind a paid platform. |
| Poppendieck 2006 (S08) | borderline | L7 | Seven principles in 2006, four in 2002; principles are underlying truths and practices must adapt. |
| ILX PRINCE2 7 (S09) | borderline | L7 | PRINCE2 7 keeps seven principles, recasts themes as practices, adds sustainability and people; official manual paywalled. |
| Scrum Guide 2020 (S10) | keep | L4 | Three empirical pillars; 0 mentions of budget or procurement and 1 of cost; Scrum exists only in its entirety. |
| Singer, Shape Up 2019 (S11) | borderline | L7 | Shaping, betting and building in six-week cycles; fixed time, variable scope; effectiveness unevidenced. |
| Verwijs and Russo 2022 (S12) | keep | L3 | Model on about 5,000 developers and 2,000 teams: responsiveness, stakeholder concern, improvement, autonomy, management support; CFI 0.959; self-selected survey. |
| Winter et al. 2006 (S13) | borderline | L4 | UK network named five directions: complexity, social process, value creation, conceptualisation, practitioner development; abstract only. |

### 5.2 P1: Value and prioritization

The most solid items here are negative or cautionary. Estimates of value are noisy (S23, S17), people persist with
failing work even when they know the theory (S22, S20), and the cost-of-delay camp disagrees with the scoring camp about
method while agreeing on the premise (S15, S16, S14). No source in this pillar shows a scored order beating an unscored
one. The kill-rule items come from practice, not trial (S18, S21), so the strongest argument for a stop date is the
escalation evidence, not any evidence about stop dates.

| Source | Band | Level | Finding used |
|---|---|---|---|
| Arnold and Yuce 2013 (S14) | borderline | L5 | Maersk Line: top 25% of requirements worth about three orders of magnitude more than the bottom 25%; one feature waiting 38 weeks cost about $8M; author-reported. |
| Black Swan Farming (WSJF) (S15) | borderline | L7 | Three objections to WSJF: adding value and time criticality is unsound because cost of delay is zero if either is zero; relative scores hide magnitudes; scores are hard to recall past about 20 items. |
| Gilad, ICE (S16) | borderline | L7 | ICE (Impact, Confidence, Ease) is a comparison aid, "not exact science"; scoring shortens debates driven by opinion and politics. |
| Kohavi et al. 2009 (S17) | keep | L5 | About one third of well-designed experiments improved the key metric; the transferable lesson is the base rate, not the method. |
| Doerrfeld 2026 (S18) | borderline | L7 | Set exit conditions (timebox, cost ceiling, confidence threshold) and one decision-owner before starting; its statistics are second-hand. |
| Roth et al. 2015 (S20) | keep | L1 | k = 100 effect sizes, d = 0.496; continue-funding decisions d = 0.443 and the effect grows with elapsed time; knowing the theory gives no protection; mostly hypothetical monetary scenarios. |
| Singer, Betting Table (S21) | borderline | L7 | Betting is a per-cycle decision over shaped pitches; appetite is a time budget set first; a circuit breaker means no default extension; no outcome data. |
| Sleesman et al. 2012 (S22) | keep | L1 | 166 independent samples: escalation of commitment is robust; sunk-cost prominence was lower than expected; shared authority may raise escalation; mostly lab data. |
| Yeret 2014 (S23) | borderline | L8 | On a $16M-profit project, one-month delay cost estimates ran from 0 to $16M, most $150K to $2M; one informal replication. |

### 5.3 P2: Planning and scoping

This is the thinnest pillar, and it has no source of its own. The practices it contains are all defined by a method and
untested: appetite and shaping (S21, S11, with one year of field doubt in S03), written acceptance criteria and the
Definition of Done (S10, S46), and scope boundaries (S06). The measured items are indirect. Retrospective data shows
estimation accuracy did not improve while teams kept discussing it and left the repository data unused (S43), and the
success-definition critique says the on-time, on-budget triple is a shaky outcome (S02). A solo-plus-agents case study
names specification quality, not model capability, as the binding constraint (S37), which is a hypothesis in favour of
this pillar, not proof.

### 5.4 P3: Execution

Flow practice is well defined and thinly evidenced. The Kanban Guide gives the vocabulary (S31), the Little's Law note
says when its arithmetic applies (S24), and the one field study of WIP found no productivity benefit (S35). The
strongest execution evidence is psychological and comes from labs: switching costs time and shrinks with a cue (S57),
and interruptions are survived by working faster at the price of stress (S55). For AI-assisted work the data is a
vendor's telemetry (S30) and DORA's small-batch advice (S29, S26 in 5.5).

| Source | Band | Level | Finding used |
|---|---|---|---|
| 55 Degrees 2023 (S24) | borderline | L7 | Little's Law needs five assumptions (arrival equals departure, all items exit, WIP stable, age stable, consistent units); it is a diagnostic. |
| DORA trunk-based (S29) | borderline | L4 | Trunk-based development means small batches merged at least daily; the team-coordination rationale weakens for one person, the batch logic does not. |
| Faros AI 2025 (S30) | borderline | L5 | High-AI teams completed 21% more tasks and merged 98% more PRs; review time rose 91%; vendor telemetry, the weakest data-bearing source. |
| Kanban Guide 2020 (S31) | borderline | L4 | Four flow measures plus the Service Level Expectation (period and probability); WIP is controlled "often" with limits; no outcome evidence. |
| Sjoberg 2018 (S35) | borderline | L3 | 8,505 items, five teams, 2010 to 2013: WIP and lead time correlate 0.80 at year level (n=4, not significant) and 0.12 at quarter level; WIP and productivity 0.71, partly Little's Law arithmetic; no optimal limit. |
| Mark et al. 2008 (S55) | keep | L2 | Interrupted tasks finished faster with no quality loss, at the price of more stress, frustration, time pressure and effort. |
| Rubinstein et al. 2001 (S57) | keep | L2 | Switch cost is measurable, grows with rule complexity and shrinks with a cue; the popular 40% figure is not in the abstract. |

### 5.5 P4: Delivery

Delivery evidence is dominated by the DORA surveys, which are large and self-reported, plus the definitions of "done".
The two DORA years disagree on the sign of throughput and agree that stability is the casualty of AI (S26, S27); the
metric owner warns against turning its keys into goals (S28); and an outside reviewer shows the method cannot carry the
causal language (S32). The Definition of Done appears twice because two tracks read the same passage of the same Guide
(S34, S46); section 6.4 flags this as a redundancy.

| Source | Band | Level | Finding used |
|---|---|---|---|
| DORA 2024 (S26) | borderline | L3 | Per 25% more AI adoption: throughput -1.5%, stability -7.2%; individual benefit, system-level cost; small batches and testing are the stated fix; self-reported. |
| DORA 2025 (S27) | borderline | L3 | 2025: AI adoption positive for throughput and product performance, still negative for stability; AI amplifies existing strengths and flaws; tests and fast feedback advised. |
| DORA four keys 2026 (S28) | keep | L4 | Five delivery metrics; pitfalls include setting metrics as a goal, relying on a single metric, cross-application comparison and team competition. |
| Lee, Accelerate review (S32) | borderline | L7 | Accelerate uses causal words over a cross-sectional survey design; continuous integration and trunk-based work may be right "not because of this research". |
| Scrum Guide DoD (T3) (S34) | borderline | L4 | Work that fails the Definition of Done cannot be released or shown at review; no outcome evidence. |
| Vilas Boas et al. 2026 (S37) | borderline | L5 | One engineer with four AI agents delivered a four-person initiative in half the planned time; 90% first-review acceptance; self-reported; specification quality is the binding constraint. |
| Scrum Guide DoD (T4) (S46) | borderline | L4 | The Definition of Done is the Increment's commitment and a binary gate; the team sets it where no standard exists; no evidence on strictness. |

### 5.6 P5: Monitoring and feedback

This pillar holds the measurement evidence for RQ3. The framework text says what to measure (S36, S58), the Goodhart
literature says how measures fail (S19, S39), and the experiments say how self-report fails: the AI trial's gap between
belief and clock (S33), the modelled status distortion (S48), and the point that incident counts are not learning
(S38). One practitioner response argues the effort-and-output family of measures is the problem (S25).

| Source | Band | Level | Finding used |
|---|---|---|---|
| Manheim and Garrabrant 2019 (S19) | borderline | L7 | Four Goodhart modes: regressional, extremal, causal, adversarial; adversarial is live when the scorer is rewarded by the score. |
| Beck and Orosz 2023 (S25) | borderline | L7 | Argues McKinsey's framework measures effort and output and creates perverse incentives; reasoning, not data. |
| METR 2025 (S33) | keep | L2 | RCT, 16 developers: 19% longer with AI; they forecast 24% faster and afterwards still believed 20% faster; METR now marks the result out of date. |
| Forsgren et al. 2021 (SPACE) (S36) | keep | L7 | At least three dimensions, one perceptual; activity never alone to reward or penalize; individuals may track their own productivity; framework, not trial. |
| Allspaw 2025 (S38) | borderline | L7 | Incident counts are a poor proxy for learning in either direction; organisations can only create conditions for learning. |
| Bevan and Hood 2006 (S39) | keep | L5 | Targets worked and were gamed; gaming spreads; a met target cannot be told from gaming; health-service evidence applied by analogy. |
| Snow and Keil 2002 (S48) | borderline | L6 | Reported status differs from true status through perception error and deliberate bias; executives should be skeptical of favourable reports; modelled, abstract only. |
| Forsgren 2023 (Azure blog) (S58) | borderline | L7 | Companion blog naming SPACE's five dimensions; activity, speed or volume alone miss what success needs. |

### 5.7 P6: Risk and quality

Risk evidence is the weakest of the delivery-side pillars. One survey associates risk-management practice with project
success (S45), a premortem article offers a 30% figure the run could not verify from the live page (S42), a practitioner
proposes timelines and futurespectives instead of a register (S47), and the SRE chapter sets the postmortem practice
without measuring its effect (S41). Quality gates appear under delivery (S34, S46), and the circuit-breaker mechanism
under value (S21).

| Source | Band | Level | Finding used |
|---|---|---|---|
| Lunney and Lueder 2016 (S41) | borderline | L4 | Postmortems document, find causes and prevent recurrence; blameless; explicit triggers; no measured effect offered. |
| Klein 2007 (S42) | borderline | L7 | Assume the plan failed, then list why; cites a 30% improvement seen only in a truncated copy; body paywalled. |
| Rabechini 2013 (S45) | borderline | L3 | 415 projects: risk-management practice has a significant positive impact on success; non-probability, perception-based sample. |
| Silver 2023 (S47) | borderline | L7 | Registers treat risk as independent point events; alternatives are a living timeline reviewed twice a week and futurespective narratives; experience report. |

### 5.8 P7: Sustainability and capacity

Most of the strongest-labelled evidence in the run sits here, and nearly all of it is adjacent: wartime munitions
workers (S56), call-centre staff (S52), lab switching tasks (S57), children with ADHD (S53), and clinical samples (S60).
For adult software engineers with ADHD the evidence is one interview study (S54), one small trial of a clinician-led
intervention (S62), and one podcast guest (S59). The conclusion the evidence supports is modest: external scaffolding
and if-then plans plausibly help, long hours plausibly hurt, and no source tests a project-management method on this
population.

| Source | Band | Level | Finding used |
|---|---|---|---|
| Agile principle 8 (S51) | borderline | L7 | Principle 8: sponsors, developers and users should maintain a constant pace indefinitely; gives no measure. |
| Collewet and Sauermann 2017 (S52) | keep | L3 | Within-person data: longer hours raise handling time per call, even in a mostly part-time workforce; speed metric only. |
| Gawrilow and Gollwitzer 2008 (S53) | borderline | L2 | If-then plans raised inhibition in children with ADHD to the level of children without; best with medication; lab task, no adult or workplace outcome. |
| Liebel et al. 2024 (S54) | keep | L6 | Interviews: task organization and estimation are hard; lists, calendars, reminders and pairing help; self-selected sample. |
| Pencavel 2014 (S56) | keep | L3 | Output is proportional to hours below a threshold and rises at a decreasing rate above it; munitions workers a century ago; the popular 49-hour figure was not verified in the body. |
| Kennedy and Ferdinandi 2024 (S59) | borderline | L8 | Time blindness, hyperfocus and body doubling; small tasks can sit on a list for years; self-report only. |
| Toli et al. 2016 (S60) | keep | L1 | Large effect of if-then plans on goal attainment in mental-health samples; held across problems; likely optimistic outside the lab. |
| Tulili et al. 2023 (S61) | keep | L1 | 92 papers mapped from the early 1990s; research shifted from qualitative to quantitative; the abstract lists no causes. |
| Work-MAP RCT 2024 (S62) | borderline | L2 | Waitlist RCT, n=46, 11-session telehealth: gains in self-rated performance held at 3 months; small, clinician-delivered. |

### 5.9 P8: Learning and adaptation

The best single outcome result in the run is here (S49), and it comes from debriefs in simulated and medical settings,
not software retrospectives. The software evidence points the other way: retros mostly recycle opinion and repeat
topics (S43), and practitioners describe rituals that change nothing (S40, S44). Army doctrine adds the step the
others skip, which is following up until the lesson changes behaviour (S50).

| Source | Band | Level | Finding used |
|---|---|---|---|
| Corry 2023 (S40) | borderline | L7 | Three retrospective antipatterns (Wheel of Fortune, In the soup, Loudmouth); process-design failures, no outcome data. |
| Lehtinen et al. 2017 (S43) | borderline | L5 | 37 retros, 7 teams: 445 negative statements led to 180 actions; 43 statements recurred; estimation accuracy did not improve; earlier outcomes and repository data went unused. |
| Maric 2026 (S44) | borderline | L7 | No rigorous study of action-item completion exists, by its own account; the 48% repeat-incident figure is second-hand. |
| Tannenbaum and Cerasoli 2013 (S49) | keep | L1 | d = .67 across 46 samples (about 25% better); facilitated d = .75 against .25; quasi-experimental. |
| US Army TC 25-20 1993 (S50) | borderline | L4 | An AAR (after-action review) is a discussion, "not a critique", with a chapter on following up so results change later work. |

---

## 6. Methodology

### 6.1 Research Design

**Research questions.**
1. RQ1: Do the major project-management frameworks agree on the pillars a project is made of?
2. RQ2: Which documented practices have outcome evidence, and how strong is it?
3. RQ3: How should project health be measured, and what does Goodhart's law do to the measures?

The evidence feeds an assessment of borg-collective on two axes: (A) design against best practice, and (B) measured
effectiveness.

**Scope.** In scope: PMBOK, PRINCE2, Scrum, Kanban, Shape Up, Lean, DORA and SPACE; prioritization, stopping rules,
flow, delivery, measurement, risk, retrospectives and sustainable pace; ADHD-relevant capacity evidence; and AI-assisted
solo delivery. Out of scope: enterprise portfolio tooling, construction-style project management, certification
outcomes, and usability of borg's commands. Inclusion criteria were set per track before searching: English-language
sources, primary texts preferred, no date floor (older work is flagged as foundational), all five perspective
categories sought for each track.

**Target audience.** The owner of borg-collective: a solo developer with ADHD who runs parallel AI sessions, wants a
verdict first, and will act on a short list. **Tier:** full, with independent citation verification.
**Methodology version:** deep-research, full tier, as installed in the research-tools plugin on 2026-10-03.

### 6.2 Source Discovery

**Search strategy.** Five parallel tracks searched the open web on 2026-10-03: T1 pillars and frameworks, T2 value and
prioritization, T3 flow and delivery and measurement, T4 feedback (monitoring, risk, learning), and T5 capacity and
sustainability. Engines were the Claude web search tool for all tracks, the OpenAlex scholarly adapter (T4, T5), the
Semantic Scholar graph API and Europe PMC for abstracts (T5), and direct fetches of primaries with curl, WebFetch and
`pdftotext`. 111 queries were logged ("HTTP 403" in the log means the site refused an automated fetch); 18 are tagged as
falsification queries (framed to find evidence the thesis is wrong, such as "evidence that PMBOK or PRINCE2
certification does not improve project success" and "WIP limits do not help criticism"). Source-diversity targets were
academic, institutional, practitioner, boots-on-the-ground and contrarian for every track.

**Search log** (one row per query; the logs do not record result counts per query, so the last column records what each
query yielded):

| Track | # | Query | Engine | Framing | Result used |
|---|---|---|---|---|---|
| T1 | 1 | PMBOK Guide Seventh Edition 12 principles 8 performance domains list PMI | WebSearch | factual | becomeaprojectmanager.com (names; rejected), ricardo-vargas.com (read, not carded) |
| T1 | 2 | PRINCE2 seven themes seven principles seven processes official overview | WebSearch | factual | prince2.com ILX blog (read) |
| T1 | 3 | PMBOK Guide 8th edition released 2025 changes principles performance domains PMI official announcement | WebSearch | factual (recency) | learningtree.com (read, cut), PMA (carded) |
| T1 | 4 | pmi.org PMBOK Guide Eighth Edition announcement ... (allowed_domains pmi.org) | WebSearch | factual (primary) | pmi.org/standards/pmbok snippet only (HTTP 403 to fetch); PMI facts + FAQ PDFs (carded) |
| T1 | 5 | PMI press release PMBOK Guide Eighth Edition released November 2025 "48,000 data points" | WebSearch | factual (primary) | no primary press release found; trainer pages only |
| T1 | 6 | critique of PMBOK body of knowledge project management theory Winter Smith Morris Cicmil | WebSearch | contrarian | Winter et al. 2006 (carded, abstract); scielo critical review (cut, no abstract text) |
| T1 | 7 | Winter Smith Morris Cicmil 2006 "Directions for future research..." abstract | WebSearch | contrarian | Manchester Research Explorer abstract (carded) |
| T1 | 8 | is project management methodology evidence that PMBOK PRINCE2 certification does not improve project success empirical study | WebSearch | FALSIFICATION | only low-quality comparison papers surfaced; none carded |
| T1 | 9 | project management body of knowledge criticized "one size fits all" empirical evidence practitioners ignore PMBOK tools usage survey | WebSearch | FALSIFICATION | arXiv 2506.02214 (carded); no usage-survey found |
| T1 | 10 | Eveleens Verhoef "The rise and fall of the Chaos report figures" IEEE Software | WebSearch | FALSIFICATION | VU author PDF (carded) |
| T1 | 11 | "Eveleens" "Verhoef" Chaos report figures pdf ... | WebSearch | FALSIFICATION | cs.vu.nl PDF located |
| T1 | 12 | Serrador Pinto "Does Agile work" quantitative analysis ... | WebSearch | evaluative | APM 2-page summary read (cut; secondary) |
| T1 | 13 | comparison PMBOK PRINCE2 Scrum Kanban common elements knowledge areas mapping systematic literature review | WebSearch | evaluative | only trainer comparisons; none carded (no neutral mapping study found) |
| T1 | 14 | PRINCE2 7 what's new practices replace themes people sustainability digital data PeopleCert | WebSearch | factual | prince2.com v7 page (carded); lumifywork, purplegriffon, projex snippets (corroboration only) |
| T1 | 15 | PRINCE2 criticism bureaucratic overhead small projects failure study | WebSearch | FALSIFICATION/contrarian | only blog-grade pros/cons; no failure study; none carded |
| T1 | 16 | Scrum Guide 2020 changes what's new Schwaber Sutherland removed prescriptive | WebSearch | factual | scrumguides.org/revisions.html fetched (not carded); InfoQ Q&A snippet |
| T1 | 17 | Scrum criticism empirical evidence does Scrum improve outcomes study teams | WebSearch | evaluative/contrarian | Verwijs and Russo (carded) |
| T1 | 18 | Kanban evidence study WIP limits effect on cycle time empirical software teams | WebSearch | evaluative | ACM WIP study (HTTP 403; covered by track T3/T5 cards) |
| T1 | 19 | Kanban vs Scrum which for small team experience report switched from Scrum to Kanban | WebSearch | experiential | Agile Alliance, Caktus, Mind the Product snippets (not fetched; overlaps T3) |
| T1 | 20 | Poppendieck Lean Software Development seven principles eliminate waste amplify learning decide as late as possible | WebSearch | factual | secondary pages only; led to #21 |
| T1 | 21 | Poppendieck "Principles of Lean Thinking" pdf eliminate waste amplify learning build integrity in see the whole | WebSearch | factual | 2002 paper (read, superseded) and InfoQ ch.2 (carded) |
| T1 | 22 | lean software development criticism limitations Poppendieck waste metaphor manufacturing not software | WebSearch | FALSIFICATION | Springer lit review (not fetched; abstract-level only) |
| T1 | 23 | Ron Jeffries "Developers Should Abandon Agile" ronjeffries.com | WebSearch | contrarian | ronjeffries.com (carded) |
| T1 | 24 | Shape Up methodology experience after one year problems criticism small team not Basecamp | WebSearch | experiential/contrarian | fnune.com (carded); Shape Up forum 'disappointing' post (read, not carded) |
| T1 | 25 | Shape Up Ryan Singer book review pros cons appetite betting table | WebSearch | evaluative | review snippets only (circuit-breaker depends on leadership; shapers vs delivery teams) |
| T1 | 26 | solo developer project management Scrum kanban one person team what works experience | WebSearch | experiential | HN item 21905423 (carded, rejected); scrum.org forum (HTTP 403) |
| T1 | 27 | PMI Pulse of the Profession 2025 project success rates performance report | WebSearch | evaluative | Pulse 2025 PDF read (cut, tangential) |
| T2 | 1 | Reinertsen cost of delay Principles of Product Development Flow CD3 weighted shortest job first | WebSearch | - | wind4change, Wikipedia (not fetched); led to Arnold and Yeret |
| T2 | 2 | WSJF criticism flaws weighted shortest job first SAFe problems (falsification) | WebSearch | falsification | blackswanfarming.com WSJF (carded), Kusters blog (cut) |
| T2 | 3 | Shape Up appetite betting table Basecamp | WebSearch | - | basecamp.com/shapeup ch.8 (carded), ch.3, ch.9 (fetched) |
| T2 | 4 | Staw escalation of commitment sunk cost project failure review meta-analysis | WebSearch | - | Sleesman 2012 PDF (carded), Roth 2015 (paywalled) |
| T2 | 5 | prioritization frameworks don't work RICE scoring criticism product management (falsification) | WebSearch | falsification | vendor guides only (cut); led to Gilad |
| T2 | 6 | backlog bankruptcy declare delete old backlog items practice | WebSearch | - | ProductPlan (carded, reject), HN thread (cut), Mountain Goat (unreachable) |
| T2 | 7 | Kohavi online controlled experiments only one-third of ideas improve metrics Microsoft | WebSearch | - | Kohavi 2009 PDF (carded) |
| T2 | 8 | Goodhart's law metrics software engineering teams measurement dysfunction study | WebSearch | - | vendor/blog Goodhart pages (cut); led to Manheim arXiv |
| T2 | 9 | empirical study prioritization techniques requirements release planning systematic review outcomes | WebSearch | - | SLR ScienceDirect (paywalled candidate) |
| T2 | 10 | kill criteria stopping rules project portfolio when to stop a project evidence | WebSearch | - | LeadDev (carded); PMI/APM pages not fetchable |
| T2 | 11 | Intercom RICE scoring origin Sean McBride | WebSearch | - | vendor pages only (cut) |
| T2 | 12 | Reinertsen "cost of delay" estimates differ 50 to 1 intuitive study product managers | WebSearch | - | Yeret exercise (carded) |
| T2 | 13 | Cooper Edgett Kleinschmidt portfolio management new product development lessons from leading firms | WebSearch | - | Wiley article blocked (paywalled candidate) |
| T2 | 14 | Itamar Gilad ICE scoring confidence meter evidence-guided prioritization | WebSearch | - | Gilad ICE page (carded) |
| T2 | 15 | Scaled Agile Framework WSJF official guidance cost of delay ... | WebSearch | - | framework.scaledagile.com blocked by Cloudflare; scaledagile.com blog fetched, not carded |
| T2 | 16 | Joshua Arnold Black Swan Farming cost of delay profiles value distribution backlog data | WebSearch | - | Arnold/Yuce paper (carded) |
| T2 | 17 | solo developer side project abandon sunk cost when to kill a project experience | WebSearch | - | dev.to 47 side projects (cut), LeadDev |
| T3 | 1 | DORA 2024 Accelerate State of DevOps report AI adoption delivery throughput stability findings | WebSearch | - | Google Cloud 2024 blog |
| T3 | 2 | DORA 2025 State of AI-assisted Software Development report findings | WebSearch | - | Google Cloud 2025 blog |
| T3 | 3 | DORA metrics criticism Goodhart gaming four keys | WebSearch | falsification | dora.dev four-keys guide |
| T3 | 4 | Kanban Guide 2020 Daniel Vacanti Prateek Singh WIP flow metrics definition | WebSearch | - | Kanban Guide 2020.12 |
| T3 | 5 | SPACE framework developer productivity Forsgren Storey ACM Queue | WebSearch | - | (led to #17) |
| T3 | 6 | METR randomized controlled trial AI experienced open-source developers slower | WebSearch | - | METR blog |
| T3 | 7 | WIP limits empirical evidence study effect on lead time software teams kanban | WebSearch | - | Sjoberg ESEM 2018 (SINTEF) |
| T3 | 8 | WIP limits don't help criticism kanban evidence weak | WebSearch | falsification | ProKanban WIP post (read, not carded) |
| T3 | 9 | Little's Law software development cycle time WIP throughput Vacanti Actionable Agile | WebSearch | - | led to #19 |
| T3 | 10 | trunk-based development research small batches continuous integration DORA capability | WebSearch | - | DORA trunk-based page |
| T3 | 11 | solo developer personal kanban WIP limit one-person team experience | WebSearch | - | none (low-quality blogs) |
| T3 | 12 | DORA metrics are harmful misleading critique Accelerate statistical validity methodology | WebSearch | falsification | led to #20 |
| T3 | 13 | "An empirical study of WIP in kanban teams" authors abstract | WebSearch | - | SINTEF record |
| T3 | 14 | Faros AI Productivity Paradox report 10,000 developers | WebSearch | - | Faros page |
| T3 | 15 | Kent Beck Gergely Orosz measuring developer productivity McKinsey response | WebSearch | contrarian | Beck/Orosz newsletter |
| T3 | 16 | solo developer AI coding agents shipping workflow lessons small batches review bottleneck | WebSearch | experiential | Folkman (excluded), Osmani (not carded) |
| T3 | 17 | "SPACE of Developer Productivity" "productivity cannot be reduced to a single dimension" | WebSearch | - | atlas.science mirror |
| T3 | 18 | DORA pausing annual survey 2026 dora.dev announcement | WebSearch | - | dora.dev/survey (no primary pause statement found) |
| T3 | 19 | Vacanti Little's Law assumptions flow metrics stable system | WebSearch | - | 55 Degrees post |
| T3 | 20 | Accelerate DORA research critique self-reported survey causal claims methodology | WebSearch | falsification | Keunwoo Lee review |
| T3 | 21 | Goodhart's law software engineering metrics empirical study gaming velocity story points | WebSearch | falsification | none (blogs only; no empirical study found) |
| T3 | 22 | arXiv survey solo developers agile practices one-person software projects | WebSearch | - | arXiv 2605.18461 |
| T3 | 23 | Hacker News Ask HN solo developer how do you manage tasks WIP limit kanban | WebSearch | experiential | HN item 41473997 (excluded) |
| T4 | 1 | Tannenbaum Cerasoli 2013 debriefs meta-analysis performance improvement 25% | WebSearch | factual | cebma.org PDF (card) |
| T4 | 2 | Google SRE book postmortem culture learning from failure blameless | WebSearch | factual | sre.google chapter (card) |
| T4 | 3 | Klein pre-mortem prospective hindsight 30% increase identify reasons for outcomes | WebSearch | factual | hbr.org (card), USC mirror (context) |
| T4 | 4 | post-mortems don't prevent recurrence incident review action items never completed research | WebSearch | falsification | odd.fyi lead only; vendor blogs triaged out |
| T4 | 5 | retrospectives effectiveness empirical study agile teams do retrospectives improve outcomes | WebSearch | evaluative | leads to Lehtinen, Stålesen/Dølvik, arXiv 2007.08265 (not carded) |
| T4 | 6 | agile retrospectives are useless waste of time critique | WebSearch | falsification/contrarian | Corry on martinfowler.com (card) |
| T4 | 7 | watermelon project status reporting green outside red inside research | WebSearch | experiential | all vendor/PM blogs; triaged out |
| T4 | 8 | Goodhart's law software metrics gaming measurement dysfunction empirical | WebSearch | factual | Thomas & Uminsky arXiv (triaged); vendor blogs out |
| T4 | 9 | risk register effectiveness criticism project risk management lightweight alternative evidence | WebSearch | evaluative/contrarian | niksilver.com (card) |
| T4 | 10 | definition of done quality gates Scrum Guide commitment increment | WebSearch | factual | scrumguides.org (card) |
| T4 | 11 | Learning from incidents post-incident reviews do not reduce recurrence Allspaw blameless critique Safety-II | WebSearch | falsification | odd.fyi (card), ACL Allspaw (card) |
| T4 | 12 | project post-mortem reviews software organizations study learning actually applied Dingsøyr postmortem review | WebSearch | evaluative | Dingsøyr papers identified (paywalled) |
| T4 | 13 | Snow Keil optimistic pessimistic biasing software project status reporting study | WebSearch | factual | leads (MIT Sloan article blocked) |
| T4 | 14 | Keil Robey "Blowing the whistle on troubled software projects" escalation reporting bad news | WebSearch | factual | paywalled list |
| T4 | 15 | Hacker News retrospectives are theater nothing changes solo developer weekly review | WebSearch | experiential | HN item 28352828 (card, rejected) |
| T4 | 16 | Bevan Hood "What's measured is what matters" targets and gaming English public health care system | WebSearch | factual | LSE eprints (card) |
| T4 | 17 | Cox "What's wrong with risk matrices" Risk Analysis 2008 | WebSearch | contrarian | paywalled list |
| T4 | 18 | US Army A Leader's Guide to After-Action Reviews TC 25-20 four questions | WebSearch | factual | TC 25-20 mirror (card) |
| T4 | 19 | Gary Klein premortem project failure prospective hindsight Mitchell Russo Pennington 1989 30 percent original | WebSearch | factual | paywalled list |
| T4 | 20 | Lehtinen Mantyla problem causes software projects retrospective Recurring opinions productive improvements 13% | WebSearch | evaluative | Lehtinen Springer (blocked), arXiv 2502.03570 (not carded) |
| T4 | 21 | agile retrospectives effectiveness team learning | OpenAlex adapter | evaluative | leads only |
| T4 | 22 | postmortem reviews software projects organizational learning | OpenAlex adapter | factual | Desouza/Dingsøyr 2005 lead |
| T4 | 23 | after action review effectiveness team learning | OpenAlex adapter | factual | Tannenbaum record, hospice AAR lead |
| T4 | 24 | project risk management practice effectiveness empirical | OpenAlex adapter | evaluative | Rabechini 2013 (card) |
| T4 | 25 | project status reporting bias software projects | OpenAlex adapter | factual | Snow & Keil 2002 (card), Anandasivam 2009 lead |
| T4 | 26 | Goodhart law performance measurement dysfunction | OpenAlex adapter | factual | Bevan & Hamblin 2008 lead |
| T4 | 27 | retrospective meetings agile software teams improvement | OpenAlex adapter | evaluative | Matthies 2019 lead |
| T4 | 28 | What is wrong with risk matrices Cox | OpenAlex adapter | contrarian | Elmontsri 2014 lead (Cox not indexed) |
| T5 | 1 | task switching costs executive control | OpenAlex adapter | factual | Rubinstein 2001 identified (abstract via Europe PMC) |
| T5 | 2 | interrupted work cost | OpenAlex adapter | factual | Mark 2008 identified |
| T5 | 3 | burnout software engineering systematic | OpenAlex adapter | factual | Tulili 2023 |
| T5 | 4 | implementation intentions ADHD | OpenAlex adapter | factual | 0 results |
| T5 | 5 | working hours productivity output | OpenAlex adapter | factual | Pencavel; Collewet and Sauermann |
| T5 | 6 | Pencavel productivity of working hours output falls after 49 hours IZA | WebSearch | factual | IZA DP 8129 |
| T5 | 7 | WIP limits individual personal kanban evidence no empirical support | WebSearch | falsification | ESEM 2018 WIP study |
| T5 | 8 | ADHD productivity systems criticism evidence external scaffolding planners adults randomized trial | WebSearch | falsification | Work-MAP RCT; ScienceWorks (rejected); neural-revolution, pckt (cut) |
| T5 | 9 | Liebel "software engineers with ADHD" challenges strengths strategies case study arXiv | WebSearch | factual | Liebel 2024 |
| T5 | 10 | Gawrilow Gollwitzer implementation intentions facilitate response inhibition children ADHD | WebSearch | factual | Gawrilow 2008; Toli 2016 surfaced |
| T5 | 11 | Rubinstein Meyer Evans 2001 executive control of cognitive processes in task switching pdf | WebSearch | factual | Rubinstein bibliographic record; pop-press pages cut |
| T5 | 12 | Leroy 2009 "Why is it so hard to do my work" attention residue task switching | WebSearch | factual | Leroy identified (paywalled; blog explainers cut) |
| T5 | 13 | Tulili Capiluppi Rastogi Burnout in software engineering systematic mapping study IST | WebSearch | factual | Groningen portal record |
| T5 | 14 | SPACE of Developer Productivity "Satisfaction and well-being" "at least three dimensions" Forsgren Storey | WebSearch | factual | Azure blog (primary blocked) |
| T5 | 15 | developer with ADHD first-person experience task management what worked what failed blog software engineer time blindness | WebSearch | experiential | Talk Python 473; Medium and kodaps posts cut |
| T5 | 16 | Agile principle 8 / c2 wiki SustainablePace | WebFetch | factual | agilemanifesto.org; c2 wiki returned no text |

**Totals.** Queries: 111. Sources pulled for evaluation: 69 (one card each). Triaged out before carding: 73 entries
listed in 6.6, some of which bundle several pages. Results returned per query were not counted, so I report no total
for "sources discovered". A paywall scan found high-value candidates, listed in 6.7.

### 6.3 Source Evaluation

**Evaluation framework.** Each source got a 10-dimension credibility card (authority, evidence quality, currency,
intent, bias, logic, corroboration, candour about limits, specificity, relevance), a weighted average reported as one of
three bands (keep at 7.0 or above, borderline 5.0 to 6.9, reject below 5.0), and a Verified Quote section with a
location reference. **Evidence classification:** the 9-level hierarchy (level 1 meta-analysis down to level 9
marketing). **Bias guards:** on every card the evaluator scored dimensions 5, 6 and 8 harder when agreeing with the
source and more generously when disagreeing, and applied a triangulation rule that no claim rests on one source type.
One evaluator scored all cards, so there is no inter-rater check.

**Bias-Guard Summary.**

| Bias-guard outcome | Count |
|--------------------|-------|
| Agreed with source: scored harder on dims 5, 6, 8 | 17 |
| Disagreed with source: scored more generously on dims 5, 6, 8 | 2 |
| Neutral / no strong reaction | 50 |
| **Total sources evaluated** | **69** |

The agree-to-disagree ratio is 17:2, above the 3:1 line, so the run carries the Phase 2 falsification queries (18, see
6.2) and the steel-man subsection in 4.4. The skew is not evenly spread, since 14 of the 17 agreed-with cards sit in T4
and T5, the tracks closest to my prior view that debriefs help and capacity limits matter for a developer with ADHD.
Both sources I disagreed with were T3 cards that challenge DORA's evidence or the WIP-limit practice (S32 and S35).

**Citation-Verification Report.** An independent verifier agent (a different agent ID from the synthesis agent, recorded
in `verification-report.md`) fetched each sampled card's URL, searched for each verbatim quote, and checked attribution
and location. The sample of 21 of 69 (30%) was drawn by a seeded random draw, not weighted toward important sources.

| Metric | Value |
|--------|-------|
| Total source cards | 69 |
| Cards sampled for verification | 21 of 69 (30%) |
| Verified | 17 |
| Failed | 0 |
| Inaccessible (flagged cached/partial before verification) | 4 |
| **Failure rate** (`failed / (verified + failed)`) | 0% (0 of 17) |
| Failure-rate band | `<=5%` |

The four inaccessible cards (S35 Sjoberg, S43 Lehtinen, S48 Snow and Keil, S60 Toli) returned HTTP 403, a bot challenge
or an empty page to automated fetch; each carried an `Access status: cached/partial` line before verification, and the
verifier used no substitute host. Their quotes were therefore not machine-checked in this run. For Sjoberg and
Lehtinen the synthesis read user-supplied full text; for Snow and Keil and Toli only the abstract was read. The
inaccessible share, 4 of 21 (19%), is under the 30% threshold, so no low-confidence stamp applies.

**Round-1 history (reported in full).** The run did not pass first time. Round 1 sampled the same 21 of 69 (30%) with
seed 20261003 and a different verifier: 16 verified, 3 failed, 2 inaccessible, a failure rate of 15.8% (3 of 19), band
`>10%`. All three failures were location errors, not content errors: two quotes were verbatim but sat in a paragraph 2
or 3 positions away from the one the card cited, and one was verbatim but in a different section (the closing FAQ) from
the one named. The failed cards were t2-leaddev, t4-maric and t5-scienceworks. No quote was paraphrased, misattributed
or absent. The gate rule is that a rate above 5% blocks the deliverable, so remediation followed path 1: a location
audit of all 69 cards (57 now carry a "Card revised: 2026-10-03 (location audit before re-verification)" line), then a
fresh draw. Round 2 used seed 20261032 and a different verifier agent (both IDs are in the reports): 17 verified, 0
failed, 4 inaccessible, a rate of 0%, band `<=5%`. The round-1 report is archived in `drafts/`. The original sample was
treated as contaminated and not reused. Two caveats: the remediation fixed the error type round 1 found, and round 2
does not prove the other 48 unsampled cards are clean; and the verifier checks quotes and locations, not whether the
paraphrased "Key Findings" on each card are right. The round-2 sample contained one excluded card (the Hacker News
retrospectives thread), so 20 of the 62 included cards (32%) were verified.

### 6.4 Inclusion/Exclusion Results

I worked the six rules of the inclusion matrix, in order, for every card and stopped at the first match. The cards
record a decision and a rationale, not a rule number, so the rule numbers below are my reading of those rationales.

**Summary.**

| Category | Count |
|----------|-------|
| Total sources evaluated (cards) | 69 |
| Included, Core | 23 |
| Included, Supporting | 39 |
| Excluded | 7 |
| Overrides applied | 10 |

Rule counts across the 62 included: Rule 1 (keep, not redundant) 17; Rule 2 (sole voice of a perspective) 5 (S03,
S15, S23, S32, S59); Rule 3 (unique insight) 30; Rule 4 (moderate, two factors) 3 (S16, S18, S25); overrides 7 (the six
upgrades to Core and the retained S34, below). Excluded: 6 by Rule 5 (reject band, redundant, no unique perspective;
three of them only by overriding Rule 2) and 1 by Rule 6 (duplicate).

**Distribution by evidence level.**

| Level | Description | Included | Excluded | Total |
|-------|-------------|----------|----------|-------|
| 1 | Systematic review / meta-analysis | 5 | 0 | 5 |
| 2 | RCT (randomized controlled trial) | 5 | 0 | 5 |
| 3 | Large-scale observational | 8 | 1 | 9 |
| 4 | Expert consensus / professional body | 11 | 0 | 11 |
| 5 | Practitioner case study | 6 | 0 | 6 |
| 6 | Qualitative research | 3 | 0 | 3 |
| 7 | Expert opinion / thought leadership | 21 | 0 | 21 |
| 8 | Anecdotal / personal experience | 3 | 5 | 8 |
| 9 | Marketing / promotional | 0 | 1 | 1 |
| | **Total** | **62** | **7** | **69** |

Levels 1 and 2 hold 10 included sources, so no "no primary evidence" banner is required. Section 2 says what that
primary evidence tests: adjacent populations and constructs, not project-management practice for a solo developer. The
level-1 sources are S20, S22, S49, S60 and S61; the level-2 sources are S33, S53, S55, S57 and S62.

**Distribution by source category.**

| Category | Included | Excluded |
|----------|----------|----------|
| Academic | 25 | 1 |
| Institutional | 13 | 0 |
| Practitioner | 15 | 1 |
| Boots-on-the-ground | 3 | 5 |
| Contrarian | 6 | 0 |

**Distribution by credibility band** (three buckets, not decimal composites; composites are on the T4 and T5 cards
only).

| Band | Weighted average | Count | Disposition |
|------|------------------|-------|-------------|
| keep | 7.0 or above | 19 | 19 included, 0 excluded |
| borderline | 5.0 to 6.9 | 44 | 43 included, 1 excluded |
| reject | below 5.0 | 6 | 0 included, 6 excluded |

**Real cut made this run.** Seven sources were excluded: the Hacker News solo-developer planning thread (X1), the
ProductPlan backlog-bankruptcy post (X2), a Substack one-person AI factory (X3), the Hacker News solo-developer task
thread (X4), the Hacker News retrospectives thread (X5), a duplicate card of the Sjoberg WIP paper (X6), and a
ScienceWorks ADHD blog (X7). Six scored
reject; the seventh was a duplicate (section 7 lists reasons). **The lowest-scoring source that cleared the bar is S47,
Silver's "Alternatives to a traditional risk register" (weighted average about 5.0, borderline, level 7).** The T1 cards
record bands only; the search log puts Jeffries, the PM Academy PMBOK 8 article and the PRINCE2 7 page at about 5.1.
The weakest data-bearing source is the vendor telemetry in S30.

**Overrides applied (10).** Six borderline sources are labelled Core on their cards, though Rules 3 and 4 would make
them Supporting: S21 (primary text for appetite and the circuit breaker), S26 and S27 (the DORA 2024 and 2025 reports),
S31 (the Kanban Guide's flow definitions), S35 (the only field study of WIP) and S46 (the Definition of Done gate). In
each case the role is "sole or primary source for a documented practice", used for definitions and caveats, never for
outcome claims. Three Rule 2 overrides: Rule 2 would have kept a boots-on-the-ground voice for T3 (X3 and X4) and T4
(X5), because each track had no included voice in that category; I kept them out because they are anonymous or
self-reported, and instead record the gap in 6.5. One Rule 6 override: S34 and S46 are the same Scrum Guide passage read
by two tracks, and S10 is the same Guide at the same URL. Rule 6 would exclude S34 as superseded. The card decision
stands as the decision of record (I did not edit cards), and the effect is that the 62 included cards rest on 60
distinct documents. Dropping S34 changes no conclusion.

### 6.5 Perspective Balance

Counts are included sources only. Every track has at least three of the five categories.

| Topic area | Academic | Institutional | Practitioner | Boots | Contrarian |
|------------|----------|---------------|--------------|-------|------------|
| T1 Pillars and frameworks | Y (3) | Y (3) | Y (4) | Y (1) | Y (2) |
| T2 Value and prioritization | Y (4) | N (0) | Y (4) | Y (1) | Y (1) |
| T3 Flow, delivery, measurement | Y (4) | Y (6) | Y (3) | N (0) | Y (1) |
| T4 Feedback: monitoring, risk, learning | Y (5) | Y (3) | Y (3) | N (0) | Y (2) |
| T5 Capacity and sustainability | Y (9) | Y (1) | Y (1) | Y (1) | N (0) |

The gaps are real absences, not skipped searches. T2 has no institutional voice because no standards body publishes on
prioritization economics that I could fetch (the SAFe page was blocked by a Cloudflare challenge). Boots-on-the-ground
is empty for T3 and T4 because the solo-developer and retrospective forum threads were anecdotes (6.4). The T5
contrarian slot is empty because the falsification queries (T5 #7 and #8) returned a WIP study, a trial and a commercial
blog, none of which argues against capacity limits. The ADHD evidence in T5 is mostly academic and adjacent.

### 6.6 Triage-outs

Sources screened out before a card was written, with the one-line reason from each track's log:

| Track | Source | Reason triaged out |
|---|---|---|
| T1 | becomeaprojectmanager.com "Significant Changes in the PMBOK Guide's Seventh Edition" (2022) | Exam-prep blog; est. weighted score ~4.3 (reject). Used only to read the names (see below); not carded |
| T1 | Learning Tree PMBOK 8 article | Training vendor, secondary; est. ~5.0; redundant with the PMA card (same 6/7/40/5 counts) |
| T1 | Poppendieck "Principles of Lean Thinking" (2002 paper) | Read in full; scored borderline (~5.5) but superseded by the 2006 chapter; kept as a cited claim in that card |
| T1 | HN Ask HN solo devs (item 21905423) | Carded but REJECT band (~4.5): anonymous anecdote; the run's deliberate real cut |
| T1 | Serrador and Pinto APM summary | Two-page secondary summary of a paywalled paper; tangential to decomposition; listed as paywalled candidate |
| T1 | PMI Pulse of the Profession 2025 | Self-reported survey n=2,254; tangential (business-acumen skills, not decomposition); the '31% successful' snippet was not found in the PDF text |
| T1 | scielo.org.co PMBOK critical review (Spanish) | No abstract/body text recovered in fetch |
| T1 | Scrum.org forum "One man Scrum Team" | HTTP 403; HN thread used instead |
| T1 | ACM "An empirical study of WIP in kanban teams" | HTTP 403; handled by T3/T5 tracks |
| T1 | Shape Up forum 'My experience ... disappointing' (2023) | Thin single post; overlaps fnune.com; kept out to avoid redundancy |
| T1 | prince2.com ILX older blog (principles/themes/processes) | Superseded by ILX V7 page |
| T1 | Wikipedia and generic trainer pages (asana, monday, knowledgehut, etc.) | Not minimally credible / redundant |
| T1 | ricardo-vargas.com PMBOK 7 domains podcast | Page text only says domains have 'no sequence'; no list; thin |
| T2 | Kusters, "Why WSJF is Nonsense" (failfastmoveon.blogspot.com, 2021-03-15) | Real cut. Toy numeric example of error compounding; weak authority; the structural WSJF critique is carried by the Black Swan Farming card. Its "do the discussion, forget the numbers" recommendation is opinion. |
| T2 | ProductPlan backlog bankruptcy (productplan.com) | Scored band reject (4.9); retained as an Excluded card only for audit. |
| T2 | Hacker News thread 10829735 (2016) | Anonymous forum comments; useful idea ("inbox zero or bankrupt") but no verifiable authority. |
| T2 | Mountain Goat Software backlog-bankruptcy URL | Page returned a different blog index; claimed article not found. |
| T2 | Humanizing Work "life-changing focus of a clean backlog" | Blocked by Cloudflare challenge. |
| T2 | framework.scaledagile.com/wsjf | Blocked by Cloudflare challenge; official SAFe formula taken from search summary only, flagged unverified. |
| T2 | Scaled Agile blog "Challenge of Economic Prioritization" | Fetched; generic organizational-culture prose, no data on WSJF outcomes. |
| T2 | PMI "Pull the plug", "sunk-cost dilemma", APM "when to give up" | Not fetchable (error page) or only snippets. |
| T2 | Vendor RICE/WSJF guides (Atlassian, monday.com, Tempo, projectmanager.com, airfocus, ProdPad, Ducalis) | Vendor marketing; redundant with each other and lower quality than Gilad. |
| T2 | Goodhart blog posts (axify, typoapp, ctoframework, codepulsehq, Hillel Wayne) | Redundant with Manheim and Garrabrant; blogs without systematic evidence. |
| T2 | dev.to "47 unfinished side projects" | Anecdote, no authority, generic content. |
| T2 | Wikipedia Cost of delay | Tertiary. |
| T2 | cond-mat arXiv "Performance Variability and Project Dynamics" | Off-topic (physics model). |
| T2 | Sleesman duplicate: ResearchGate copies | Redundant with the NTNU-hosted PDF. |
| T3 | Medium: "DORA Report 2024 reviewed", RedMonk, New Stack, OpsLevel, Scribd copies | Secondary summaries of a primary already fetched |
| T3 | Scrum.org DORA 2025 summary | Secondary; Google blog is primary |
| T3 | Honeycomb / Faros DORA 2025 takeaways | Vendor summaries of the same report |
| T3 | codepulsehq, keypup, typoapp, alekseialeinikov, neuralwired Goodhart/DORA posts | Vendor or low-credibility content marketing; DORA guide already states Goodhart |
| T3 | Aviator "Everything wrong with DORA metrics", Medium "Optimisation Trap" | Vendor/blog opinion; Lee review covers the substantive critique |
| T3 | Bryan Finster "How to Misuse & Abuse DORA Metrics" PDF | Promising practitioner source; PDF returned binary, not text-verifiable this run (follow-up candidate) |
| T3 | InfoQ "How Not to Use the DORA Metrics" | Fetched; overlaps DORA guide and pre-dates 2024; not carded |
| T3 | Thoughtworks Radar DORA metrics | Page did not render usable text (JS); not verified |
| T3 | super-productivity.com, easykanb, miro, kanbantool, teachingagile WIP posts | Vendor marketing; no evidence |
| T3 | Medium Little's Law posts, leanability, calade, resumelens | Secondary explanations; 55 Degrees (Vacanti's firm) used instead |
| T3 | ProKanban "WIP: what it is" post | Read; conceptual, no evidence beyond assertion; claim that the ProKanban guide removed the WIP-limit requirement was not verified and the 2020 Guide still says "often using WIP Limits" |
| T3 | Osmani "AI writes code faster..." (Jan 2026) | Read; opinion with unsourced statistics (75% logic errors); overlaps Faros/Folkman themes |
| T3 | Waydev "DORA is pausing the survey" | Vendor blog; primary dora.dev announcement not found, so claim left unused |
| T3 | METR 2026 follow-up and ingenire/particula summaries | Secondary; Feb 2026 METR follow-up not fetched (gap) |
| T3 | DORA 2025 PDF/ROI report | Not fetched; Google blog used instead |
| T3 | Folkman substack (carded) | Rubric band reject: anecdote, unverified credentials |
| T3 | HN Ask solo developer thread (carded) | Rubric band reject: anonymous anecdotes |
| T3 | tameflow, spamcast, agilelaws, businessmap | Secondary / low-authority |
| T4 | incident.io, hyperping, Atlassian, upstat, itoc360 and similar postmortem guides | Vendor content marketing; restate SRE book; unsourced statistics |
| T4 | TeamRetro "178 Agile statistics" page | Vendor stats page; unsourced figures (e.g. 24% responsiveness, 20% balanced performance) |
| T4 | Watermelon-status blogs (Cascade, Pragmatic Coders, Cultivated, Medium, Substack, etc.) | Vendor or opinion pieces with no evidence; mechanism covered by Snow & Keil |
| T4 | MIT Sloan "The Pitfalls of Project Status Reporting" | Blocked by Cloudflare to the fetcher; could not verify quotes |
| T4 | Thomas & Uminsky 2020, arXiv 2002.08512 | Fetched (abstract verified) but AI-specific, lower authority than Bevan & Hood; superseded for Goodhart evidence |
| T4 | Bevan & Hamblin 2008 ambulance targets | Adapter abstract only; narrower than Bevan & Hood 2006 |
| T4 | Anandasivam & Premm 2009 (survey, n = 91) | Abstract only via adapter; overlaps Snow & Keil; thin |
| T4 | Desouza, Dingsøyr, Awazu 2005 postmortems; Dingsøyr 2007 | Abstract only / paywalled; no outcome evidence |
| T4 | Matthies 2019 ICSE-Companion; Milani/Storey 2025 (arXiv 2502.03570, n = 19) | Doctoral-symposium abstract and tiny survey; retro-data-use topic only |
| T4 | Elmontsri 2014 and Capogna/Bull 2022 risk-matrix pieces | Abstract-level adapter hits; mild critiques; Cox 2008 is the real source but paywalled |
| T4 | Hospice AAR poster (BMJ SPCare 2025) | Conference abstract; single-site; healthcare |
| T4 | Lehtinen 2017 (Springer) and Aalto theses | Fetcher blocked; moved to paywalled list; 13% figure unverified |
| T4 | Etsy Debriefing Facilitation Guide | Blocked (JavaScript challenge) |
| T4 | Wikipedia risk register / premortem pages, Medium premortem posts | Tertiary or marketing |
| T4 | Hacker News thread 28352828 | Carded but band reject; illustration only |
| T5 | ScienceWorks Health, External Systems for ADHD at Work | Carded then rejected: commercial intent, secondary citation of primary studies |
| T5 | neural-revolution.com ADHD coaching evidence blog | Commercial coaching site; claims not independently verifiable |
| T5 | pckt.blog "What Actually Works for Productivity With ADHD" | Anonymous-tier personal blog; page fetched but not usable |
| T5 | ScienceWorks "ADHD Software Engineers: Sprints and Standups" | Same publisher as rejected card; redundant |
| T5 | Medium/kodaps ADHD developer tips | Anecdotal tips, redundant with Talk Python card |
| T5 | get-alfred.ai, strongerhabits, hushpod, goalsandprogress attention-residue explainers | Secondary popularizations of Leroy 2009; primary is paywalled instead |
| T5 | vocal.media, minagi, zenexmachina "myth of multitasking" | Low-authority explainers of Rubinstein |
| T5 | Collewet and Sauermann (journal) vs IZA | Same work; IZA DP carded |
| T5 | Tether (arXiv 2509.01946) | LLM ADHD tool prototype, "not yet evaluated by target users": no evidence of efficacy |
| T5 | attexis CBT RCT (medRxiv 2025), A self-guided internet intervention protocol, ISCAP 2025 paper | Clinical interventions or protocols without a task-management mechanism; preprint/protocol status |
| T5 | OpenAlex adapter auto-cards (capacity-01..05) | Abstract-only stubs, unreviewed; sit in claude-plugins hooks dir |
| T5 | Machine-learning burnout detection SLR (OpenAlex) | Duplicative of Tulili on topic; not fetched |
| T5 | SPACE secondary explainers (getdx, swarmia, space-framework.com) | Vendor content; Azure/primary preferred |

### 6.7 Paywalled and skipped sources

No fee was paid and no account was registered. Four papers were supplied by Noah as full text on 2026-10-03 (Roth 2015,
Sjoberg 2018, Forsgren et al. 2021, Lehtinen 2017) and are read in full. Noah declined to buy three of the book-length
candidates. The candidates file lists five books (Reinertsen 2009; Forsgren, Humble and Kim 2018; two Vacanti books;
Poppendieck 2003) and does not record which three were declined, so I list all five as not read.

| Candidate | Why it matters | Status |
|-----------|----------------|--------|
| PMI, PMBOK Guide 7th and 8th editions and the Standard for Project Management | Primary check of the principle and domain lists now known from trainers (S06, S07) | Not read; pmi.org blocked automated fetch, standard paywalled |
| PeopleCert, Managing Successful Projects with PRINCE2 7 | Primary definition of the principles and practices (S09) | Not read; paywalled manual |
| Reinertsen, Principles of Product Development Flow (2009) | Primary source for cost of delay and the 50-to-1 estimate spread (S14, S15, S23) | Book; not read |
| Forsgren, Humble and Kim, Accelerate (2018) | Statistical basis behind DORA; would adjudicate the critique S32 | Book; not read |
| Vacanti, Actionable Agile Metrics (2015) and When Will It Be Done (2020) | Primary on Little's Law and percentile forecasting (S24, S31) | Books; not read |
| Poppendieck, Lean Software Development (2003) | Original wording of the Lean principles, which differs from S08 | Book; not read |
| Cox, "What is Wrong with Risk Matrices?" (2008) | Peer-reviewed critique that would supersede S47 on evidence quality | Paywalled; not read |
| Mitchell, Russo and Pennington (1989) | Lab basis of the 30% premortem claim (S42) | Paywalled; not read |
| Cooper, Edgett and Kleinschmidt (2001) | Would test whether scored portfolio methods beat ad hoc selection | Paywalled; not read |
| Staw (1976) | Original escalation experiments behind S22 | Not read |
| Keil and Robey (2001); Dingsoyr et al. (2007) | Bad-news reluctance and reuse of postmortems | Not located / paywalled |
| Gollwitzer and Sheeran (2006); Leroy (2009) | Effect size of if-then plans; attention residue | Paywalled; not read |
| Serrador and Pinto (2015); Standish CHAOS reports; a 2019 review of prioritization techniques | Agile-versus-waterfall survey; the statistics S02 attacks; whether prioritization methods show benefits | Paywalled or commercial; not read |
| Pencavel's refereed version | Whether the 49-hour threshold held (S56 cites the working paper) | Not located |

The most load-bearing gaps are the PMBOK 8 and PRINCE2 7 primaries, which leave RQ1's account of the current frameworks
resting on trainer summaries, and Reinertsen, which leaves the cost-of-delay material at level 5 to 8.

### 6.8 Local-measurement method

All LOCAL MEASUREMENT values come from commands run on the personal machine on 2026-10-03 against the main checkout of
borg-collective (commit `a4bd1c1`), the public GitHub repo via `gh`, `~/.claude/token-spend.jsonl` (API-equivalent
dollars, not billing) and the state root `~/.local/state/borg/`. They are a baseline, not a benchmark. Aggregates that
mention other registered projects are reported unnamed. The earlier unverified draft's numbers were re-run, not trusted
(section 3.12). Figures from the 2026-08-20 completion audit are labelled prior internal audit and were not re-run.

### 6.9 Limitations

- **One evaluator, one rater.** All 69 cards and all eight Axis A scores come from a single agent. No inter-rater
  agreement exists, and the 17:2 skew shows my prior leaked into the cards despite the bias guard.
- **Abstract-level reading.** Ten included cards rest on an abstract or an article introduction (S13, S37, S42, S45,
  S48, S53, S57, S60, S61, S62). Where an abstract omits the number, I did not infer it.
- **Unverified at the quote level.** The independent check covered 21 of 69 cards and 4 of those were inaccessible. It
  tests quotes and locations, not the correctness of each card's paraphrased findings.
- **Redundancy.** The Scrum Guide sits on three cards, the SPACE paper on two (S36, S58), and the two DORA reports share
  a sponsor, so the corpus has fewer independent voices than 62.
- **Adjacent evidence.** Every level-1 and level-2 source tests an adjacent population (call-centre staff, lab
  participants, children, clinical samples, open-source maintainers). The strongest-labelled findings in section 3 are
  therefore not shown to hold for a solo developer using AI agents.
- **Web-search skew.** Web search favours well-optimised pages and bot walls hid some journals; 11 included cards carry
  a cached/partial access flag.
- **Local data is one repo and one machine.** Plan data comes from borg-collective only, ages use filing dates, the
  lead-time median is survivor-biased (39 of 60), the `fix` share is a title proxy, and spend capture is broken. The
  work machine was not examined.
- **The Axis A rubric is mine.** Its scoring rule (section 3.1) is unvalidated, and the 14 of 24 total should be read as
  14 plus or minus 2.
- **Prior unverified draft.** Its external claims (for example the SAFe WSJF formula and the Lean Enterprise Institute
  glossary) were not reused unless re-carded here.

---

## 7. Bibliography

Every included source, 62 in all, grouped by track and numbered S01 to S62 in the order the sections above cite them.
Each entry gives the full citation, URL, score band, evidence level, perspective category, inclusion decision (with the
matrix rule or override), and a one-line contribution. The seven excluded cards (X1 to X7) follow, with reasons. Card
files are at `sources/<id>.md` in this directory, named `t<track>-<slug>.md`.


### Pillars and frameworks (RQ1)

**S01** Burdakov, A. and Ahn, M. J. "Is PMBOK Guide the Right Fit for AI? Re-evaluating Project Management in the Face
of Artificial Intelligence Projects." arXiv:2506.02214, June 2025 (preprint). https://arxiv.org/pdf/2506.02214 Band:
borderline. Level: 6. Category: Academic. Decision: Supporting (Rule 3 (unique insight)). Contribution: The one recent
critique of the PMBOK decomposition for AI and iterative work; a signal, not a test.

**S02** Eveleens, J. L. and Verhoef, C. "The Rise and Fall of the Chaos Report Figures." IEEE Software 27(1), 30-36,
2010. https://www.cs.vu.nl/~x/the_rise_and_fall_of_the_chaos_report_figures.pdf Band: keep. Level: 3. Category:
Contrarian. Decision: Core (Rule 1). Contribution: Tests the Standish success figures on 5,457 forecasts of 1,211
projects and finds them misleading; weakens the on-time/on-budget definition of success.

**S03** Nunez Alberro, F. "Reflecting on a year of Shape Up after Scrum." fnune.com, 12 May 2020.
https://fnune.com/2020/05/12/reflecting-on-a-year-of-shape-up-after-scrum/ Band: borderline. Level: 8. Category:
Boots-on-the-ground. Decision: Supporting (Rule 2 (diversity)). Contribution: A year of field use: no-backlog and
cool-down liked, but appetite does not remove estimation and practices do not transfer on faith.

**S04** Jeffries, R. "Developers Should Abandon Agile." ronjeffries.com, 10 May 2018.
https://ronjeffries.com/articles/018-01ff/abandon-1/ Band: borderline. Level: 7. Category: Contrarian. Decision:
Supporting (Rule 3 (unique insight)). Contribution: An insider's opinion that ceremonies survive while the intent
(autonomy, learning) is lost; no data.

**S05** Coleman, J. and Vacanti, D. et al. "The Kanban Guide." Kanban University, v2025.5, 1 May 2025.
https://kanbanguides.org/the-kanban-guide/2025.5/ Band: keep. Level: 4. Category: Institutional. Decision: Core (Rule
1). Contribution: The smallest framework: three practices, four flow measures; its own change list drops the
immutability claim.

**S06** Aldridge, E. "PMBOK 7 vs PMBOK 8: What Project Managers Need to Know." Project Management Academy blog, late
2025. https://projectmanagementacademy.net/resources/blog/pmbok-7-vs-pmbok-8-differences/ Band: borderline. Level: 7.
Category: Practitioner. Decision: Supporting (Rule 3 (unique insight)). Contribution: Only accessible account of PMBOK 8
(6 principles, 7 domains, about 40 processes); a trainer, so the PMI text is unchecked.

**S07** Project Management Institute. "The PMBOK Guide: Seven Facts About the Pending Seventh Edition" (20 Jan 2021) and
"PMBOK Guide Public FAQs" (29 Mar 2021).
https://www.pmi.org/-/media/pmi/documents/public/pdf/pmbok-standards/pmbok-guide-seven-facts.pdf?v=8dc5f84d-76f6-4405-8b1b-999dd3d4beef
Band: borderline. Level: 4. Category: Institutional. Decision: Supporting (Rule 3 (unique insight)). Contribution: PMI's
own words for the 2021 shift from processes to 12 principles and 8 domains.

**S08** Poppendieck, M. and Poppendieck, T. "Chapter 2: Principles." In Implementing Lean Software Development.
Addison-Wesley, 2006. https://res.infoq.com/articles/poppendieck-implementing-lean/en/resources/poppendieck_ch02.pdf
Band: borderline. Level: 7. Category: Practitioner. Decision: Supporting (Rule 3 (unique insight)). Contribution: The
Lean principle list (seven, up from four in 2002): the count of pillars is a framing choice.

**S09** ILX Marketing Team. "What is PRINCE2 (Version 7) and what changed from 6th Edition." prince2.com, updated 2026.
https://www.prince2.com/usa/blog/what-is-prince2-version-7-and-what-changed-from-6th-edition Band: borderline. Level: 7.
Category: Practitioner. Decision: Supporting (Rule 3 (unique insight)). Contribution: PRINCE2 7 keeps seven principles,
recasts themes as practices, adds people and sustainability.

**S10** Schwaber, K. and Sutherland, J. "The Scrum Guide." scrumguides.org, November 2020.
https://scrumguides.org/scrum-guide.html Band: keep. Level: 4. Category: Institutional. Decision: Core (Rule 1).
Contribution: Scrum's decomposition: three empirical pillars, silent on cost and portfolio, and insists Scrum exists
only in its entirety.

**S11** Singer, R. "Shape Up: Stop Running in Circles and Ship Work that Matters." Basecamp, 2019 (chapter 1).
https://basecamp.com/shapeup/0.3-chapter-01 Band: borderline. Level: 7. Category: Practitioner. Decision: Supporting
(Rule 3 (unique insight)). Contribution: Shaping, betting, building in six-week cycles; fixed time, variable scope;
effectiveness unevidenced.

**S12** Verwijs, C. and Russo, D. "A Theory of Scrum Team Effectiveness." ACM TOSEM, doi:10.1145/3571849
(arXiv:2105.12439), 2022. https://arxiv.org/abs/2105.12439 Band: keep. Level: 3. Category: Academic. Decision: Core
(Rule 1). Contribution: Structural-equation model on about 2,000 Scrum teams: feedback loops and improvement carry the
weight, not roles.

**S13** Winter, M., Smith, C., Morris, P. and Cicmil, S. "Directions for future research in project management." Int. J.
of Project Management 24(8), 638-649, 2006.
https://research.manchester.ac.uk/en/publications/directions-for-future-research-in-project-management-the-main-fin/
Band: borderline. Level: 4. Category: Academic. Decision: Supporting (Rule 3 (unique insight)). Contribution: Academic
critique agenda (complexity, social process, value) that PMBOK 7/8 later absorbed; abstract only.


### Value and prioritization

**S14** Arnold, J. J. and Yuce, O. "Black Swan Farming Using Cost of Delay." Agile 2013 Conference (web edition at
blackswanfarming.com). https://blackswanfarming.com/black-swan-farming-using-cost-of-delay/ Band: borderline. Level: 5.
Category: Practitioner. Decision: Supporting (Rule 3 (unique insight)). Contribution: Author-reported case at one firm:
value per requirement is heavy-tailed, top quarter worth about 1000x the bottom quarter.

**S15** Black Swan Farming. "SAFe and Weighted Shortest Job First (WSJF)." blackswanfarming.com, c. 2013.
https://blackswanfarming.com/safe-and-weighted-shortest-job-first-wsjf/ Band: borderline. Level: 7. Category:
Contrarian. Decision: Supporting (Rule 2 (diversity)). Contribution: Three structural objections to relative-score WSJF
while still endorsing quantified cost of delay.

**S16** Gilad, I. "ICE Scores - All You Need to Know." itamargilad.com, undated (site copyright 2026).
https://itamargilad.com/ice-scores/ Band: borderline. Level: 7. Category: Practitioner. Decision: Supporting (Rule 4).
Contribution: A practitioner defense of ICE scoring that admits the scores are opinion-driven estimates.

**S17** Kohavi, R. et al. "Online Experimentation at Microsoft." ThinkWeek paper, 2009.
http://ai.stanford.edu/~ronnyk/ExPThinkWeek2009Public.pdf Band: keep. Level: 5. Category: Academic. Decision: Core (Rule
1). Contribution: Only about one third of well-designed experiments improved the key metric: a-priori value estimates
are right a minority of the time.

**S18** Doerrfeld, B. "When to kill a software project." LeadDev, 28 May 2026.
https://leaddev.com/leadership/when-to-kill-a-software-project Band: borderline. Level: 7. Category: Practitioner.
Decision: Supporting (Rule 4). Contribution: Set exit conditions and one decision-owner before starting; statistics are
second-hand.

**S19** Manheim, D. and Garrabrant, S. "Categorizing Variants of Goodhart's Law." arXiv:1803.04585v4, 2019.
https://arxiv.org/pdf/1803.04585 Band: borderline. Level: 7. Category: Academic. Decision: Supporting (Rule 3 (unique
insight)). Contribution: Taxonomy of four Goodhart failure modes (regressional, extremal, causal, adversarial).

**S20** Roth, S., Robbert, T. and Straus, L. "On the sunk-cost effect in economic decision-making: a meta-analytic
review." Business Research 8, 99-138, 2015. https://link.springer.com/article/10.1007/s40685-014-0014-8 Band: keep.
Level: 1. Category: Academic. Decision: Supporting (Rule 3 (unique insight)). Contribution: Meta-analysis, k=100, d
about 0.50 (0.44 for continue-funding decisions); knowing the theory does not protect.

**S21** Singer, R. "Shape Up, Chapter 8: The Betting Table." Basecamp, 2019. https://basecamp.com/shapeup/2.2-chapter-08
Band: borderline. Level: 7. Category: Practitioner. Decision: Core (Override: borderline band upgraded to Core).
Contribution: Primary text for appetite, betting without a backlog, and the default-no-extension circuit breaker.

**S22** Sleesman, D. J., Conlon, D. E., McNamara, G. and Miles, J. E. "Cleaning Up the Big Muddy." Academy of Management
Journal 55(3), 541-562, 2012.
http://www.iot.ntnu.no/innovation/norsi-pims-courses/huber/Sleesman,%20Conlon%20&%20McNamara%20(2012).pdf Band: keep.
Level: 1. Category: Academic. Decision: Core (Rule 1). Contribution: Meta-analysis of 166 samples: escalation of
commitment to failing courses is robust; sunk cost is only one driver.

**S23** Yeret, Y. "Don Reinertsen's Cost of Delay Intuition Exercise - a facilitator's guide." yuvalyeret.com, 2014.
https://yuvalyeret.com/blog/lean-product-development-flow/don-reinertsens-cost-of-delay-intuition-exercise-a-facilitators-guide/
Band: borderline. Level: 8. Category: Boots-on-the-ground. Decision: Supporting (Rule 2 (diversity)). Contribution: One
informal replication: one-month delay cost estimates ranged 0 to $16M on a $16M project.


### Flow, delivery and measurement

**S24** 55 Degrees (ActionableAgile). "Little's Law: It's Always The Assumptions." 23 May 2023.
https://www.55degrees.se/blog/post/littles-law-assumptions Band: borderline. Level: 7. Category: Practitioner. Decision:
Supporting (Rule 3 (unique insight)). Contribution: Little's Law holds only under five assumptions, so it is a
diagnostic, not a promise.

**S25** Beck, K. and Orosz, G. "Measuring developer productivity? A response to McKinsey." Tidy First? newsletter, 29
Aug 2023. https://newsletter.kentbeck.com/p/measuring-developer-productivity Band: borderline. Level: 7. Category:
Practitioner. Decision: Supporting (Rule 4). Contribution: Argues effort and output metrics create perverse incentives;
reasoning, not data.

**S26** DORA / Google Cloud. "Announcing the 2024 DORA report." Google Cloud Blog, 22 Oct 2024.
https://cloud.google.com/blog/products/devops-sre/announcing-the-2024-dora-report Band: borderline. Level: 3. Category:
Institutional. Decision: Core (Override: borderline band upgraded to Core). Contribution: Per 25% more AI adoption:
throughput -1.5%, stability -7.2% (self-reported survey); small batches and testing are the stated fix.

**S27** DORA / Google Cloud. "Announcing the 2025 DORA Report." Google Cloud Blog, 23 Sep 2025.
https://cloud.google.com/blog/products/ai-machine-learning/announcing-the-2025-dora-report Band: borderline. Level: 3.
Category: Institutional. Decision: Core (Override: borderline band upgraded to Core). Contribution: Throughput sign
flipped positive in 2025; stability still negative; AI as amplifier of existing strengths and flaws.

**S28** DORA. "DORA's software delivery metrics: the four keys." dora.dev, updated 5 Jan 2026.
https://dora.dev/guides/dora-metrics-four-keys/ Band: keep. Level: 4. Category: Institutional. Decision: Core (Rule 1).
Contribution: The metric owner lists 'setting metrics as a goal' as a pitfall and cites Goodhart's law.

**S29** DORA. "Capabilities: Trunk-based development." dora.dev, accessed 2026-10-03.
https://dora.dev/capabilities/trunk-based-development/ Band: borderline. Level: 4. Category: Institutional. Decision:
Supporting (Rule 3 (unique insight)). Contribution: Institutional definition of daily merges to trunk as the small-batch
enabler.

**S30** Faros AI. "AI Software Engineering" / AI Productivity Paradox. faros.ai, 23 Jul 2025.
https://www.faros.ai/blog/ai-software-engineering Band: borderline. Level: 5. Category: Practitioner. Decision:
Supporting (Rule 3 (unique insight)). Contribution: Vendor telemetry: 21% more tasks and 98% more PRs, but PR review
time up 91%; the weakest data-bearing source.

**S31** Vacanti, D. S., Singh, P. et al. "The Kanban Guide." v2020.12, December 2020.
https://kanbanguides.org/the-kanban-guide/2020.12/ Band: borderline. Level: 4. Category: Institutional. Decision: Core
(Override: borderline band upgraded to Core). Contribution: Definitions of the four flow measures and the service level
expectation; no outcome evidence.

**S32** Lee, K. "A review of Accelerate: The Science of Lean Software and DevOps." keunwoo.com, c. 2022.
https://keunwoo.com/notes/accelerate-devops/ Band: borderline. Level: 7. Category: Contrarian. Decision: Supporting
(Rule 2 (diversity)). Contribution: Sceptical reading: causal words over cross-sectional surveys; practices may be right
'not because of this research'.

**S33** METR (Becker, Rush, Barnes, Rein et al.). "Measuring the Impact of Early-2025 AI on Experienced Open-Source
Developer Productivity." metr.org, 10 Jul 2025. https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/
Band: keep. Level: 2. Category: Academic. Decision: Core (Rule 1). Contribution: RCT, 16 developers: 19% slower with AI,
yet they believed they were 20% faster.

**S34** Schwaber, K. and Sutherland, J. "The Scrum Guide" (Definition of Done passages, T3 reading). scrumguides.org,
November 2020. https://scrumguides.org/scrum-guide.html Band: borderline. Level: 4. Category: Institutional. Decision:
Supporting (Override: Rule 6 would exclude; kept). Contribution: Same URL as S10 and S46; kept as decision of record,
flagged redundant.

**S35** Sjoberg, D. I. K. "An Empirical Study of WIP in Kanban Teams." ESEM 2018, doi:10.1145/3239235.3239238.
https://dl.acm.org/doi/10.1145/3239235.3239238 Band: borderline. Level: 3. Category: Academic. Decision: Core (Override:
borderline band upgraded to Core). Contribution: 8,505 items, five teams, 3.5 years: no support for a productivity
benefit of low WIP; lead-time link vanishes at quarter level.

**S36** Forsgren, N., Storey, M.-A., Maddila, C., Zimmermann, T., Houck, B. and Butler, J. "The SPACE of Developer
Productivity." ACM Queue 19(1), 2021. https://queue.acm.org/detail.cfm?id=3454124 Band: keep. Level: 7. Category:
Academic. Decision: Core (Rule 1). Contribution: Multi-dimension measurement: at least three dimensions, one perceptual;
activity counts never alone. Framework, not a trial.

**S37** Vilas Boas, M. et al. "One Developer Is All You Need: A Case Study of an AI-Augmented One-Person Squad."
arXiv:2605.18461, 18 May 2026. https://arxiv.org/abs/2605.18461 Band: borderline. Level: 5. Category: Academic.
Decision: Supporting (Rule 3 (unique insight)). Contribution: Only solo-plus-agents research case; self-reported
outcomes; spec quality named as the binding constraint.


### Feedback: monitoring, risk, learning

**S38** Allspaw, J. "What Progress In Learning From Incidents Actually Looks Like." Adaptive Capacity Labs, 28 Feb 2025.
https://www.adaptivecapacitylabs.com/2025/02/28/what-progress-in-learning-from-incidents-actually-looks-like/ Band:
borderline. Level: 7. Category: Practitioner. Decision: Supporting (Rule 3 (unique insight)). Contribution: Incident
counts are a poor proxy for learning, in either direction.

**S39** Bevan, G. and Hood, C. "What's measured is what matters: targets and gaming in the English public health care
system." Public Administration 84(3), 517-538, 2006. https://eprints.lse.ac.uk/16211/ Band: keep. Level: 5. Category:
Academic. Decision: Core (Rule 1). Contribution: Targets work and get gamed; a met target cannot be told apart from
gaming.

**S40** Corry, A. "Retrospectives Antipatterns." martinfowler.com, 15 Feb 2023.
https://www.martinfowler.com/articles/retrospective-antipatterns.html Band: borderline. Level: 7. Category:
Practitioner. Decision: Supporting (Rule 3 (unique insight)). Contribution: Three ways retros fail to change anything;
no outcome data.

**S41** Lunney, J. and Lueder, S. "Postmortem Culture: Learning from Failure." In Site Reliability Engineering, ch. 15.
Google / O'Reilly, 2016. https://sre.google/sre-book/postmortem-culture/ Band: borderline. Level: 4. Category:
Institutional. Decision: Supporting (Rule 3 (unique insight)). Contribution: Primary statement of blameless postmortems
with explicit triggers; no measured effect.

**S42** Klein, G. "Performing a Project Premortem." Harvard Business Review, September 2007.
https://hbr.org/2007/09/performing-a-project-premortem Band: borderline. Level: 7. Category: Practitioner. Decision:
Supporting (Rule 3 (unique insight)). Contribution: The premortem; the 30% prospective-hindsight figure is cited, not
verified; body paywalled.

**S43** Lehtinen, T. O. A., Itkonen, J. and Lassenius, C. "Recurring opinions or productive improvements." Empirical
Software Engineering 22, 2409-2452, 2017. https://link.springer.com/article/10.1007/s10664-016-9464-2 Band: borderline.
Level: 5. Category: Academic. Decision: Supporting (Rule 3 (unique insight)). Contribution: 37 retros, 7 teams:
estimation talk recurred while accuracy did not improve; repository data was not used in the meetings.

**S44** Maric, I. "Incident post-mortems that change nothing." odd.fyi, 14 Apr 2026.
https://odd.fyi/blog/article/incident-post-mortems-that-change-nothing-the-ritual-of-blameless-accountability/ Band:
borderline. Level: 7. Category: Contrarian. Decision: Supporting (Rule 3 (unique insight)). Contribution: Concedes there
is no rigorous study of action-item completion; track what changed, not whether a write-up exists.

**S45** Rabechini Jr., R. and Monteiro de Carvalho, M. "Understanding the Impact of Project Risk Management on Project
Performance." J. Technology Management & Innovation 8(S1), 2013. https://doi.org/10.4067/s0718-27242013000300006 Band:
borderline. Level: 3. Category: Academic. Decision: Supporting (Rule 3 (unique insight)). Contribution: Survey of 415
projects: risk practices associate with success; perception-based, non-probability sample.

**S46** Schwaber, K. and Sutherland, J. "The Scrum Guide" (Definition of Done passages, T4 reading). scrumguides.org,
November 2020. https://scrumguides.org/scrum-guide.html Band: borderline. Level: 4. Category: Institutional. Decision:
Core (Override: borderline band upgraded to Core). Contribution: The DoD as a binary gate; the team sets it when no
standard exists.

**S47** Silver, N. "Alternatives to a traditional risk register." niksilver.com, 1 Aug 2023.
https://niksilver.com/2023/08/01/alternatives-to-a-traditional-risk-register/ Band: borderline. Level: 7. Category:
Contrarian. Decision: Supporting (Rule 3 (unique insight)). Contribution: Lowest-scoring included source: experience
report on timelines and 'futurespectives' in place of a register.

**S48** Snow, A. P. and Keil, M. "The challenge of accurate software project status reporting." IEEE Trans. Engineering
Management, 2002. https://doi.org/10.1109/tem.2002.807290 Band: borderline. Level: 6. Category: Academic. Decision:
Supporting (Rule 3 (unique insight)). Contribution: Modelled evidence that reported status differs from true status
through perception error and bias; abstract only.

**S49** Tannenbaum, S. I. and Cerasoli, C. P. "Do Team and Individual Debriefs Enhance Performance? A Meta-Analysis."
Human Factors 55(1), 231-245, 2013. https://cebma.org/assets/Uploads/Tannenbaum-Cerasoli.pdf Band: keep. Level: 1.
Category: Academic. Decision: Core (Rule 1). Contribution: 46 samples, d = .67 (about 25% better); facilitated debriefs
stronger, but mostly non-software settings.

**S50** Headquarters, Department of the Army. "TC 25-20, A Leader's Guide to After-Action Reviews." 30 Sep 1993.
https://nick.groenen.me/attachments/public/gitignored/TC%2025-20%20A%20Leader's%20Guide%20to%20After-Action%20Reviews.pdf
Band: borderline. Level: 4. Category: Institutional. Decision: Supporting (Rule 3 (unique insight)). Contribution:
Origin of the AAR, including the follow-up step that turns discussion into change.


### Capacity and sustainability

**S51** Beck, K. et al. "Principles behind the Agile Manifesto" (principle 8). agilemanifesto.org.
https://agilemanifesto.org/principles.html Band: borderline. Level: 7. Category: Practitioner. Decision: Supporting
(Rule 3 (unique insight)). Contribution: Canonical definition of sustainable pace; supplies no measure.

**S52** Collewet, M. and Sauermann, J. "Working Hours and Productivity." IZA Discussion Paper 10722, April 2017.
https://docs.iza.org/dp10722.pdf Band: keep. Level: 3. Category: Academic. Decision: Supporting (Rule 3 (unique
insight)). Contribution: Within-person call-centre data: longer hours raise handling time per call.

**S53** Gawrilow, C. and Gollwitzer, P. M. "Implementation Intentions Facilitate Response Inhibition in Children with
ADHD." Cognitive Therapy and Research 32, 261-280, 2008. https://doi.org/10.1007/s10608-007-9150-1 Band: borderline.
Level: 2. Category: Academic. Decision: Supporting (Rule 3 (unique insight)). Contribution: If-then plans lifted
inhibition in children with ADHD to control level in a lab task; abstract only.

**S54** Liebel, G., Langlois, N. and Gama, K. "Challenges, Strengths, and Strategies of Software Engineers with ADHD: A
Case Study." ICSE-SEIS 2024 (arXiv:2312.05029). https://arxiv.org/abs/2312.05029 Band: keep. Level: 6. Category:
Academic. Decision: Core (Rule 1). Contribution: Interview study: task organization and estimation are hard; to-do
lists, reminders and pairing help; self-selected sample.

**S55** Mark, G., Gudith, D. and Klocke, U. "The Cost of Interrupted Work: More Speed and Stress." CHI 2008.
https://www.ics.uci.edu/~gmark/chi08-mark.pdf Band: keep. Level: 2. Category: Academic. Decision: Core (Rule 1).
Contribution: Interrupted work finished faster with no quality loss, at the price of stress and effort.

**S56** Pencavel, J. "The Productivity of Working Hours." IZA Discussion Paper 8129, April 2014.
https://docs.iza.org/dp8129.pdf Band: keep. Level: 3. Category: Academic. Decision: Core (Rule 1). Contribution: Output
rises with hours at a decreasing rate past a threshold (munitions workers, a century old).

**S57** Rubinstein, J. S., Meyer, D. E. and Evans, J. E. "Executive control of cognitive processes in task switching."
J. Experimental Psychology: HPP 27(4), 763-797, 2001. https://doi.org/10.1037/0096-1523.27.4.763 Band: keep. Level: 2.
Category: Academic. Decision: Core (Rule 1). Contribution: Switching has a measurable cost that grows with rule
complexity and shrinks with a cue; abstract only.

**S58** Forsgren, N. "Navigating the SPACE between productivity and developer happiness." Microsoft Azure Blog, 11 May
2023. https://azure.microsoft.com/en-us/blog/navigating-the-space-between-productivity-and-developer-happiness/ Band:
borderline. Level: 7. Category: Institutional. Decision: Supporting (Rule 3 (unique insight)). Contribution:
Live-accessible summary of SPACE; the primary is S36.

**S59** Kennedy, M. (host) with Ferdinandi, C. "Episode 473: Being a developer with ADHD." Talk Python To Me, 2 Aug
2024. https://talkpython.fm/episodes/show/473/being-a-developer-with-adhd Band: borderline. Level: 8. Category:
Boots-on-the-ground. Decision: Supporting (Rule 2 (diversity)). Contribution: Sole first-person ADHD developer voice:
time blindness, hyperfocus, avoidance of small tasks.

**S60** Toli, A. et al. "Does forming implementation intentions help people with mental health problems to achieve
goals?" British J. of Clinical Psychology, 2016 (author list unverified). https://doi.org/10.1111/bjc.12086 Band: keep.
Level: 1. Category: Academic. Decision: Core (Rule 1). Contribution: Meta-analysis: if-then planning has a large effect
on goal attainment in clinical samples (lab-based, likely optimistic).

**S61** Tulili, T. R., Capiluppi, A. and Rastogi, A. "Burnout in software engineering: A systematic mapping study."
Information and Software Technology 155, 107116, 2023.
https://research.rug.nl/en/publications/burnout-in-software-engineering-a-systematic-mapping-study Band: keep. Level: 1.
Category: Academic. Decision: Core (Rule 1). Contribution: Maps 92 papers; shows the research exists and turned
quantitative; abstract only, causes not read.

**S62** "Randomized controlled trial of Work-MAP: telehealth metacognitive intervention for work performance of adults
with ADHD." European Psychiatry, 27 Aug 2024 (PMC11859935; authors not extracted).
https://pmc.ncbi.nlm.nih.gov/articles/PMC11859935/ Band: borderline. Level: 2. Category: Academic. Decision: Supporting
(Rule 3 (unique insight)). Contribution: Only adult-ADHD work-performance RCT found: n=46, gains held at 3 months,
clinician-delivered.


### Excluded sources (cards kept for audit, not cited as evidence)

**X1** Ask HN: Solo devs, how do you plan your development? Hacker News item 21905423, 30 Dec 2019.
https://news.ycombinator.com/item?id=21905423 Band: reject. Level: 8. Category: Boots-on-the-ground. Reason: Reject
band, anonymous anecdote (Rule 5). Kept as a card to make the cut auditable.

**X2** Bryant, A. "When to Declare Backlog Bankruptcy." ProductPlan blog, 21 Jan 2020.
https://www.productplan.com/backlog-bankruptcy/ Band: reject. Level: 8. Category: Boots-on-the-ground. Reason: Reject
band, single vendor-blog anecdote (Rule 5).

**X3** Folkman, T. "I built a one-person software factory." Substack, 22 Feb 2026.
https://tylerfolkman.substack.com/p/i-built-a-one-person-software-factory Band: reject. Level: 8. Category:
Boots-on-the-ground. Reason: Reject band, self-reported efficacy, unverified credentials (Rule 5; Rule 2 override, see
section 6).

**X4** Ask HN thread started by lukev, item 41473997, 7 Sep 2024. https://news.ycombinator.com/item?id=41473997 Band:
reject. Level: 8. Category: Boots-on-the-ground. Reason: Reject band, anonymous anecdotes (Rule 5; Rule 2 override, see
section 6).

**X5** js8 and replies. Hacker News item 28352828, 30 Aug 2021. https://news.ycombinator.com/item?id=28352828 Band:
reject. Level: 8. Category: Boots-on-the-ground. Reason: Reject band, anecdote (Rule 5; Rule 2 override, see section 6).

**X6** Sjoberg, D. I. K. "An Empirical Study of WIP in Kanban Teams." ESEM 2018 (duplicate card of S35).
https://dl.acm.org/doi/10.1145/3239235.3239238 Band: borderline. Level: 3. Category: Academic. Reason: Same paper as S35
(Rule 6, superseded).

**X7** Burns, R. "External Systems for ADHD at Work: What Actually Helps." ScienceWorks Health blog, 19 Jun 2026.
https://www.scienceworkshealth.com/post/external-systems-for-adhd-at-work Band: reject. Level: 9. Category:
Practitioner. Reason: Reject band, commercial intent, cites primary work second-hand (Rule 5). The run's clearest cut.
