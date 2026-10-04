Generated: 2026-10-03

# Why One-Page Cheat Sheets Work

*Conducted: 2026-10-03 | Methodology: deep-research (full tier) | AI-scoring: 80/100*

---

## Glossary: read this first

- **ADHD** (attention-deficit/hyperactivity disorder): a condition where attention, impulse control and the ability to
  juggle information in your head work less reliably than in most people.
- **Working memory**: the mental scratchpad that holds a few things while you use them, like a phone number between
  hearing it and dialing it.
- **Job aid**: a sheet, card or checklist you consult while doing a task so you do not have to remember the steps.
- **Effect size (d, g, r)**: one number for how big a difference or link is. By rule of thumb 0.2 is small, 0.5 medium
  and 0.8 large for d and g (group comparisons); for r (a correlation) about 0.15 is small.
- **RCT** (randomized controlled trial): a study that assigns people to get the thing or not by chance, the cleanest
  way to test whether something works.
- **Meta-analysis**: a study that pools the results of many earlier studies into one estimate.
- **Affect labeling**: putting a word on a feeling ("I'm anxious") and then checking whether the feeling changes.
- **Emotion differentiation (granularity)**: how finely someone can tell similar feelings apart, such as annoyed versus
  resentful versus contemptuous.
- **Implementation intention**: an "if X happens, then I will do Y" plan made ahead of time.
- **Push vs. pull**: push means the tool interrupts you with a prompt; pull means you go look at it because you need it.
- **JITAI** (just-in-time adaptive intervention): a prompt that fires at a moment picked by rules about what the person
  is doing or feeling right now.
- **Alert fatigue**: the habit of ignoring prompts once there are too many of them or too many are useless.

---

## 1. Recommendations

These are evidence-level statements: what the literature says works, fails, or is unproven. Turning them into specific
features is a separate, later step. The evidence tiers behind each one are spelled out in §3 and §4.

1. **Treat a one-page aid as a small first step, not a treatment.** Passive psychoeducation (reading a handout with no
   clinician) pooled to d = 0.20, with a confidence interval that nearly touches zero (§3 principle 9; §4.3).
2. **Give each aid one main message and no more than about four groups of items.** Stripping decoration produced the
   largest effects in the multimedia meta-analysis, and working memory holds roughly four chunks (§3 principle 1).
3. **Make the aid visible where the work happens, so the user recognizes the next move instead of recalling it.** ADHD
   is described as a failure to use known information at the moment of need, and stress degrades the prefrontal
   machinery that does recall (§3 principle 2; §4.4).
4. **Pair every named state with a next move.** Naming a feeling correlates with better regulation through how
   strategies get used, and naming before a regulation step made people feel worse in two experiments (§3 principle 3).
5. **Show problem and counter-move side by side, as contrasting pairs.** Case comparison beat single examples at
   d = 0.50 across a meta-analysis; pairing errors with corrections reached d = 0.44 (§3 principle 4).
6. **Build the vocabulary from the user's own failure data and keep it small and closed.** The only published precedents
   (11 developer-frustration categories, 6 programmer learning barriers) were derived from observation, and nobody has
   tested whether showing the list helps (§3 principle 5).
7. **Write scripts as short, rehearsed if-then plans with one or two prompts.** Contingent plans beat other formats, but
   the bias-corrected effect shrinks to between 0.15 and 0.35 (§3 principle 6).
8. **Highlight few things and make those few physically distinct.** If everything is highlighted, the cue stops working,
   and the picture benefit may come from distinctiveness rather than pictures (§3 principle 7).
9. **Default to pull. Use push rarely, tied to context, and measure whether it is acted on.** Two adult-ADHD trials
   found no effect from generic reminders or from an app people liked, and alert fatigue is documented (§3 principle 8).
10. **Avoid duplicating what the user already tracks, avoid mandating the aid, and avoid letting it grow.** Duplication
    was the top barrier in 16 of 18 cancer centers, and the mandated rollout in Ontario showed no outcome change
    (§3 principle 10).
11. **Label diagrams as heuristics and do not quote prediction accuracy for them.** The window-of-tolerance chart is a
    trauma-clinic hypothesis, the inverted-U arousal curve has been called folklore, and the Four Horsemen prediction
    figures failed to replicate in one independent sample (§3 principle 11; §4.3).
12. **Test locally before trusting any of this.** No study in the corpus tests a one-page aid with adult ADHD users or
    developers; several tests are cheap to run on your own logs (§2, testability paragraph).

---

## 2. Summary

