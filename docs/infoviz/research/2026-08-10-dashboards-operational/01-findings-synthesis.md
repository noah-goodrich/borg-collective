# Phase 2 Findings Synthesis — Dashboards & Operational/Monitoring UI (Track 1)

**Date:** 2026-08-10
**Track question (from `curriculum.md`):** is this one screen, does it show exceptions, and is every interrupt
urgent AND actionable?
**Sources:** the six Track 1 / operational cards written in Phase 0, re-read here, with three re-fetched live for
first-hand verification.

---

## 0. The headline finding is about the evidence, not the advice

Track 1 is the curriculum's designated **read-first** track, and it has the **weakest evidence base in the
corpus**. The six cards carry these levels:

| Source | Level | What that means |
|---|---|---|
| Tariq et al., *Alert Fatigue in SOCs* (ACM CSUR 2025) | **1** | Systematic review |
| Budiu / NN/G, *Information Foraging* (2019) | **4** | Professional-body synthesis over a Level 3 research program |
| Ewaschuk / Google SRE, *Monitoring Distributed Systems* (2016) | **5** | Practitioner case study at very large scale |
| Few, *Information Dashboard Design* (2006/2013) | **7** | Expert opinion |
| Few, *Why Most Dashboards Fail* (2007) | **7** | Expert opinion |
| Brownlow, *Dashboards are Dead* (2020/2023) | **8** | Personal account |

Exactly **one** Level 1 source, and it is about alert fatigue in security operations — not about dashboard
layout at all. The track's spine — Few's single-screen doctrine, which every other source builds on or argues
with — is Level 7. The contrarian close is Level 8, and its author substantially revised it three years later.

This matters for how Phase 2's rules get written. Phase 1 could anchor P1 to a controlled experiment and its
large-N replication. Phase 2 mostly cannot. The honest move is to state each rule at the confidence its source
actually supports, and to be explicit that the track's most-quoted claims are the least-tested ones.

---

## 1. The single-screen doctrine (Few) — load-bearing, and unvalidated

Few's definition is the track's foundation:

> A dashboard is a visual display of the most important information needed to achieve one or more objectives;
> consolidated and arranged on a single screen so the information can be monitored at a glance.

And the boundary condition, stated as a hard line:

> A dashboard fits on a single computer screen. The information must fit on a single screen, entirely available
> within the viewer's eye span so it can all be seen at once, at a glance. If you must scroll around to see all
> the information, it has transgressed the boundaries of a dashboard.

Two things are true at once. The rule is **operationally useful** — it is falsifiable, cheap to check, and
converts a taste argument into a measurement. And it is **Level 7** — Few offers no experiment establishing that
one screen is the threshold, or that a 1.3-screen display degrades measurably. He argues from perceptual
principles and consulting observation.

Few's companion claim in *Why Most Dashboards Fail* is even less hedged:

> Most dashboards that are used in businesses today fail. At best they deliver only a fraction of the insight
> that is needed to monitor the business.

No data is cited for "most." The curriculum's own reading instruction for this piece is to hold the question
"can I now spot the difference between a finding and a strong opinion?" — this sentence is the intended target.

**What survives appraisal:** the *direction* (bounded display, exceptions over completeness) is corroborated
independently by the SRE chapter, which reached a compatible conclusion from production incident response rather
than from design theory. Two independent derivations of the same constraint is meaningfully stronger than either
alone — though neither is an experiment.

**What does not survive:** "one screen" as a precise threshold, and "most dashboards fail" as a quantified claim.

---

## 2. Information foraging — the mechanism under the doctrine

The NN/G piece supplies what Few asserts but does not explain: *why* a bounded, well-ordered display works.

Scent is defined as:

> How promising a potential source of information appears to the user

Users are not optimizers. They operate under bounded rationality, using "satisficing and other imperfect
heuristics," and they abandon a view when the payoff curve flattens:

> Scrolling or clicking a lot more would probably gain the user more information, but in the user's estimation,
> the rate-of-gain ratio would decrease.

And scent is carried by specific, controllable surface features:

> the scent is given by the title, images, and the information that is easily visible above the fold

This is the most transferable finding in the track, because it converts "put the important thing first" from
taste into mechanism: **the top of the display is not merely prominent, it is where the user decides whether to
keep looking at all.** Content placed above the fold is not just seen first — it determines whether anything
below it is seen.

The design guidance follows directly:

> designers use scanning-friendly formatting such as bulleted lists, bolded keywords, descriptive headlines to
> help users find the information that is relevant to them

with the overarching instruction to optimize "for the top task that your page or site is supposed to address."

**Evidence note:** the NN/G article is Level 4, but it summarizes Pirolli & Card's information-foraging program,
which is a large and long-running HCI research effort (Level 3). The *mechanism* is well-supported; the
*specific layout prescriptions* are professional-body guidance.

---

## 3. The alerting discipline (Google SRE) — the sharpest instrument in the track

The SRE chapter is the only source here that supplies a **test** rather than a principle. Its paging rule:

