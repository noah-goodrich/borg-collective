# Infoviz Design-Principles Playbook

The canonical, accreting playbook for the infoviz learning program. Each phase APPENDS its evidence-traced
house rules here rather than re-deriving them. Every rule states the house rule, the evidence it traces to,
and its confidence/caveat. Rules are prefixed by phase (P = Phase 1 Perception & Encoding, D = Phase 2
Dashboards & Operational UI); later phases continue the numbering scheme with their own prefixes.

For the full derivation, source appraisal, and the 5-second-story comprehension check, see the phase research
folders under `research/`.

---

## Phase 1 — Perception & Encoding Effectiveness (2026-07-30)

Derived in `research/2026-07-30-perception-encoding/` (findings synthesis, ELI10 brief, playbook additions,
empirical test).

**P1 — Put the most important number on the highest-ranked channel available: position on a shared scale
first, then length, then angle, then area, then color/shading last.**
Evidence: Cleveland & McGill (1984) ranking, position > length ≈ angle > area > volume > color, replicated at
scale by Heer & Bostock (2010) and again by Davis et al. (2022). [Cleveland & McGill 1984; Heer & Bostock 2010;
Davis et al. 2022]
Confidence: high for population-level design defaults. Caveat: this is a strong prior, not a universal law —
see P2.

**Weighting audit, 2026-08-10.** Re-checked after Bateman et al. turned out to be thinner than P7 assumed.
**P1 holds.** Its weight does not rest on the 1984 original — which this program has still only read via a
third-party paraphrase — but on **two independent Level 2 replications that were both read first-hand**: Heer &
Bostock (2010), which replicated the spatial-encoding ranking on a crowdsourced pool, and Davis et al. (2022),
which replicated and extended it with Bayesian multilevel regression. Davis also confirms the exact scope P1
claims: the ranking is a population-average result and "fails to hold consistently at the individual level,"
which is what P2 exists to handle. Two known limits: Heer & Bostock found a divergence on angle-vs-length
(already encoded in the `≈` above), and their sample size is not verified first-hand here — `vis.stanford.edu`
serves a mismatched TLS certificate, so only secondary figures were available. Consequence: reading Cleveland &
McGill (1984) directly is now **historical interest, not a blocking gap**.

**P2 — For high-stakes or accessibility-sensitive displays, never rely on channel choice alone; pair the
top-ranked channel with a redundant cue (direct label, exact value on hover/print).**
Evidence: Davis et al. (2022/2023) found ~30% of viewers deviate from the "average observer" ranking the
Cleveland-McGill rule assumes. [Davis et al. 2022]
Confidence: high that individual variance exists; moderate on the specific 30% figure generalizing beyond the
tested task set — treat as directional, not a universal constant.

**P3 — An anomaly that must be noticed needs to visually stand out from its neighbors, not merely be present
and "visible."**
Evidence: Simons & Chabris (1999) — 46% of attentionally-loaded observers missed a fully visible, unexpected
event; detection depended on dissimilarity from attended items, not on raw visual salience or spatial
proximity to what's already being watched. [Simons & Chabris 1999]
Confidence: high (Level 2 controlled experiment, extremely widely replicated). Caveat: "make it pop" is a
directional design principle here, not a specific pixel/color spec — that specification work is downstream.

**P4 — Match the highest-salience channel to the most important attribute in the data; don't let a
low-priority attribute accidentally grab the loudest channel (Munzner's "effectiveness principle"). Don't
imply an order the data doesn't have (Munzner's "expressiveness principle").**
Evidence: Munzner, *Visualization Analysis and Design* (2014), marks/channels framework, operationalizing the
Cleveland-McGill ranking as a design rule. [Munzner VAD 2014, via Romanowski review 2023]
Confidence: high — this is the field's standard teaching framework, directly derived from P1's evidence base.

**P5 — Ask "does the reader need to look up an exact number, or spot a trend?" before choosing table vs.
chart. Default to a table for precision/lookup tasks; default to a chart for comparison/trend/pattern
tasks.**
Evidence: Remshard & Queenborough (2023) — tables for "specific information, precise numerical values, or
ranks," charts for "comparisons, predictions, or perceiving patterns and trends." [Remshard & Queenborough
2023]
Confidence: high, peer-reviewed, task-based (not aesthetic) framing.

**P6 (STANDING REQUIREMENT — Noah-flagged) — Visualizations of hierarchical/complex operational data should
support navigable multi-level / semantic zoom: an overview by default, with zoom/filter into a level of
detail, and full detail only on demand.**
Evidence chain:
- The requirement's classic articulation is Shneiderman's Mantra: "Overview first, zoom and filter, then
  details-on-demand." [Shneiderman 1996] — but this is Level-7 expert opinion; Craft & Cairns (2005) found "no
  reasonably obvious studies that have validated Shneiderman's recommendations" as a complete prescription,
  while explicitly not claiming it's wrong ("For most designers, the Mantra works"). [Craft & Cairns 2005]