Picture a trail marker at a fork. The hiker reading it is tired, a little lost, and has about two seconds. If the marker
carries one arrow and one word, she takes the right branch. If it carries a paragraph of local history, she guesses.
The six sheets in this study (a feelings wheel, a "wise mind" Venn diagram, an Internal Family Systems parts map, a
Nonviolent Communication fill-in script, a window-of-tolerance chart, and Gottman's Four Horsemen with antidotes) are
all trail markers for emotional terrain. The question was what makes such a marker work, and which of those features
carry over to the project and workflow terrain of a solo developer with ADHD. The run evaluated 59 sources across four
tracks, kept 54, and had an independent verifier check 18 of the 59 cards (0 failed).

**The sheets themselves are unproven as sheets.** No published evaluation of the Willcox feelings wheel turned up; its
own profile page says it "does not establish" effectiveness. Internal Family Systems (IFS, a therapy that treats the
mind as a team of "parts") has a "strikingly small" trial base, and the one RCT in the corpus tested a 9-month therapy
package for rheumatoid arthritis, not a map. The Nonviolent Communication (NVC, a four-slot speaking script) trial
tested an 8-hour course plus a journal and found no change in stress. For Dialectical Behavior Therapy (DBT, the skills
program that contains "wise mind"), the strong evidence is for skills training, and no study isolates the Venn handout.
The Four Horsemen prediction figures (93% accuracy) were in-sample, and an independent team found only 2 of 22
affective processes replicated. The window-of-tolerance chart is a hypothesis about trauma, and the inverted-U arousal
curve it resembles has been called folklore. NICABM (a continuing-education company) promotes the chart with no outcome
data, so that source was cut.

**The design principles underneath the sheets are better supported than the sheets.** Across meta-analyses and trials,
the same few features recur: one main message, small groups, decoration removed, text paired with a diagram, contrasting
pairs, if-then phrasing, and recognition instead of recall. Effects are modest (multimedia g = 0.37, if-then d between
0.15 and 0.35 after bias correction, passive handouts d = 0.20), which is the right size to expect from a trail marker.
It will not carry the hiker up the mountain; it only keeps her from taking the wrong fork.

**Naming a state is a handle, not a fix.** Emotion differentiation (telling similar feelings apart) correlates with
less dysregulated behavior at r = -0.15, a small link, and seems to work by improving how a chosen strategy is used, not
which strategy gets chosen. Two experiments (N = 80 and N = 60) found that naming before reappraising made people feel
worse, and a 2026 replication (N = 226) found the hoped-for delayed benefit did not appear. Teaching emotion words did
not directly lower distress in a 2024 trial. An aid that stops at "name it" has no support, while one that says "name
it, then do this" has a plausible mechanism and little direct testing.

**Push is the weak link.** An SMS reminder trial and an app trial in adults with ADHD both came back null on adherence,
even though users liked the app. A systematic review of clinician alerts found they get ignored when frequent, badly
presented or inaccurate. The just-in-time prompt framework is elegant, but the review of mental-health versions found
only five and called their timing rules empirically unsupported. The theory-backed alternative is to make the
information visible at the point of performance (where the work happens), and that alternative rests on mechanism, not
on an ADHD trial.

Experts agree on small groups, no decoration, recognition over recall, and a modest effect from handouts. They disagree
about whether naming regulates emotion, whether checklists save lives once mandated, whether pictures work through dual
coding or distinctiveness, and whether emotion dysregulation is core to ADHD. What surprised me most was how often the
original authors are the ones conceding the limits: the surgical-checklist originators wrote that mandated use "has, on
occasion, failed to result in meaningful improvements".

Evidence quality is mixed in a specific way. Of the 54 included sources, 22 are Level 1 or 2 (meta-analyses or RCTs; the
levels are explained in §5), but nearly all test a neighboring thing: children instead of adults, a course instead of a
sheet, surgeons instead of developers. No card reports a test of a one-page aid on adult ADHD users or on developers,
and none was run here, so the transfer to a solo developer is reasoning from neighbors and the findings are predictions
with a literature behind them.

**Testability.** Cheaply testable in your own environment: whether a draft aid passes a binary design rubric such as the
20-item CDC Clear Communication Index (CDC is the US Centers for Disease Control and Prevention); whether nudges you
already receive get acted on, using existing hook logs over a few weeks; and whether an if-then script gets opened at
all, by logging opens. Testable but slow: whether a small closed vocabulary of "stuck" types shortens time-to-unblock,
which needs weeks of your own data. Declared untestable here: durability over months and generalization to other people
(a single user cannot show either), and the causal mechanisms behind naming effects (they need controlled lab work).

**The one thing to remember:** a one-page aid works like a trail marker, so build it to show one decision, at the place
and moment it is needed, with a next move attached to every name, and keep it silent until someone looks.

---

## 3. Design Principles for a One-Page Aid

The research did not hand over a ready-made model, so this section builds one: eleven principles, each tied to the
cards that support it, each with an evidence-strength label. **Strong** means a meta-analysis or several RCTs speak
directly to the point. **Moderate** means Level 1 or 2 evidence with a gap in population or setting, or consistent
mid-level evidence plus a mechanism. **Weak** means a single study, descriptive work, or expert statement only.
**Theory-only** means the claim follows from a mechanism and nobody has tested it for this use. No principle earns
Strong. Card tags like [C1-09] point to the bibliography in §7. The six sheets are described by their design features
and not reproduced; those feature descriptions come from the run brief and from the Alexithymia Awareness Network (AAN)
and Pennsylvania Department of Human Services pages, not from a card on each sheet.

**Principle 1: one message, few chunks, no decoration.** Moderate. The CDC Clear Communication Index asks for one main
message statement ("the one thing the audience must remember") in one to three short sentences and for splitting any
list longer than seven [C1-01]. Cowan's review puts the real working-memory limit at about four chunks and notes that
Miller's seven was a "rhetorical device" [C1-02]. The Level 1 evidence is Mayer's multimedia meta-analysis (92 articles,
181 studies): overall g = 0.37, with the largest effects for removing seductive detail (interesting but irrelevant
material), sentence-level coherence and text plus diagrams [C1-09]. Mayer's corpus is one research programme's own work,
and de Jong's critique says cognitive load theory is a design heuristic and not a law, so the right use is "remove
clutter", not "budget exactly four boxes" [C1-03].

**Principle 2: recognition at the point of performance.** Moderate for the mechanism, Theory-only for adult ADHD.
Nielsen Norman Group's sixth usability heuristic says information needed "should be visible or easily retrievable when
needed" because recognition costs less than recall [C1-10]. Kofler's study of 172 children found central-executive
working-memory deficits of d = 1.63 to 2.03 in ADHD, with the problem in manipulating held information and not in simple
storage [C1-08]. Arnsten's review shows even mild uncontrollable stress rapidly impairs prefrontal working memory,
mostly from animal and cellular work [C4-01]. Barkley frames ADHD as failing to use known information at the moment of
need and says information must be externalized at that point [C4-02], and Risko and Gilbert explain that offloading is
driven by beliefs about one's own memory, not just actual capacity [C4-09]. All of it points to "design for the worst
working-memory day". But no card tests point-of-performance aids in adult ADHD, and the adult working-memory
meta-analysis the C4 track wanted was not located.

**Principle 3: every name routes to a next move.** Moderate for "label plus response", Weak for "vocabulary alone".
Kalokerinos found that finer emotion differentiation did not predict which regulation strategy people chose, but people
with low differentiation got worse results from the same strategies, in two experience-sampling studies with 34,660 and
6,282 measurements [C2-05]. The pooled link between differentiation and behavioral dysregulation is small, r = -0.15,
across 17 studies [C2-11]. Against the idea that a label is automatically calming, naming before reappraisal left
people feeling worse in experiments with N = 80 and N = 60 [C2-10], and a 2026 replication (N = 226) saw labeling reduce
reappraisal's effectiveness with no delayed benefit at the 1 to 2 day follow-up [C2-02]. Torre and Lieberman's review,
from the lab that started the field, calls labeling "implicit" regulation and admits boundary conditions are not
understood [C2-14]; Lieberman's original fMRI study showed the amygdala quieting when people labeled [C2-08]. The design
reading is to use the name to select a response, as the Pennsylvania state-map tip sheet does by pairing each of its
three zones with symptoms and re-engagement actions [C3-14], and never to promise that the name itself does the work.

**Principle 4: pair the problem with its counter-move, shown as a contrast.** Moderate for the mechanism, Weak for the
one-page format. Alfieri's meta-analysis found case comparison beats single-case and sequential presentation at
d = 0.50 (95% CI 0.44 to 0.56) [C3-01], and Keith and Frese's meta-analysis of 24 studies found error-management
training at d = 0.44, strongest for novel tasks at d = 0.80 [C3-10]. Both justify a layout with "what going wrong looks
like" next to "what to do instead". The problem-listing half of the Four Horsemen sheet has contested support: Gottman
and Levenson's sample of 79 couples found criticism, defensiveness, contempt and stonewalling distinguished early
divorce, with a model "predicting divorce with 93% accuracy" in-sample [C3-07], while Kim and colleagues found "the
major findings failed to replicate", with only 2 of 22 affective processes related to outcomes in 85 at-risk couples
[C3-11]. No card tests the antidote half at all.

**Principle 5: a small closed vocabulary, built from the audience's own failures.** Weak. Ford and Parnin sorted 45
developers' recalled frustrations into 11 cause categories, and 67% rated their latest frustration severe [C2-04]; Ko,
Myers and Aung watched beginners and found six learning barriers, each implying a different remedy [C2-06]. These are
the closest precedents for a "stuck types" list, and both are descriptive. Two process points come from elsewhere:
pictograph interventions "need to be carefully developed and validated with both the targeted patient population"
[C1-13], and the CDC guide says its Index "cannot take the place of formative research or pretesting" [C1-01]. Nobody in
the corpus tested whether showing people a taxonomy changes what they do.

**Principle 6: scripts as rehearsed if-then plans.** Moderate in general, Weak for adult ADHD, Weak for feeling-sentence
scripts. The 2025 meta-analysis of 642 tests found raw effects of d = 0.27 to 0.66, larger for contingent (if-then)
plans and rehearsed ones, but the trim-and-fill correction gives d = 0.35 and a Robust Bayesian estimate gives d = 0.15
with "extreme" evidence of publication bias [C3-09]; it also found no reliable effect on vaccination or voting. In
children with ADHD, adding an if-then plan raised response inhibition to the level of non-ADHD children and stacked with
medication, on a lab task [C3-06]. An ADHD coach advises picking one or two prompts out of a when/where/what list,
designing for low-energy days with a "smallest possible version", and reviewing without pass or fail [C3-02]. For the
NVC style of sentence, the only experimental support is a vignette study in which an opener combining the speaker's
feeling and the other person's perspective was rated least hostile [C3-08], plus the training RCT whose gains were in
empathy and relationships, not stress [C3-13].

**Principle 7: sparse, distinctive visual cues.** Weak to Moderate. Few's practitioner synthesis says the eye picks up a
difference in color, shape or position without effort, but only position and length encode quantity accurately [C1-04].
Mayer's meta-analysis found cueing only a medium effect [C1-09]. Higdon and colleagues report that the picture advantage
vanished against typographically distinctive words, arguing that distinctiveness and not dual coding is the cause
[C1-07]; that is one research group, so treat it as a live debate. The pictograph review is more favorable, with 48 of
56 studies supportive, though its authors call the evidence "promising" and not conclusive [C1-13]. The practical
reading is that a few items made distinct beat many items decorated.

**Principle 8: pull by default, push rarely and with context.** Moderate for "generic push does not help", Weak for any
positive alternative. In a micro-randomized trial in adults with ADHD, SMS reminders had no effect on module completion,
logins or practice [C4-08]. In a 73-person RCT, the FOCUS app produced no difference in adherence even though adoption
and usability ratings were favorable, so liking is not efficacy [C4-05]. A qualitative systematic review of nine studies
ties clinician alert fatigue to frequency, presentation and accuracy [C4-06]. Nahum-Shani's framework says support given
when the person is not receptive "may not help and can harm engagement" and that decision-point frequency should match
how fast the situation really changes [C4-07]. Van Genugten's review found only five mental-health JITAIs and called
their decision rules empirically unsupported [C4-11]. "Just in time" is therefore a hypothesis, and "visible when you
look" is the lower-risk default.

**Principle 9: a handout is a first step and wants practice behind it.** Moderate. Donker's meta-analysis found passive
psychoeducation at d = 0.20 (95% CI 0.01 to 0.40) from only 4 RCTs out of 9,010 screened abstracts [C3-05]. In the DBT
component trial, interventions with skills training beat those without, which says the taught and practiced skill is the
active ingredient and not the handout [C3-12]. The NVC trial couples 8 hours of education with a 5-week journal [C3-13].
Expect the sheet to cut friction and to support rehearsed behavior, not to supply the behavior.

**Principle 10: do not duplicate, mandate, or let the sheet grow.** Moderate. Fourcade's audit of 1,440 procedures in 18
cancer centers found 90.2% compliance but only 61% completion, with duplication of existing checklists as the top
barrier (16 of 18 centers) [C1-05]. Thomassen's focus groups warn that an "excessive or improperly designed list could
cause checklist fatigue" and block a better list later [C1-11]. The original WHO checklist study associated the
checklist with a fall in deaths from 1.5% to 0.8% [C1-06], but Ontario's mandated rollout across 101 hospitals saw no
significant change [C1-12], and the checklist's originators concede it "may encourage box-ticking" and that thoughtful
local implementation is what works [C1-14]. For a solo developer, "mandated" translates to a rule imposed on yourself
that you did not help write, and "duplication" translates to a second place restating what the tracker already says.

**Principle 11: diagrams are heuristics, not measurements.** Moderate. The window-of-tolerance model is described by its
peer-reviewed source as a model of the effects of severe trauma with proposed mechanisms [C3-04]; the inverted-U arousal
curve it resembles "has no basis in empirical fact" according to Corbett [C3-03]; IFS's evidence base is small enough
that its critics say use has "moved beyond" it [C2-03]; the Four Horsemen prediction has the replication problem above;
and the feelings wheel's own advocate page refuses any claim that it is a measure or a treatment [C2-01]. A sheet can
still be useful as a shared picture, but it should say so, and it should not borrow a percentage from a study.

| # | Principle | Strength | Core cards |
|---|-----------|----------|-----------|
| 1 | One message, few chunks, no decoration | Moderate | C1-01, C1-02, C1-09, C1-03 |
| 2 | Recognition at point of performance | Moderate (mechanism) / Theory-only (adult ADHD) | C1-10, C1-08, C4-01, C4-02, C4-09 |
| 3 | Every name routes to a next move | Moderate / Weak (vocabulary alone) | C2-05, C2-11, C2-10, C2-02, C3-14 |
| 4 | Problem and counter-move as contrast | Moderate (mechanism) / Weak (format) | C3-01, C3-10, C3-07, C3-11 |
| 5 | Small closed vocabulary from own failures | Weak | C2-04, C2-06, C1-13, C1-01 |
| 6 | Rehearsed if-then scripts | Moderate / Weak (adult ADHD) | C3-09, C3-06, C3-02, C3-08, C3-13 |
| 7 | Sparse, distinctive cues | Weak to Moderate | C1-04, C1-07, C1-09, C1-13 |
| 8 | Pull by default, push rarely | Moderate (push null) / Weak (alternative) | C4-08, C4-05, C4-06, C4-07, C4-11 |
| 9 | First step, wants practice | Moderate | C3-05, C3-12, C3-13 |
| 10 | No duplication, no mandate, no growth | Moderate | C1-05, C1-11, C1-12, C1-14 |
| 11 | Heuristic, not measurement | Moderate | C3-03, C3-04, C3-11, C2-03, C2-01 |

**Boundary conditions.** Almost every effect size above comes from a population unlike a solo developer: children
(Kofler, Gawrilow), trauma patients (the window of tolerance), nursing students (NVC), hospitals (checklists), or
undergraduates (affect labeling). The principles hold together across those populations, which earns modest confidence
and no more. As frameworks go, this set sits closest to the job-aid tradition (checklists, cognitive load) plus the
just-in-time-intervention tradition. The classic job-aid handbook by Rossett and Gautier-Downes, which reportedly says
job aids fit infrequent, high-error-cost tasks and fit fluid, speed-critical work poorly, was not accessible in full
(see §6, paywalled sources) and is not a basis for any claim here.

---

## 4. Analysis

### 4.1 What design features make a one-page aid work? (Track C1 and part of C3)

**Research question:** which layout, memory and visual-encoding features of job aids and handouts have evidence behind
them?

**What the evidence says.** The firmest ground is subtractive. Mayer's meta-analysis [C1-09] and the CDC guide [C1-01]
agree that one message, no seductive detail and text paired with a diagram are the useful moves, and Wang and Voss's
systematic review [C1-13] backs pictures in patient education (48 of 56 studies supportive). Recognition over recall
has a practitioner heuristic [C1-10] and a mechanism in limited working memory [C1-02], [C1-08].

**Where sources agree.** Reduce load, group small, and show the options instead of asking the user to remember them. The
applied sources (CDC, Nielsen Norman Group, Few) and the lab sources (Cowan, Mayer, Kofler) point the same way.

**Where sources disagree.** Why pictures help is contested, since Higdon's experiments say distinctiveness and not dual
coding [C1-07]. How much cognitive load theory can predict is contested too: de Jong calls it a heuristic with
"problematic conceptual, methodological and application-related issues" [C1-03]. Whether checklists save lives is
contested between Haynes [C1-06] and Urbach [C1-12], with Weiser and Haynes [C1-14] explaining the gap as local
implementation and fidelity. Haynes is a before/after design with no concurrent control (Level 3) and Urbach a
101-hospital natural experiment (also Level 3), so the evidence level does not break the tie.

**What is missing.** No experiment ties chunk count to comprehension of a printed sheet. Colour-coding research was seen
but not read (Christ 1975 is paywalled). Nothing tests a one-page cheat sheet for developers against alternatives, and
Rossett's job-aid fit criteria were not read first-hand.

**Institutional vs. ground truth.** The CDC guide offers 20 binary items and a pass mark of 90 [C1-01], which is neat
and checkable, and the CDC itself says no rubric replaces pretesting. On the ground, Fourcade measured 90.2% compliance
beside 61% completion [C1-05]: the form was used and mostly not done. Thomassen's clinicians describe the checklist
drawing attention away from the patient [C1-11]. The institution's rule list and the operating room's reality differ by
about 30 percentage points of fidelity.

### 4.2 Does a named, shared vocabulary help? (Track C2)

**Research question:** do feeling wheels, parts maps and "stuck" taxonomies help people regulate or act, and through
what mechanism?

**What the evidence says.** There is a small, robust, correlational link: lower emotion differentiation goes with more
maladaptive regulation behavior (r = -0.15, 17 studies, the same in clinical and nonclinical samples [C2-11]), and the
mechanism seems to be better use of strategies [C2-05]. Putting a word on a feeling lowers amygdala response in the
lab [C2-08].

**Where sources agree.** Granularity is associated with better outcomes, labeling has some lab effects, and no source
claims a large effect.

**Where sources disagree.** The main fight is whether labeling regulates at all outside the original lab. Torre and
Lieberman defend implicit regulation while admitting unknown boundaries [C2-14]. Nook's two experiments found naming
impedes reappraisal and mindful acceptance [C2-10], and Ariely's replication in 226 people found the same with no
delayed benefit [C2-02]. A 2026 preprint meta-analysis (not peer reviewed, one screener, self-corrected) estimates g =
-0.49 on peripheral physiology but only g = -0.23 in labs independent of the original group versus -0.74 inside it
[C2-15]; it is used here only as a directional flag. On whether vocabulary can be taught, Matt's brief word-training
trial found no direct effect on differentiation or distress, with exploratory signals only for those who engaged more
[C2-09]. On whether the construct is measured well, Thompson's review notes a disconnect between how granularity is
defined and how it is measured [C2-13]. For parts-based models, IFS has about three studies behind it [C2-03] and its
best RCT tested a package in arthritis patients [C2-12]. Third-person self-talk reduced a neural marker of
self-referential reactivity without engaging control networks [C2-07], which supplies a plausible distance mechanism for
"it's a part of me, not me" framings.

**What is missing.** No evaluation of the Willcox wheel exists in what was found [C2-01]. Nobody has tested whether
showing a wheel or taxonomy to adults with ADHD changes behavior. The commonly quoted 20 to 40% figure for ADHD with
alexithymia (difficulty identifying one's own feelings) traced to lay pages and no primary source, so it was not used
(C2 search log).

**Institutional vs. ground truth.** The practitioner layer overclaims: a coaching-company post (excluded, X-2) says
naming feelings lessens overwhelm and impulsivity with no evidence, against Nook and Ariely. The advocacy organization's
page on the wheel was the most careful voice in the set [C2-01]. One personal blog (excluded, X-4) describes working
through the wheel from the outer ring inward as a step-by-step lookup, not a glance-and-feel chart; that is a single
self-report, but it changes how one would design for speed. A Substack post (excluded, X-3) describes unnamed feelings
arriving as "mystery symptoms", which illustrates the audience problem without testing any tool.

### 4.3 Do scripts, state maps and problem/antidote pairings work? (Track C3)

**Research question:** is there evidence for fill-in scripts, zone charts and paired problem/fix layouts, and for
psychoeducation sheets generally?

**What the evidence says.** If-then planning is the best-supported ingredient [C3-09], with a bias-corrected effect
about a third of the headline. Contrast and error-based learning are well supported as methods [C3-01], [C3-10]. Passive
psychoeducation shows a small effect [C3-05], and skills training outperforms its absence [C3-12].

**Where sources agree.** Format matters (contingent beats other plan types), rehearsal matters, and taught skills beat
leaflets.

**Where sources disagree.** On the Four Horsemen, 93% in-sample accuracy [C3-07] meets a failure to replicate [C3-11],
and the authors' own data show negative affect predicted early but not later divorce, so even the original is a partial,
time-limited predictor. On the window of tolerance, a peer-reviewed formulation as a model [C3-04] sits beside a
critique of the inverted-U that shaped how such charts are drawn [C3-03]. NVC training was positive on empathy and null
on stress [C3-13].

**What is missing.** No controlled study of the wise-mind Venn handout, of a window-of-tolerance chart as a handout, or
of Horsemen antidotes. The cross-validation critique of Gottman's accuracy (Heyman and Slep 2001) is paywalled and
unread, and the homework-adherence meta-analysis (Kazantzis 2010) was blocked.

**Institutional vs. ground truth.** The Pennsylvania DHS tip sheet is a clean example of the format: three zones,
symptoms per zone, actions per zone, one page [C3-14]. It carries no outcome data. Its source article at NICABM calls
the chart "an easy psychoeducational tool" and teaches by wave and dam metaphor with no data, which is why NICABM was
excluded (X-5) and the state agency's sheet kept as the exemplar.

### 4.4 What works in the moment, with ADHD? (Track C4)

**Research question:** for a person with ADHD whose executive function (the brain's planning and self-control skills) is
strained, should an aid push prompts or wait to be pulled, and what makes prompts stop working?

**What the evidence says.** ADHD carries large working-memory deficits in children [C1-08], emotion dysregulation is
common across the lifespan [C4-10], [C4-04], and acute stress impairs prefrontal function [C4-01]. Hence the theory that
information and motivation need to sit outside the head at the point of performance [C4-02], [C4-03]. In practice,
generic reminders [C4-08] and a well-liked app [C4-05] did not change adherence, and alert fatigue is documented
[C4-06].

**Where sources agree.** Externalize rather than rely on recall; do not expect plain reminders to rescue adherence; too
many prompts erode response.

**Where sources disagree.** On whether the just-in-time idea works, Nahum-Shani gives six design elements and the idea
of receptivity [C4-07], and van Genugten finds the mental-health evidence thin, with receptivity and adaptivity often
missing [C4-11]. On whether emotion dysregulation is core to ADHD, the Faraone panel says it may be specific enough to
serve as a diagnostic criterion with debate continuing [C4-04], and Shaw's review says the field lacks consensus
[C4-10].

**What is missing.** No RCT of point-of-performance prompts or visual externalization in adult ADHD. No adult
working-memory meta-analysis was located, and a primary study of notification habituation was not found. No
lived-experience source cleared the credibility bar, so the ground-level view is thin (see §6, limitations).

**Institutional vs. ground truth.** The clinical handouts (CHOP) and Barkley's fact sheet carry theory without trial
data. The ground-level voices that were found and rejected on the rubric say the same thing from the other side. A
Substack discussion thread (Level 8, in the C4 search log, not carded) quotes "The alarm is still going off. You are
still dismissing it," and a developer's tool-stack post (also rejected, affiliate links) says "Adopting all six at once
usually backfires. Each one adds a habit you have to remember to run, and remembering to run habits is exactly the
function that's unreliable in the first place." Neither is evidence, and both illustrate the failure the two null RCTs
measured.

### 4.5 Cross-cutting tensions

Two collisions are worth stating. Several sheets start with "name what's happening", while Nook and Ariely show that
naming before regulating can make things worse and Kalokerinos shows that naming helps by improving how a strategy is
used. My reading, an inference and not a finding, is to put the name in step one and a matched action in step two on the
same page, so naming never stands alone. Likewise Barkley says to act at the point of performance, while Nordby and the
FOCUS trial show prompts at a chosen time failing. The reconciling reading, also an inference, is that "where" (a cue
visible in the place of work) and "when" (an interrupt) are different levers, and only the first has theory support.

---

## 5. Research

Format: **Author year** [ID] [band | evidence level]. Band is keep, borderline or reject; evidence level is 1 to 9
(1 = systematic review or meta-analysis, 2 = RCT, 3 = large observational or lab experiment, 4 = expert consensus or
professional body, 5 = practitioner case study or mixed methods, 6 = qualitative, 7 = expert opinion or narrative
review, 8 = anecdote, 9 = marketing).

### Track C1: job aids and visual design (14 sources)

- **CDC 2019** [C1-01] [borderline | L4]. Twenty zero-or-one items, 90 or higher passes; one main message in 1 to 3
  sentences; split lists longer than seven; the guide says it cannot replace pretesting.
- **Cowan 2001** [C1-02] [keep | L7]. Capacity is about four chunks once rehearsal and recoding are controlled; Miller's
  seven was "a rhetorical device".
- **de Jong 2010** [C1-03] [keep | L7]. Cognitive load theory's premise (limited working memory) stands, but its
  conceptual and methodological issues make it a heuristic.
- **Few 2004** [C1-04] [borderline | L7]. Pre-attentive attributes make one thing stand out; only position and length
  encode quantity accurately.
- **Fourcade 2012** [C1-05] [keep | L5]. 90.2% compliance but 61% completion across 18 centers; duplication the top
  barrier.
- **Haynes 2009** [C1-06] [keep | L3]. Death 1.5% to 0.8% and complications 11.0% to 7.0% in 8 hospitals; no concurrent
  control.
- **Higdon 2025** [C1-07] [keep | L2]. Picture advantage eliminated against distinctive words; dual coding "no longer a
  viable explanation".
- **Kofler 2020** [C1-08] [keep | L3]. Central-executive working-memory deficits of d = 1.63 to 2.03 in ADHD children;
  covary with symptom severity.
- **Mayer-corpus meta-analysis 2025** [C1-09] [keep | L1]. g = 0.37 overall; text plus diagrams large and consistent;
  seductive-detail removal largest.
- **Nielsen Norman Group** [C1-10] [borderline | L7]. Recognition rather than recall; show options instead of asking
  users to remember them.
- **Thomassen 2010** [C1-11] [borderline | L6]. Focus groups: checklist fatigue, attention diverted, scope creep of the
  sheet, a champion "crucial".
- **Urbach 2014** [C1-12] [keep | L3]. Mortality OR 0.91 (95% CI 0.80 to 1.03) after mandated adoption in 101 hospitals.
- **Wang and Voss 2021** [C1-13] [keep | L1]. 48 of 56 studies supported pictographs; need validation with the target
  audience.
- **Weiser and Haynes 2018** [C1-14] [borderline | L7]. Originators concede box-ticking and failed mandates; thoughtful
  local implementation works.

### Track C2: naming and vocabulary (15 sources)

- **Alexithymia Awareness Network (Willcox wheel)** [C2-01] [borderline | L7]. Origin 1982; vocabulary scaffold from
  broad to specific words; the page itself claims no effectiveness.
- **Ariely 2026** [C2-02] [keep | L2]. Labeling reduced reappraisal's effectiveness, N = 226; no delayed benefit at 1 to
  2 days.
- **Brownstone 2024** [C2-03] [borderline | L7]. IFS evidence "strikingly small"; use has expanded beyond it.
- **Ford and Parnin 2015** [C2-04] [borderline | L6]. 45 developers, 67% severe frustration, 11 cause categories.
- **Kalokerinos 2019** [C2-05] [keep | L3]. Low differentiators use the same strategies less effectively; strategy
  choice unaffected.
- **Ko, Myers and Aung 2004** [C2-06] [borderline | L6]. Six learning barriers, each implying a different remedy.
- **Moser et al. 2017** [C2-07] [keep | L3]. Third-person self-talk lowered self-referential reactivity without
  recruiting cognitive control.
- **Lieberman 2007** [C2-08] [keep | L3]. Labeling diminished amygdala response; right ventrolateral prefrontal cortex
  activity rose.
- **Matt, Seah and Coifman 2024** [C2-09] [keep | L2]. Brief word training had no direct effect on differentiation or
  distress; exploratory benefits for high engagement.
- **Nook 2021** [C2-10] [keep | L2]. Naming before reappraising left people feeling worse (N = 80, replicated N = 60).
- **Seah and Coifman 2022** [C2-11] [keep | L1]. Pooled r = -0.15 across 17 studies; shrinks to -0.09 controlling for
  negative affect.
- **Shadick 2013** [C2-12] [keep | L2]. IFS RCT in rheumatoid arthritis (N = 79): gains in pain and function;
  feasibility only.
- **Thompson, Springstein and Boden 2021** [C2-13] [keep | L7]. Differentiation's definition and measurement diverge.
- **Torre and Lieberman 2018** [C2-14] [borderline | L7]. Labeling as implicit regulation; boundary conditions unknown.
- **Wahba 2026** [C2-15] [borderline | L1 as labelled, not peer reviewed]. Pooled g = -0.49 for physiology; -0.23 in
  independent labs; self-corrected; hypothesis-generating only.

### Track C3: scripts, state maps, problem/antidote pairing, psychoeducation (14 sources)

- **Alfieri 2013** [C3-01] [keep | L1]. Case comparison d = 0.50 (95% CI 0.44 to 0.56) over single-case presentation.
- **Winston 2026 (Brighter coaching blog)** [C3-02] [borderline | L7]. Pick one or two prompts, smallest version, dread
  rating, review without pass or fail.
- **Corbett 2015** [C3-03] [borderline | L7]. Yerkes-Dodson inverted-U "has no basis in empirical fact".
- **Corrigan, Fisher and Nutt 2011** [C3-04] [borderline | L7]. Window of tolerance as a proposed model of trauma
  effects; mechanisms "proposed".
- **Donker 2009** [C3-05] [keep | L1]. Passive psychoeducation d = 0.20 (95% CI 0.01 to 0.40), 4 RCTs.
- **Gawrilow and Gollwitzer 2008** [C3-06] [borderline | L2]. If-then plans lifted inhibition in ADHD children to the
  non-ADHD level; additive to medication.
- **Gottman and Levenson 2000** [C3-07] [borderline | L3]. 93% in-sample divorce prediction; four negative codes
  distinguished early divorce; 79 couples, 21 divorces.
- **Rogers et al. 2018** [C3-08] [borderline | L2]. I-language plus acknowledging the other's view lowered perceived
  hostility; vignettes.
- **Sheeran, Listrom and Gollwitzer 2025** [C3-09] [keep | L1]. 642 tests; raw d = 0.27 to 0.66; bias-corrected
  d = 0.35 and 0.15.
- **Keith and Frese 2008** [C3-10] [keep | L1]. Error-management training d = 0.44 across 24 studies; adaptive transfer
  d = 0.80.
- **Kim, Capaldi and Crosby 2007** [C3-11] [keep | L3]. Gottman affective-process findings failed to replicate in 85
  at-risk couples.
- **Linehan 2015** [C3-12] [keep | L2]. DBT with skills training beat DBT without it (99 women, high suicide risk).
- **Park et al. 2025** [C3-13] [borderline | L2]. NVC course plus journal: empathy and relationships up, stress and
  resilience unchanged.
- **Pennsylvania DHS 2024** [C3-14] [borderline | L4]. One-page three-zone chart with symptoms and actions per zone; no
  outcome data.

### Track C4: in-the-moment use with ADHD (11 sources)

- **Arnsten 2009** [C4-01] [keep | L7]. Mild uncontrollable stress rapidly impairs prefrontal working memory; mostly
  animal evidence.
- **Barkley (fact sheet)** [C4-02] [borderline | L7]. ADHD as failure to use known information at the point of
  performance; externalize information and motivation.
- **CHOP 2023** [C4-03] [keep | L4]. No agreed definition of executive functions; working memory defined; hot versus
  cool executive functions.
- **Faraone et al. 2019** [C4-04] [keep | L4]. Emotional symptoms common and persistent in ADHD; core status debated.
- **Carvalho et al. 2023** [C4-05] [keep | L2]. 73 adults, FOCUS app: no adherence difference despite favorable
  usability.
- **Gani et al. 2025** [C4-06] [keep | L1]. Alert fatigue linked to frequency, presentation and accuracy; 9 studies.
- **Nahum-Shani et al. 2018** [C4-07] [keep | L7]. Six JITAI elements; receptivity; unsolicited support when not
  receptive can harm.
- **Nordby et al. 2022** [C4-08] [keep | L2]. SMS reminders had no effect on completion, logins or practice in adults
  with ADHD.
- **Risko and Gilbert 2016** [C4-09] [keep | L7]. Offloading is driven by beliefs about internal capacity; not
  ADHD-specific.
- **Shaw et al. 2014** [C4-10] [keep | L1]. Emotion dysregulation prevalent across the ADHD lifespan; the field lacks
  consensus on its core status.
- **van Genugten et al. 2025** [C4-11] [keep | L1]. Five mental-health JITAIs found; receptivity and decision-rule
  evidence missing.

---

## 6. Methodology

### Research Design

**Research questions** (run brief, 2026-10-03):

1. What makes one-page psychoeducational aids effective, covering a feelings wheel, a DBT "wise mind" Venn diagram, an
   IFS internal-system map, an NVC "When __, I feel __, because I need __" script, a window-of-tolerance chart, and the
   Gottman Four Horsemen with antidotes?
2. Which design principles transfer to project and workflow management for a solo developer with ADHD?

**Tracks:** C1 job aids and visual design; C2 naming and vocabulary; C3 scripts, state maps, problem/antidote pairing
and psychoeducation; C4 in-the-moment use with ADHD (push versus pull, alert fatigue).

**Scope boundaries.** In scope: peer-reviewed and institutional evidence on aid design, naming, scripting,
psychoeducation and ADHD prompt use, with 2024 to 2026 preferred and older foundational work kept where it is the origin
of a claim. Out of scope: designing features for any particular tool (a later decision-design phase), reproducing the
copyrighted sheets, and clinical advice.

**Target audience:** a solo developer with ADHD who builds workflow tooling and needs to know what the literature
supports.

**Methodology version:** deep-research (research-tools plugin), full tier, evidence mode.

### Source Discovery

**Search strategy.** 91 queries across four tracks, run on 2026-10-03: OpenAlex via the scholarly adapter (academic
topics), Europe PMC REST and web search (everything else). At least 18 queries were tagged falsification queries, framed
to find evidence the thesis fails, such as "Urbach 2014 ... no significant reduction", "Nook 2021 affect labeling
reappraisal", "implementation intentions publication bias", "Heyman Slep cross-validation" and "notification fatigue
reminders backfire". The track logs did not record per-query hit counts, so the table groups queries by subtopic and
reports the cards each group produced. Source diversity targets were academic, institutional, practitioner,
boots-on-the-ground and contrarian.

**Search log** (grouped by subtopic; F = falsification query):

| # | Track and subtopic | Queries (examples) | Count | Cards produced |
|---|--------------------|--------------------|-------|----------------|
| 1 | C1 cognitive load, chunking, recognition | CLT critique (F, adapter and web); Cowan 2001; NN/g recognition vs recall; Kofler ADHD working memory | 5 | Cowan, de Jong, NN/g, Kofler |
| 2 | C1 multimedia, pictures, dual coding | Mayer meta-analysis (adapter and web); dual coding critique (F); Carney and Levin; patient-education pictograms | 4 | Mayer, Higdon, Wang and Voss |
| 3 | C1 checklists and job aids | Haynes 2009; Urbach 2014 (F); checklist fatigue and box-ticking (F); adapter and web on job aids; Rossett | 6 | Haynes, Urbach, Thomassen, Fourcade, Weiser |
| 4 | C1 pre-attentive, colour, handout design | Few 2004; colour-coding benefit and harm (F); CDC Clear Communication Index | 3 | Few, CDC |
| 5 | C2 affect labeling | Lieberman 2007; Torre and Lieberman 2018; adapter meta-analysis; Nook 2021 (F) | 4 | Lieberman, Torre, Nook, Ariely, Wahba |
| 6 | C2 granularity | Kashdan 2015; adapter ED and regulation; Seah and Coifman; ED measurement criticism (F) | 4 | Seah, Kalokerinos, Thompson, Matt |
| 7 | C2 feeling wheel | Willcox 1982; Willcox evaluation or effectiveness (F/gap) | 2 | AAN-Willcox |
| 8 | C2 IFS | adapter IFS RCT; IFS critique (F); Europe PMC IFS PTSD | 3 | Shadick, Brownstone |
| 9 | C2 externalization, narrative, self-distance | adapter; narrative therapy effectiveness; Kross third-person self-talk | 3 | Moser/Kross (Dulwich excluded) |
| 10 | C2 work-state taxonomies | developer blockers taxonomy; shared terminology; Ko et al.; Ford and Parnin | 4 | Ko, Ford and Parnin |
| 11 | C2 ADHD and lived experience | alexithymia in ADHD; ADHD feelings wheel; ADHD developer blog | 3 | none kept (Shimmer, Substack excluded) |
| 12 | C3 if-then scripts | Gollwitzer and Sheeran 2006; ADHD implementation intentions; publication bias (F); two adapter runs; ADHD personal accounts | 6 | 642-tests, Gawrilow, Brighter |
| 13 | C3 NVC and I-statements | NVC evidence and critique (F); NVC RCT or review; I-statements; adapter NVC | 4 | Park NVC RCT, Rogers I-language |
| 14 | C3 state maps | NICABM chart; Corrigan critique (F); Yerkes-Dodson (F); wise mind evidence; Linehan 2015; Neacsiu 2010 | 6 | Corrigan, Corbett, Linehan, PA DHS (NICABM excluded) |
| 15 | C3 antidote pairing | Gottman and Levenson 2000; Heyman and Slep (F); Alfieri; Keith and Frese; adapter Gottman | 5 | Gottman-Levenson, Kim, Alfieri, Keith and Frese |
| 16 | C3 psychoeducation and handouts | Donker 2009; Kazantzis; handout stickiness; reddit ADHD/DBT handouts; adapter; feelings wheel plus ADHD | 6 | Donker (Just1Voice excluded) |
| 17 | C4 externalization and offloading | Barkley point of performance; CHADD; Risko and Gilbert; adult ADHD working memory (adapter and Europe PMC) | 7 | Barkley, CHOP, Risko and Gilbert |
| 18 | C4 emotion dysregulation, stress | Shaw, Faraone, Arnsten (adapter, web, Europe PMC) | 6 | Shaw, Faraone, Arnsten |
| 19 | C4 JITAI | Nahum-Shani (adapter and web) | 2 | Nahum-Shani, van Genugten |
| 20 | C4 apps, reminders, fatigue | ADHD app evidence (F); notification fatigue (F); "I stopped seeing reminders" (F); reddit; Hacker News; developer blog; adapter | 8 | FOCUS, Nordby, Gani |
| | **Total** | | **91** | **59** |

**Total sources pulled for evaluation (carded):** 59. **Triaged out without a card:** about 40 named items, listed
below (several entries bundle adapter noise, so the count is a lower bound). The number of raw search hits was not
logged and is not reported.

**Triage-out log** (not carded; reason in one line):

| Item | Track | Reason |
|------|-------|--------|
| Fusco 2025 oncology data visualisation | C1 | Redundant with Few; used as a corroboration note only |
| redasadki.me Mayer blog | C1 | Practitioner opinion, low authority |
| Jelacic 2023 OR checklists | C1 | Off-topic for design features |
| Adapter "job aids" (Navy, antenatal, health worker) | C1 | Domain mismatch |
| Adapter cognitive-load metrics, Popper pieces | C1 | Irrelevant |
| Wikipedia, Medium, UX blogs | C1 | Tertiary, not fetched |
| Hu 2024 narrative therapy meta-analysis | C2 | GRADE very low, I2 95%, not about externalization |
| Edel 2015 ADHD alexithymia | C2 | Correlational n = 78; did not support the use |
| Vromans and Schweitzer 2011, Lopes 2014 | C2 | Snippets only, not fetched |
| Lay pages with "20-40%" ADHD alexithymia | C2 | No primary traced |
| Espinosa 2007 shared mental models | C2 | Blocked; leaves a gap |
| Antipatterns in software taxonomies (arXiv) | C2 | About software classification, not work states |
| Wikipedia IFS, therapygroupdc, innerlifestrategies | C2 | Secondary summaries |
| Adapter noise (nutrition labels, art therapy) | C2 | Off topic |
| Heyman and Slep 2001 | C3 | Paywalled; abstract summaries only |
| Kazantzis 2010; Beck Institute homework blog | C3 | Blocked; quote could not be verified, discarded |
| Toli 2016 clinical implementation intentions | C3 | Verified but superseded by the 2025 meta-analysis |
| Neacsiu 2010 | C3 | Fetched, not carded to cap size |
| Learning Scientists, simplypsychology, helpfulprofessor | C3 | Corroboration only or uncritical popularising |
| Iran NVC studies, breast cancer and childbirth psychoeducation | C3 | Low quality or disease-specific |
| Gottman marketing pages (94% claims), ML divorce prediction | C3 | Promotional, or circular in-sample |
| Wikipedia, goodreads, ebay, scribd | C3 | Non-primary |
| Soler-Gutierrez 2023 | C4 | Good but redundant with Shaw and Faraone |
| Schweitzer 2006 adult working memory | C4 | n = 51, 2006, abstract only; leaves adult WM as a gap |
| Hu 2019, AI-offloading papers | C4 | Off-track or redundant with Risko and Gilbert |
| Hardeman 2019, Hollis 2016, Shou 2022, Parkin 2022 | C4 | Domain, population or scope mismatch |
| Joseph 2021, Hussain 2021 alert fatigue | C4 | Older or non-peer-reviewed; Gani supersedes |
| Bored Leopard Substack thread (2026-05-09) | C4 | Rubric reject (about 4.4, anecdote); used as illustration only |
| chudi.dev ADHD tool stack (2026-07-21) | C4 | Rubric reject (about 4.4, affiliate links); illustration only |
| Product roundups, HN todo thread, 49-96% override stat | C4 | Marketing, off-target, or single secondary source |

### Source Evaluation

**Evaluation framework:** 10-dimension credibility rubric (see source-evaluation-rubric.md; weights
25/20/10/10/10/5/5/5/5/5). **Evidence classification:** 9-level hierarchy (see evidence-hierarchy.md). **Bias guards
applied:** a confirmation check on every card (score harder when agreeing, more generously when disagreeing, on
dimensions 5, 6 and 8) and the triangulation rule.

**Bias-Guard Summary:**

| Bias-guard outcome | Count |
|--------------------|-------|
| Agreed with source - scored harder on dims 5, 6, 8 | 5 |
| Disagreed with source - scored more generously on dims 5, 6, 8 | 4 |
| Neutral / no strong reaction | 50 |
| **Total sources evaluated** | 59 |

The agree-to-disagree ratio is 1.25 to 1, well under 3 to 1, so the confirmation-skew gate does not fire and no
steel-man subsection is required. Falsification queries were run anyway (18 or more) and the contrarian category holds
12 included sources. Agreement fired on Kofler, Fourcade, Thomassen, Weiser and Torre; disagreement on de Jong, Urbach,
Nook and Wahba.

**Citation-Verification Report** (full report at `verification-report.md`):

| Metric | Value |
|--------|-------|
| Total source cards | 59 |
| Cards sampled for verification | 18 of 59 (30%) |
| Verified | 15 |
| Failed | 0 |
| Inaccessible (flagged unverifiable) | 3 |
| **Failure rate** (`failed / (verified + failed)`) | 0% |
| Failure-rate band | `<=5%` |

Sampling method: seeded random draw (seed 20261031), not weighted by importance. Synthesis agent ID
beb3b143-038d-490e-bf76-bd2d8fc898ce; verifier agent ID a39d5cbf904c10fbc (distinct). The three inaccessible cards
(Fourcade 2012, Higdon 2025, Kalokerinos 2019) point to Europe PMC article pages that returned HTTP 403 to automated
fetch; each carries `cached/partial`, and a side check on the Europe PMC REST records matched every quote. Inaccessible
is 17% of the sample, under the roughly 30% cap, so no low-confidence stamp applies. Of all 59 cards, 39 are live and 20
are cached/partial (mostly abstract-only).

### Inclusion/Exclusion Results

Each source went through the six matrix rules in order, stopping at the first match. Weighted averages were recomputed
from each card's dimension table using the rubric weights.

| Rule outcome | Sources | Count |
|--------------|---------|-------|
| Rule 1 strong include, labelled Core (weighted average 7.0 or higher, not redundant) | the 22 cards labelled Core | 22 |
| Rule 1 met on score but labelled Supporting, because the card's redundancy check shows it extends or qualifies a Core source (label downgrade, still included) | Ariely, Cowan, de Jong, Higdon, Moser/Kross, Thompson, Shadick, Linehan, Keith and Frese, Gani, Faraone, CHOP | 12 |
| Rule 2 diversity include (only included voice of its category in the track) | CDC (Institutional, C1), AAN-Willcox (Practitioner, C2), Brighter (Practitioner, C3), PA DHS (Institutional, C3) | 4 |
| Rule 3 unique-insight include (score 5.0 or higher, finding not found elsewhere) | Few, NN/g, Thomassen, Weiser, Ford and Parnin, Ko, Torre, Wahba, Brownstone, Corbett, Corrigan, Gottman-Levenson, Gawrilow, Rogers, Park NVC, Barkley | 16 |
| Rule 4 moderate include | none reached it (Rules 2 or 3 matched first) | 0 |
| Rule 5 weak exclude (below 5.0, redundant, no unique perspective) | Shimmer, NICABM | 2 |
| Rule 6 default exclude | Dulwich Centre | 1 |
| Override: Rule 2 would have included, excluded instead | carmen_authenticallyadhd Substack, Just1Voice | 2 |
| **Total evaluated** | | **59** |

The counts reconcile: 22 + 12 + 4 + 16 = 54 included, and 2 + 1 + 2 = 5 excluded, for 59 cards on disk.

**Overrides applied (2).** The rule that would have applied was Rule 2, because each was the only lived-experience voice
in its track. The reason for overriding is that both are single anecdotes at Level 8 with weighted averages below 5.0,
and neither can carry a claim. Their role in the document is to mark a gap in §4.2 and in the limitations, and nothing
else. Two further C4 anecdotes (Bored Leopard, chudi.dev) were rubric-rejected without cards for the same reason and
appear only as illustrations in §4.4.

**Summary:**

| Category | Count |
|----------|-------|
| Total sources evaluated | 59 |
| Included - Core | 22 |
| Included - Supporting | 32 |
| Excluded | 5 |
| Overrides applied | 2 |

**Distribution by evidence level** (all 59 cards; the excluded five sit at levels 7, 8, 8, 9 and 9):

| Level | Description | Count (all cards) | Included |
|-------|-------------|-------------------|----------|
| 1 | Systematic review / meta-analysis | 11 | 11 |
| 2 | RCT / controlled experiment | 11 | 11 |
| 3 | Large-scale observational | 8 | 8 |
| 4 | Expert consensus / professional body | 4 | 4 |
| 5 | Practitioner case study | 1 | 1 |
| 6 | Qualitative research | 3 | 3 |
| 7 | Expert opinion / thought leadership | 17 | 16 |
| 8 | Anecdotal / personal experience | 2 | 0 |
| 9 | Marketing / promotional | 2 | 0 |

Level 1 and 2 are both non-zero, so the "no primary evidence" banner does not apply. Two cautions on those 22 sources:
the Level 1 count includes a non-peer-reviewed preprint (Wahba 2026) and a meta-analysis of a single research
programme's own corpus (Mayer), and Level 3 holds fMRI lab experiments because the hierarchy has no lab-experiment tier.

**Distribution by source category:**

| Category | Included | Excluded |
|----------|----------|----------|
| Academic | 31 | 0 |
| Institutional | 3 | 0 |
| Practitioner | 6 | 3 |
| Boots-on-the-ground | 2 | 2 |
| Contrarian | 12 | 0 |
| **Total** | **54** | **5** |

**Distribution by credibility band** (three-bucket; weighted-average tiers recomputed from the cards):

| Band | Weighted average | Count | Disposition |
|------|------------------|-------|-------------|
| keep | 7.0 or higher | 34 | 34 included, 0 excluded |
| borderline | 5.0 to 6.9 | 20 | 20 included, 0 excluded |
| reject | below 5.0 | 5 | 0 included, 5 excluded |

Finer tiers (7 and up, 5 to 6.9, 3 to 4.9, below 3): 34, 20, 5, 0.

**Real cut made this run.** Five sources were excluded: Shimmer 2024 (coaching-company marketing, about 3.9), Just1Voice
2022 (anecdote, about 4.3), NICABM (marketing-adjacent, about 4.4), Dulwich Centre (about 4.6) and the Substack post
(about 4.6). The lowest-scoring source that cleared the bar is the Nielsen Norman Group heuristic page [C1-10]
(borderline, about 5.4 on its own card), kept as the sole source for the recognition-versus-recall mechanism and as
design vocabulary only. The C2 card for Wahba 2026 also calls itself the lowest-scoring kept source (about 5.6), but the
C1 card for NN/g scores lower, so NN/g is the true marginal keep and the Wahba label reflects that track's view.

### Perspective Balance

Counts of included sources per track and category:

| Topic area | Academic | Institutional | Practitioner | Boots | Contrarian |
|------------|----------|---------------|--------------|-------|------------|
| C1 job aids and visual design | Y (5) | Y (1) | Y (3) | Y (2) | Y (3) |
| C2 naming and vocabulary | Y (10) | N | Y (1) | N | Y (4) |
| C3 scripts, state maps, psychoeducation | Y (10) | Y (1) | Y (1) | N | Y (2) |
| C4 in-the-moment use with ADHD | Y (6) | Y (1) | Y (1) | N | Y (3) |

Every track has at least three of the five categories (C1 five, C2 three, C3 four, C4 four). The Boots column is thin,
and I want to be plain about it. The two included Boots-on-the-ground sources (Fourcade, Thomassen) are staff experience
from surgical teams, not people with ADHD or developers. They qualify because they report firsthand experience of using
a job aid and they are the best-scored such sources, but they are a proxy. Every lived-experience source from ADHD or
developer communities that the tracks found (two carded and excluded, two uncarded) failed the credibility rubric. The
gap is a real absence of retrievable, credible sources as much as a search gap: forum searches returned sales pages and
affiliate content.

### Limitations

- **Thin ground-level evidence.** Only two Boots-on-the-ground sources are included, both surgical-staff studies. No
  credible first-hand account from adults with ADHD or from developers cleared the bar, so findings about what works "in
  the moment" lean on theory and trials, not lived experience.
- **Transfer gap.** Almost no source studied the target use (a one-page aid for adult ADHD in knowledge work). Effects
  come from children, trauma patients, nursing students, undergraduates and hospitals, so every principle in §3 is an
  inference across that gap.
- **No direct observation.** No card reports a test of a one-page aid on the target population, and none was run here.
- **Abstract-level reading.** 20 of 59 cards are `cached/partial`, and several load-bearing reviews (Shaw 2014, Faraone
  2019, Risko and Gilbert 2016, Keith and Frese 2008, Alfieri 2013, Corbett 2015, Corrigan 2011) were read as abstracts
  only. The de Jong card warns against citing specific sub-criticisms, so none are cited.
- **Single evaluator and one author.** One agent scored every card and wrote this document, with no inter-rater check.
  The independent verifier checked quotes and locations, not scores or interpretations.
- **Verification coverage.** 18 of 59 cards (30%) were sampled, the minimum the gate allows, and three of those were
  inaccessible to the verifier because of a Cloudflare block.
- **Evidence-level labels are approximate.** The hierarchy has no lab-experiment tier, one Level 1 is a preprint, and
  one is a self-corpus meta-analysis, so the counts overstate how much hard evidence there is.
- **Search bias.** Web search favors SEO-optimized content, and the OpenAlex adapter returned off-topic results for
  several queries (for example, "implementation intentions ADHD" returned zero).
- **Date skew.** Several foundational sources predate 2020 (Cowan 2001, Ko 2004, Few 2004); they were kept only where
  they are the origin of a claim.

**Paywalled sources excluded and why.** None of these were carded or used as evidence, because they could not be read
and the run does not summarize from an abstract or a search snippet:

- Rossett and Gautier-Downes, *A Handbook of Job Aids* (1991, book): would give the job-aid fit criteria for infrequent,
  high-error-cost tasks; only a search summary was seen.
- Carney and Levin 2002, *Educational Psychology Review* (Springer): pictorial-illustration boundary conditions.
- Christ 1975, *Human Factors* (SAGE): classic colour-coding review; would settle when colour helps or hurts.
- Sweller 1988, *Cognitive Science* (Wiley): origin of cognitive load theory; not fetched.
- Mayer-corpus meta-analysis full text (Elsevier): heterogeneity and moderator tables; abstract used.
- Haynes 2009 and Urbach 2014 full texts (NEJM): component and compliance detail; abstracts used.
- Kashdan, Barrett and McKnight 2015 (*Current Directions in Psychological Science*): canonical statement of the
  granularity argument.
- Willcox 1982 (*Transactional Analysis Journal*, SAGE): the wheel's origin document; only a secondary profile page
  read.
- IFS scoping review, *Australian Psychologist* 2025 (Taylor and Francis), and Torre and Lieberman 2025, *Trends in
  Cognitive Sciences* (Cell Press): both blocked.
- Heyman and Smith Slep 2001 (*Journal of Marriage and Family*, Wiley): the primary cross-validation critique of
  Gottman's accuracy.
- Kazantzis, Whittington and Dattilio 2010 (*Clinical Psychology: Science and Practice*): homework-adherence
  meta-analysis.
- Gollwitzer and Sheeran 2006 chapter (*Advances in Experimental Social Psychology*): abstract only.

---

## 7. Bibliography

Format: citation, then [band | level | decision] and a one-line contribution. Core is a Rule 1 strong include;
Supporting carries its rule in parentheses. Excluded sources are listed at the end of this section.

### Track C1: job aids and visual design

> **C1-01.** Centers for Disease Control and Prevention. "CDC Clear Communication Index User Guide." 2019.
> https://www.cdc.gov/ccindex/pdf/clear-communication-user-guide.pdf
> [borderline | L4 | Supporting, Rule 2] Checkable layout rules; one main message; says pretesting is irreplaceable.

> **C1-02.** Cowan N. "The magical number 4 in short-term memory." *Behavioral and Brain Sciences* 24(1). 2001.
> https://europepmc.org/article/MED/11515286
> [keep | L7 | Supporting, Rule 1 label downgrade] About four chunks of working memory.

> **C1-03.** de Jong T. "Cognitive load theory, educational research, and instructional design." *Instructional
> Science* 38(2). 2010. https://research.utwente.nl/en/publications/cognitive-load-theory-educational-research-and-instructional-desi
> [keep | L7 | Supporting, Rule 1 label downgrade] Falsification source: CLT is a heuristic with open problems.

> **C1-04.** Few S. "Tapping the Power of Visual Perception." Perceptual Edge. 2004.
> https://www.perceptualedge.com/articles/ie/visual_perception.pdf
> [borderline | L7 | Supporting, Rule 3] Pre-attentive attributes and what each can encode.

> **C1-05.** Fourcade A, et al. "Barriers to staff adoption of a surgical safety checklist." *BMJ Quality & Safety*
> 21(3). 2012. https://europepmc.org/article/MED/22069112
> [keep | L5 | Core] Strongest quantitative account of how aids fail in use.

> **C1-06.** Haynes AB, et al. "A surgical safety checklist to reduce morbidity and mortality in a global population."
> *NEJM* 360(5). 2009. https://europepmc.org/article/MED/19144931
> [keep | L3 | Core] The load-bearing positive-effect claim for checklists.

> **C1-07.** Higdon KF, et al. "Distinctiveness, not dual coding, explains the picture-superiority effect." *QJEP*
> 78(1). 2025. https://europepmc.org/article/MED/38360549
> [keep | L2 | Supporting, Rule 1 label downgrade] Picture benefit may be distinctiveness; falsification of dual coding.

> **C1-08.** Kofler MJ, et al. "Working memory and short-term memory deficits in ADHD: a bifactor modeling approach."
> *Neuropsychology* 34(6). 2020. https://pmc.ncbi.nlm.nih.gov/articles/PMC7483636/
> [keep | L3 | Core] ADHD-specific rationale for externalizing working memory (children).

> **C1-09.** "A meta-analysis of Richard Mayer's multimedia learning research." *Educational Research Review*. 2025.
> https://experts.illinois.edu/en/publications/a-meta-analysis-of-richard-mayers-multimedia-learning-research-se/
> [keep | L1 | Core] Ranks design features by effect; g = 0.37 overall.

> **C1-10.** Nielsen Norman Group. "10 Usability Heuristics for User Interface Design" (heuristic 6). 1994, current
> page.
> https://www.nngroup.com/articles/ten-usability-heuristics/
> [borderline | L7 | Supporting, Rule 3] Recognition rather than recall. Lowest-scoring included source.

> **C1-11.** Thomassen O, et al. "Checklists in the operating room: help or hurdle?" *BMC Health Services Research* 10.
> 2010. https://pmc.ncbi.nlm.nih.gov/articles/PMC3009978/
> [borderline | L6 | Supporting, Rule 3] The checklist-fatigue mechanism.

> **C1-12.** Urbach DR, et al. "Introduction of surgical safety checklists in Ontario, Canada." *NEJM* 370(11). 2014.
> https://europepmc.org/article/MED/24620866
> [keep | L3 | Core] Population-level null for mandated adoption.

> **C1-13.** Wang T, Voss JG. "Effectiveness of pictographs in improving patient education outcomes: a systematic
> review." 2021;36(1):9-40. https://europepmc.org/article/MED/33331898
> [keep | L1 | Core] 48 of 56 studies supportive; validate with the audience.

> **C1-14.** Weiser TG, Haynes AB. "Ten years of the Surgical Safety Checklist." *British Journal of Surgery* 105(8).
> 2018. https://pmc.ncbi.nlm.nih.gov/articles/PMC6032919/
> [borderline | L7 | Supporting, Rule 3] Originators name the failure modes.

### Track C2: naming and vocabulary

> **C2-01.** Alexithymia Awareness Network. "Gloria Willcox and the Feeling Wheel." (refers to Willcox G, *Transactional
> Analysis Journal* 12(4), 1982). https://alexithymiaawarenessnetwork.org/wilcox/
> [borderline | L7 | Supporting, Rule 2] Wheel origin; explicitly no effectiveness claim.

> **C2-02.** Ariely Y, et al. "Affect Labeling and Reappraisal as an Emotion Regulation Strategy." *Affective Science*.
> 2026. https://pmc.ncbi.nlm.nih.gov/articles/PMC13269579/
> [keep | L2 | Supporting, Rule 1 label downgrade] Independent replication; no delayed benefit.

> **C2-03.** Brownstone LM, et al. "Internal Family Systems: Exploring Its Problematic Popularity." Society for the
> Advancement of Psychotherapy. 2024.
> https://societyforpsychotherapy.org/internal-family-systems-exploring-its-problematic-popularity/
> [borderline | L7 | Supporting, Rule 3] IFS critique: evidence base small.

> **C2-04.** Ford D, Parnin C. "Exploring Causes of Frustration for Software Developers." CHASE 2015.
> https://denaeford.me/papers/developer-frustration-CHASE-2015.pdf
> [borderline | L6 | Supporting, Rule 3] 11 developer frustration categories.

> **C2-05.** Kalokerinos EK, et al. "Differentiate to Regulate." *Psychological Science*. 2019.
> https://europepmc.org/article/MED/30990768
> [keep | L3 | Core] Mechanism: differentiation improves strategy use, not choice.

> **C2-06.** Ko AJ, Myers BA, Aung HH. "Six Learning Barriers in End-User Programming Systems." VL/HCC 2004.
> https://faculty.washington.edu/ajko/papers/Ko2004LearningBarriers.pdf
> [borderline | L6 | Supporting, Rule 3] Typed "stuck" vocabulary for programmers.

> **C2-07.** Moser JS, et al. "Third-person self-talk facilitates emotion regulation without engaging cognitive
> control." *Scientific Reports* 7. 2017. https://pmc.ncbi.nlm.nih.gov/articles/PMC5495792/
> [keep | L3 | Supporting, Rule 1 label downgrade] Psychological-distance mechanism.

> **C2-08.** Lieberman MD, et al. "Putting feelings into words." *Psychological Science* 18(5). 2007.
> https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=EXT_ID:17576282%20AND%20SRC:MED&format=json&resultType=core
> [keep | L3 | Core] Origin study of the labeling mechanism.

> **C2-09.** Matt LM, Seah THS, Coifman KG. "Effects of a brief online emotion word learning task." *PLOS ONE*. 2024.
> https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0299540
> [keep | L2 | Core] Only intervention test of teaching emotion words; null direct effect.

> **C2-10.** Nook EC, Satpute AB, Ochsner KN. "Emotion Naming Impedes Both Cognitive Reappraisal and Mindful
> Acceptance." *Affective Science* 2. 2021. https://pmc.ncbi.nlm.nih.gov/articles/PMC9383041/
> [keep | L2 | Core] Strongest experimental challenge to "naming equals regulating".

> **C2-11.** Seah THS, Coifman KG. "Emotion differentiation and behavioral dysregulation: a meta-analysis." *Emotion*
> 22(7). 2022. https://www.ovid.com/journals/emotn/fulltext/10.1037/emo0000968~emotion-differentiation-and-behavioral-dysregulation-in
> [keep | L1 | Core] Pooled r = -0.15.

> **C2-12.** Shadick NA, et al. "A Randomized Controlled Trial of an Internal Family Systems-based Psychotherapeutic
> Intervention on Outcomes in Rheumatoid Arthritis." *Journal of Rheumatology*. 2013. https://doi.org/10.3899/jrheum.121465
> [keep | L2 | Supporting, Rule 1 label downgrade] Best controlled IFS trial located; a package, not a map.

> **C2-13.** Thompson RJ, Springstein T, Boden M. "Gaining clarity about emotion differentiation." *Social and
> Personality Psychology Compass* 15(3). 2021.
> https://bpb-us-e2.wpmucdn.com/sites.wustl.edu/dist/f/1305/files/2025/03/Social-Personality-Psych-2021-Thompson-Gaining-clarity-about-emotion-differentiation.pdf
> [keep | L7 | Supporting, Rule 1 label downgrade] Measurement critique of granularity.

> **C2-14.** Torre JB, Lieberman MD. "Putting Feelings Into Words: Affect Labeling as Implicit Emotion Regulation."
> *Emotion Review* 10(2). 2018.
> https://static1.squarespace.com/static/651b09f505bc433349d85ab7/t/651d2f2843e6d165beeccb23/1696411432954/Torre(2018)ER.pdf
> [borderline | L7 | Supporting, Rule 3] Mechanism hypotheses and boundary conditions from the proponent lab.

> **C2-15.** Wahba MAR. "Putting feelings into words: a systematic review and meta-analysis of affect labeling." Zenodo
> v1.1.0. 2026. https://doi.org/10.5281/zenodo.20109595
> [borderline | L1 (labelled; not peer reviewed) | Supporting, Rule 3] Only pooled labeling estimate; smaller in
> independent labs. Directional flag only.

### Track C3: scripts, state maps, problem/antidote pairing, psychoeducation

> **C3-01.** Alfieri L, Nokes-Malach TJ, Schunn CD. "Learning through case comparisons: a meta-analytic review."
> *Educational Psychologist* 48(2). 2013. https://eric.ed.gov/?id=EJ1000186
> [keep | L1 | Core] Case comparison d = 0.50; mechanism behind side-by-side layouts.

> **C3-02.** Winston E. "Action planning - an ADHD coach's approach." Brighter coaching blog. 2026.
> https://brighter.coach/blog/2026/01/25/action-planning-with-adhd-audhd.html
> [borderline | L7 | Supporting, Rule 2] Practitioner usability rules for a planning prompt.

> **C3-03.** Corbett M. "From law to folklore: work stress and the Yerkes-Dodson Law." *Journal of Managerial
> Psychology* 30(6). 2015. https://www.emerald.com/jmp/article-abstract/30/6/741/233069/From-law-to-folklore-work-stress-and-the-Yerkes
> [borderline | L7 | Supporting, Rule 3] The inverted-U curve lacks empirical basis.

> **C3-04.** Corrigan FM, Fisher JJ, Nutt DJ. "Autonomic dysregulation and the Window of Tolerance model." *Journal of
> Psychopharmacology* 25(1). 2011.
> https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=DOI%3A10.1177%2F0269881109354930&resultType=core&format=json&pageSize=3
> [borderline | L7 | Supporting, Rule 3] The window of tolerance as a proposed trauma model.

> **C3-05.** Donker T, et al. "Psychoeducation for depression, anxiety and psychological distress: a meta-analysis."
> *BMC Medicine* 7. 2009. https://pmc.ncbi.nlm.nih.gov/articles/PMC2805686/
> [keep | L1 | Core] Passive psychoeducation d = 0.20.

> **C3-06.** Gawrilow C, Gollwitzer PM. "Implementation intentions facilitate response inhibition in ADHD children."
> *Cognitive Therapy and Research* 32. 2008.
> https://www.socmot.uni-konstanz.de/publications/implementation-intentions-facilitate-response-inhibition-adhd-children
> [borderline | L2 | Supporting, Rule 3] Only ADHD-specific controlled evidence for if-then plans.

> **C3-07.** Gottman JM, Levenson RW. "The Timing of Divorce." *Journal of Marriage and Family* 62. 2000.
> https://bpl.studentorg.berkeley.edu/docs/61-Timing%20of%20Divorce00.pdf
> [borderline | L3 | Supporting, Rule 3] Primary source for the four-pattern problem list; 93% in-sample.

> **C3-08.** Rogers et al. "I understand you feel that way, but I feel this way." *PeerJ* 6. 2018.
> https://pmc.ncbi.nlm.nih.gov/articles/PMC5961625/
> [borderline | L2 | Supporting, Rule 3] Experimental support for I-statement openers (vignettes).

> **C3-09.** Sheeran P, Listrom O, Gollwitzer PM. "The when and how of planning: meta-analysis ... in 642 tests."
> *European Review of Social Psychology* 36(1). 2025.
> https://kops.uni-konstanz.de/server/api/core/bitstreams/d703c468-46e9-47fc-8900-d32d7d19c8d9/content
> [keep | L1 | Core] If-then effect, with bias-corrected estimates and where it fails.

> **C3-10.** Keith N, Frese M. "Effectiveness of error management training: a meta-analysis." *Journal of Applied
> Psychology* 93(1). 2008.
> https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=DOI%3A10.1037%2F0021-9010.93.1.59&resultType=core&format=json&pageSize=3
> [keep | L1 | Supporting, Rule 1 label downgrade] Error-based learning d = 0.44.

> **C3-11.** Kim HK, Capaldi DM, Crosby L. "Generalizability of Gottman and Colleagues' Affective Process Models."
> *Journal of Marriage and Family*. 2007. https://pmc.ncbi.nlm.nih.gov/articles/PMC1828692/
> [keep | L3 | Core] Independent failure to replicate.

> **C3-12.** Linehan MM, et al. "DBT for high suicide risk in individuals with borderline personality disorder."
> *JAMA Psychiatry* 72(5). 2015. https://www.pdbti.org/wp-content/uploads/2023/10/12.1-Linehan-et-al.-2015-DBT-RCT-Component-Analysis.pdf
> [keep | L2 | Supporting, Rule 1 label downgrade] Skills training is the active ingredient, not the handout.

> **C3-13.** Park et al. "Effects of a Nonviolent Communication Education Program ... Korean Nursing Students." 2025.
> https://pmc.ncbi.nlm.nih.gov/articles/PMC12051804/
> [borderline | L2 | Supporting, Rule 3] Controlled NVC evidence with honest nulls.

> **C3-14.** Pennsylvania Department of Human Services, OMHSAS. Trauma-informed care tip sheet (window of tolerance).
> September 2024. https://www.pa.gov/content/dam/copapwp-pagov/en/dhs/documents/trauma-informed-care/tip-sheets/2024-09-september-final-tts.pdf
> [borderline | L4 | Supporting, Rule 2] The institutional exemplar of a one-page state map.

### Track C4: in-the-moment use with ADHD

> **C4-01.** Arnsten AFT. "Stress signalling pathways that impair prefrontal cortex structure and function." *Nature
> Reviews Neuroscience* 10(6). 2009. https://pmc.ncbi.nlm.nih.gov/articles/PMC2907136/
> [keep | L7 | Core] Stress degrades prefrontal working memory.

> **C4-02.** Barkley RA. "The Important Role of Executive Functioning and Self-Regulation in ADHD." Fact sheet.
> https://www.russellbarkley.org/factsheets/ADHD_EF_and_SR.pdf
> [borderline | L7 | Supporting, Rule 3] Point-of-performance design premise.

> **C4-03.** Children's Hospital of Philadelphia, Center for Management of ADHD. "What Are Executive Functions and How
> Are They Related to ADHD?" 2023. https://www.chop.edu/sites/default/files/adhd-exec-5-what-are-efs-and-how-are-they-related-to-adhd.pdf
> [keep | L4 | Supporting, Rule 1 label downgrade] Institutional definitions of executive function.

> **C4-04.** Faraone SV, et al. "Practitioner Review: Emotional dysregulation in ADHD." *J Child Psychol Psychiatry*
> 60(2). 2019.
> https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=EXT_ID%3A29624671%20AND%20SRC%3AMED&resultType=core&format=json
> [keep | L4 | Supporting, Rule 1 label downgrade] Clinical-recognition view; core status debated.

> **C4-05.** Carvalho LR, et al. "Evaluation of the effectiveness of the FOCUS ADHD App." *European Psychiatry*. 2023.
> https://www.ncbi.nlm.nih.gov/pmc/articles/PMC10377453/
> [keep | L2 | Core] Null on adherence despite favorable usability.

> **C4-06.** Gani I, et al. "Understanding 'Alert Fatigue' in Primary Care." *JMIR*. 2025.
> https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11845892/
> [keep | L1 | Supporting, Rule 1 label downgrade] Why prompts stop working.

> **C4-07.** Nahum-Shani I, et al. "Just-in-Time Adaptive Interventions in Mobile Health." *Annals of Behavioral
> Medicine* 52(6). 2018. https://pmc.ncbi.nlm.nih.gov/articles/PMC5364076/
> [keep | L7 | Core] Receptivity and decision-point design rules.

> **C4-08.** Nordby ES, et al. "The Effect of SMS Reminders on Adherence in a Self-Guided Internet-Delivered
> Intervention for Adults With ADHD." *Frontiers in Digital Health*. 2022. https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9149073/
> [keep | L2 | Core] Generic reminders had no effect.

> **C4-09.** Risko EF, Gilbert SJ. "Cognitive Offloading." *Trends in Cognitive Sciences* 20(9). 2016.
> https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=EXT_ID%3A27542527%20AND%20SRC%3AMED&resultType=core&format=json
> [keep | L7 | Core] The offloading mechanism and its metacognitive trigger.

> **C4-10.** Shaw P, Stringaris A, Nigg J, Leibenluft E. "Emotion dysregulation in ADHD." *American Journal of
> Psychiatry* 171(3). 2014.
> https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=EXT_ID%3A24480998%20AND%20SRC%3AMED&resultType=core&format=json
> [keep | L1 | Core] Emotion dysregulation is prevalent and impairing in ADHD.

> **C4-11.** van Genugten C, et al. "Beyond the current state of just-in-time adaptive interventions in mental health."
> *Frontiers in Digital Health*. 2025. https://doi.org/10.3389/fdgth.2025.1460167
> [keep | L1 | Core] Audit: JITAI timing evidence is early-stage.

### Excluded sources (5; cards on disk, not cited as evidence)

- **X-1.** Dulwich Centre, "What is Narrative Therapy?" [reject | L7 | Excluded, Rule 6]. Statement of the
  externalization premise with no outcome data; kept as a card so the cut is visible.
- **X-2.** Shimmer ADHD Coaching, "Can naming your feelings help ADHD?" 2024 [reject | L9 | Excluded, Rule 5].
  Unqualified claim that naming lowers intensity; the practitioner overclaim that Nook and Ariely contradict.
- **X-3.** carmen_authenticallyadhd Substack, "AuDHD, Alexithymia, and Anhedonia." 2026 [reject | L8 | Excluded,
  override of Rule 2]. Lived-experience anecdote; illustrates the unnamed-state problem only.
- **X-4.** Just1Voice, "Feelings Wheel for Alexithymia." 2022 [reject | L8 | Excluded, override of Rule 2]. Single
  self-report describing the wheel as a stepwise lookup.
- **X-5.** NICABM, "How to Expand a Client's Window of Tolerance" [reject | L9 | Excluded, Rule 5]. Marketing-adjacent,
  no evidence; superseded by the PA DHS sheet and Corrigan 2011.