> Does this rule detect *an otherwise undetected condition* that is urgent, actionable, and actively or
> imminently user-visible?

Four conjunctive conditions. An alert failing any one of them does not deserve to interrupt.

The chapter then closes the obvious loophole — the alert that is technically actionable but whose action never
varies:

> Pages with rote, algorithmic responses should be a red flag.

> If a page merely merits a robotic response, it shouldn't be a page.

This is the single most directly applicable finding of Phase 2, and it is the one that indicts our own tooling
(see `04-empirical-test.md`). "Actionable" is not satisfied by "the user could in principle do something." It
requires that *what the user should do varies with the alert*. If the response is the same every time, the alert
is carrying no information and is spending attention for nothing.

The chapter also insists on **channel routing** rather than a single interrupt path:

> Email alerts are of very limited value and tend to easily become overrun with noise; instead, you should favor
> a dashboard that monitors all ongoing subcritical problems for the sort of information that typically ends up
> in email alerts.

Three tiers: pages (interrupt), tickets (queue), dashboards/logs (display on request). Subcritical signal that is
routed to an interrupt channel does not become more important — it degrades the interrupt channel.

And the symptom/cause split:

> it's better to spend much more effort on catching symptoms than causes; when it comes to causes, only worry
> about very definite, very imminent causes.

> Your monitoring system should address two questions: what's broken, and why? The "what's broken" indicates the
> symptom; the "why" indicates a (possibly intermediate) cause.

**Evidence note:** Level 5. This is distilled operational experience across Google's fleet, not a controlled
study. Its authority comes from scale and from the cost of being wrong in that environment, not from a
methodology. Transfer to non-service operational displays is by analogy and should be stated as such.

---

## 4. Alert fatigue (Tariq et al.) — the one Level 1 source, and a gap we could not close

This is the only systematic review in the track, and its relevance is deliberately broad — the authors position
the problem as generalizing:

> We anticipate that it will inspire new research directions for addressing alert fatigue not just in SOCs but
> across other Command and Control (C2) domains as well.

The review establishes three things relevant here:

1. Alert fatigue is a **real and documented** phenomenon, not a design-blog complaint — "recent studies, by both
   industry and academia, have highlighted the problem of alert fatigue and burnout in SOC."
2. The authors "identify four major causes of alert fatigue in SOC."
3. Existing mitigations are **not adequate** — the paper "examine[s] the shortcomings of existing solutions and
   propose[s] several potential research directions leveraging AI."

### The four causes (§5.3), read first-hand

> Through a meticulous evaluation of the existing literature […] we have identified four overarching groups of
> factors causing alert fatigue in SOC.

1. **Staff and Skills Shortage** (§5.3.1) — "the significant demand for skilled personnel and the shortage of
   proficient analysts […] leads to long working hours, overload, and, ultimately, alert fatigue," worsened by
   "the continuous growth in the volume and complexity of security alerts."
2. **High False-alarm Rate** (§5.3.2) — "One of the biggest problems with SOCs is the high rate of false
   positives."
3. **Disconnected and Overloaded Dashboards** (§5.3.3) — "SOCs struggle with fragmented and overloaded
   dashboards, hindering enterprise-wide visibility and alert correlation. The lack of visibility stems from
   analysts' restricted access, difficulties in consolidating data from multiple sources, and the absence of
   tools for organising and presenting information."
4. **Inefficient Standard Operating Procedures (SOPs)** (§5.3.4) — absent playbooks and orchestration leave
   "manual […] interventions that are prone to errors, delays, and inconsistencies."

**Cause 3 is the most consequential result in Phase 2.** A Level 1 systematic review independently names
*overloaded displays* as a primary cause of a documented, measurable harm — arriving from operational research,
with no reference to Few or the design-theory lineage. This is what D1 and D3 were asserting on Level 7
authority alone. It does **not** validate "one screen" as a threshold; it validates the claim underneath it.
Cause 2 does the same work for D4: a high false-alarm rate is precisely the condition where the correct response
to an alert is always the same, which is what D4 forbids.

**One appraisal note against the paper.** It reports its own cited industry survey inconsistently. Page 2: "51%
of SOC teams feel overwhelmed by alert volume, with analysts spending over 25% of their time handling false
positives." Page 8: "54% of SOC teams feel overwhelmed by alerts, 55% lack confidence in prioritising or
responding to them, and security experts spend 27% of their time handling false positives." Same citation [83].
The causal categories are sound and are what this phase relies on; the percentages should not be quoted from
this source without checking the underlying Trend Micro survey directly.

**Access correction (2026-08-10).** An earlier draft of this document recorded the four causes as unreadable and
the paper as paywalled. **Both were wrong.** The article is **CC BY 4.0 open access** — the license is printed on
its first page. What blocked retrieval was `dl.acm.org` returning HTTP 403 to *automated* fetch; a browser
downloads it freely. The standing lesson for this program: **bot-blocked is not the same as paywalled**, the two
have completely different remedies, and conflating them cost this phase a Level 1 anchor it always had access to.