- The *zooming* mechanism specifically (as opposed to the Mantra as a whole) has strong Level-1 evidence:
  Cockburn, Karlson & Bederson's systematic review (2008) confirms zoom-based techniques work but are "easy to
  do badly" — the failure mode is cognitive discontinuity between pre- and post-zoom states, mitigated by
  animated/smooth transitions. No single technique (overview+detail, zooming, focus+context, cue-based)
  dominates for every task; task type should drive the choice. [Cockburn, Karlson & Bederson 2008]
- Recent (2025-2026) domain-specific work applying semantic zoom to large hierarchical/network structures
  (software architecture "cities," supply-chain flow networks) reports improved task performance and reduced
  navigation time for smooth macro↔detail zoom versus flat, all-at-once layouts — current corroboration for
  this exact use case, though only verified via search summaries, not full-text fetch. [arXiv 2510.00003,
  2025; arXiv 2604.08823, 2026 — flagged for follow-up full-text verification]

**Confidence:** the *requirement itself* (build multi-level/semantic zoom) is well-supported at the mechanism
level (Level 1 review + current 2025-2026 domain studies), even though the umbrella "Mantra" it's usually cited
under is Level 7 and formally unvalidated as a complete prescription. Practical implication: justify the zoom
requirement to stakeholders by citing the mechanism-level evidence (Cockburn et al.) and the 2025-2026
domain studies, not by citing Shneiderman's 1996 mantra alone as if it were proven — and always spec animated/
smooth transitions, since jumpy zoom is the documented failure mode.

**P7 — Don't treat "minimalism"/data-ink reduction as an unqualified virtue; strip ink only up to the point it
stops helping, and watch for accessibility exclusion.**
Evidence: Elavsky (2025) — pushing the data-ink ratio to its logical extreme produces imperceptible charts,
showing the ratio alone can't be the design criterion. [Elavsky 2025] Bateman et al. (CHI 2010), **read
first-hand 2026-08-10**: embellished (Nigel Holmes) charts were described no less accurately than plain ones,
and recalled significantly better after a two-to-three-week gap; eye-tracking confirmed participants attended to
the non-data ink, and they "overwhelmingly chose Holmes-style charts over plain charts." [Bateman et al. 2010]

Confidence: **REVISED DOWN 2026-08-10 — moderate on the core critique, low-to-moderate on the memorability
claim.** Separate the two:
- The *critique of data-ink-ratio-as-law* (Elavsky) stands on its own argument and does not depend on Bateman.
  Unchanged.
- The *memorability finding* is thinner than this program assumed when citing it secondhand. The study is
  **n=20 total** (9 male, 11 female, one university), across 14 charts all embellished by a **single artist**,
  and participants were split into immediate- and long-term-recall conditions with **ten in each** — so P7's
  load-bearing multi-week result rests on **n=10**. It is a real, peer-reviewed CHI result with a coherent
  mechanism; it is not a foundation to win design arguments with.
- The authors refuse to generalize it, and the reason matters: "we do not advocate this strategy as a general
  principle, because the use of strong images in charts is contentious — for example, images convey messages
  that may intentionally or unintentionally bias the viewer's interpretation of the data."
- Cross-phase note: Phase 2's D1/D3 gained **Level 1** support pulling the other way (Tariq et al. name
  overloaded displays as a primary cause of alert fatigue). On operational displays, default to reduction. Read
  P7 as a caution against *dogmatic* minimalism, not as a licence to embellish.

---

## Phase 2 — Dashboards & Operational UI (2026-08-10)

Derived in `research/2026-08-10-dashboards-operational/` (findings synthesis, ELI10 brief, playbook
additions, empirical test).

**Standing note on this phase's confidence.** Track 1 carries the corpus's weakest evidence base: one
Level 1 source, one Level 4, one Level 5, two Level 7, one Level 8. Every rule below states its level, and
**no rule derived solely from a Level 7 or Level 8 source is stated at high confidence.** That constraint
is deliberate — preserve it through future edits.

