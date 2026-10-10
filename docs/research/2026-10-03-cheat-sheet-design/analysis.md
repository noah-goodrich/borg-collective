Generated: 2026-10-04

# How borg Should Communicate

*Conducted: 2026-10-03 to 2026-10-04 | Methodology: deep-research (full tier, evidence mode) | AI-scoring: 84/100 (self-scored)*

---

## Glossary: read this first

- **Situation awareness (SA)**: knowing what is happening, what it means, and what happens next. Endsley's model has three levels: perceiving the facts, comprehending them, projecting forward.
- **Progressive disclosure**: show the few most important things first and reveal the rest only when the user asks.
- **Choice overload**: the idea that too many options make people choose worse, choose less, or enjoy the choice less.
- **Decision fatigue (ego depletion)**: the idea that willpower or decision quality drains with use, like a battery.
- **Default (and nudge)**: a pre-selected option; a nudge is any small design push toward one choice.
- **Alert fatigue**: ignoring alerts because there are too many or too many are useless. Push means the tool interrupts you; pull means you go look.
- **Resumption lag**: the time it takes to get going again after an interruption.
- **Handoff and I-PASS**: a handoff passes a job and its context to someone else (or to yourself later). I-PASS is a hospital handoff script: Illness severity, Patient summary, Action list, Situation awareness and contingency, Synthesis by the receiver.
- **If-then plan (implementation intention)**: a plan made ahead of time in the form "if X happens, then I will do Y".
- **Effect size (d, g, r, OR)**: one number for how big a difference or link is. For d and g (group differences) 0.2 is small, 0.5 medium, 0.8 large. For r (a correlation) about 0.15 is small. OR is an odds ratio; 1.0 means no difference.
- **Meta-analysis and RCT**: a meta-analysis pools many studies into one estimate; an RCT (randomized controlled trial) assigns people by chance to get the thing or not.
- **Job aid**: a sheet, card or checklist you consult while doing a task so you do not have to remember it.

---

## ELI10

Picture a trail marker at a fork. The hiker reading it is tired, a little lost, and has about two seconds. A marker with one arrow and one word works. A marker with a paragraph of local history means she guesses.

borg is a tool that has to put up trail markers for one developer who is running about twenty projects at once. The question this report answers is how those markers should talk: what to say, when, how, and how much. The research started from one-page diagrams and cheat sheets used in therapy and clinics, then widened to everything the literature says about status displays, alerts, coming back to interrupted work, handing work to someone else, and how many options to show.

The short version is that most of the famous claims are weaker than they sound, and a few unglamorous ones are solid. Showing less is not automatically better. Showing a dashboard does not by itself make anyone decide better. Willpower running out like a battery did not replicate. But putting the conclusion first, interrupting only for things that are urgent and actionable, handing the user back their last context when they return, and handing off in a fixed set of fields chosen from what people actually forget all have real support, mostly from hospitals and programmers rather than from tools like borg.

---

## 1. Recommendations