---

## 5. The contrarian (Brownlow) — read for the question, not the answer

Brownlow's thesis is that dashboards fail because they are asked to do incompatible jobs at once:

> we've been misusing them by expecting them to do everything for us

— storytelling, aesthetics, glanceable lookup, and ad hoc self-service analysis from one artifact, producing
"death by 1,000 filters," dashboards ballooning to dozens of pages, and users re-exporting to Excel because they
do not trust the numbers.

The critical detail is what happened next. Three years later the author **substantially revised his own
diagnosis**:

> the root of my discontent was the relationships, communication, processes, and people

> Trust is also about relationships, communication, and even feeling free to make mistakes

This is a Level 8 personal account whose author publicly concluded that his original causal story was wrong —
the artifact was not the problem, the organization was. Treating the 2020 piece as a design rule would mean
adopting a diagnosis its own author retracted.

**What it is still good for:** the *question* it forces — "what jobs is this display being asked to do, and
which of them belong somewhere else?" — is a useful smell test, and it is the question the curriculum assigns to
this read. It is a design prompt, not evidence.

---

## 6. Where the sources agree, and where the agreement is weaker than it looks

**Genuine convergence — two independent derivations:**
Few (design theory, 2006) and Google SRE (production operations, 2016) independently arrive at the same
structural claim: *a monitoring surface should carry bounded, exception-level signal, and everything else
belongs somewhere else.* Few reaches it from perceptual limits and eye span; SRE reaches it from pager fatigue
and on-call cost. Neither cites the other. Convergent derivation from unrelated premises is the strongest thing
this track has, and it is still not an experiment.

**Apparent convergence that is actually one voice:**
"Most dashboards fail" (Few 2007), "dashboards are dead" (Brownlow 2020), and "dashboards fail when over-tasked"
(Brownlow 2023) read like a chorus. They are two authors, one of whom retracted his causal account, and neither
of whom presents data. The field's most-repeated claim about dashboards failing rests on Level 7 and Level 8
sources.

**A tension that resolved asymmetrically once both sides were read first-hand:**
Few's prescription is *reduce* — fewer mechanisms, less decoration, tighter boundary. Phase 1's P7 (Elavsky via
Bateman) held that stripping ink is not an unqualified virtue and that embellishment measurably aided recall.
Read directly on 2026-08-10, the two sides moved in opposite directions: the reduction side gained **Level 1**
support (§4, cause 3), while Bateman turned out to rest on **n=20 total, n=10 for the multi-week recall result**,
using charts from a single artist, with the authors explicitly declining to generalize. Few's distinction —
decorative *display mechanisms* versus load-bearing annotation — still stands, and no source supplies a test for
telling them apart. But these are no longer equal weights, and on operational displays the evidence now favors
reduction. See the tension section in `03-design-principles-playbook-additions.md` and Phase 1's revised P7.

---

## 7. Paywalled / unverified for this phase

- ~~**Tariq et al. (2025)** — four causes unread.~~ **RESOLVED 2026-08-10.** Never paywalled: the article is
  CC BY 4.0 open access and `dl.acm.org` merely 403s automated fetch. Read in full; see §4.
- **Few, *Information Dashboard Design*** — Chapter 1 claims are verified against a full-text scan at
  http://public.magendanz.com/Temp/Information%20Dashboard%20Design.pdf, whose provenance is a personal temp
  directory. The quotes used here are cross-checked against the widely reproduced canonical definition, but
  anything cited beyond Chapter 1 should be treated as secondhand. Legitimate access: publisher or library.
- **Brownlow (2020), original "Dashboards are Dead"** — https://medium.com/count/dashboards-are-dead-69fb825bef6
  returns HTTP 410 Gone. The original's claims are reconstructed from the author's own 2023 follow-up (live) and
  secondary summaries. Given the author's later retraction, closing this gap is low value.

## 8. Sources index

| # | Source | Level | Access |
|---|---|---|---|
| 1 | Tariq et al., Alert Fatigue in SOCs (2025) | 1 | full text read (CC BY; browser only, 403s to bots) |
| 2 | Budiu / NN/G, Information Foraging (2019) | 4 | live, re-verified this phase |
| 3 | Ewaschuk / Google SRE, Monitoring Distributed Systems (2016) | 5 | live, re-verified this phase |
| 4 | Few, Information Dashboard Design (2006/2013) | 7 | scan, uncertain provenance |
| 5 | Few, Why Most Dashboards Fail (2007) | 7 | live |
| 6 | Brownlow, Dashboards are Dead + 3 Years Later (2020/2023) | 8 | follow-up live; original 410 Gone |

1. https://doi.org/10.1145/3723158
2. https://www.nngroup.com/articles/information-foraging/
3. https://sre.google/sre-book/monitoring-distributed-systems/
4. Publisher or library — no stable free URL with sound provenance
5. https://www.perceptualedge.com/articles/misc/WhyMostDashboardsFail.pdf
6. https://medium.com/data-science/dashboards-are-dead-3-years-later-72347757bfa6