**D1 — A status display must fit in one screen without scrolling. If it doesn't, it is a report, and it should
stop pretending to be a status display.**
Evidence: Few's canonical definition — "consolidated and arranged on a single screen so the information can be
monitored at a glance" — and its boundary condition: "If you must scroll around to see all the information, it
has transgressed the boundaries of a dashboard." [Few, *Information Dashboard Design*, Ch. 1, Level 7]
Confidence: **moderate-to-high for the claim underneath, moderate for the threshold.** Separate the two. That
**display overload is a real, harm-causing failure mode** now has Level 1 support: Tariq et al.'s systematic
review names "Disconnected and Overloaded Dashboards" as one of four primary causes of alert fatigue, citing
"the absence of tools for organising and presenting information" [Tariq et al. 2025, §5.3.3, Level 1]. That is
independent of Few and arrives from operational research rather than design theory. What remains Level 7 is the
**one-screen threshold specifically** — no source tested one screen against 1.5 or 3, so the boundary is a
convention, not a measurement. Treat "one screen" as a cheap, falsifiable check you should actually run; treat
"overloaded displays cause measurable harm" as established.

**D2 — The top of the display decides whether the rest is read at all. Put the answer to the top task there,
and spend that space on nothing else.**
Evidence: information scent is "how promising a potential source of information appears to the user," and on a
view "the scent is given by the title, images, and the information that is easily visible above the fold." Users
satisfice under bounded rationality and abandon when "the rate-of-gain ratio would decrease." [Budiu / NN/G 2019,
Level 4, summarizing Pirolli & Card's information-foraging program, Level 3]
Confidence: **high for the mechanism, moderate for specific layout prescriptions.** The foraging account is a
large, long-running HCI research program; NN/G's particular formatting advice (bulleted lists, bold keywords,
descriptive headlines) is professional-body guidance. The load-bearing consequence is stronger than "important
things first": content below the fold is not merely seen later, it is seen *conditionally on the top earning the
reader's continued attention*. Decorative headers occupy the highest-value real estate on the display.

**D3 — Show exceptions and summaries, not the full inventory. A row that says the same thing as every other row
is costing space and returning nothing.**
Evidence: Few — a dashboard shows abbreviated summaries and exceptions because "you cannot monitor at a glance
all the details needed to achieve your objectives" [Level 7]; Google SRE independently routes subcritical,
non-exceptional signal to a dashboard and off the interrupt path [Level 5].
Confidence: **moderate-to-high.** Two non-experimental sources converging from unrelated starting points
(perceptual limits vs. on-call cost), now joined by Level 1 corroboration: the same "Disconnected and Overloaded
Dashboards" finding traces the failure specifically to difficulty "consolidating data from multiple sources" and
the absence of tools for "organising and presenting information" — which is what D3 prescribes fixing [Tariq et
al. 2025, §5.3.3, Level 1]. Practical test: compute the variance of your status column. If nearly every row
carries the same value, that column is displaying zero information at full cost.

**D4 — An interrupt must be urgent, actionable, human-judgment-requiring, and actively user-visible — all four.
If the correct response is the same every time, it must not interrupt.**
Evidence: "Does this rule detect *an otherwise undetected condition* that is urgent, actionable, and actively or
imminently user-visible?" — followed by the loophole-closing pair: "Pages with rote, algorithmic responses should
be a red flag" and "If a page merely merits a robotic response, it shouldn't be a page." [Ewaschuk / Google SRE
2016, Level 5]
Confidence: **moderate-to-high for the direction, and this is the most operationally useful rule in the phase.**
Level 5 — distilled fleet-scale operational experience, not a controlled study; its authority comes from scale
and the cost of being wrong, not from methodology. Corroborated in direction by the phase's only Level 1 source,
which finds alert fatigue real and unsolved (D7). The sharp edge is the second half: "actionable" is **not**
satisfied by "the user could in principle do something." It requires that the right action *varies with the
alert*. A constant response means the alert carries no information.

**D5 — Route by urgency into distinct channels: interrupt / queue / display-on-request. Subcritical signal put
on the interrupt channel does not become important; it degrades the channel.**
Evidence: the SRE chapter's three-way classification into pages, tickets, and email alerts, with the explicit
verdict: "Email alerts are of very limited value and tend to easily become overrun with noise; instead, you
should favor a dashboard that monitors all ongoing subcritical problems for the sort of information that
typically ends up in email alerts." [Google SRE 2016, Level 5]
Confidence: **moderate.** Same Level 5 caveat as D4. The design consequence is structural rather than cosmetic:
if a system has only *one* delivery channel, every signal it emits is by construction an interrupt, and D4 must
then be enforced on every single one — which is usually infeasible. Building the queue/display tiers is what
makes D4 affordable.

