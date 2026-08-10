# Phase 2 Playbook Additions — Dashboards & Operational UI (D1-D8)

**Date:** 2026-08-10
**Derived in:** `01-findings-synthesis.md`. These rules are appended verbatim to `docs/infoviz/playbook.md`
under a Phase 2 heading. Phase 1's P1-P7 are untouched.

**A standing note on this phase's confidence.** Track 1 carries the corpus's weakest evidence base: one Level 1
source, one Level 4, one Level 5, two Level 7, one Level 8 (see findings synthesis §0). Phase 1's rules could
anchor to a controlled experiment and its large-N replication; most of these cannot. Every rule below states its
level. **No rule derived solely from a Level 7 or Level 8 source is stated at high confidence** — that
constraint is deliberate and should survive future edits.

---

**D1 — A status display must fit in one screen without scrolling. If it doesn't, it is a report, and it should
stop pretending to be a status display.**
Evidence: Few's canonical definition — "consolidated and arranged on a single screen so the information can be
monitored at a glance" — and its boundary condition: "If you must scroll around to see all the information, it
has transgressed the boundaries of a dashboard." [Few, *Information Dashboard Design*, Ch. 1, Level 7]
Confidence: **moderate, and only for the direction.** Level 7 expert opinion; no source in this track tested one
screen against 1.5 or 3, so the threshold is a convention, not a measurement. What raises it above one man's
taste is that the SRE chapter reaches a compatible bounded-signal conclusion from unrelated premises (production
on-call cost), and D2 supplies an independent mechanism for why early-quitting makes long displays fail. Treat
"one screen" as a cheap, falsifiable check you should actually run — not as a proven threshold.

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
Confidence: **moderate.** Two sources, neither experimental, but they converge from unrelated starting points
(perceptual limits vs. on-call cost). Practical test: compute the variance of your status column. If nearly every
row carries the same value, that column is displaying zero information at full cost.

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
industry and academia, have highlighted the problem of alert fatigue and burnout," that the authors "identify
four major causes of alert fatigue in SOC," that existing mitigations have "shortcomings," and that the problem
generalizes "not just in SOCs but across other Command and Control (C2) domains as well." [Tariq et al., ACM
CSUR 2025, Level 1]
Confidence: **high that the phenomenon is real, generalizes beyond security operations, and is unsolved — this
is the one claim in Phase 2 resting on Level 1 evidence. Low on any specific mitigation**, for two reasons: the
review's own finding is that existing solutions fall short, and **its four causes could not be read** (ACM DL
returns 403 to automated fetch; only the abstract was verifiable). Do not cite specific causes of alert fatigue
from this program until someone reads the full text. The rule claims only what the abstract supports.

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

D1/D3 push toward **reduction**: fewer mechanisms, tighter boundary, exceptions only. Phase 1's **P7** establishes
that stripping ink is not an unqualified virtue, citing Bateman et al.'s finding that embellished charts scored no
worse on accuracy and significantly better on multi-week recall.

These are not flatly contradictory. Few targets decorative *display mechanisms* — "those gauges, meters, and
traffic lights are so damn cute, but their appeal is only skin deep" — rather than annotation, labels, and
status chrome, which Phase 1 found load-bearing. But **neither source supplies a test for telling useful chrome
from cute gauge**, and D2 sharpens the stakes: decoration is not merely neutral, it consumes the highest-scent
region of the display. Phase 2 does not resolve this. Where the two pull in opposite directions on a real
artifact, `04-empirical-test.md` says so rather than picking a winner.

---

## Open items for Phase 3+

- **Read Tariq et al. (2025) in full and enumerate the four causes of alert fatigue.** This is the phase's one
  unclosed source gap and the highest-value unblock in the track — it is the only Level 1 evidence available,
  and D7 is currently written to claim strictly less than the paper knows. https://doi.org/10.1145/3723158
  (ACM DL 403s to automated fetch; needs subscription or institutional access.)
- **Few's *Information Dashboard Design* beyond Chapter 1** — in particular the full enumeration of the 13
  mistakes, of which only the first (exceeding the single-screen boundary) is verified here. The available
  full-text scan has uncertain provenance; a legitimate copy should back any citation past Ch. 1.
- **The useful-chrome vs. cute-gauge boundary has no test in either phase.** Candidate for a dedicated
  sub-project: it is now blocking clean application of P7 against D1/D3 on real artifacts.
- **D6's transfer claim is untested.** The symptom/cause distinction is crisp for user-facing services and fuzzy
  for developer tooling and personal operational displays. Worth checking whether the HCI or
  human-factors literature has an equivalent formulation outside the SRE lineage.
- **Track 1 is now done; the curriculum's next-highest-relevance track is Track 2 (Perception), already
  completed as Phase 1.** Sequencing choice for Phase 3 is open — Track 4 (Narrative) feeds the ELI10 mandate
  most directly; Track 6 (Networks) becomes urgent if a DAG project goes live, per the curriculum's own note.