These are evidence-level statements: what the literature says works, fails, or is unproven for communicating project information. Turning them into features is a separate, later phase. This report decides how borg should say things; the project-management research (#252 and #262) decides what borg should know and enforce.

1. **Lead each surface with the one question it answers, put detail one step away, and stop at two layers.** Frequent needs belong on the first display, and designs past two levels lose users (§3 P1; §4.1).
2. **Keep the "what next" set small and varied, but justify the cap by task difficulty rather than by a general "less is more" slogan.** The pooled effect of option count is about zero, and it turns positive only under named conditions that a next-move choice happens to meet (§3 P3; §4.1, §4.2).
3. **Present any recommended next move as a recommendation, show the reason, and log whether it is followed.** A default borrows the authority of its source, a wrong one carries an emotional cost, and its true size is disputed (§3 P5; §4.2).
4. **Stop citing decision fatigue or willpower depletion as the reason for any limit.** Two large preregistered replications found effects of 0.04 and 0.06; justify limits by what users actually read and act on (§3 P4; §4.2).
5. **Give status a frame and a comparison (since when, against what), and let "nothing needs you" render as a visibly intentional blank that cannot be mistaken for a crash.** Bare numbers do not give comprehension, and one source's blank corner is anecdote, so the blank needs a freshness mark (§3 P6; §4.3).
6. **Interrupt only for what is urgent and actionable, suppress repeats of the same item, and set a numeric interrupt budget you will measure.** Each extra reminder per encounter cut acceptance by 30% in one large clinical dataset, and generic reminders did nothing in two adult-ADHD trials (§3 P7; §4.3).
7. **Pair every status view with the action it implies, and judge it by what got done, not by whether the user felt informed.** Standalone clinical dashboards showed conflicting or null effects across 11 RCTs, and situation awareness predicts performance at only r = 0.26 (§3 P8; §4.3).
8. **On re-entry, put the last context back in front of the user automatically, and capture the cue when leaving rather than when returning.** Programmers took 10 to 15 minutes to resume editing, and an automated activity cue doubled task success over their own notes (§3 P9; §4.4).
9. **Define the end-of-session handoff as a small fixed set of fields chosen from what past handoffs actually left out, including an if-then contingency and a check-back from the receiver.** Fixed fields changed what got transmitted in every comparison, without lengthening the handoff (§3 P10; §4.4).
10. **Treat any handoff format as one part of a bundle and budget for practice and feedback, not only the template.** I-PASS worked as a bundle, and the randomized trials of its clinical outcomes were null (§3 P10; §4.4).
11. **Attach a next move to every named state, written as an if-then, with the problem and its counter-move side by side.** A label alone has weak support and sometimes backfires; a label plus a matched response has a plausible mechanism (§3 P11; §4.5).
12. **Put cues where the work happens, keep them few and visibly distinct, and hold interrupts away from mid-edit moments.** Interruption costs most at high memory load, and highlight loses force when everything is highlighted (§3 P12, P7; §4.4, §4.5).
13. **Keep every artifact small, owned by its user, non-duplicative and labelled as a heuristic; do not mandate it and do not quote accuracy figures for diagrams.** Duplication was the top barrier in 16 of 18 centers and the mandated checklist rollout showed no outcome change (§3 P13; §4.5).
14. **Test locally with the logs borg already keeps before trusting any of this.** No card tests these principles on a developer running many projects, and several tests are cheap (§2 testability; §4.9).

---

## 2. Summary

**What was asked.** How should borg, a command-line tool that coordinates one developer's roughly twenty projects, communicate status, priority, context and next moves so the right information arrives at the right time, in the right way and in the right amount? The method was to start with what makes one-page psychoeducational diagrams work (the first run, which looked at feelings wheels, state maps, scripts and problem/antidote sheets, with a lens on ADHD), then widen to the general communication literature. The widening added three tracks: status displays and situational awareness, re-entry and handoff, and amount and layering. In total 98 sources were evaluated across seven tracks and 93 were kept. An independent verifier checked 30 of the 98 cards and found 0 failed quotes.

**What the evidence supports.** Five findings carry most of the weight.

1. *The conclusion-first, few-layers rule is the best-supported layout advice, but its support is mostly from web text and expert taxonomies.* Concise, scannable, objective writing scored +124% on a usability measure against promotional text in a 51-user study [S3-12], progressive disclosure guidance says designs deeper than two levels lose users [S3-13], and the classic "overview first, details on demand" mantra is, by its author's own words, "only a starting point" [S3-16].
2. *"Fewer options" and "decision fatigue" are weaker than their reputations.* The pooled effect of assortment size is about zero [S3-15], though it becomes real under conditions like a hard task and an unsure chooser [S3-02]; and the willpower-battery effect came back at d = 0.04 (23 labs) and d = 0.06 (36 labs) in preregistered replications [S3-07; S3-17].
3. *A status display alone does not change decisions.* Across 11 randomized trials, standalone clinical dashboards gave conflicting or null results and did better inside multicomponent programs [S1-11]; situation awareness correlates with performance at only r = 0.26 across 678 effects [S1-02].
4. *Interrupt rarely, for the actionable, and never with repeats.* Process-control, hospital and site-reliability sources converge, and two adult-ADHD trials found generic reminders and a well-liked app did nothing for adherence [S1-01; S1-07; S1-09; C4-05; C4-08].
5. *Re-entry and handoff have the most direct evidence for the target user.* Programmers resume slowly (10 to 15 minutes), an automated activity cue doubled task success over their own notes [S2-07], and a fixed-element handoff raised the inclusion of key information in every comparison in the original I-PASS study [S2-09] and in 32 hospitals [S2-10]. The format did not by itself prove better patient outcomes: two randomized trials were null [S2-04].

**Where experts agree, disagree, and what surprised me.** They agree on conclusion-first writing, small groups, recognition over recall, and interrupt restraint. They disagree on whether choice overload exists as a general effect, whether defaults and nudges survive publication-bias correction (one correction found no evidence for nudging overall, while a default meta-analysis found d = 0.68), whether situation awareness is even a valid construct, and whether a handoff script helps or becomes ritual. What surprised me was how consistently the strongest negative evidence is also the best-controlled: the replications, the null randomized trials, and the corrections are larger and cleaner than the studies they correct.

**Evidence quality.** Of the 93 included sources, 22 are systematic reviews or meta-analyses and 18 are randomized or controlled experiments, so the level-1-and-2 count is not the problem. The problem is distance. Nearly all of that evidence comes from hospitals, shoppers, students, lab tasks and web readers, not from a solo developer reading a terminal. Fifty-six cards were read live and 42 are cached or partial (mostly abstract-only). The principles in §3 are therefore reasoning from neighbors, supported where I could find two or more neighbors that agree.

**Testability (Phase 2 classification).** No direct-observation artifact was produced in this run, so the findings are literature-derived predictions. Cheaply testable in borg's own environment, with no artifact yet: whether the drill-in view of a page is ever opened (open counts), whether a surfaced alert is acted on within a set window (hook logs, which already exist for other hooks), whether time to first edit after re-entry falls when the last checkpoint is injected (session timestamps; the programmer studies used exactly this measure), whether recommended next moves are followed (adoption rate), and whether a draft page passes a binary rubric such as the 20-item CDC Clear Communication Index. Testable but slow: whether a handoff record's completeness (measured as element inclusion, the same process measure I-PASS used) predicts shorter re-orientation later, which needs weeks of one person's data. Declared untestable here: generalization to anyone other than the one user, durability over months, and the causal mechanisms of attention and memory, which need controlled lab work.

**The one thing to remember:** a trail marker works because it says one thing at the fork, and the evidence says the same of borg's surfaces: give the conclusion first, interrupt only for what can be acted on, give the user their own last context back, and measure what they did rather than what they saw.

---

## 3. Communication Principles by Moment

The research did not hand over a ready-made model, so this section builds one: thirteen principles, each tied to the cards that support it and each given an evidence-strength label, then mapped onto the six moments at which borg speaks to its user. **Strong** means a meta-analysis or several large preregistered studies speak directly to the point. **Moderate** means Level 1 or 2 evidence with a gap in population or setting, or consistent mid-level evidence plus a mechanism. **Weak** means a single study, descriptive work, or expert statement only. **Theory-only** means the claim follows from a mechanism and nobody has tested it for this use. Card tags like [S3-12] point to the bibliography in §7. The six moments were chosen from borg's real surfaces (the cross-project page, the next-move recommendation, the session-start context load, the plan-versus-edit workflow, the session-end checkpoint, and alerts and warnings); they are descriptions of when borg speaks, not feature proposals.

### 3.1 The thirteen principles

**P1: Lead with the conclusion, reveal detail on request, stop at two layers.** Moderate for concise and scannable text, Weak for the two-layer cap. The Morkes and Nielsen study of 51 users and five site versions measured +58% usability for concise text, +47% for scannable, +27% for objective, and +124% for all three combined, against a promotional control; the authors did not isolate conclusion-first as its own variable, and the material was web text [S3-12]. Nielsen's progressive disclosure guidance says what users need frequently must be on the initial display, secondary content should be needed rarely, and designs with more than two levels usually have low usability because people get lost between them, which is practitioner judgment and not an experiment [S3-13]. Shneiderman's mantra (overview first, zoom and filter, then details on demand) is a taxonomy that its author calls "only a starting point" [S3-16], and Cockburn's review of overview-plus-detail interfaces found that a combined view can beat a single view but that the best style depends on the task, that the literature gives no clear guidelines, and that integrating two views costs mental effort [S3-03]. The command-line guidelines add "err on the side of less" for default output [S1-04]. The reading is that conclusion-first is well supported as writing advice and layering is supported as a design heuristic with a known switching cost.

**P2: One message, few groups, subtract decoration.** Moderate. The CDC Clear Communication Index asks for one main message in one to three short sentences and splits lists longer than seven [C1-01]; Cowan's review puts the working-memory limit near four chunks and calls Miller's seven "a rhetorical device" [C1-02]; the multimedia meta-analysis (92 articles, 181 studies) found g = 0.37 overall with the largest gains from removing seductive detail and pairing text with a diagram [C1-09]. De Jong's critique says cognitive load theory is a design heuristic with open problems, so "remove clutter" is safer than "draw exactly four boxes" [C1-03]. Few's dashboard paper makes the same point for status screens: the display acts as external memory for about four chunks [S1-06].

**P3: Size the set to the task, not to a slogan.** Weak to Moderate, and contested. The famous jam study found people more likely to buy or finish when offered 6 options than 24 or 30 [S3-08], but the meta-analysis of 63 conditions found the mean effect of assortment size "virtually zero" with large unexplained variance [S3-15]. A later meta-analysis found overload reliably appears under four conditions: a complex set, a difficult task, an unsure chooser, and a goal of minimizing effort [S3-02]. A 2022 preprint argues the usual tests are underpowered, so the literature may under-report overload [S3-05]. For recommender lists, small diverse sets were as satisfying as ranked top-N lists and less effortful to choose from [S3-18], and 12 interviewed streaming users trusted recommendation lists yet felt frustration when they missed [S3-14]. The design reading is conditional: "what should I work on next" meets all four conditions (hard, uncertain, effort-minimizing), so a small set binds there; a standing at-rest overview that the user scans does not obviously meet them.

**P4: Do not justify limits with "decision fatigue" or "willpower depletion".** Strong that the lab effect is near zero; unresolved for the field. A 23-lab preregistered replication (N = 2,141) found d = 0.04, 95% CI -0.07 to 0.15 [S3-07]; a 36-lab preregistered test (N = 3,531) found d = 0.06 and data about four times likelier under the null than under an informed prior of δ = 0.30 (SD 0.15) [S3-17]; a 2025 multi-lab paper found d of about 0.31 to 0.35 but only after 30 to 40 minutes of intense self-control exertion, and argues earlier nulls used weak manipulations [S3-04]. The "hungry judge" study that made decision fatigue famous implied d = 1.96, and a simulation reproduced the pattern with a rational judge and a case-ordering artefact [S3-06]. A systematic review of 82 healthcare studies found 45% of tested cases showed decision-fatigue effects and called the construct inconsistently defined [S3-11], and a review of 87 information-overload papers found the evidence for overload interventions mixed [S3-01]. The usable rule is negative: do not defend a cap with a mechanism that failed to replicate.

**P5: A recommended default is a lever of unknown size; label it and show why.** Weak, and contested. A meta-analysis of 58 studies found a default effect of d = 0.68 (95% CI 0.53 to 0.83), larger when the default reads as an endorsement or as the status quo, with several null and two negative effects [S3-09]. A bias-corrected re-analysis of the nudging literature found no evidence for nudge effectiveness overall, evidence against "information" and "assistance" interventions, and left "structure" interventions (the category holding defaults) undecided [S3-10]. The streaming-user interviews add that people trust a recommendation by default and feel it when it is wrong [S3-14]. Together they say a single labelled recommendation probably helps by borrowing authority, that its size is probably smaller than the lab number, and that its failures have a cost, so it should carry its reason and its adoption should be logged.

**P6: Give state a frame and a comparison, and let "nothing needs you" look intentional.** Weak to Moderate. Few's dashboard paper argues a status display must support perception, comprehension and projection, that numbers alone do not give comprehension without a target, a prior period or history beside them, and that scoring everything good or bad drowns the few items needing attention [S1-06]. A hobbyist's e-paper family dashboard converged after years on a corner that stays blank when nothing needs attention, with a read-only display separated from control; that is one anecdote at the lowest evidence tier [S1-08]. The command-line guidelines say to suggest the next command and to show brief output on success so silence does not read as hanging [S1-04]. These two pull in different directions, and my reconciliation, an inference and not a finding, is that a *command* should confirm it finished while a *standing display* may be blank for "nothing needs you" provided a freshness mark distinguishes blank from broken. In a 13-person documentation team, a Kanban board raised perceived communication, which the authors attributed to visibility and a standard card structure; the sample and setting are small [S1-10].

**P7: Interrupt only for the urgent and actionable, suppress repeats, set and measure a budget.** Moderate. In one clinical decision-support dataset, each additional reminder per encounter cut the likelihood of acceptance by 30%, repeated reminders lowered it further, and the authors found no desensitization over time, which points at low-information repeats as the lever [S1-01]. A systematic review of alert fatigue ties it to frequency, presentation and accuracy [C4-06]. The Google site-reliability guidance tests every alert for "urgent, actionable, user-visible", says a human can react with urgency only a few times a day, and tells teams to automate any page with a rote response [S1-07]. The process-control benchmark across 37 consoles reports alarm-rate bands of under 1 per 10 minutes as likely acceptable and over 10 as unacceptable, with the authors noting the numbers are "devoid of context" [S1-09]. On the ADHD side, a micro-randomized trial of SMS reminders in adults with ADHD found no effect on module completion, logins or practice [C4-08], and a 73-person trial of a liked app found no adherence difference [C4-05]. The just-in-time framework says to match prompts to receptivity [C4-07], though a 2025 review found only five mental-health versions and called their timing rules unsupported [C4-11]. Interruption cost also depends on timing: programmers needed at least seven minutes to reach a low-memory breakpoint, and interruption is worst mid-edit [S2-06].

**P8: A status display does not change decisions by itself; pair it with an action and measure outcomes.** Moderate. Across 11 RCTs standalone clinical dashboards gave conflicting evidence on antibiotic prescribing and no effect on statin prescribing, and worked more often inside multicomponent interventions [S1-11]. The meta-analysis of 678 effects from 77 papers found situation awareness correlates with performance at a mean r = 0.26 (plausible range -0.15 to 0.60) and concluded that SA-targeted display redesigns may not produce performance gains [S1-02]. The construct is disputed: critics call it a circular folk model, defenders call it a useful diagnostic of system design, and a context-dependence critique says the "important contents" cannot be fixed in advance [S1-03; S1-05]. The use of the SA levels is therefore as a checklist for what to show (Few), with outcome measures as the test.

**P9: On return, re-present the last context; capture the cue at departure.** Moderate, with the most direct evidence for developers. After an interruption the resumption lag in one task environment was 3.8 seconds against 1.9 for uninterrupted actions, and cues present just before the interruption reduced it [S2-02]. In a survey of 371 programmers plus a controlled comparison, developers using either of two automated activity cues completed tasks at twice the success rate of those using note-taking alone, and, tellingly, preferred the chronological code-snippet cue despite the two performing the same [S2-07]. Field analysis of 10,000 sessions found 10 to 15 minutes before editing resumed, resumption within a minute only 10% of the time, and TODO comments failing because nothing prompts anyone to view them [S2-06]. Preference and performance diverging means user taste should not be the only evidence for a re-entry layout.

**P10: Hand off in fixed fields chosen from observed omissions, with a contingency and a receiver check-back, as part of a bundle.** Moderate for what gets transmitted, Weak for patient or project outcomes. The I-PASS elements were chosen from what observers found missing in real handoffs (illness severity, contingency planning, receiver read-back), and the authors describe the SBAR format as best for briefings of fewer than five key points and limited for complex cases, which is the case that resembles a project handoff [S2-08]. The original study used a bundle (mnemonic, training, faculty observation, sustainability campaign), cut medical errors 23% and preventable adverse events 30%, raised inclusion of the prespecified key elements in 14 of 14 comparisons, left oral handoff duration unchanged (2.4 versus 2.5 minutes), and was significant at only six of nine sites [S2-09]. A 32-hospital implementation with 18 months of external coaching raised full five-element inclusion from 20% to 66% (verbal) and 10% to 74% (written), contingency plans from 29% to 78%, receiver synthesis from 31% to 83%, and reported adverse events fell 47% [S2-10]. The cautions are real: a 2025 systematic review rated I-PASS as moderate certainty, noted the two randomized trials found no significant clinical outcome effect, and found nearly all evidence in academic physician training [S2-04]; an orthopaedic implementation sustained handoff quality for 18 months with no significant change in readmissions or infections [S2-05]; and a systematic review of 36 handoff-tool evaluations found rigor varied enough to limit what it could say [S2-01]. An emergency-department adaptation shows the fields need local tailoring, with staff asking for an anticipated-disposition field [S2-03].

**P11: Every name routes to a next move, written as an if-then, problem beside counter-move.** Moderate for the mechanism, Weak for any one-page format. Emotion differentiation correlates with less dysregulated behavior at only r = -0.15 across 17 studies [C2-11] and seems to work by improving how a chosen strategy is used rather than which is chosen [C2-05]; naming before reappraising made people feel worse in two experiments [C2-10] and a 2026 replication found no delayed benefit [C2-02]. If-then planning is the best-supported ingredient, with raw effects of d = 0.27 to 0.66 shrinking to 0.15 to 0.35 after bias correction [C3-09]. Comparing cases beat single cases at d = 0.50 [C3-01], and error-management training reached d = 0.44 [C3-10]. A one-page three-zone state map that pairs each zone with symptoms and actions is the institutional exemplar of the format and carries no outcome data [C3-14]. Applied to project states, "stale" or "blocked" is a handle and the sheet earns its keep only if the label routes to a response.

**P12: Put cues where the work is, keep them few and distinct.** Moderate for the mechanism, Theory-only for adult ADHD. Recognition costs less than recall, which is the sixth usability heuristic [C1-10]. Children with ADHD showed central-executive working-memory deficits of d = 1.63 to 2.03 [C1-08], mild uncontrollable stress rapidly impairs prefrontal working memory [C4-01], and Barkley frames the problem as failing to use known information at the point of performance [C4-02]. Offloading depends on beliefs about one's own memory, not only on capacity [C4-09]. For distinctness, Few says only position and length encode quantity accurately [C1-04], the command-line guidelines warn that color means nothing if everything is colored [S1-04], and one research group reports the picture advantage vanished against typographically distinctive words, a live debate [C1-07]. No card tests point-of-performance cues in adult ADHD.

**P13: Keep it small, owned, non-duplicative, and labelled as a heuristic.** Moderate. Passive psychoeducation pooled to d = 0.20 (95% CI 0.01 to 0.40) from four RCTs [C3-05], and in a skills-component trial the taught and practiced skill, not the handout, was the active ingredient [C3-12]. Fourcade's audit of 1,440 procedures found 90.2% compliance but 61% completion, with duplication of existing checklists the top barrier in 16 of 18 centers [C1-05]; focus groups warned that "checklist fatigue" blocks a better list later [C1-11]; the mandated rollout in 101 Ontario hospitals saw mortality OR 0.91 (95% CI 0.80 to 1.03) [C1-12], and the originators themselves concede mandated use "may encourage box-ticking" [C1-14]. Diagrams are heuristics, not measurements: the window-of-tolerance chart is a trauma-clinic model [C3-04], the inverted-U arousal curve has been called folklore [C3-03], and the Four Horsemen's 93% divorce prediction was in-sample and failed to replicate [C3-07; C3-11]. A vocabulary should be built from the audience's own failures: the two programmer precedents (11 frustration categories, 6 learning barriers) came from observation, and nobody has tested whether showing the list helps [C2-04; C2-06].

| # | Strength |
|---|----------|
| P1 | Moderate (text) / Weak (layer cap) |
| P2 | Moderate |
| P3 | Weak to Moderate, contested |
| P4 | Strong (lab null) / unresolved (field) |
| P5 | Weak, contested |
| P6 | Weak to Moderate |
| P7 | Moderate |
| P8 | Moderate |
| P9 | Moderate |
| P10 | Moderate (content) / Weak (outcomes) |
| P11 | Moderate (mechanism) / Weak (format) |
| P12 | Moderate (mechanism) / Theory-only (ADHD) |
| P13 | Moderate |

- **P1** — Principle: Conclusion first, detail on request, two layers; Core cards: S3-12, S3-13, S3-16, S3-03, S1-04
- **P2** — Principle: One message, few groups, no decoration; Core cards: C1-01, C1-02, C1-09, C1-03, S1-06
- **P3** — Principle: Size the set to the task; Core cards: S3-15, S3-02, S3-05, S3-08, S3-18, S3-14
- **P4** — Principle: No decision-fatigue justification; Core cards: S3-07, S3-17, S3-04, S3-06, S3-11, S3-01
- **P5** — Principle: Recommended default: label it, show why; Core cards: S3-09, S3-10, S3-14
- **P6** — Principle: Frame and comparison; intentional blank; Core cards: S1-06, S1-08, S1-04, S1-10
- **P7** — Principle: Interrupt only urgent and actionable; budget; Core cards: S1-01, S1-07, S1-09, C4-06, C4-08, C4-05, C4-07, C4-11, S2-06
- **P8** — Principle: Display plus action; measure outcomes; Core cards: S1-11, S1-02, S1-03, S1-05
- **P9** — Principle: Re-present context; cue at departure; Core cards: S2-02, S2-07, S2-06
- **P10** — Principle: Fixed handoff fields from observed omissions, as a bundle; Core cards: S2-08, S2-09, S2-10, S2-04, S2-05, S2-01, S2-03
- **P11** — Principle: Name routes to if-then next move; Core cards: C2-11, C2-05, C2-10, C2-02, C3-09, C3-01, C3-10, C3-14
- **P12** — Principle: Cues at point of work, few and distinct; Core cards: C1-10, C1-08, C4-01, C4-02, C4-09, C1-04, S1-04
- **P13** — Principle: Small, owned, non-duplicative, heuristic; Core cards: C3-05, C3-12, C1-05, C1-11, C1-12, C1-14, C3-03, C3-04, C3-07, C3-11, C2-04, C2-06

### 3.2 Which principles bind at which moment

A filled circle means the principle is a hard constraint at that moment; an open circle means it applies more softly or by implication.

| Principle | M1 | M2 | M3 | M4 | M5 | M6 |
|---|---|---|---|---|---|---|
| P1 Conclusion first, two layers | ● | ● | ● | ● | ○ | ○ |
| P2 One message, few groups | ● | ● | ● | ○ | ● | ● |
| P3 Size the set to the task | ○ | ● |  |  |  |  |
| P4 No decision-fatigue justification | ○ | ● |  |  |  |  |
| P5 Label the recommendation, show why |  | ● | ○ |  |  |  |
| P6 Frame, comparison, intentional blank | ● |  |  |  |  | ○ |
| P7 Interrupt budget | ○ |  | ○ | ● |  | ● |
| P8 Display plus action; outcomes | ● | ○ |  |  |  | ● |
| P9 Re-present context; cue at departure |  |  | ● | ● | ● |  |
| P10 Fixed handoff fields |  |  | ○ |  | ● |  |
| P11 Name routes to if-then move |  | ○ | ○ | ● |  | ● |
| P12 Cue at the point of work | ○ |  | ○ | ● |  | ○ |
| P13 Small, owned, heuristic | ○ | ○ | ○ | ○ | ● | ○ |

Moments: M1 Glance, M2 Next move, M3 Re-enter, M4 Plan vs do, M5 End / hand off, M6 Going wrong.

### 3.3 The six moments, one at a time

**M1, the glance (status at rest across about twenty projects).** What binds hardest is P1, P2, P6 and P8. A design must satisfy: the first display answers one question (does anything need me, and what), carries the frequently needed facts, and shows each fact with a comparison (since when, versus what) rather than a bare number [S1-06]; at most two alert types, because everything-colored means nothing [S1-04; S1-06]; an empty state that is visibly intentional and distinguishable from a stale or failed sweep (inference from S1-08 and S1-04); and a pointer to the action each item implies, because the display alone is the weakest-supported piece [S1-11; S1-02]. Evidence strength for this moment is the thinnest of the six: one practitioner white paper, one anecdote, one small team study, and the negative dashboard trials. Testable cheaply: does the user ever open the detail, and how long until the first action after looking.

**M2, choosing what to do next.** P3, P4, P5 bind hardest, with P1 and P2. The evidence asks for a small set, varied rather than near-duplicate [S3-18], because this moment meets the conditions under which overload shows up (hard task, unsure preference, effort-minimizing goal) [S3-02]; a recommended move that is labelled as a recommendation with its reason, since people trust it by default and feel its misses [S3-14] and since its authority comes from being read as endorsement [S3-09]; and no appeal to depletion as the justification [S3-07; S3-17]. Whether a single move beats a ranked few is a gap: no primary study of exactly one was found (S3 search log). Testable cheaply: adoption rate of the recommendation, and whether it matters if the list shows one, three or five.

**M3, re-entering a project.** P9 binds hardest, with P1 and P2. The requirement is that the last context is shown automatically at the moment of return and not behind a command [S2-07; S2-06]; the content is activity-shaped (what was last done, in order) as well as authored notes, since the cue beat notes alone at twice the success [S2-07]; and the layout is chosen by task performance and not by stated taste [S2-07]. Evidence strength is Moderate and comes from programmers, the best-matched population in the corpus. Testable cheaply: time from session start to first edit with and without the injected context, the same measure the programmer studies used.

**M4, switching between planning and doing.** P7, P9, P11, P12 bind hardest, with P1. This is the moment with the thinnest direct evidence; no card studies a plan-to-execute mode switch. What applies by inference: an overview-plus-detail split costs mental effort to integrate [S3-03]; interruption cost is highest mid-edit and lowest at breakpoints [S2-06], so push belongs at breakpoints and not inside a working stretch; a cue set just before leaving a task reduces the lag on return [S2-02]; and the guidance for acting should be an if-then plan [C3-09], placed where the work happens [C4-02]. Testable cheaply: whether alerts raised mid-edit are dismissed more often than those at breakpoints, from hook logs.

**M5, ending and handing off a session.** P10 and P9 bind hardest, with P2 and P13. The handoff wants fixed fields, few, chosen from what past checkpoints left out and not from convention [S2-08]; one field for the contingency ("if X, then Y") and one for what the next reader should confirm, the two elements that moved most in the 32-hospital study [S2-10]; a format that does not lengthen the task, which the original study showed was possible [S2-09]; and no mandate or duplication, since the checklist evidence says duplicated and mandated artifacts are skipped or ticked [C1-05; C1-12; C1-14]. What is claimed here is narrow: the format changed what was transmitted; the clinical-outcome evidence is mixed and the format worked inside a bundle [S2-04; S2-09]. Testable cheaply: field-inclusion rate across checkpoints, which is a process measure available from the files themselves.

**M6, something going wrong.** P7, P8, P11 bind hardest, with P2. An alert has to pass the test of urgent, actionable and not a repeat [S1-07; S1-01]; a rote response is automated, not paged [S1-07]; the message pairs what went wrong with the counter-move [C3-01; C3-10], in a vocabulary small enough to learn and built from the user's own recurring failures [C2-04; C2-06]; and the rate is counted [S1-09]. A caution from the corpus: silent failure with a reassuring message is the opposite error from alert flooding, and a status that says nothing is only safe if it can be told apart from a status that broke (inference). Testable cheaply: alerts per day, fraction acted on, fraction repeated.

### 3.4 Boundary conditions and how this compares

Almost every effect size here comes from a population unlike a solo developer: hospital teams, shoppers, students, controllers, web readers, children with ADHD, trauma patients. The principles hold together across those populations, which earns modest confidence and no more. As frameworks go, this one sits closest to the situation-awareness and alarm-management tradition (Endsley, EEMUA) for M1 and M6, the interruption-and-resumption tradition for M3 and M4, the handoff-bundle tradition for M5, and the job-aid and just-in-time-prompt traditions for the rest. It differs from them by being organized around *when the tool speaks* and not around a single technique. The classic job-aid handbook (Rossett and Gautier-Downes), the alarm standards (EEMUA 191, ISA-18.2) and Endsley's primary SA papers were paywalled and are not a basis for any claim here (§6, paywalled).

---

## 4. Analysis

### 4.1 How much, and how many layers? (Track S3, with C1)

**Research question:** how much information should a surface carry, and how should it be layered?

**What the evidence says.** Writing concise, scannable and objective measurably helped web readers [S3-12]; two layers is the practitioner ceiling [S3-13]; overview-then-detail is a taxonomy [S3-16] and a reviewed interface family with a known integration cost [S3-03]; and the command-line guidelines favor less output by default [S1-04]. For option count, the original jam result [S3-08] sits against a near-zero pooled mean [S3-15], a conditional-effect reading [S3-02], and a power critique [S3-05].

**Where sources agree.** Put what is frequently needed on the first display, strip decoration, group small [S3-13; C1-01; C1-02; C1-09].

**Where sources disagree.** Whether cutting options helps at all. Scheibehenne finds no general effect; Chernev finds an effect once moderators are included; Dean argues the tests lack power. The summary is that "choice overload exists in general" is unproven and "choice overload exists under named conditions" is supported, and a next-move choice meets those conditions. A second dispute is silence: the command-line guidelines want output on success so quiet does not read as hung [S1-04], while a household-dashboard author found the blank state the winning design [S1-08].

**What's missing.** No primary study of a single recommendation against a ranked few. No terminal-specific study of layering. The government plain-language doctrine and military conclusion-first guidance were not retrieved because the web-search budget ran out (§6). Eppler and Mengis's canonical overload review was abstract-only.

**Institutional vs. ground truth.** The Nielsen findings are 51 web readers, and Few warns the user must already hold a domain mental model, which this user does. The best-known vivid story, the jam stall, is the origin of "fewer is better" and is now the weakest-replicated piece of it.

### 4.2 Choosing and deciding: fatigue, defaults, recommendations (Track S3)

**Research question:** is "decision fatigue" a valid reason to limit what borg shows, and does a recommended default help?

**What the evidence says.** The lab willpower-battery effect is near zero in the two largest preregistered tests [S3-07; S3-17]; the famous field example was likely an artefact [S3-06]; the healthcare field literature is split (45% of tested cases) and uses an inconsistent definition [S3-11]; and a 2025 multi-lab paper recovers a small effect only after 30 to 40 minutes of intense exertion [S3-04]. Defaults are larger in meta-analysis than in bias-corrected nudging analysis [S3-09; S3-10].

**Where sources agree.** That the original ego-depletion headline overstated the effect, and that defaults work more when read as endorsement.

**Where sources disagree.** Whether any real depletion remains (Dang says yes under intense exertion; Hagger and Vohs say effectively no), and whether nudges survive correction for publication bias (Maier says no evidence overall; Jachimowicz reports d = 0.68 with wide variation). Maier's undecided category, "structure", contains defaults, so the two sources are not strictly opposed.

**What's missing.** Nothing studies a developer choosing among their own projects. The primary organ-donation default study (Johnson and Goldstein 2003) and the primary parole study (Danziger 2011) were paywalled or blocked, and the Szaszi rebuttal to Maier 2022 was not searched for because of the search budget.

**Institutional vs. ground truth.** "Decision fatigue" is the stock justification for trimming interfaces, and the primary-source work behind it is the most-corrected result in this corpus.

### 4.3 Status at rest and interrupts (Track S1, with C4)

**Research question:** what makes a status display useful at a glance, and when should a tool interrupt?

**What the evidence says.** A practitioner paper gives display rules built on the three SA levels [S1-06]; a meta-analysis shows the SA-to-performance link is weak [S1-02]; a systematic review shows standalone dashboards are not shown to change decisions [S1-11]; alert-rate evidence from clinical, process-control and site-reliability settings agrees that volume and repeats degrade response [S1-01; S1-07; S1-09; C4-06]; and two trials in adults with ADHD show that plain reminders and a liked app did nothing [C4-05; C4-08].

**Where sources agree.** Reserve interruption for the urgent and actionable; repeats and volume are the enemy; context beats bare numbers.

**Where sources disagree.** Whether SA is a valid construct at all [S1-03; S1-05], and whether alert fatigue involves habituation over time (Ancker found none, only repeat-driven loss) or just volume. On timing, the just-in-time framework favors well-timed prompts [C4-07] while its own audit says the decision rules are unsupported [C4-11].

**What's missing.** Glanceability research (the one candidate source had no findings in its abstract), terminal-specific information design (the command-line guidelines are the only source and say so), cumulative flow and burn-chart comprehension (no evidence found), and the primary alarm-rate documents (EEMUA 191, ISA-18.2, the HSE report), all paywalled or unretrievable.

**Institutional vs. ground truth.** The EEMUA bands read like thresholds; the benchmark paper that reports them calls them "devoid of context" and says no single fix reaches them. The site-reliability claim that a human can react with urgency only "a few times a day" is practitioner experience with no cited trial.

### 4.4 Re-entry and handoff (Track S2)

**Research question:** what helps a person resume interrupted work, and what makes a handoff transmit what matters?

**What the evidence says.** Resumption is slow and cue-dependent [S2-02; S2-06; S2-07], and handoff formats change what is transmitted [S2-08; S2-09; S2-10].

**Where sources agree.** Cues at return, and cues set at departure, shorten resumption; chosen fields raise the inclusion of what matters; the format does not cost time [S2-09].

**Where sources disagree.** Whether handoff scripts improve outcomes or only process. The 2025 systematic review rates I-PASS moderate certainty while noting both randomized trials were null on clinical outcomes [S2-04]; the orthopaedic study improved quality and not outcomes [S2-05]; the original NEJM study had significant error reductions at six of nine sites [S2-09]. Because the intervention was a bundle, the script cannot be credited alone. A second dispute sits in the paywalled ethnographies of handover as ritual, which I could not read.

**What's missing.** Field evidence for the cross-team case (95% of tool evaluations were within one department [S2-01]); the Iqbal and Horvitz field study of task recovery; the full Parnin and Rugaber strategy analysis. No card studies a handoff to a future self or to an AI agent, which is the actual borg case.

**Institutional vs. ground truth.** The institutional literature (a Making Healthcare Safer review) grades the evidence plainly as moderate and mostly pre-post [S2-04]. Frontline voices wanted brevity and an extra field [S2-03]. For developers, the preference-versus-performance split in the resumption study is the closest thing in the corpus to ground truth contradicting a design intuition [S2-07].

### 4.5 The one-page sheets: naming, scripts, diagrams (Tracks C1 to C3)

**Research question:** which features of the first run's one-page psychoeducational sheets (a feelings wheel, a wise-mind Venn diagram, a parts map, a four-slot speaking script, a state map, a problem-and-antidote list) carry over to project communication?

**What the evidence says.** The sheets themselves are unproven as sheets: no evaluation of the feelings wheel was found, the parts-map therapy has a very small trial base (its one RCT tested a nine-month package), the speaking-script trial changed empathy and not stress, the state chart is a trauma hypothesis, and the problem-list prediction figures were in-sample and failed to replicate [C2-01; C2-03; C2-12; C3-13; C3-04; C3-07; C3-11]. The design principles underneath are better supported than the sheets: one message, subtraction, text plus diagram, contrasting pairs, if-then phrasing, and recognition over recall [C1-01; C1-09; C3-01; C3-09; C1-10]. Effects are modest: g = 0.37 for multimedia, d between 0.15 and 0.35 for corrected if-then planning, d = 0.20 for passive handouts [C1-09; C3-09; C3-05].

**Where sources agree.** Small groups, no decoration, a modest handout effect, practice beats a sheet [C1-02; C3-05; C3-12].

**Where sources disagree.** Whether naming regulates [C2-14 versus C2-10, C2-02]; whether pictures work through dual coding or distinctiveness [C1-13 versus C1-07]; whether mandated checklists save lives [C1-06 versus C1-12, with C1-14 explaining the gap as local implementation]. The pooled labelling estimate (a preprint, not peer reviewed) is g = -0.49 on physiology but only -0.23 in labs independent of the originators [C2-15].

**What's missing.** Rossett's fit criteria for job aids; the Willcox 1982 origin paper; the cross-validation critique of the problem-list prediction. No study of a one-page aid with developers.

**Institutional vs. ground truth.** The CDC guide offers 20 binary items and a pass mark of 90, and says itself that it cannot replace pretesting [C1-01]. Staff using the surgical checklist completed 61% of it while 90.2% of procedures counted as compliant [C1-05].

### 4.6 The ADHD strand (Track C4, with parts of C1 to C3)

The ADHD evidence is a supporting strand, not the frame. What it adds is a reason to expect the penalty for violating the general principles to be higher for this user, not a different set of principles. Children with ADHD show large central-executive working-memory deficits [C1-08], emotion dysregulation is common and its status as a core feature is debated [C4-04; C4-10], acute stress degrades prefrontal function [C4-01], and the theory that information must sit outside the head at the point of performance is Barkley's [C4-02] and Risko and Gilbert's offloading account [C4-09]. Against that theory sit two null trials of reminders and an app in adults [C4-05; C4-08], and a review calling just-in-time timing rules unsupported [C4-11]. If-then plans lifted inhibition in ADHD children to the non-ADHD level [C3-06]. No card tests any of this on adults with ADHD in knowledge work, and no first-hand developer or ADHD account cleared the credibility bar. So the strand supports P7 and P12 as expectations and nothing more.

### 4.7 The strongest negatives

- **Better situational awareness means better decisions** — Strongest evidence against: Mean r = 0.26, plausible range -0.15 to 0.60, 678 effects; Source: [S1-02]; Reading: Use SA as a checklist for what to show; measure outcomes
- **A dashboard changes behavior** — Strongest evidence against: 11 RCTs: conflicting or null for standalone dashboards; Source: [S1-11]; Reading: Couple display to action
- **Willpower drains as you decide** — Strongest evidence against: d = 0.04 (23 labs); d = 0.06 (36 labs); Source: [S3-07; S3-17]; Reading: Do not use depletion to justify limits
- **The hungry judge shows decision fatigue** — Strongest evidence against: Implied d = 1.96; reproduced by a rational-judge simulation; Source: [S3-06]; Reading: Treat the story as an artefact
- **Fewer options always helps** — Strongest evidence against: Pooled mean about zero over 63 conditions; Source: [S3-15]; Reading: Condition the cap on task difficulty [S3-02]
- **Nudges and defaults are reliable levers** — Strongest evidence against: No evidence overall after publication-bias correction; Source: [S3-10]; Reading: Defaults are plausible, size unknown [S3-09]
- **A handoff script saves outcomes** — Strongest evidence against: Two RCTs null on clinical outcomes; orthopaedic null; Source: [S2-04; S2-05]; Reading: The script is one part of a bundle
- **Reminders and apps fix adherence** — Strongest evidence against: SMS reminders no effect; app trial null; Source: [C4-08; C4-05]; Reading: Default to pull
- **Checklists work when mandated** — Strongest evidence against: Ontario OR 0.91 (CI 0.80 to 1.03); Source: [C1-12]; Reading: Do not mandate
- **A handout teaches** — Strongest evidence against: Passive psychoeducation d = 0.20; Source: [C3-05]; Reading: Rehearsal carries the weight
- **Naming a feeling regulates it** — Strongest evidence against: Naming before reappraisal made people feel worse; Source: [C2-10; C2-02]; Reading: Pair every name with a next move

### 4.8 Bias-guard note and the steel-man

The agree-to-disagree ratio is 5 to 7, far under 3 to 1, so the confirmation-skew gate does not fire and a steel-man is not required. I include one anyway because the thesis of this report is more cautious than most design advice, and the most useful objection comes from the opposite side.

### Steel-man the contrarian

The strongest case against everything above is that communication design is the wrong lever for a single expert user who wrote the tool. This user already holds the domain model that Few says a display cannot supply [S1-06]; they chose the projects, know their history, and can tell a blank from a failure by habit. For that person, an interrupt budget, a freshness mark and a handoff template are friction they must also maintain, and the same evidence that says "duplication is the top barrier" [C1-05] says an extra structure is a cost in itself. The hospital evidence arrives with coaching, observation and a training campaign, none of which a one-person tool has [S2-09; S2-10]. The dashboards and SA literature do not show that better displays help even experts [S1-02; S1-11]. One more point cuts against the project: much of what looks like a communication problem may be a prioritization problem, which is the other research thread's territory (#252 and #262). Taken charitably, this is an argument to ship the smallest change, instrument it, and let the logs decide, which is where recommendation 14 already points. What it does not rebut is the narrower, better-supported claims: conclusion first, interrupt restraint, and returning the user's own last context, all of which cost the user nothing to maintain.

### 4.9 Cross-cutting tensions and gaps

Three collisions are worth stating. First, "show less" collides with "silence reads as hung"; the reconciling reading (inference) is a quiet standing display with a freshness mark and a confirming command. Second, "name the state" collides with the evidence that naming alone can backfire; the reconciliation is to name in step one and attach a matched action in step two on the same surface. Third, "recommend one move" collides with "no study tested exactly one"; the evidence favors a small diverse set and a labelled recommendation, and leaves one-versus-few as an open, cheaply testable question. The gaps, in priority order: no direct observation of any principle on a developer with many projects; no primary study of a plan-to-execute mode switch (M4); no evidence on handoffs to a future self or an AI agent (M5); thin ground-level voices; and a search budget that cut off several planned falsification and corroboration queries (§6).

---

## 5. Research

Format: **Author year** [ID] [band | evidence level]. Band is keep, borderline or reject; evidence level is 1 to 9 (1 = systematic review or meta-analysis, 2 = RCT or controlled experiment, 3 = large observational or lab experiment, 4 = expert consensus or professional body, 5 = practitioner case study or mixed methods, 6 = qualitative, 7 = expert opinion or narrative review, 8 = anecdote, 9 = marketing). Tracks C1 to C4 are the first run; S1 to S3 are the re-scoped run. All 93 included sources appear below.

### Track C1: job aids and visual design (14 sources)

- **CDC 2019** [C1-01] [borderline | L4]. Twenty zero-or-one items, 90 or higher passes; one main message in 1 to 3 sentences; split lists longer than seven; the guide says it cannot replace pretesting.
- **Cowan 2001** [C1-02] [keep | L7]. Capacity is about four chunks once rehearsal and recoding are controlled; Miller's seven was "a rhetorical device".
- **de Jong 2010** [C1-03] [keep | L7]. Cognitive load theory's premise (limited working memory) stands, but its conceptual and methodological issues make it a heuristic.
- **Few 2004** [C1-04] [borderline | L7]. Pre-attentive attributes make one thing stand out; only position and length encode quantity accurately.
- **Fourcade 2012** [C1-05] [keep | L5]. 90.2% compliance but 61% completion across 18 centers; duplication the top barrier.
- **Haynes 2009** [C1-06] [keep | L3]. Death 1.5% to 0.8% and complications 11.0% to 7.0% in 8 hospitals; no concurrent control.
- **Higdon 2025** [C1-07] [keep | L2]. Picture advantage eliminated against distinctive words; dual coding "no longer a viable explanation".
- **Kofler 2020** [C1-08] [keep | L3]. Central-executive working-memory deficits of d = 1.63 to 2.03 in ADHD children; covary with symptom severity.
- **Mayer-corpus meta-analysis 2025** [C1-09] [keep | L1]. g = 0.37 overall; text plus diagrams large and consistent; seductive-detail removal largest.
- **Nielsen Norman Group** [C1-10] [borderline | L7]. Recognition rather than recall; show options instead of asking users to remember them.
- **Thomassen 2010** [C1-11] [borderline | L6]. Focus groups: checklist fatigue, attention diverted, scope creep of the sheet, a champion "crucial".
- **Urbach 2014** [C1-12] [keep | L3]. Mortality OR 0.91 (95% CI 0.80 to 1.03) after mandated adoption in 101 hospitals.
- **Wang and Voss 2021** [C1-13] [keep | L1]. 48 of 56 studies supported pictographs; need validation with the target audience.
- **Weiser and Haynes 2018** [C1-14] [borderline | L7]. Originators concede box-ticking and failed mandates; thoughtful local implementation works.

### Track C2: naming and vocabulary (15 sources)

- **Alexithymia Awareness Network (Willcox wheel)** [C2-01] [borderline | L7]. Origin 1982; vocabulary scaffold from broad to specific words; the page itself claims no effectiveness.
- **Ariely 2026** [C2-02] [keep | L2]. Labeling reduced reappraisal's effectiveness, N = 226; no delayed benefit at 1 to 2 days.
- **Brownstone 2024** [C2-03] [borderline | L7]. IFS evidence "strikingly small"; use has expanded beyond it.
- **Ford and Parnin 2015** [C2-04] [borderline | L6]. 45 developers, 67% severe frustration, 11 cause categories.
- **Kalokerinos 2019** [C2-05] [keep | L3]. Low differentiators use the same strategies less effectively; strategy choice unaffected.
- **Ko, Myers and Aung 2004** [C2-06] [borderline | L6]. Six learning barriers, each implying a different remedy.
- **Moser et al. 2017** [C2-07] [keep | L3]. Third-person self-talk lowered self-referential reactivity without recruiting cognitive control.
- **Lieberman 2007** [C2-08] [keep | L3]. Labeling diminished amygdala response; right ventrolateral prefrontal cortex activity rose.
- **Matt, Seah and Coifman 2024** [C2-09] [keep | L2]. Brief word training had no direct effect on differentiation or distress; exploratory benefits for high engagement.
- **Nook 2021** [C2-10] [keep | L2]. Naming before reappraising left people feeling worse (N = 80, replicated N = 60).
- **Seah and Coifman 2022** [C2-11] [keep | L1]. Pooled r = -0.15 across 17 studies; shrinks to -0.09 controlling for negative affect.
- **Shadick 2013** [C2-12] [keep | L2]. IFS RCT in rheumatoid arthritis (N = 79): gains in pain and function; feasibility only.
- **Thompson, Springstein and Boden 2021** [C2-13] [keep | L7]. Differentiation's definition and measurement diverge.
- **Torre and Lieberman 2018** [C2-14] [borderline | L7]. Labeling as implicit regulation; boundary conditions unknown.
- **Wahba 2026** [C2-15] [borderline | L1 as labelled, not peer reviewed]. Pooled g = -0.49 for physiology; -0.23 in independent labs; self-corrected; hypothesis-generating only.

### Track C3: scripts, state maps, problem/antidote pairing, psychoeducation (14 sources)

- **Alfieri 2013** [C3-01] [keep | L1]. Case comparison d = 0.50 (95% CI 0.44 to 0.56) over single-case presentation.
- **Winston 2026 (Brighter coaching blog)** [C3-02] [borderline | L7]. Pick one or two prompts, smallest version, dread rating, review without pass or fail.
- **Corbett 2015** [C3-03] [borderline | L7]. Yerkes-Dodson inverted-U "has no basis in empirical fact".
- **Corrigan, Fisher and Nutt 2011** [C3-04] [borderline | L7]. Window of tolerance as a proposed model of trauma effects; mechanisms "proposed".
- **Donker 2009** [C3-05] [keep | L1]. Passive psychoeducation d = 0.20 (95% CI 0.01 to 0.40), 4 RCTs.
- **Gawrilow and Gollwitzer 2008** [C3-06] [borderline | L2]. If-then plans lifted inhibition in ADHD children to the non-ADHD level; additive to medication.
- **Gottman and Levenson 2000** [C3-07] [borderline | L3]. 93% in-sample divorce prediction; four negative codes distinguished early divorce; 79 couples, 21 divorces.
- **Rogers et al. 2018** [C3-08] [borderline | L2]. I-language plus acknowledging the other's view lowered perceived hostility; vignettes.
- **Sheeran, Listrom and Gollwitzer 2025** [C3-09] [keep | L1]. 642 tests; raw d = 0.27 to 0.66; bias-corrected d = 0.35 and 0.15.
- **Keith and Frese 2008** [C3-10] [keep | L1]. Error-management training d = 0.44 across 24 studies; adaptive transfer d = 0.80.
- **Kim, Capaldi and Crosby 2007** [C3-11] [keep | L3]. Gottman affective-process findings failed to replicate in 85 at-risk couples.
- **Linehan 2015** [C3-12] [keep | L2]. DBT with skills training beat DBT without it (99 women, high suicide risk).
- **Park et al. 2025** [C3-13] [borderline | L2]. NVC course plus journal: empathy and relationships up, stress and resilience unchanged.
- **Pennsylvania DHS 2024** [C3-14] [borderline | L4]. One-page three-zone chart with symptoms and actions per zone; no outcome data.

### Track C4: in-the-moment use with ADHD (11 sources)

- **Arnsten 2009** [C4-01] [keep | L7]. Mild uncontrollable stress rapidly impairs prefrontal working memory; mostly animal evidence.
- **Barkley (fact sheet)** [C4-02] [borderline | L7]. ADHD as failure to use known information at the point of performance; externalize information and motivation.
- **CHOP 2023** [C4-03] [keep | L4]. No agreed definition of executive functions; working memory defined; hot versus cool executive functions.
- **Faraone et al. 2019** [C4-04] [keep | L4]. Emotional symptoms common and persistent in ADHD; core status debated.
- **Carvalho et al. 2023** [C4-05] [keep | L2]. 73 adults, FOCUS app: no adherence difference despite favorable usability.
- **Gani et al. 2025** [C4-06] [keep | L1]. Alert fatigue linked to frequency, presentation and accuracy; 9 studies.
- **Nahum-Shani et al. 2018** [C4-07] [keep | L7]. Six JITAI elements; receptivity; unsolicited support when not receptive can harm.
- **Nordby et al. 2022** [C4-08] [keep | L2]. SMS reminders had no effect on completion, logins or practice in adults with ADHD.
- **Risko and Gilbert 2016** [C4-09] [keep | L7]. Offloading is driven by beliefs about internal capacity; not ADHD-specific.
- **Shaw et al. 2014** [C4-10] [keep | L1]. Emotion dysregulation prevalent across the ADHD lifespan; the field lacks consensus on its core status.
- **van Genugten et al. 2025** [C4-11] [keep | L1]. Five mental-health JITAIs found; receptivity and decision-rule evidence missing.

### Track S1: status displays and situational awareness (11 sources)

- **Ancker 2017** [S1-01] [keep | L3]. Each extra reminder per encounter cut acceptance by 30%; repeats, not workload, drove it; no desensitization over time.
- **Bakdash 2021** [S1-02] [keep | L1]. 678 effects from 77 papers: SA predicts performance at r = 0.26 (range -0.15 to 0.60).
- **Carsten and Vanderhaegen 2015** [S1-03] [borderline | L7]. Editorial laying out the circularity critique, the context-dependence critique and Endsley's rebuttal.
- **clig.dev** [S1-04] [borderline | L7]. Only terminal-design source: err on the side of less, show state and the next command, color sparingly; design hypotheses, not evidence.
- **Endsley (SAGAT)** [S1-05] [borderline | L7]. Primary-author statement of the freeze-and-query SA measure; element perception falls as display load rises (abstract only).
- **Few 2007** [S1-06] [borderline | L7]. Translates the three SA levels into display rules: context beside numbers, alert restraint, history for projection.
- **Google SRE** [S1-07] [borderline | L5]. Alert test of urgent, actionable and user-visible; a human reacts with urgency a few times a day; automate rote pages.
- **Hawksley 2026** [S1-08] [borderline | L8]. Anecdote: a status corner that stays blank when nothing needs attention, on a read-only display. Marginal keep; hypothesis weight only.
- **Reising and Montgomery 2005** [S1-09] [borderline | L3]. Alarm-rate bands across 37 consoles; the authors call the numbers devoid of context.
- **Rodrigues 2026** [S1-10] [borderline | L6]. 13-person team: perceived communication rose after Kanban, credited to visibility and a standard card structure; one setting.
- **Xie 2022** [S1-11] [keep | L1]. 11 RCTs: standalone dashboards gave conflicting or null effects; multicomponent programs did better.

### Track S2: re-entry, resumption and handoff (10 sources)

- **Abraham 2013** [S2-01] [keep | L1]. 36 handoff-tool evaluations; rigor varied enough to limit standardization advice; 95% intra-departmental.
- **Altmann and Trafton 2004** [S2-02] [keep | L2]. Resumption lag 3.8 s versus 1.9 s; cues present just before the interruption reduce it.
- **Heilman 2016** [S2-03] [borderline | L6]. Frontline focus groups endorsed the elements, wanted brevity and an anticipated-disposition field; usability, not effectiveness.
- **Making Healthcare Safer IV 2025** [S2-04] [keep | L1]. I-PASS moderate certainty, SBAR low; two I-PASS RCTs null on clinical outcomes; evidence mostly physician training.
- **Orthopaedic I-PASS 2022** [S2-05] [borderline | L3]. Handoff quality improved for 18 months; no significant change in readmissions or infections (1,984 patients).
- **Parnin 2013** [S2-06] [borderline | L7]. 10 to 15 minutes to resume editing; 10% within a minute; TODO comments fail without a prompt to view them.
- **Parnin and DeLine 2010** [S2-07] [keep | L2]. Automated activity cues doubled task success over note-taking alone; preference and performance diverged.
- **Starmer 2012** [S2-08] [borderline | L7]. Fields chosen from what real handoffs omitted; SBAR fits briefings under five points, not complex cases.
- **Starmer 2014** [S2-09] [keep | L3]. A bundle: errors down 23%, preventable adverse events down 30%, key-element inclusion up, handoff time unchanged; six of nine sites significant.
- **Starmer 2022** [S2-10] [keep | L3]. 32 hospitals with 18 months of coaching: key-element inclusion 20% to 66% (verbal), receiver synthesis 31% to 83%, reported events down 47%.

### Track S3: amount and layering (18 sources)

- **Arnold 2023** [S3-01] [keep | L1]. 87 papers on overload prevention and intervention; evidence for interventions mixed.
- **Chernev 2015** [S3-02] [keep | L1]. Four moderators (set complexity, task difficulty, preference uncertainty, effort-minimizing goal) govern overload.
- **Cockburn 2008** [S3-03] [keep | L1]. Combined views can beat single views, task-dependent, no clear guidelines, integration costs mental effort.
- **Dang 2025** [S3-04] [keep | L2]. 14 samples: small depletion effect, but only after 30 to 40 minutes of intense exertion.
- **Dean, Ravindran and Stoye** [S3-05] [keep | L3]. Argues usual tests are underpowered, so overload may be under-reported; preprint.
- **Glockner 2016** [S3-06] [keep | L3]. Original effect implies d = 1.96; a rational-judge simulation reproduces it.
- **Hagger 2016** [S3-07] [keep | L2]. 23 labs, N = 2,141: d = 0.04, CI -0.07 to 0.15.
- **Iyengar and Lepper 2000** [S3-08] [keep | L2]. Origin of "fewer options": 6 beat 24 or 30 on purchase and satisfaction; later meta-analysis found the mean near zero.
- **Jachimowicz 2019** [S3-09] [keep | L1]. 58 studies: d = 0.68 with wide variation; stronger when the default reads as endorsement.
- **Maier 2022** [S3-10] [keep | L1]. After bias correction, no evidence for nudging overall; structure interventions undecided.
- **Maier 2025** [S3-11] [keep | L1]. 82 studies: 45% of tested cases showed decision-fatigue effects; construct inconsistently defined.
- **Morkes and Nielsen 1997** [S3-12] [borderline | L5]. 51 users: concise +58%, scannable +47%, objective +27%, all three +124% usability; web text.
- **Nielsen 2006** [S3-13] [borderline | L7]. Frequent needs on the first display; beyond two disclosure levels usability falls.
- **Romero Meza and D'Urso 2024** [S3-14] [borderline | L6]. 12 interviews: high trust in recommendation lists and frustration when they miss.
- **Scheibehenne 2010** [S3-15] [keep | L1]. 63 conditions: mean effect of assortment size virtually zero; no sufficient conditions found.
- **Shneiderman 1996** [S3-16] [borderline | L7]. Overview first, zoom and filter, details on demand; a taxonomy its author calls a starting point.
- **Vohs 2021** [S3-17] [keep | L2]. 36 labs, N = 3,531: d = 0.06, data about four times likelier under the null than under an informed prior of δ = 0.30 (SD 0.15).
- **Willemsen 2016** [S3-18] [keep | L2]. Small diverse recommendation sets were as satisfying as top-N lists and less effortful.

---

## 6. Methodology

### Research Design

**Research questions** (re-scoped by the project owner on 2026-10-04; this replaces the first run's framing, which centered ADHD):

1. How should borg-collective, a command-line tool that orchestrates one developer's roughly twenty projects across repos, communicate project information (status, priority, context, next moves) so the right information arrives at the right time, in the right way and in the right amount?
2. Which of the features that make effective one-page psychoeducational diagrams and cheat sheets work transfer to that communication problem, and which of the claims around them survive scrutiny?

**Scope boundaries.** In scope: peer-reviewed, institutional and practitioner evidence on job aids and visual design, naming and vocabulary, scripts and state maps, in-the-moment use (including ADHD as one supporting strand), status displays and situational awareness, re-entry and handoff, and amount and layering (choice overload, decision fatigue, progressive disclosure, defaults). Out of scope: designing borg features (a decision-design phase follows), the project-management question of what borg should know and enforce (a separate research effort, #252 and #262), reproducing any copyrighted or private sheet, and clinical advice. The sheets the first run started from are described by their design features and not reproduced.

**Tracks.** C1 job aids and visual design; C2 naming and vocabulary; C3 scripts, state maps, problem/antidote pairs and psychoeducation; C4 in-the-moment use with ADHD; S1 status displays and situational awareness; S2 re-entry, resumption and handoff; S3 amount and layering. C-tracks ran 2026-10-03; S-tracks ran 2026-10-04.

**Target audience:** a solo developer who builds and uses workflow tooling and needs to know what the literature supports before designing communication surfaces.

**Methodology version:** deep-research (research-tools plugin), full tier, evidence mode.

### Source Discovery

**Search strategy.** 152 logged entries across seven tracks. The first run (C1 to C4, 2026-10-03) logged 91 queries across OpenAlex through the scholarly adapter, Europe PMC REST and web search. The re-scoped run (S1 to S3, 2026-10-04) logged 61 entries: 53 search queries (WebSearch and the OpenAlex adapter) and 8 direct fetches of known URLs. At least 27 queries were framed as falsification queries, aimed at evidence the thesis fails: in the first run 18 or more (for example "Urbach 2014 no significant reduction", "implementation intentions publication bias", "notification fatigue reminders backfire"), and in the second run the dashboards-don't-improve-decisions query, the SA circularity query, four handoff falsification queries (I-PASS null results, standardized-handoff null results, ritual and ethnography critique) and the ego-depletion and choice-overload replication queries. Per-query hit counts were not logged, so the table groups queries by subtopic and reports the cards each group produced. Source diversity targets were academic, institutional, practitioner, boots-on-the-ground and contrarian.

**Search log** (grouped by subtopic; F marks falsification queries; counts are logged actions):

- **1** — Track and subtopic: C1 cognitive load, chunking, recognition; Queries (examples): CLT critique (F, adapter and web); Cowan 2001; NN/g recognition vs recall; Kofler ADHD working memory; Count: 5; Cards produced: Cowan, de Jong, NN/g, Kofler
- **2** — Track and subtopic: C1 multimedia, pictures, dual coding; Queries (examples): Mayer meta-analysis (adapter and web); dual coding critique (F); Carney and Levin; patient-education pictograms; Count: 4; Cards produced: Mayer, Higdon, Wang and Voss
- **3** — Track and subtopic: C1 checklists and job aids; Queries (examples): Haynes 2009; Urbach 2014 (F); checklist fatigue and box-ticking (F); adapter and web on job aids; Rossett; Count: 6; Cards produced: Haynes, Urbach, Thomassen, Fourcade, Weiser
- **4** — Track and subtopic: C1 pre-attentive, colour, handout design; Queries (examples): Few 2004; colour-coding benefit and harm (F); CDC Clear Communication Index; Count: 3; Cards produced: Few, CDC
- **5** — Track and subtopic: C2 affect labeling; Queries (examples): Lieberman 2007; Torre and Lieberman 2018; adapter meta-analysis; Nook 2021 (F); Count: 4; Cards produced: Lieberman, Torre, Nook, Ariely, Wahba
- **6** — Track and subtopic: C2 granularity; Queries (examples): Kashdan 2015; adapter ED and regulation; Seah and Coifman; ED measurement criticism (F); Count: 4; Cards produced: Seah, Kalokerinos, Thompson, Matt
- **7** — Track and subtopic: C2 feeling wheel; Queries (examples): Willcox 1982; Willcox evaluation or effectiveness (F/gap); Count: 2; Cards produced: AAN-Willcox
- **8** — Track and subtopic: C2 IFS; Queries (examples): adapter IFS RCT; IFS critique (F); Europe PMC IFS PTSD; Count: 3; Cards produced: Shadick, Brownstone
- **9** — Track and subtopic: C2 externalization, narrative, self-distance; Queries (examples): adapter; narrative therapy effectiveness; Kross third-person self-talk; Count: 3; Cards produced: Moser/Kross (Dulwich excluded)
- **10** — Track and subtopic: C2 work-state taxonomies; Queries (examples): developer blockers taxonomy; shared terminology; Ko et al.; Ford and Parnin; Count: 4; Cards produced: Ko, Ford and Parnin
- **11** — Track and subtopic: C2 ADHD and lived experience; Queries (examples): alexithymia in ADHD; ADHD feelings wheel; ADHD developer blog; Count: 3; Cards produced: none kept (Shimmer, Substack excluded)
- **12** — Track and subtopic: C3 if-then scripts; Queries (examples): Gollwitzer and Sheeran 2006; ADHD implementation intentions; publication bias (F); two adapter runs; ADHD personal accounts; Count: 6; Cards produced: 642-tests, Gawrilow, Brighter
- **13** — Track and subtopic: C3 NVC and I-statements; Queries (examples): NVC evidence and critique (F); NVC RCT or review; I-statements; adapter NVC; Count: 4; Cards produced: Park NVC RCT, Rogers I-language
- **14** — Track and subtopic: C3 state maps; Queries (examples): NICABM chart; Corrigan critique (F); Yerkes-Dodson (F); wise mind evidence; Linehan 2015; Neacsiu 2010; Count: 6; Cards produced: Corrigan, Corbett, Linehan, PA DHS (NICABM excluded)
- **15** — Track and subtopic: C3 antidote pairing; Queries (examples): Gottman and Levenson 2000; Heyman and Slep (F); Alfieri; Keith and Frese; adapter Gottman; Count: 5; Cards produced: Gottman-Levenson, Kim, Alfieri, Keith and Frese
- **16** — Track and subtopic: C3 psychoeducation and handouts; Queries (examples): Donker 2009; Kazantzis; handout stickiness; reddit ADHD/DBT handouts; adapter; feelings wheel plus ADHD; Count: 6; Cards produced: Donker (Just1Voice excluded)
- **17** — Track and subtopic: C4 externalization and offloading; Queries (examples): Barkley point of performance; CHADD; Risko and Gilbert; adult ADHD working memory (adapter and Europe PMC); Count: 7; Cards produced: Barkley, CHOP, Risko and Gilbert
- **18** — Track and subtopic: C4 emotion dysregulation, stress; Queries (examples): Shaw, Faraone, Arnsten (adapter, web, Europe PMC); Count: 6; Cards produced: Shaw, Faraone, Arnsten
- **19** — Track and subtopic: C4 JITAI; Queries (examples): Nahum-Shani (adapter and web); Count: 2; Cards produced: Nahum-Shani, van Genugten
- **20** — Track and subtopic: C4 apps, reminders, fatigue; Queries (examples): ADHD app evidence (F); notification fatigue (F); "I stopped seeing reminders" (F); reddit; Hacker News; developer blog; adapter; Count: 8; Cards produced: FOCUS, Nordby, Gani
- **21** — Track and subtopic: S1 SA theory, measurement, validity; Queries (examples): Endsley 1995 three levels; Dekker/Flach circularity (F); SAGAT validity; SA meta-analysis of performance validity; Count: 4; Cards produced: Bakdash, Carsten, Endsley SAGAT
- **22** — Track and subtopic: S1 alarms and alert fatigue; Queries (examples): EEMUA 191 alarm rate; HSE Bransby and Jenkinson; alarm flood human factors; Ancker 2017; Count: 4; Cards produced: Reising, Ancker
- **23** — Track and subtopic: S1 dashboards; Queries (examples): dashboards do not improve decisions (F); Few dashboard SA; Hacker News alert fatigue and dashboard; Count: 3; Cards produced: Xie, Few 2007, Hawksley
- **24** — Track and subtopic: S1 Kanban and flow; Queries (examples): cumulative flow diagram comprehension; kanban visualization; burndown chart evidence; Count: 2; Cards produced: Rodrigues
- **25** — Track and subtopic: S1 glanceability and CLI design; Queries (examples): glanceable display (adapter); clig.dev fetched directly; Count: 2; Cards produced: clig
- **26** — Track and subtopic: S2 handoff outcomes; Queries (examples): I-PASS NEJM 2014; implementation fidelity multicenter; nursing and PICU; Count: 4; Cards produced: Starmer 2014, Starmer 2022
- **27** — Track and subtopic: S2 handoff content and tools; Queries (examples): what to include in a handoff; AHRQ TeamSTEPPS I-PASS; Count: 2; Cards produced: Heilman, Starmer 2012, MHS IV
- **28** — Track and subtopic: S2 falsification; Queries (examples): I-PASS no improvement (F); standardized handoff reviews (F); handoff null results (F); handoff ritual and ethnography critique (F); Count: 4; Cards produced: Orthopaedic I-PASS, Abraham
- **29** — Track and subtopic: S2 SBAR; Queries (examples): SBAR effectiveness systematic review; Count: 1; Cards produced: none (MHS IV supersedes)
- **30** — Track and subtopic: S2 resumption theory and cues; Queries (examples): Parnin and Rugaber; Altmann and Trafton memory for goals; preparing to resume; Parnin and DeLine cues; Iqbal and Horvitz; Count: 5; Cards produced: Altmann and Trafton, Parnin and DeLine
- **31** — Track and subtopic: S2 task context and developer practice; Queries (examples): Mylyn task context; resumption cue developers; developer notes and TODO technique; Count: 3; Cards produced: Parnin 2013
- **32** — Track and subtopic: S3 choice overload; Queries (examples): Scheibehenne 2010; Chernev 2015; conceptual review; single vs ranked list; list length; highlighted top recommendation; Count: 6; Cards produced: Scheibehenne, Chernev, Dean, Willemsen, Romero
- **33** — Track and subtopic: S3 ego depletion and decision fatigue; Queries (examples): Hagger 2016; Glockner 2016; Weinshall-Margel; Vohs 2021; depletion meta-analysis and publication bias (F); decision fatigue validity (F); Count: 6; Cards produced: Hagger, Vohs, Dang, Glockner, Maier 2025
- **34** — Track and subtopic: S3 defaults and nudging; Queries (examples): Jachimowicz 2019; Maier 2022; Count: 2; Cards produced: Jachimowicz, Maier 2022
- **35** — Track and subtopic: S3 information overload and layering; Queries (examples): Cockburn 2008; Eppler and Mengis 2004; plain language and conclusion first; progressive disclosure UI; executive summary placement; overload in knowledge work; Count: 6; Cards produced: Cockburn, Arnold
- **36** — Track and subtopic: S3 direct fetches; Queries (examples): Shneiderman 1996; NN/g progressive disclosure; Morkes and Nielsen 1997; Iyengar and Lepper 2000; arXiv 2212.03931; NN/g inverted pyramid; Danziger 2011 abstract; Count: 7; Cards produced: Shneiderman, NN/g, Morkes and Nielsen, Iyengar and Lepper
- **Total** — Count: **152**; Cards produced: **98**

The Google site-reliability chapter (card S1-07) was fetched directly from a known URL and is not tied to a logged query. Subtopics that ended with fewer than three varied queries because the web-search budget ran out: S1 glanceability (1), command-line information design (0 searches), the "single pane of glass" critique (0), S1 alert fatigue (1), and in S3 the plain-language doctrine and any Szaszi-type rebuttal to the nudging correction.

**Total sources carded:** 98. **Raw search hits** were not logged and are not reported. **Triaged out without a card:** about 40 named items from the first run plus the S-track cuts below (several rows bundle several items, so the counts are lower bounds).

**Triage-out log, first run (C1 to C4)** (not carded; one-line reason):

- **Fusco 2025 oncology data visualisation** — Track: C1; Reason: Redundant with Few; used as a corroboration note only
- **redasadki.me Mayer blog** — Track: C1; Reason: Practitioner opinion, low authority
- **Jelacic 2023 OR checklists** — Track: C1; Reason: Off-topic for design features
- **Adapter "job aids" (Navy, antenatal, health worker)** — Track: C1; Reason: Domain mismatch
- **Adapter cognitive-load metrics, Popper pieces** — Track: C1; Reason: Irrelevant
- **Wikipedia, Medium, UX blogs** — Track: C1; Reason: Tertiary, not fetched
- **Hu 2024 narrative therapy meta-analysis** — Track: C2; Reason: GRADE very low, I2 95%, not about externalization
- **Edel 2015 ADHD alexithymia** — Track: C2; Reason: Correlational n = 78; did not support the use
- **Vromans and Schweitzer 2011, Lopes 2014** — Track: C2; Reason: Snippets only, not fetched
- **Lay pages with "20-40%" ADHD alexithymia** — Track: C2; Reason: No primary traced
- **Espinosa 2007 shared mental models** — Track: C2; Reason: Blocked; leaves a gap
- **Antipatterns in software taxonomies (arXiv)** — Track: C2; Reason: About software classification, not work states
- **Wikipedia IFS, therapygroupdc, innerlifestrategies** — Track: C2; Reason: Secondary summaries
- **Adapter noise (nutrition labels, art therapy)** — Track: C2; Reason: Off topic
- **Heyman and Slep 2001** — Track: C3; Reason: Paywalled; abstract summaries only
- **Kazantzis 2010; Beck Institute homework blog** — Track: C3; Reason: Blocked; quote could not be verified, discarded
- **Toli 2016 clinical implementation intentions** — Track: C3; Reason: Verified but superseded by the 2025 meta-analysis
- **Neacsiu 2010** — Track: C3; Reason: Fetched, not carded to cap size
- **Learning Scientists, simplypsychology, helpfulprofessor** — Track: C3; Reason: Corroboration only or uncritical popularising
- **Iran NVC studies, breast cancer and childbirth psychoeducation** — Track: C3; Reason: Low quality or disease-specific
- **Gottman marketing pages (94% claims), ML divorce prediction** — Track: C3; Reason: Promotional, or circular in-sample
- **Wikipedia, goodreads, ebay, scribd** — Track: C3; Reason: Non-primary
- **Soler-Gutierrez 2023** — Track: C4; Reason: Good but redundant with Shaw and Faraone
- **Schweitzer 2006 adult working memory** — Track: C4; Reason: n = 51, 2006, abstract only; leaves adult WM as a gap
- **Hu 2019, AI-offloading papers** — Track: C4; Reason: Off-track or redundant with Risko and Gilbert
- **Hardeman 2019, Hollis 2016, Shou 2022, Parkin 2022** — Track: C4; Reason: Domain, population or scope mismatch
- **Joseph 2021, Hussain 2021 alert fatigue** — Track: C4; Reason: Older or non-peer-reviewed; Gani supersedes
- **Bored Leopard Substack thread (2026-05-09)** — Track: C4; Reason: Rubric reject (about 4.4, anecdote); used as illustration only
- **chudi.dev ADHD tool stack (2026-07-21)** — Track: C4; Reason: Rubric reject (about 4.4, affiliate links); illustration only
- **Product roundups, HN todo thread, 49-96% override stat** — Track: C4; Reason: Marketing, off-target, or single secondary source

**Triage-out log, re-scoped run (S1 to S3)** (not carded; one-line reason):

- **Wikipedia, Wrike, Kanbantool, Adobe, Kissflow, Microtool flow-diagram explainers** — Track: S1; Reason: Vendor or tutorial content, no comprehension evidence
- **Buddaraju 2011 alarm-management thesis** — Track: S1; Reason: Master's thesis, abstract only; redundant with Reising 2005
- **Guy 2016 alarm-flood thesis** — Track: S1; Reason: Abstract only; priority-distribution claim unverified; noted as a lead
- **Matthews 2006 glanceable displays** — Track: S1; Reason: Proposal-style abstract with no findings; glanceability left as a gap
- **Ericsson and Granlof 2011 Kanban thesis** — Track: S1; Reason: Student thesis, abstract only; superseded by Rodrigues 2026
- **Seqent, Industry Digits, Emerson, ABB, exida alarm pages** — Track: S1; Reason: Vendor marketing around EEMUA numbers
- **medium.com dashboard survey, ResearchGate "interactive dashboards", two arXiv LLM-interface preprints** — Track: S1; Reason: Weak, off-topic, or not fetched
- **Hacker News dashboard comments** — Track: S1; Reason: Noise; only the Timeframe post kept
- **Flach 1995, Dekker and Hollnagel 2004, Endsley 1995 and 2015, Sarter and Woods 1995** — Track: S1; Reason: Paywalled; listed in paywalled candidates
- **Parnin and Rugaber 2009 and 2011** — Track: S2; Reason: Abstract only or Springer redirect; redundant with Parnin 2013 numbers
- **Kersten and Murphy 2015 (Mylyn)** — Track: S2; Reason: Generic abstract, no effect size
- **Muller 2018 SBAR review, Rosenthal 2017, Shahid 2018, Patel 2024, Tarter 2026, Rasiya 2026** — Track: S2; Reason: Redundant with or weaker than MHS IV 2025 and Abraham 2013
- **Horwitz 2013 JAMA editorial** — Track: S2; Reason: Commentary on a pre-2014 evidence base
- **Borst 2015, Ratwani and Trafton 2007, Monk 2004, Radovic 2026, Labonte 2021, Perry 2020, Moon 2016, Yin 2014, Puente 2017, Yang 2011** — Track: S2; Reason: Lab-only, off-task, or redundant with Parnin and Altmann
- **Aiss 2025, Gagnier 2016, Mueller 2023, Lakhani 2025 nursing QI** — Track: S2; Reason: Single-site process outcomes; Heilman kept as the one frontline voice
- **Content-mill developer-productivity blogs (seven sites)** — Track: S2; Reason: Uncited numbers, SEO, sales intent
- **Hacker News item 35459333; two handover-ritual ethnographies** — Track: S2; Reason: Not fetched or HTTP 403; ethnographies logged as paywalled
- **Swedish plain-language thesis** — Track: S3; Reason: Student thesis, wrong population, null
- **Inzlicht and Friese 2019; Carter and McCullough 2014** — Track: S3; Reason: Commentary or redundant with Hagger, Vohs, Glockner
- **NN/g Inverted Pyramid (Schade 2018)** — Track: S3; Reason: Non-independent restatement of Morkes and Nielsen
- **Loepp 2023 multi-list interfaces** — Track: S3; Reason: No outcome data on list size
- **Hospitality choice-overload SLR, haptic-input paper, fruit-and-candy justification paper, EEG choice-overload paper** — Track: S3; Reason: Domain-specific or tangential
- **"Progressive disclosure" in algorithmic-transparency papers** — Track: S3; Reason: Different meaning of the term

### Source Evaluation

**Evaluation framework:** 10-dimension credibility rubric (see source-evaluation-rubric.md; weights 25/20/10/10/10/5/5/5/5/5). **Evidence classification:** 9-level hierarchy (see evidence-hierarchy.md). **Bias guards applied:** a confirmation check on every card (score harder when agreeing, more generously when disagreeing, on dimensions 5, 6 and 8) and the triangulation rule.

**Bias-Guard Summary:**

| Bias-guard outcome | Count |
|--------------------|-------|
| Agreed with source - scored harder on dims 5, 6, 8 | 5 |
| Disagreed with source - scored more generously on dims 5, 6, 8 | 7 |
| Neutral / no strong reaction | 86 |
| **Total sources evaluated** | 98 |

The agree-to-disagree ratio is 5 to 7, well under 3 to 1, so the confirmation-skew gate does not fire. Falsification queries were run anyway (27 or more), and the contrarian category holds 19 included sources. Agreement fired on Kofler, Fourcade, Thomassen, Weiser and Torre; disagreement on de Jong, Urbach, Nook, Wahba, Bakdash, Endsley (SAGAT) and Xie. A short steel-man is included in §4.8 regardless.

**Citation-Verification Report** (full report at `verification-report.md`):

| Metric | Value |
|--------|-------|
| Total source cards | 98 |
| Cards sampled for verification | 30 of 98 (30%) |
| Verified | 27 |
| Failed | 0 |
| Inaccessible (flagged unverifiable) | 3 |
| **Failure rate** (`failed / (verified + failed)`) | 0.0% |
| Failure-rate band | `<=5%` |

Sampling method: seeded random draw (seed 20261004), not weighted by importance. Synthesis agent ID beb3b143-038d-490e-bf76-bd2d8fc898ce; verifier agent ID af424dfeb01de4ddb (distinct). The three inaccessible cards (Higdon 2025, Wang and Voss 2021, Kalokerinos 2019) point to Europe PMC article pages that returned HTTP 403 to automated fetch; each carries `cached/partial`. Inaccessible is 10% of the sample, under the roughly 30% cap, so no low-confidence stamp applies. The verifier noted that two Cloudflare-blocked pages (Wahba 2026 and Corbett 2015) were reached only through a summarizing fetch layer, which is weaker than a raw-text match but did match the strings character for character. Of the 98 cards, 56 are live and 42 are cached/partial (mostly abstract-only).

**Verification history (v1 to v2).** The first run's 59 cards were verified on 2026-10-03: 18 of 59 sampled (30%), 15 verified, 0 failed, 3 inaccessible (Fourcade 2012, Higdon 2025, Kalokerinos 2019), band `<=5%`, seed 20261031; that report is archived as `drafts/verification-report-v1-59cards.md`. After the 2026-10-04 re-scope added 39 S-track cards, the old sample no longer covered 30% of the corpus, so a fresh seeded draw of 30 of 98 was verified (the first sample was not reused or topped up). Each card with a changed URL was re-verified against its final URL before sampling. The first-run analysis is archived at `drafts/v1/analysis.md`; this document reuses its C-track findings and replaces its framing.

### Inclusion/Exclusion Results

Each source went through the six matrix rules in order, stopping at the first match. Weighted averages were recomputed from each card's dimension table using the rubric weights.

**Summary:**

| Category | Count |
|----------|-------|
| Total sources evaluated | 98 |
| Included - Core | 39 |
| Included - Supporting | 54 |
| Excluded | 5 |
| Overrides applied | 2 |

Counts reconcile: 39 + 54 = 93 included and 5 excluded = 98 cards on disk = 98 cards in the verification report's population = 93 entries in §5 and §7 plus the 5 excluded listed in §7. By track, included/evaluated: C1 14/14, C2 15/18, C3 14/16, C4 11/11, S1 11/11, S2 10/10, S3 18/18.

**Rule outcomes for the first-run cards (C1 to C4, 59 cards).** The 39 S-track cards record their rule on each card; all were included (17 Core, 22 Supporting) and none was excluded.

- **Rule 1 strong include, labelled Core (weighted average 7.0 or higher, not redundant)** — Sources: the 22 first-run cards labelled Core; Count: 22
- **Rule 1 met on score but labelled Supporting (the redundancy check shows it extends or qualifies a Core source)** — Sources: Ariely, Cowan, de Jong, Higdon, Kross, Thompson, Shadick, Linehan, Keith and Frese, Gani, Faraone, CHOP; Count: 12
- **Rule 2 diversity include** — Sources: CDC, AAN-Willcox, Brighter, PA DHS; Count: 4
- **Rule 3 unique-insight include** — Sources: Few 2004, NN/g, Thomassen, Weiser, Ford and Parnin, Ko, Torre, Wahba, Brownstone, Corbett, Corrigan, Gottman-Levenson, Gawrilow, Rogers, Park NVC, Barkley; Count: 16
- **Rule 4 moderate include** — Sources: none reached it; Count: 0
- **Rule 5 weak exclude** — Sources: Shimmer, NICABM; Count: 2
- **Rule 6 default exclude** — Sources: Dulwich Centre; Count: 1
- **Override: Rule 2 would have included, excluded instead** — Sources: Substack post, Just1Voice; Count: 2
- **Total** — **59**

**Overrides applied (2).** The rule that would have applied was Rule 2, because each was the only lived-experience voice in its track. The reason for overriding is that both are single anecdotes at Level 8 with weighted averages below 5.0 and neither can carry a claim. Their role in the document is to mark a gap and nothing else. Two further C4 anecdotes (a Substack thread and a developer tool-stack post) were rubric-rejected without cards and appear nowhere as evidence.

**Distribution by evidence level** (all 98 cards; the excluded five sit at levels 7, 8, 8, 9 and 9):

| Level | Description | Count (all cards) | Included |
|-------|-------------|-------------------|----------|
| 1 | Systematic review / meta-analysis | 22 | 22 |
| 2 | RCT / controlled experiment | 18 | 18 |
| 3 | Large-scale observational | 15 | 15 |
| 4 | Expert consensus / professional body | 4 | 4 |
| 5 | Practitioner case study | 3 | 3 |
| 6 | Qualitative research | 6 | 6 |
| 7 | Expert opinion / thought leadership | 25 | 24 |
| 8 | Anecdotal / personal experience | 3 | 1 |
| 9 | Marketing / promotional | 2 | 0 |
| | **Total** | **98** | **93** |

Level 1 and 2 are both non-zero, so the primary-evidence banner does not apply. Three cautions on those 40 sources. The level 1 count includes a non-peer-reviewed preprint (Wahba 2026), and a meta-analysis of a single research programme's own corpus (Mayer); level 3 holds lab experiments because the hierarchy has no lab-experiment tier. Most of them study a neighboring population, which is a relevance problem and not a rigor problem. And none tests a communication surface on a developer running many projects.

**Distribution by source category:**

| Category | Included | Excluded |
|----------|----------|----------|
| Academic | 51 | 0 |
| Institutional | 5 | 0 |
| Practitioner | 13 | 3 |
| Boots-on-the-ground | 5 | 2 |
| Contrarian | 19 | 0 |
| **Total** | **93** | **5** |

**Distribution by credibility band** (three-bucket; weighted-average tiers recomputed from the cards):

| Band | Weighted average | Count | Disposition |
|------|------------------|-------|-------------|
| keep | 7.0 or higher | 57 | 57 included, 0 excluded |
| borderline | 5.0 to 6.9 | 36 | 36 included, 0 excluded |
| reject | below 5.0 | 5 | 0 included, 5 excluded |

**Real cut made this run, and the marginal keep.** Five sources were excluded, all from the first run: Shimmer 2024 (coaching-company marketing, about 3.9), Just1Voice 2022 (anecdote, about 4.3), NICABM (marketing-adjacent, about 4.4), Dulwich Centre (about 4.6) and the Substack post (about 4.6). The lowest-scoring included source is Hawksley 2026, the family e-paper dashboard post [S1-08] (borderline, weighted average about 5.0, level 8). It cleared the bar only under the diversity rule, as the sole boots-on-the-ground voice in the status-display track, and it carries hypothesis weight only: it supports no claim in §3 by itself. This supersedes the first run's naming of the Nielsen Norman Group heuristic page (about 5.4) as the marginal keep.

### Perspective Balance

| Track | Acad | Inst | Prac | Boots | Contr |
|---|---|---|---|---|---|
| C1 | Y (5) | Y (1) | Y (3) | Y (2) | Y (3) |
| C2 | Y (10) | N | Y (1) | N | Y (4) |
| C3 | Y (10) | Y (1) | Y (1) | N | Y (2) |
| C4 | Y (6) | Y (1) | Y (1) | N | Y (3) |
| S1 | Y (5) | Y (1) | Y (3) | Y (1) | Y (1) |
| S2 | Y (4) | Y (1) | Y (2) | Y (1) | Y (2) |
| S3 | Y (11) | N | Y (2) | Y (1) | Y (4) |

Columns: Acad = Academic, Inst = Institutional, Prac = Practitioner, Boots = Boots-on-the-ground, Contr = Contrarian. Tracks:

- **C1** — job aids and visual design
- **C2** — naming and vocabulary
- **C3** — scripts, state maps, psychoeducation
- **C4** — in-the-moment use with ADHD
- **S1** — status displays and SA
- **S2** — re-entry and handoff
- **S3** — amount and layering

Every track has at least three of the five categories (C1 five, C2 three, C3 four, C4 four, S1 five, S2 five, S3 four). The Boots column is thin and I want to be plain about it. The five included Boots-on-the-ground sources are surgical-staff experience (Fourcade, Thomassen), emergency-department focus groups (Heilman), twelve streaming-service users (Romero) and one hobbyist's dashboard post (Hawksley). None is a developer working across many projects, and every lived-experience source from ADHD or developer communities that the tracks found failed the credibility rubric. The Institutional column is empty for C2 and S3 because no government or professional-body source on naming or on choice and layering was retrieved; the S3 plain-language and conclusion-first doctrine search was cut by the search budget, so that absence is partly a search gap.

### Limitations

- **Search budget exhausted.** The session-wide WebSearch budget (200 calls, shared across parallel tracks) ran out partway through the S-tracks: S1 made about 9 web searches, S2 about 8, S3 about 9. Discovery continued through the OpenAlex adapter, the Europe PMC and Hacker News APIs and direct fetches, which find papers well and practitioner or institutional material badly. Planned queries not run include the glanceability and terminal-design searches, the "single pane of glass" critique, two S3 falsification searches, the plain-language and conclusion-first doctrine search, and a search for rebuttals to the nudging correction. Iqbal and Horvitz (2007) on task recovery could not be retrieved.
- **Thin ground-level evidence.** Five Boots sources, none from developers working across many projects (above).
- **Transfer gap.** Almost no source studied a one-person tool. Effects come from hospitals, students, shoppers, controllers, web readers, children with ADHD and trauma patients, so every principle in §3 is an inference across that gap.
- **No direct observation.** No card reports a test of any principle on the target user, and none was run here.
- **Abstract-level reading.** 42 of 98 cards are `cached/partial`. Several load-bearing sources were read as abstracts only (Bakdash 2021, Xie 2022, Chernev 2015, Scheibehenne 2010, Hagger 2016, Vohs 2021, Jachimowicz 2019, Maier 2025, Starmer 2014, Starmer 2022, and the C-track reviews Shaw 2014, Faraone 2019, Risko and Gilbert 2016, Keith and Frese 2008, Alfieri 2013).
- **Cards point at record endpoints.** Several S-track card URLs are OpenAlex or Europe PMC record endpoints rather than publisher pages, because publishers blocked automated fetch. The quotes were verified against those endpoints, and §7 gives the DOI or canonical page where the citation has one.
- **Single evaluator and one author.** One agent scored every card and wrote this document, with no inter-rater check. The independent verifier checked quotes and locations, not scores or interpretations. This document's AI-scoring pass is also a self-score.
- **Verification coverage.** 30 of 98 cards (30%) were sampled, the minimum the gate allows, and three of those were inaccessible to the verifier.
- **Non-peer-reviewed items.** Wahba 2026 (preprint), Dean, Ravindran and Stoye (arXiv), the Hawksley post and the clig.dev guidelines are not peer reviewed and are marked as hypothesis-level in §3.
- **Evidence-level labels are approximate.** The hierarchy has no lab-experiment tier, one level 1 is a preprint and one a self-corpus meta-analysis, so the counts overstate how much hard evidence there is.
- **Date skew.** Several foundational sources predate 2020 (Cowan 2001, Ko 2004, Few 2004, Shneiderman 1996, Iyengar and Lepper 2000, Morkes and Nielsen 1997, Reising 2005); they were kept where they are the origin of a claim.

**Paywalled sources excluded and why.** None of these were carded or used as evidence, because they could not be read and the run does not summarize from an abstract or a search snippet. The full list with access routes is in `drafts/paywalled-candidates.md`.

- Rossett and Gautier-Downes, *A Handbook of Job Aids* (1991, book): job-aid fit criteria; only a search summary was seen.
- Carney and Levin 2002 (*Educational Psychology Review*, Springer): pictorial-illustration boundary conditions.
- Christ 1975 (*Human Factors*, SAGE): colour-coding review.
- Sweller 1988 (*Cognitive Science*, Wiley): origin of cognitive load theory.
- Mayer-corpus meta-analysis full text (Elsevier): heterogeneity and moderator tables; abstract used.
- Haynes 2009 and Urbach 2014 full texts (NEJM): abstracts used.
- Kashdan, Barrett and McKnight 2015 (*Current Directions in Psychological Science*); Willcox 1982 (*Transactional Analysis Journal*); the IFS scoping review (*Australian Psychologist* 2025); Torre and Lieberman 2025 (*Trends in Cognitive Sciences*).
- Heyman and Smith Slep 2001 (*Journal of Marriage and Family*): cross-validation critique of the problem-list prediction.
- Kazantzis, Whittington and Dattilio 2010; Gollwitzer and Sheeran 2006 chapter; Keith and Frese 2008 and Alfieri 2013 full texts.
- Endsley 1995 (*Human Factors*), Endsley 2015, Flach 1995, Dekker and Hollnagel 2004, Sarter and Woods 1995: the primary situation-awareness theory and its critique.
- EEMUA Publication 191 (3rd ed. 2013), ISA-18.2 / IEC 62682, and the HSE report CRR 166/1998: the primary alarm-management documents; the rate bands in §3 P7 come second-hand through an open benchmark paper.
- Altmann and Trafton 2002 (*Cognitive Science*); Parnin and Rugaber 2011 (*Software Quality Journal*); Starmer 2014 full text (NEJM); Iqbal and Horvitz 2007 (CHI); two handover-as-ritual ethnographies (one in *International Journal of Medical Informatics*).
- Eppler and Mengis 2004 (*The Information Society*); Johnson and Goldstein 2003 (*Science*); Danziger, Levav and Avnaim-Pesso 2011 and Weinshall-Margel and Shapard 2011 (*PNAS*); full texts of Chernev 2015 and Scheibehenne 2010.
- Bakdash 2021 and Endsley's SAGAT chapter full texts (Taylor and Francis), Xie 2022 full trial table (open in a browser behind a CAPTCHA).

---

## 7. Bibliography

Format: citation, then [band | level | decision] and a one-line contribution. Core is a Rule 1 strong include; Supporting carries its rule where the first run recorded it. All 93 included sources are listed; the 5 excluded sources follow at the end.

### Track C1: job aids and visual design

- **C1-01.** Centers for Disease Control and Prevention. "CDC Clear Communication Index User Guide." 2019. https://www.cdc.gov/ccindex/pdf/clear-communication-user-guide.pdf [borderline | L4 | Supporting, Rule 2] Checkable layout rules; one main message; says pretesting is irreplaceable.
- **C1-02.** Cowan N. "The magical number 4 in short-term memory." *Behavioral and Brain Sciences* 24(1). 2001. https://europepmc.org/article/MED/11515286 [keep | L7 | Supporting, Rule 1 label downgrade] About four chunks of working memory.
- **C1-03.** de Jong T. "Cognitive load theory, educational research, and instructional design." *Instructional Science* 38(2). 2010. https://research.utwente.nl/en/publications/cognitive-load-theory-educational-research-and-instructional-desi [keep | L7 | Supporting, Rule 1 label downgrade] Falsification source: CLT is a heuristic with open problems.
- **C1-04.** Few S. "Tapping the Power of Visual Perception." Perceptual Edge. 2004. https://www.perceptualedge.com/articles/ie/visual_perception.pdf [borderline | L7 | Supporting, Rule 3] Pre-attentive attributes and what each can encode.
- **C1-05.** Fourcade A, et al. "Barriers to staff adoption of a surgical safety checklist." *BMJ Quality & Safety* 21(3). 2012. https://europepmc.org/article/MED/22069112 [keep | L5 | Core] Strongest quantitative account of how aids fail in use.
- **C1-06.** Haynes AB, et al. "A surgical safety checklist to reduce morbidity and mortality in a global population." *NEJM* 360(5). 2009. https://europepmc.org/article/MED/19144931 [keep | L3 | Core] The load-bearing positive-effect claim for checklists.
- **C1-07.** Higdon KF, et al. "Distinctiveness, not dual coding, explains the picture-superiority effect." *QJEP* 78(1). 2025. https://europepmc.org/article/MED/38360549 [keep | L2 | Supporting, Rule 1 label downgrade] Picture benefit may be distinctiveness; falsification of dual coding.
- **C1-08.** Kofler MJ, et al. "Working memory and short-term memory deficits in ADHD: a bifactor modeling approach." *Neuropsychology* 34(6). 2020. https://pmc.ncbi.nlm.nih.gov/articles/PMC7483636/ [keep | L3 | Core] ADHD-specific rationale for externalizing working memory (children).
- **C1-09.** "A meta-analysis of Richard Mayer's multimedia learning research." *Educational Research Review*. 2025. https://experts.illinois.edu/en/publications/a-meta-analysis-of-richard-mayers-multimedia-learning-research-se/ [keep | L1 | Core] Ranks design features by effect; g = 0.37 overall.
- **C1-10.** Nielsen Norman Group. "10 Usability Heuristics for User Interface Design" (heuristic 6). 1994, current page. https://www.nngroup.com/articles/ten-usability-heuristics/ [borderline | L7 | Supporting, Rule 3] Recognition rather than recall.
- **C1-11.** Thomassen O, et al. "Checklists in the operating room: help or hurdle?" *BMC Health Services Research* 10. 2010. https://pmc.ncbi.nlm.nih.gov/articles/PMC3009978/ [borderline | L6 | Supporting, Rule 3] The checklist-fatigue mechanism.
- **C1-12.** Urbach DR, et al. "Introduction of surgical safety checklists in Ontario, Canada." *NEJM* 370(11). 2014. https://europepmc.org/article/MED/24620866 [keep | L3 | Core] Population-level null for mandated adoption.
- **C1-13.** Wang T, Voss JG. "Effectiveness of pictographs in improving patient education outcomes: a systematic review." 2021;36(1):9-40. https://europepmc.org/article/MED/33331898 [keep | L1 | Core] 48 of 56 studies supportive; validate with the audience.
- **C1-14.** Weiser TG, Haynes AB. "Ten years of the Surgical Safety Checklist." *British Journal of Surgery* 105(8). 2018. https://pmc.ncbi.nlm.nih.gov/articles/PMC6032919/ [borderline | L7 | Supporting, Rule 3] Originators name the failure modes.

### Track C2: naming and vocabulary

- **C2-01.** Alexithymia Awareness Network. "Gloria Willcox and the Feeling Wheel." (refers to Willcox G, *Transactional Analysis Journal* 12(4), 1982). https://alexithymiaawarenessnetwork.org/wilcox/ [borderline | L7 | Supporting, Rule 2] Wheel origin; explicitly no effectiveness claim.
- **C2-02.** Ariely Y, et al. "Affect Labeling and Reappraisal as an Emotion Regulation Strategy." *Affective Science*. 2026. https://pmc.ncbi.nlm.nih.gov/articles/PMC13269579/ [keep | L2 | Supporting, Rule 1 label downgrade] Independent replication; no delayed benefit.
- **C2-03.** Brownstone LM, et al. "Internal Family Systems: Exploring Its Problematic Popularity." Society for the Advancement of Psychotherapy. 2024. https://societyforpsychotherapy.org/internal-family-systems-exploring-its-problematic-popularity/ [borderline | L7 | Supporting, Rule 3] IFS critique: evidence base small.
- **C2-04.** Ford D, Parnin C. "Exploring Causes of Frustration for Software Developers." CHASE 2015. https://denaeford.me/papers/developer-frustration-CHASE-2015.pdf [borderline | L6 | Supporting, Rule 3] 11 developer frustration categories.
- **C2-05.** Kalokerinos EK, et al. "Differentiate to Regulate." *Psychological Science*. 2019. https://europepmc.org/article/MED/30990768 [keep | L3 | Core] Mechanism: differentiation improves strategy use, not choice.
- **C2-06.** Ko AJ, Myers BA, Aung HH. "Six Learning Barriers in End-User Programming Systems." VL/HCC 2004. https://faculty.washington.edu/ajko/papers/Ko2004LearningBarriers.pdf [borderline | L6 | Supporting, Rule 3] Typed "stuck" vocabulary for programmers.
- **C2-07.** Moser JS, et al. "Third-person self-talk facilitates emotion regulation without engaging cognitive control." *Scientific Reports* 7. 2017. https://pmc.ncbi.nlm.nih.gov/articles/PMC5495792/ [keep | L3 | Supporting, Rule 1 label downgrade] Psychological-distance mechanism.
- **C2-08.** Lieberman MD, et al. "Putting feelings into words." *Psychological Science* 18(5). 2007. https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=EXT_ID:17576282%20AND%20SRC:MED&format=json&resultType=core [keep | L3 | Core] Origin study of the labeling mechanism.
- **C2-09.** Matt LM, Seah THS, Coifman KG. "Effects of a brief online emotion word learning task." *PLOS ONE*. 2024. https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0299540 [keep | L2 | Core] Only intervention test of teaching emotion words; null direct effect.
- **C2-10.** Nook EC, Satpute AB, Ochsner KN. "Emotion Naming Impedes Both Cognitive Reappraisal and Mindful Acceptance." *Affective Science* 2. 2021. https://pmc.ncbi.nlm.nih.gov/articles/PMC9383041/ [keep | L2 | Core] Strongest experimental challenge to "naming equals regulating".
- **C2-11.** Seah THS, Coifman KG. "Emotion differentiation and behavioral dysregulation: a meta-analysis." *Emotion* 22(7). 2022. https://www.ovid.com/journals/emotn/fulltext/10.1037/emo0000968~emotion-differentiation-and-behavioral-dysregulation-in [keep | L1 | Core] Pooled r = -0.15.
- **C2-12.** Shadick NA, et al. "A Randomized Controlled Trial of an Internal Family Systems-based Psychotherapeutic Intervention on Outcomes in Rheumatoid Arthritis." *Journal of Rheumatology*. 2013. https://doi.org/10.3899/jrheum.121465 [keep | L2 | Supporting, Rule 1 label downgrade] Best controlled IFS trial located; a package, not a map.
- **C2-13.** Thompson RJ, Springstein T, Boden M. "Gaining clarity about emotion differentiation." *Social and Personality Psychology Compass* 15(3). 2021. https://bpb-us-e2.wpmucdn.com/sites.wustl.edu/dist/f/1305/files/2025/03/Social-Personality-Psych-2021-Thompson-Gaining-clarity-about-emotion-differentiation.pdf [keep | L7 | Supporting, Rule 1 label downgrade] Measurement critique of granularity.
- **C2-14.** Torre JB, Lieberman MD. "Putting Feelings Into Words: Affect Labeling as Implicit Emotion Regulation." *Emotion Review* 10(2). 2018. https://static1.squarespace.com/static/651b09f505bc433349d85ab7/t/651d2f2843e6d165beeccb23/1696411432954/Torre(2018)ER.pdf [borderline | L7 | Supporting, Rule 3] Mechanism hypotheses and boundary conditions from the proponent lab.
- **C2-15.** Wahba MAR. "Putting feelings into words: a systematic review and meta-analysis of affect labeling." Zenodo v1.1.0. 2026. https://doi.org/10.5281/zenodo.20109595 [borderline | L1 (labelled; not peer reviewed) | Supporting, Rule 3] Only pooled labeling estimate; smaller in independent labs. Directional flag only.

### Track C3: scripts, state maps, problem/antidote pairing, psychoeducation

- **C3-01.** Alfieri L, Nokes-Malach TJ, Schunn CD. "Learning through case comparisons: a meta-analytic review." *Educational Psychologist* 48(2). 2013. https://eric.ed.gov/?id=EJ1000186 [keep | L1 | Core] Case comparison d = 0.50; mechanism behind side-by-side layouts.
- **C3-02.** Winston E. "Action planning - an ADHD coach's approach." Brighter coaching blog. 2026. https://brighter.coach/blog/2026/01/25/action-planning-with-adhd-audhd.html [borderline | L7 | Supporting, Rule 2] Practitioner usability rules for a planning prompt.
- **C3-03.** Corbett M. "From law to folklore: work stress and the Yerkes-Dodson Law." *Journal of Managerial Psychology* 30(6). 2015. https://www.emerald.com/jmp/article-abstract/30/6/741/233069/From-law-to-folklore-work-stress-and-the-Yerkes [borderline | L7 | Supporting, Rule 3] The inverted-U curve lacks empirical basis.
- **C3-04.** Corrigan FM, Fisher JJ, Nutt DJ. "Autonomic dysregulation and the Window of Tolerance model." *Journal of Psychopharmacology* 25(1). 2011. https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=DOI%3A10.1177%2F0269881109354930&resultType=core&format=json&pageSize=3 [borderline | L7 | Supporting, Rule 3] The window of tolerance as a proposed trauma model.
- **C3-05.** Donker T, et al. "Psychoeducation for depression, anxiety and psychological distress: a meta-analysis." *BMC Medicine* 7. 2009. https://pmc.ncbi.nlm.nih.gov/articles/PMC2805686/ [keep | L1 | Core] Passive psychoeducation d = 0.20.
- **C3-06.** Gawrilow C, Gollwitzer PM. "Implementation intentions facilitate response inhibition in ADHD children." *Cognitive Therapy and Research* 32. 2008. https://www.socmot.uni-konstanz.de/publications/implementation-intentions-facilitate-response-inhibition-adhd-children [borderline | L2 | Supporting, Rule 3] Only ADHD-specific controlled evidence for if-then plans.
- **C3-07.** Gottman JM, Levenson RW. "The Timing of Divorce." *Journal of Marriage and Family* 62. 2000. https://bpl.studentorg.berkeley.edu/docs/61-Timing%20of%20Divorce00.pdf [borderline | L3 | Supporting, Rule 3] Primary source for the four-pattern problem list; 93% in-sample.
- **C3-08.** Rogers et al. "I understand you feel that way, but I feel this way." *PeerJ* 6. 2018. https://pmc.ncbi.nlm.nih.gov/articles/PMC5961625/ [borderline | L2 | Supporting, Rule 3] Experimental support for I-statement openers (vignettes).
- **C3-09.** Sheeran P, Listrom O, Gollwitzer PM. "The when and how of planning: meta-analysis ... in 642 tests." *European Review of Social Psychology* 36(1). 2025. https://kops.uni-konstanz.de/server/api/core/bitstreams/d703c468-46e9-47fc-8900-d32d7d19c8d9/content [keep | L1 | Core] If-then effect, with bias-corrected estimates and where it fails.
- **C3-10.** Keith N, Frese M. "Effectiveness of error management training: a meta-analysis." *Journal of Applied Psychology* 93(1). 2008. https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=DOI%3A10.1037%2F0021-9010.93.1.59&resultType=core&format=json&pageSize=3 [keep | L1 | Supporting, Rule 1 label downgrade] Error-based learning d = 0.44.
- **C3-11.** Kim HK, Capaldi DM, Crosby L. "Generalizability of Gottman and Colleagues' Affective Process Models." *Journal of Marriage and Family*. 2007. https://pmc.ncbi.nlm.nih.gov/articles/PMC1828692/ [keep | L3 | Core] Independent failure to replicate.
- **C3-12.** Linehan MM, et al. "DBT for high suicide risk in individuals with borderline personality disorder." *JAMA Psychiatry* 72(5). 2015. https://www.pdbti.org/wp-content/uploads/2023/10/12.1-Linehan-et-al.-2015-DBT-RCT-Component-Analysis.pdf [keep | L2 | Supporting, Rule 1 label downgrade] Skills training is the active ingredient, not the handout.
- **C3-13.** Park et al. "Effects of a Nonviolent Communication Education Program ... Korean Nursing Students." 2025. https://pmc.ncbi.nlm.nih.gov/articles/PMC12051804/ [borderline | L2 | Supporting, Rule 3] Controlled NVC evidence with honest nulls.
- **C3-14.** Pennsylvania Department of Human Services, OMHSAS. Trauma-informed care tip sheet (window of tolerance). September 2024. https://www.pa.gov/content/dam/copapwp-pagov/en/dhs/documents/trauma-informed-care/tip-sheets/2024-09-september-final-tts.pdf [borderline | L4 | Supporting, Rule 2] The institutional exemplar of a one-page state map.

### Track C4: in-the-moment use with ADHD

- **C4-01.** Arnsten AFT. "Stress signalling pathways that impair prefrontal cortex structure and function." *Nature Reviews Neuroscience* 10(6). 2009. https://pmc.ncbi.nlm.nih.gov/articles/PMC2907136/ [keep | L7 | Core] Stress degrades prefrontal working memory.
- **C4-02.** Barkley RA. "The Important Role of Executive Functioning and Self-Regulation in ADHD." Fact sheet. https://www.russellbarkley.org/factsheets/ADHD_EF_and_SR.pdf [borderline | L7 | Supporting, Rule 3] Point-of-performance design premise.
- **C4-03.** Children's Hospital of Philadelphia, Center for Management of ADHD. "What Are Executive Functions and How Are They Related to ADHD?" 2023. https://www.chop.edu/sites/default/files/adhd-exec-5-what-are-efs-and-how-are-they-related-to-adhd.pdf [keep | L4 | Supporting, Rule 1 label downgrade] Institutional definitions of executive function.
- **C4-04.** Faraone SV, et al. "Practitioner Review: Emotional dysregulation in ADHD." *J Child Psychol Psychiatry* 60(2). 2019. https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=EXT_ID%3A29624671%20AND%20SRC%3AMED&resultType=core&format=json [keep | L4 | Supporting, Rule 1 label downgrade] Clinical-recognition view; core status debated.
- **C4-05.** Carvalho LR, et al. "Evaluation of the effectiveness of the FOCUS ADHD App." *European Psychiatry*. 2023. https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10377453/ [keep | L2 | Core] Null on adherence despite favorable usability.
- **C4-06.** Gani I, et al. "Understanding 'Alert Fatigue' in Primary Care." *JMIR*. 2025. https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11845892/ [keep | L1 | Supporting, Rule 1 label downgrade] Why prompts stop working.
- **C4-07.** Nahum-Shani I, et al. "Just-in-Time Adaptive Interventions in Mobile Health." *Annals of Behavioral Medicine* 52(6). 2018. https://pmc.ncbi.nlm.nih.gov/articles/PMC5364076/ [keep | L7 | Core] Receptivity and decision-point design rules.
- **C4-08.** Nordby ES, et al. "The Effect of SMS Reminders on Adherence in a Self-Guided Internet-Delivered Intervention for Adults With ADHD." *Frontiers in Digital Health*. 2022. https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9149073/ [keep | L2 | Core] Generic reminders had no effect.
- **C4-09.** Risko EF, Gilbert SJ. "Cognitive Offloading." *Trends in Cognitive Sciences* 20(9). 2016. https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=EXT_ID%3A27542527%20AND%20SRC%3AMED&resultType=core&format=json [keep | L7 | Core] The offloading mechanism and its metacognitive trigger.
- **C4-10.** Shaw P, Stringaris A, Nigg J, Leibenluft E. "Emotion dysregulation in ADHD." *American Journal of Psychiatry* 171(3). 2014. https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=EXT_ID%3A24480998%20AND%20SRC%3AMED&resultType=core&format=json [keep | L1 | Core] Emotion dysregulation is prevalent and impairing in ADHD.
- **C4-11.** van Genugten C, et al. "Beyond the current state of just-in-time adaptive interventions in mental health." *Frontiers in Digital Health*. 2025. https://doi.org/10.3389/fdgth.2025.1460167 [keep | L1 | Core] Audit: JITAI timing evidence is early-stage.

### Track S1: status displays and situational awareness

- **S1-01.** Ancker JS, Edwards A, Nosal S, Hauser D, Mauer E, Kaushal R. "Effects of workload, work complexity, and repeated alerts on alert fatigue in a clinical decision support system." *BMC Medical Informatics and Decision Making* 17:36. 2017. https://doi.org/10.1186/s12911-017-0430-8 [keep | L3 | Core] Each extra reminder per encounter cut acceptance by 30%; repeats, not workload, drove it; no desensitization over time.
- **S1-02.** Bakdash JZ, Marusich LR, Cox KR, Geuss MN. "The validity of situation awareness for performance: a meta-analysis." *Theoretical Issues in Ergonomics Science*. 2021. https://doi.org/10.1080/1463922x.2021.1921310 [keep | L1 | Core] 678 effects from 77 papers: SA predicts performance at r = 0.26 (range -0.15 to 0.60).
- **S1-03.** Carsten O, Vanderhaegen F. "Situation awareness: valid or fallacious?" *Cognition, Technology and Work* 17(2):157-158. 2015. https://doi.org/10.1007/s10111-015-0319-1 [borderline | L7 | Supporting] Editorial laying out the circularity critique, the context-dependence critique and Endsley's rebuttal.
- **S1-04.** Prasad A, Firshman B, Tashian C, Parish E. "Command Line Interface Guidelines." clig.dev. Undated living document (origin believed about 2020). https://clig.dev [borderline | L7 | Supporting] Only terminal-design source: err on the side of less, show state and the next command, color sparingly; design hypotheses, not evidence.
- **S1-05.** Endsley MR. "Direct Measurement of Situation Awareness: Validity and Use of SAGAT." In *Situational Awareness* (Routledge, 2017 reprint of a 2000 chapter). https://doi.org/10.4324/9781315087924-9 [borderline | L7 | Supporting] Primary-author statement of the freeze-and-query SA measure; element perception falls as display load rises (abstract only).
- **S1-06.** Few S. "Dashboard Design for Real-Time Situation Awareness." Perceptual Edge white paper. 2007. http://www.perceptualedge.com/articles/Whitepapers/Dashboard_Design.pdf [borderline | L7 | Supporting] Translates the three SA levels into display rules: context beside numbers, alert restraint, history for projection.
- **S1-07.** Beyer B, Jones C, Petoff J, Murphy NR (eds). "Monitoring Distributed Systems" (chapter 6). *Site Reliability Engineering*. O'Reilly/Google. 2016. https://sre.google/sre-book/monitoring-distributed-systems/ [borderline | L5 | Supporting] Alert test of urgent, actionable and user-visible; a human reacts with urgency a few times a day; automate rote pages.
- **S1-08.** Hawksley J. "How I built Timeframe, our family e-paper dashboard." hawksley.org. 2026-02-17. https://hawksley.org/2026/02/17/timeframe.html [borderline | L8 | Supporting] Anecdote: a status corner that stays blank when nothing needs attention, on a read-only display. Marginal keep; hypothesis weight only.
- **S1-09.** Reising DVC, Montgomery T. "Achieving Effective Alarm System Performance: Results of ASM Consortium Benchmarking against the EEMUA Guide for Alarm Systems." 20th CCPS International Conference. 2005. https://process.honeywell.com/content/dam/process/en/documents/document-lists/doc_asm-consortium/white-papers/February%2028%202005%20-%20Acheiving%20Effective%20Alarm%20System%20Performance%20Benchmarking.pdf [borderline | L3 | Core] Alarm-rate bands across 37 consoles; the authors call the numbers devoid of context.
- **S1-10.** Rodrigues E, Mesquita L, Costa AL, Sampaio M, Caetano R. "Using Kanban to Reshape Communication and Collaboration Across Teams." SBSC Estendido. 2026. https://doi.org/10.5753/sbsc_estendido.2026.20971 [borderline | L6 | Supporting] 13-person team: perceived communication rose after Kanban, credited to visibility and a standard card structure; one setting.
- **S1-11.** Xie CX, Chen Q, Hincapie CA, Hofstetter L, Maher CG, Machado GC. "Effectiveness of clinical dashboards as audit and feedback or clinical decision support tools on medication use and test ordering: a systematic review of randomized controlled trials." *Journal of the American Medical Informatics Association*. 2022. https://doi.org/10.1093/jamia/ocac094 [keep | L1 | Core] 11 RCTs: standalone dashboards gave conflicting or null effects; multicomponent programs did better.

### Track S2: re-entry, resumption and handoff

- **S2-01.** Abraham J, Kannampallil T, Patel VL. "A systematic review of the literature on the evaluation of handoff tools: implications for research and practice." *JAMIA*. 2013. https://doi.org/10.1136/amiajnl-2012-001351 [keep | L1 | Supporting] 36 handoff-tool evaluations; rigor varied enough to limit standardization advice; 95% intra-departmental.
- **S2-02.** Altmann EM, Trafton JG. "Task Interruption: Resumption Lag and the Role of Cues." eScholarship. 2004. https://api.openalex.org/works/W82234358 [keep | L2 | Core] Resumption lag 3.8 s versus 1.9 s; cues present just before the interruption reduce it.
- **S2-03.** Heilman JA, Flanigan M, Nelson A, Johnson T. "Adapting the I-PASS Handoff Program for Emergency Department Inter-Shift Handoffs." *Western Journal of Emergency Medicine*. 2016. https://doi.org/10.5811/westjem.2016.9.30574 [borderline | L6 | Supporting] Frontline focus groups endorsed the elements, wanted brevity and an anticipated-disposition field; usability, not effectiveness.
- **S2-04.** "Use of structured handoff protocols for within-hospital unit transitions: a systematic review from Making Healthcare Safer IV." *BMJ Quality & Safety*. 2025. https://pmc.ncbi.nlm.nih.gov/articles/PMC12232517/ [keep | L1 | Core] I-PASS moderate certainty, SBAR low; two I-PASS RCTs null on clinical outcomes; evidence mostly physician training.
- **S2-05.** "Sustained Improvement in Quality of Patient Handoffs After Orthopaedic Surgery I-PASS Intervention." *JAAOS Global Research & Reviews*. 2022. https://pmc.ncbi.nlm.nih.gov/articles/PMC9447790/ [borderline | L3 | Supporting] Handoff quality improved for 18 months; no significant change in readmissions or infections (1,984 patients).
- **S2-06.** Parnin C. "Programmer, Interrupted." *Game Developer*. April 22, 2013. https://www.gamedeveloper.com/programming/programmer-interrupted [borderline | L7 | Supporting] 10 to 15 minutes to resume editing; 10% within a minute; TODO comments fail without a prompt to view them.
- **S2-07.** Parnin C, DeLine R. "Evaluating cues for resuming interrupted programming tasks." *CHI 2010*. https://doi.org/10.1145/1753326.1753342 [keep | L2 | Core] Automated activity cues doubled task success over note-taking alone; preference and performance diverged.
- **S2-08.** Starmer AJ, Spector ND, Srivastava R, Allen AD, Landrigan CP, Sectish TC. "I-PASS, a Mnemonic to Standardize Verbal Handoffs." *Pediatrics* 129(2):201-204. 2012. https://doi.org/10.1542/peds.2011-2966 [borderline | L7 | Supporting] Fields chosen from what real handoffs omitted; SBAR fits briefings under five points, not complex cases.
- **S2-09.** Starmer AJ, Spector ND, Srivastava R, West DC, et al. "Changes in Medical Errors after Implementation of a Handoff Program." *NEJM*. 2014. https://doi.org/10.1056/NEJMsa1405556 [keep | L3 | Core] A bundle: errors down 23%, preventable adverse events down 30%, key-element inclusion up, handoff time unchanged; six of nine sites significant.
- **S2-10.** Starmer AJ, Spector ND, O'Toole JK, Bismilla Z, et al. "Implementation of the I-PASS handoff program in diverse clinical environments." *Journal of Hospital Medicine*. 2022. https://doi.org/10.1002/jhm.12979 [keep | L3 | Supporting] 32 hospitals with 18 months of coaching: key-element inclusion 20% to 66% (verbal), receiver synthesis 31% to 83%, reported events down 47%.

### Track S3: amount and layering

- **S3-01.** Arnold M, Goldschmitt M, Rigotti T. "Dealing with information overload: a comprehensive review." *Frontiers in Psychology*. 2023. https://doi.org/10.3389/fpsyg.2023.1122200 [keep | L1 | Supporting] 87 papers on overload prevention and intervention; evidence for interventions mixed.
- **S3-02.** Chernev A, Bockenholt U, Goodman J. "Choice overload: A conceptual review and meta-analysis." *Journal of Consumer Psychology* 25(2):333-358. 2015. https://doi.org/10.1016/j.jcps.2014.08.002 [keep | L1 | Core] Four moderators (set complexity, task difficulty, preference uncertainty, effort-minimizing goal) govern overload.
- **S3-03.** Cockburn A, Karlson A, Bederson BB. "A review of overview+detail, zooming, and focus+context interfaces." *ACM Computing Surveys* 41(1). 2008. https://faculty.cc.gatech.edu/~stasko/7450/Papers/cockburn-surveys08.pdf [keep | L1 | Core] Combined views can beat single views, task-dependent, no clear guidelines, integration costs mental effort.
- **S3-04.** Dang J, Xiao S, Mao L, Liu X. "Revisiting Ego Depletion: Evidence from Multi-Lab Collaborations." *Journal of Pacific Rim Psychology*. 2025. https://doi.org/10.1177/18344909251386084 [keep | L2 | Supporting] 14 samples: small depletion effect, but only after 30 to 40 minutes of intense exertion.
- **S3-05.** Dean M, Ravindran D, Stoye J. "A Better Test of Choice Overload." arXiv:2212.03931 (preprint, revised 2025). https://arxiv.org/abs/2212.03931 [keep | L3 | Supporting] Argues usual tests are underpowered, so overload may be under-reported; preprint.
- **S3-06.** Glockner A. "The irrational hungry judge effect revisited." *Judgment and Decision Making* 11(6):601-610. 2016. https://jbaron.org/journal/16/16823/jdm16823.pdf [keep | L3 | Core] Original effect implies d = 1.96; a rational-judge simulation reproduces it.
- **S3-07.** Hagger MS, Chatzisarantis NLD, et al. "A multilab preregistered replication of the ego-depletion effect." *Perspectives on Psychological Science* 11(4):546-573. 2016. https://research-portal.uu.nl/en/publications/a-multilab-preregistered-replication-of-the-ego-depletion-effect/ [keep | L2 | Core] 23 labs, N = 2,141: d = 0.04, CI -0.07 to 0.15.
- **S3-08.** Iyengar SS, Lepper MR. "When choice is demotivating: Can one desire too much of a good thing?" *Journal of Personality and Social Psychology* 79(6):995-1006. 2000. https://pubmed.ncbi.nlm.nih.gov/11138768/ [keep | L2 | Supporting] Origin of "fewer options": 6 beat 24 or 30 on purchase and satisfaction; later meta-analysis found the mean near zero.
- **S3-09.** Jachimowicz JM, Duncan S, Weber EU, Johnson EJ. "When and why defaults influence decisions: a meta-analysis of default effects." *Behavioural Public Policy* 3(2):159-186. 2019. https://ideas.repec.org/a/cup/bpubpo/v3y2019i02p159-186_00.html [keep | L1 | Core] 58 studies: d = 0.68 with wide variation; stronger when the default reads as endorsement.
- **S3-10.** Maier M, Bartos F, Stanley TD, Shanks DR, Harris AJL, Wagenmakers EJ. "No evidence for nudging after adjusting for publication bias." *PNAS* 119(31). 2022. https://pmc.ncbi.nlm.nih.gov/articles/PMC9351501/ [keep | L1 | Supporting] After bias correction, no evidence for nudging overall; structure interventions undecided.
- **S3-11.** Maier M, Powell D, Murchie P, Allan J. "Systematic review of the effects of decision fatigue in healthcare professionals on medical decision-making." *Health Psychology Review*. 2025. https://doi.org/10.1080/17437199.2025.2513916 [keep | L1 | Core] 82 studies: 45% of tested cases showed decision-fatigue effects; construct inconsistently defined.
- **S3-12.** Morkes J, Nielsen J. "Concise, SCANNABLE, and Objective: How to Write for the Web." Nielsen Norman Group. 1997. https://www.nngroup.com/articles/concise-scannable-and-objective-how-to-write-for-the-web/ [borderline | L5 | Supporting] 51 users: concise +58%, scannable +47%, objective +27%, all three +124% usability; web text.
- **S3-13.** Nielsen J. "Progressive Disclosure." Nielsen Norman Group. 2006. https://www.nngroup.com/articles/progressive-disclosure/ [borderline | L7 | Supporting] Frequent needs on the first display; beyond two disclosure levels usability falls.
- **S3-14.** Romero Meza L, D'Urso G. "User's Dilemma: A Qualitative Study on the Influence of Netflix Recommender Systems on Choice Overload." *Psychological Studies*. 2024. https://doi.org/10.1007/s12646-024-00807-0 [borderline | L6 | Supporting] 12 interviews: high trust in recommendation lists and frustration when they miss.
- **S3-15.** Scheibehenne B, Greifeneder R, Todd PM. "Can there ever be too many options? A meta-analytic review of choice overload." *Journal of Consumer Research* 37(3):409-425. 2010. https://archive-ouverte.unige.ch/unige:76440 [keep | L1 | Core] 63 conditions: mean effect of assortment size virtually zero; no sufficient conditions found.
- **S3-16.** Shneiderman B. "The Eyes Have It: A Task by Data Type Taxonomy for Information Visualizations." *IEEE Symposium on Visual Languages*. 1996. https://www.cs.umd.edu/~ben/papers/Shneiderman1996eyes.pdf [borderline | L7 | Supporting] Overview first, zoom and filter, details on demand; a taxonomy its author calls a starting point.
- **S3-17.** Vohs KD, Schmeichel BJ, Lohmann S, Gronau QF, et al. "A multisite preregistered paradigmatic test of the ego-depletion effect." *Psychological Science*. 2021. https://doi.org/10.1177/0956797621989733 [keep | L2 | Core] 36 labs, N = 3,531: d = 0.06, data about four times likelier under the null than under an informed prior of δ = 0.30 (SD 0.15).
- **S3-18.** Willemsen MC, Graus MP, Knijnenburg BP. "Understanding the role of latent feature diversification on choice difficulty and satisfaction." *User Modeling and User-Adapted Interaction* 26(4):347-389. 2016. https://doi.org/10.1007/s11257-016-9178-6 [keep | L2 | Core] Small diverse recommendation sets were as satisfying as top-N lists and less effortful.

### Excluded sources (5; cards on disk, not cited as evidence)

- **X-1.** Dulwich Centre, "What is Narrative Therapy?" [reject | L7 | Excluded, Rule 6]. Statement of the externalization premise with no outcome data; kept as a card so the cut is visible.
- **X-2.** Shimmer ADHD Coaching, "Can naming your feelings help ADHD?" 2024 [reject | L9 | Excluded, Rule 5]. Unqualified claim that naming lowers intensity; the practitioner overclaim that Nook and Ariely contradict.
- **X-3.** carmen_authenticallyadhd Substack, "AuDHD, Alexithymia, and Anhedonia." 2026 [reject | L8 | Excluded, override of Rule 2]. Lived-experience anecdote; illustrates the unnamed-state problem only.
- **X-4.** Just1Voice, "Feelings Wheel for Alexithymia." 2022 [reject | L8 | Excluded, override of Rule 2]. Single self-report describing the wheel as a stepwise lookup.
- **X-5.** NICABM, "How to Expand a Client's Window of Tolerance" [reject | L9 | Excluded, Rule 5]. Marketing-adjacent, no evidence; superseded by the PA DHS sheet and Corrigan 2011.