**D6 — Alert on symptoms (user-visible impact), not on causes or on proxies for causes.**
Evidence: "it's better to spend much more effort on catching symptoms than causes; when it comes to causes, only
worry about very definite, very imminent causes"; "Your monitoring system should address two questions: what's
broken, and why? The 'what's broken' indicates the symptom; the 'why' indicates a (possibly intermediate)
cause." [Google SRE 2016, Level 5]
Confidence: **moderate, with an explicit transfer caveat.** Derived from distributed-systems monitoring, where
"user-visible symptom" has a crisp meaning. Applying it to displays and tooling outside that setting is an
analogy, and a corollary worth naming: a *count* or *elapsed time* is a proxy, not a symptom. Alerting on "N
operations have occurred" fires identically whether things are going well or badly, so it cannot be acted on
differently — which puts it in direct violation of D4.

**D7 — Treat every added alert as a withdrawal from a shared, finite attention budget. Alert fatigue is a
documented failure mode with no established fix.**
Evidence: the only Level 1 source in the track — a systematic review finding that "recent studies, by both
industry and academia, have highlighted the problem of alert fatigue and burnout," that existing mitigations
have "shortcomings," and that the problem generalizes "not just in SOCs but across other Command and Control
(C2) domains as well." [Tariq et al., ACM CSUR 2025, Level 1]

The review's §5.3 identifies **four overarching causes**, read first-hand:
1. **Staff and Skills Shortage** — analyst scarcity producing long hours and overload.
2. **High False-alarm Rate** — "one of the biggest problems with SOCs is the high rate of false positives."
3. **Disconnected and Overloaded Dashboards** — "SOCs struggle with fragmented and overloaded dashboards,
   hindering enterprise-wide visibility and alert correlation," with the lack of visibility traced partly to
   "the absence of tools for organising and presenting information."
4. **Inefficient Standard Operating Procedures (SOPs)** — absent playbooks and orchestration, leaving manual
   interventions "prone to errors, delays, and inconsistencies."

Confidence: **high that the phenomenon is real, that these are its principal causes, that it generalizes beyond
security operations, and that it is unsolved.** This is the one Level 1 anchor in Phase 2. **Still low on any
specific mitigation** — the review's own conclusion is that existing solutions fall short, and it proposes
research directions rather than fixes. Note also that the paper reports its own cited industry survey
inconsistently (p.2: 51% of SOC teams overwhelmed, ">25%" of time on false positives; p.8: 54% overwhelmed, 27%
of time — same citation), so quote its percentages with care even though the causal categories are sound.

**D8 — Before adding a job to a display, ask which existing job it will degrade. Do not treat this as evidence
that displays are doomed.**
Evidence: Brownlow's thesis that dashboards fail because "we've been misusing them by expecting them to do
everything for us" — lookup, analysis, storytelling, and aesthetics at once. [Brownlow 2020, Level 8]
Confidence: **low, and deliberately so — this is a design prompt, not a rule.** Level 8 personal account, and
the author publicly revised the causal claim three years later, concluding the root cause was organizational:
"the root of my discontent was the relationships, communication, processes, and people." The most-shared
criticism of dashboards in the field was retracted by its own author. The question it forces — *what jobs is this
display being asked to do, and which belong elsewhere?* — is worth asking every time. The conclusion it reached
is not evidence of anything.

---

## Tension carried forward from Phase 1 (unresolved)

D1/D3 push toward **reduction**: fewer mechanisms, tighter boundary, exceptions only. Phase 1's **P7** held that
stripping ink is not an unqualified virtue, citing Bateman et al.'s finding that embellished charts scored no
worse on accuracy and significantly better on multi-week recall.

**This tension is now substantially less symmetric than it looked when Phase 2 was drafted.** Both sides were
re-read first-hand on 2026-08-10, and they moved in opposite directions:

- **D1/D3 gained Level 1 support** — overloaded displays are named as a primary cause of alert fatigue in a
  systematic review (above).
- **P7 got weaker.** Bateman et al. is n=20 total, and the multi-week recall result — P7's load-bearing claim —
  rests on a **10-participant** subgroup, using 14 charts all embellished by a single artist. The authors
  explicitly decline to generalize: "we do not advocate this strategy as a general principle, because the use of
  strong images in charts is contentious." See Phase 1's revised P7.

Few's target was always decorative *display mechanisms* — "those gauges, meters, and traffic lights are so damn
cute, but their appeal is only skin deep" — rather than annotation and labels, which Phase 1 correctly found
load-bearing. That distinction survives. What does not survive is treating P7 as an equal-weight counterweight
to D1/D3. **Neither source still supplies a test for telling useful chrome from cute gauge**, and D2 sharpens
the stakes: decoration is not merely neutral, it consumes the highest-scent region of the display. When in
doubt on an operational display, the evidence now favors reduction.
