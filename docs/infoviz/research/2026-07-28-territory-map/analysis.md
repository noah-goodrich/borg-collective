Generated: 2026-07-28

# Infoviz Territory Map: What the Field Knows, Where It Still Fights, and What to Read First

AI-scoring: 82/100
Program: infoviz learning program, Phase 0 (territory map). Audience: a senior data engineer, not a viz
specialist. Corpus: 36 source cards across 7 subfields. 72 logged searches. Verification: 11 of 36 cards
sampled, 0 failures. Companions: curriculum.md (the reading course), verification-report.md (citation audit).

## Glossary

Twelve terms, defined the way I would explain them to a ten-year-old. Every one also gets defined inline the
first time it matters.

1. **Evidence level**: a 1-to-8 ladder for how strong a source's proof is. Level 1 means someone
   systematically reviewed all the studies. Level 2 means a controlled experiment. Level 7 means a smart
   person's opinion. Level 8 means one person's story.
2. **Visual channel**: the property of a shape that carries a number: its position on an axis, its length,
   its angle, its area, or its color.
3. **Preattentive processing**: what your eyes pick up in a fraction of a second before you consciously look,
   like one red dot jumping out of a field of gray dots.
4. **Inattentional blindness**: missing something fully visible because your attention was busy elsewhere.
   The famous "invisible gorilla" effect.
5. **Grammar of graphics**: building charts from parts (data, mappings, geometry, scales) the way sentences
   are built from words, instead of picking from a fixed menu of chart types.
6. **Data-ink ratio**: Tufte's rule of thumb that every drop of ink on a chart should carry data, and that
   decoration is waste.
7. **The Mantra**: Shneiderman's 1996 design recipe: "Overview first, zoom and filter, then
   details-on-demand."
8. **Focus+context**: showing the detail you care about inside the bigger picture, like a magnifying glass
   that keeps the rest of the page visible around it.
9. **Progressive disclosure**: show the few things most people need up front; hide the rest behind a click.
10. **Information scent**: the clues (titles, labels, layout) that tell a user whether looking or clicking
    somewhere will pay off.
11. **Hairball**: a network diagram with so many nodes and crossing lines that it becomes an unreadable
    tangle.
12. **Annotation layer**: the words written directly on a chart (labels, active titles, callouts) that tell
    the reader what they are looking at and why it matters.

## 1. Recommendations

- **Run Deep-Dive 1 first: "The glanceable operational surface."** Combine the dashboards/operational
  subfield with perception (the two top-ranked territories in section 3's relevance map). The question: what
  does a single screen of pipeline status have to look like so the one number that matters gets noticed in
  under a second, given that 46% of people miss a gorilla walking through a basketball game (section 5,
  perception)? Anchor sources: Few, Google SRE, NN/G information foraging, Simons & Chabris.
- **Run Deep-Dive 2 second: "When interaction earns its keep."** The Mosca/Ottley/Chang RCT showed adding
  interaction can actively hurt comprehension, and Craft & Cairns showed the Mantra was never validated
  (section 3, debates 4 and 5; section 4, contested zones). Before building a single filter or drill-down,
  settle a house rule for when a static chart wins. Anchor sources: Mosca et al., Craft & Cairns, Cockburn
  et al., Nielsen.
- **Run Deep-Dive 3 third: "The annotation layer as the ELI10 workhorse."** Active titles, direct labels,
  and on-chart callouts are the cheapest technique in the whole corpus for making a chart pass an
  explain-like-I'm-10 test, and the NYT's Amanda Cox calls the annotation layer "the most important thing we
  do" (section 5, narrative). Fold the minimalism-vs-embellishment fight (Tufte vs. Bateman/Elavsky,
  section 3, debate 2) into this dive rather than running it standalone, because the practical question is
  the same: how many words and how much ink does a chart earn?
- **Run Deep-Dive 4 fourth: "Pipelines without hairballs."** Scope it to the graph shapes Noah actually
  meets: dbt DAGs, lineage, dependency trees. The evidence says representation family (node-link vs. matrix
  vs. treemap) matters more than layout tuning, and the crossover starts around 20 vertices (section 5,
  networks). Anchor sources: Ghoniem et al., Burch et al., Kosara, Shneiderman treemaps + NN/G critique.
- **Defer a standalone "grammar of graphics" dive.** Bertin, Munzner, and Wickham form settled vocabulary,
  not a live fight (section 4, consensus zones). Learn it through the curriculum, not a research project.
- **Adopt the evidence-level habit now.** Sixteen of the 36 keeper sources are Level 7 (expert opinion). Tag
  every design "rule" you meet with its level before trusting it; section 6 has the full distribution and
  section 3's debate register lists the rules that turned out to be folklore.
- **Start the first parallel read today:** Stephen Few, *Information Dashboard Design*, Chapter 1 (the
  single-screen definition and the 13 mistakes), paired with the free Google SRE "Monitoring Distributed
  Systems" chapter the same week. The curriculum (curriculum.md) starts there and explains why.

## 2. Summary

Think of this phase as sending surveyors into a territory nobody on the team has walked before. We did not
build anything, test anything, or run any experiment of our own. This is a literature territory map: seven
scout tracks fanned out, carded 36 sources, and an independent verifier re-fetched a random 11 of those
cards (30.6%) and checked 24 quote strings character-for-character against the live sources. Zero failed. So
the map is honest about what it is: a well-checked reading of other people's evidence, not primary evidence
of our own. The corpus itself does contain top-shelf proof, though: three Level 1 systematic reviews and
seven Level 2 controlled experiments, so the "no primary evidence" flag defined for this program does not
apply to this report.

The territory splits into two big traditions that mostly ignore each other. The academic line runs from
Jacques Bertin's 1967 *Semiology of Graphics* through Cleveland & McGill's 1984 experiments to Colin Ware's
perception textbook and Tamara Munzner's what-why-how framework: careful, experimental, and slow. The
practitioner line runs from Tufte through Stephen Few and Alberto Cairo into the newsrooms: opinionated,
fast, and full of rules that sound like science but often are not. A third voice, the institutional one
(Nielsen Norman Group, the Data Visualization Society, Google's SRE book), translates between the two. The
most useful surprise of the survey is how often the traditions converge without citing each other: Few
argues from perceptual psychology and Google's SREs argue from pager fatigue, and both land on the same
design, a single glanceable screen that shows exceptions and pushes everything subcritical out of the
interrupt channel.

The settled valleys are worth naming because they are load-bearing. Position and length beat angle, area,
and volume for reading numbers off a chart; that 1984 ranking has been replicated on Mechanical Turk with
hundreds of subjects and still holds at the population level. Tables win when the reader needs a precise
value or a rank; charts win when the reader needs a pattern. Attention, not visibility, gates what people
see: in the gorilla experiment, only 54% of 192 viewers noticed a person in a gorilla suit walk through the
scene they were staring at, which means "it's on the dashboard" and "someone saw it" are different claims.
And words on the chart beat words beside the chart: two newsrooms independently call annotation the heart of
the craft.

The borderlands are just as important, because that is where a naive reader gets hurt. The famous channel
ranking describes an average observer, and a 2022 study found as much as 30% of people are likely not "best
with the Bar," so one ranking does not fit every reader. Interaction is not a free win; the only RCT on the
question found adding it to a well-designed static chart sometimes made comprehension worse. The Mantra,
cited 5,700+ times, has never been rigorously validated; its own author called it descriptive, not
prescriptive. Tufte's data-ink minimalism took a real experimental hit: embellished charts were recalled
significantly better after two to three weeks with no accuracy penalty. Scrollytelling splits the newsroom
from the critics. And "dashboards are dead," the most-read contrarian take in the corpus (250,000+ views),
was walked back by its own author three years later into a claim about organizations, not artifacts.

For the program's stated goal, complex operational information that passes an ELI10 readability test, the
relevance map in section 3 ranks the subfields in this order: dashboards/operational first, perception
second, encoding third, narrative/annotation fourth, interaction fifth, networks sixth (situationally higher
when the data is a DAG), and field-meta last. The question inventory in section 3 is the deliverable to keep
open while reading: it turns each subfield into the questions a practitioner would actually ask about a
status page, and it hands Phase 1 its backlog.

Testability classification, stated plainly: everything in this report is literature-derived. Where a claim
rests on a Level 1 or Level 2 source, I say so; where it rests on Level 7 opinion, I say that too. Nothing
here was empirically tested by this phase.

## 3. The Territory Map

### 3.1 The framework: two traditions, three voices, seven subfields

The field's family tree is short enough to hold in your head. On the academic side, Bertin (1967) named the
visual variables, Cleveland & McGill (1984) measured them, Ware synthesized the vision science, and Munzner
(2009/2014) organized the whole discipline into a nested what-why-how stack whose central warning is that an
upstream mistake (wrong task, wrong abstraction) cascades and cannot be fixed by a beautiful chart
downstream. On the practitioner side, Tufte set the minimalist orthodoxy, Few carried it into dashboards,
Cairo carried it into journalism while explicitly rebelling against Tufte's one-right-way dogmatism, and
working newsrooms (NYT, FT) turned annotation into the craft's center of gravity. The institutional voice
(NN/G, the Data Visualization Society, Google SRE) publishes the guidance most working engineers actually
meet first. The Data Visualization Society's own onboarding guide assigns Munzner and Cairo side by side,
which is decent evidence the two traditions share one canon even while they argue.

| # | Subfield | Core claim | Anchors |
|---|----------|-----------|---------|
| 1 | Perception & cognition | Channels differ in accuracy; attention gates it all | Cleveland & McGill; Ware; Simons |
| 2 | Encoding & grammar | Marks, channels, mappings; match channel to task | Bertin; Munzner; Wickham |
| 3 | Interaction & exploration | Overview, zoom, filter, details; every mechanism can fail | Shneiderman; Cockburn |
| 4 | Narrative & explanatory | Author vs. reader control; annotation carries meaning | Segel & Heer; Schwabish |
| 5 | Dashboards & operational | One glanceable screen; alert only urgent + actionable | Few; Google SRE; NN/G |
| 6 | Networks & hierarchy | Representation family beats layout; node-link dies at scale | Ghoniem; Burch; Kosara |
| 7 | The field itself (meta) | Two schools, one canon, rules that outrun their evidence | Munzner; Makulec; Bateman |

### 3.2 The Question Inventory

This is the central deliverable. Each subfield is translated into the questions its practitioners would ask
about one concrete artifact: a page showing complex operational information (pipeline health, grant drift,
alert queues) that a smart ten-year-old should be able to read. Groups are ranked by RQ4 relevance;
questions inside each group are ranked by how early they bite in a real design.

**Group A: Dashboards & operational UI (relevance rank 1, the direct hit)**

1. Does everything fit on one screen, entirely within eye span, with no scrolling? (Few's boundary test)
2. Is this signal an alert or dashboard material? An alert must be urgent, actionable, and user-visible;
   everything else belongs on the glanceable surface. (Google SRE)
3. Am I alerting on symptoms (what users feel) or causes (what I suspect), and do I know why symptom-based
   is more robust? (Google SRE)
4. Does the layout give off scent? Can a user find the number that matters from the title, the hierarchy,
   and what sits above the fold, in about a second? (NN/G information foraging)
5. Is this one artifact being asked to do three incompatible jobs at once (storytelling, precise lookup, and
   ad hoc analysis)? (Brownlow's over-tasking diagnosis)
6. Which of Few's 13 failure modes is this design already committing, and is any gauge or traffic light here
   because it communicates or because it demos well?
7. How many alerts per day can this team absorb before desensitization sets in, and who is measuring that?
   (the ACM alert-fatigue survey says nobody has solved this yet)

**Group B: Perception & graphical cognition (relevance rank 2, the physics underneath)**

1. Which visual channel carries the most important number, and is it position or length rather than area,
   angle, or color? (Cleveland & McGill, replicated by Heer & Bostock)
2. Will the anomaly pop out preattentively, or does noticing it require attention I cannot assume the
   on-call engineer has to spare? (Ware vs. Simons & Chabris)
3. Am I designing for the average observer, knowing as much as 30% of real viewers deviate from the
   canonical channel ranking? (Davis et al.)
4. How much can one glance actually register, and what happens to everything else on the screen while
   attention is on the incident? (working-memory and inattentional-blindness limits)
5. Is the unexpected thing visually similar to what people are already monitoring? Similarity, not
   proximity, drives whether it gets noticed. (Simons & Chabris)

**Group C: Visual encoding & the grammar of graphics (relevance rank 3, the chart-or-table fork)**

1. Is the reader's task lookup and precision (use a table) or pattern and trend (use a chart)? (Remshard &
   Queenborough)
2. Does the encoding show all and only the information in the data, without implying an order that is not
   there? (Munzner's expressiveness principle)
3. Does the most noticeable channel carry the most important attribute? (Munzner's effectiveness principle)
4. How much ink can I strip before minimalism becomes an accessibility barrier or hurts recall? (Elavsky
   and Bateman against reflexive data-ink maximizing)
5. Can I describe this chart as data plus mappings plus geometry (grammar of graphics), or am I just
   picking from a chart-type menu and hoping? (Wickham)

**Group D: Narrative & explanatory visualization (relevance rank 4, the ELI10 delivery vehicle)**

1. What are the three solid points a reader should walk away with, and what got cut to protect them? (the
   NYT climate team's stated design target)
2. Does the title state the finding ("Bot logins fell 40% after keypair rollout") or just the axes? (active
   titles, Schwabish)
3. Are the labels on the data, or in a legend the reader must decode back and forth? (Schwabish)
4. Is this truthful before it is functional, and functional before it is beautiful? (Cairo's ordering)
5. Who controls the pacing, author or reader, and did I choose that on purpose? (Segel & Heer's spectrum)
6. If the presentation scrolls, does continuous scroll actually fit discrete story steps, or would an
   explicit stepper serve better? (Kosara's objection)

**Group E: Interaction & exploration (relevance rank 5, powerful and overrated)**

1. Should this be interactive at all? Would a well-designed static view beat it for the actual task?
   (Mosca, Ottley & Chang)
2. Which mechanism fits the task: overview+detail, zooming, focus+context distortion, or cue-based
   highlighting? Each has documented failure modes. (Cockburn et al.)
3. How many disclosure levels am I asking users to descend? Past two, people get lost. (Nielsen, an
   institutional heuristic that has never been independently re-tested)
4. Did I classify anything frequently needed as "secondary"? That misclassification, not hiding itself, is
   progressive disclosure's main failure mode. (Nielsen)
5. Am I following the Mantra because evidence says so or because everyone cites it? (Craft & Cairns)

**Group F: Network, hierarchy & graph visualization (relevance rank 6, situational but Noah-shaped)**

1. How big and dense is the graph, and what is the task? Past roughly 20 vertices, matrices beat node-link
   on most tasks except path-finding. (Ghoniem et al., complicated by later replications)
2. Will this be a hairball at production scale, and am I reaching for bundling or filtering when the honest
   move is a different representation family? (Kosara)
3. If I bundle edges, do I accept that path tracing gets slower and less accurate in exchange for cleaner
   cluster structure? (Burch et al. on McGee & Dingliana)
4. Is area precise enough for the comparison users need, or is this treemap asking area (a weak,
   non-preattentive channel) to do position's job? (NN/G on treemaps)
5. Does the layout need to stay stable across refreshes, and do I know that mental-map preservation has
   never been conclusively shown to help comprehension? (Burch et al.)

**Group G: The field itself (relevance rank 7, orientation value)**

1. Which school's advice am I taking right now, and what is its evidence level?
2. Is this "rule" a validated finding, or folklore with 5,000 citations? (the Mantra and the data-ink ratio
   both fail this check in different ways)
3. When a chart misleads, do I locate the failure in the person (Cairo) or in the design defaults (Few),
   and what does that choice imply about the fix?

### 3.3 The live-debate register

These are the fifteen places where credentialed experts still disagree. Each is a future deep-dive
candidate; the four recommended dives in section 1 cover debates 1 through 10.

1. **Universal channel ranking vs. individual differences.** Cleveland & McGill's hierarchy (reaffirmed by
   Heer & Bostock 2010) vs. Davis et al. 2022's finding that up to 30% of viewers deviate from the average
   observer. The ranking holds in aggregate; its use as a per-person design law is contested.
2. **Data-ink minimalism vs. embellishment.** Tufte's orthodoxy vs. Bateman et al.'s CHI 2010 RCT (better
   recall at 2-3 weeks, no accuracy penalty) and Elavsky's 2025 accessibility critique.
3. **Preattentive pop-out vs. attention-gated perception.** Ware's parallel pop-out framing vs. Simons &
   Chabris's demonstration that salient objects are routinely missed without focused attention.
4. **Does interaction improve comprehension?** Toolmaker folklore says yes; the only RCT in the corpus
   (Mosca et al. 2021) found it can significantly detract, moderated by spatial ability.
5. **Is the Mantra validated or folklore?** Craft & Cairns found no validation study despite near-universal
   citation; even they concede "for most designers, the Mantra works."
6. **Which focus+context mechanism wins?** Cockburn et al.: none universally; task type decides, and
   fisheye distortion measurably hurt targeting in a shipped product (the Mac OS X Dock).
7. **Scrollytelling: affordance or gimmick?** NYT practitioners defend disciplined scroll-driven narrative;
   Kosara argues continuous scroll mismatches discrete story steps and steppers usually serve better.
8. **Dashboards: dead artifact or implementation failure?** Brownlow 2020 vs. the rebuttal corpus
   (Holistics, Taft) vs. Brownlow's own 2023 revision blaming process and relationships, not tooling.
9. **The alert/dashboard boundary.** SRE philosophy draws a clean line (interrupt only for urgent,
   actionable, user-visible); the 2025 ACM survey shows industry still cannot operationalize it (four
   unresolved causes of alert fatigue).
10. **Node-link vs. matrix.** Ghoniem's 20-vertex crossover vs. Okoe et al.'s 835-person replication where
    node-link regained path tasks and matrices kept neighbor/group tasks. Task-dependent, unresolved.
11. **Does edge bundling help?** Preferred for large compound graphs (Telea et al.) but slower and less
    accurate for path reading (McGee & Dingliana). A trade, not a win.
12. **Mental-map preservation.** Widely assumed design principle; no experiment has found conclusive
    evidence it improves comprehension of graph evolution.
13. **Rules vs. context.** Tufte's prescriptive one-right-way vs. Cairo's five context-dependent qualities
    (truthful, functional, beautiful, insightful, enlightening).
14. **Tables vs. charts: boundary or spectrum?** The academic split (precision vs. pattern) vs. practitioner
    hybrids (sparklines inside tables) the literature has not caught up with.
15. **Is academic InfoVis rigorous, or rigor-theater?** Replication-crisis and design-study-rigor critiques
    from inside CHI raise how much weight the academic tradition's own evaluation culture deserves.

## 4. Analysis

### 4.1 Consensus zones (answers to RQ1 and RQ2)

Six claims sit in settled valleys, meaning multiple independent traditions or replications agree.

Position and length beat angle, area, and volume for decoding quantity. The 1984 experiments, the 2010
crowdsourced replication, Munzner's textbook, and even the 2022 individual-differences critique all agree at
the population level (perception: keep, Levels 2 and 7). Attention gates perception: 54% of 192 observers
noticed the gorilla, and task difficulty (not salience) predicted noticing (Simons & Chabris, keep,
Level 2). Tables serve precision and lookup; charts serve pattern and trend (Remshard & Queenborough, keep,
Level 4, corroborated across practitioner blogs). Operational surfaces should be single-screen,
exception-based, and scent-rich, a conclusion Few reaches from perceptual psychology, Google SRE reaches
from pager fatigue, and NN/G reaches from foraging theory, three roads into the same valley (keep, Levels 7,
5, 4). Annotation moves decoding work from the reader's head onto the page, endorsed independently by the
NYT and the FT and consistent with Segel & Heer's visual-narrative tactics (keep, Levels 7 and 6). And the
encoding vocabulary itself (Bertin's variables, Munzner's marks and channels, Wickham's layered grammar) is
settled infrastructure: the three frameworks descend from each other rather than compete (keep, Level 7).

### 4.2 Contested zones (RQ3, both sides fairly)

The register in section 3.3 lists all fifteen; four deserve a fair both-sides paragraph here because a naive
reading would get them wrong.

On minimalism: Tufte's position is not a straw man. His original target was non-functional decoration, and
Elavsky's own reductio (stripping a chart to one pixel per point) concedes that some "within reason" clause
was always doing the work. The Bateman side holds a real Level 2 result, better recall after two to three
weeks with no accuracy cost, but its authors explicitly refuse to recommend embellishing everything. The
honest reading: the data-ink ratio is a heuristic, not a law, and both camps now mostly agree on that.

On interaction: Mosca, Ottley & Chang is one RCT on one task type (Bayesian reasoning), and its authors
scope it carefully. It does not prove interaction is bad; it proves interaction is not automatically good,
and that a well-designed static chart can match or beat an interactive one. The mantra tradition, for its
part, was never claiming experimental backing; Shneiderman himself called the paper descriptive. The fight
is really about burden of proof, and the RCT shifts it onto whoever wants to add the widget.

On dashboards: Brownlow's over-tasking diagnosis (one artifact asked to do storytelling, lookup, and
analysis at once) survives even her own 2023 retraction of the tooling blame, and the rebuttals (Holistics,
Taft) agree the failures are real while relocating the cause to strategy and implementation. Both sides
describe the same patient; they disagree about the diagnosis, not the symptoms.

On graphs: Ghoniem's matrices-beat-node-link result is real but narrower than its fame. Later, larger
replications split the tasks (node-link recovered path-finding; matrices kept neighbor and group tasks), and
hybrids like MatLink beat both pure forms in a 36-person study. Kosara's abandon-the-node-link position is
the contrarian pole; the academic mainstream treats the families as complementary tools.

### 4.3 Gaps (RQ3 fuel for future dives)

The blank patches on the map, where a claim everyone repeats has never been properly tested: the Mantra has
no validation study (Craft & Cairns looked); Nielsen's two-level disclosure cap is repeated across 2020s UX
writing without independent re-testing; mental-map preservation has no conclusive supporting experiment;
nobody in the annotation camp seriously engages the Tufte-side worry that dense on-chart text becomes
chartjunk; the ACM survey's four causes of alert fatigue remain unsolved at industry scale; Few's "most
dashboards fail" ships with no measured failure rate; the tables-vs-charts hybrid zone (sparklines in
tables) is practitioner-led with no academic verdict; and the individual-differences program (Davis et al.)
is young, with few independent replications of its novel claim.

### 4.4 Institutional vs. ground truth (RQ4)

Where the official guidance and the working world diverge, the map should say so. NN/G's guidance is the
most widely read in the corpus, and its foraging material faithfully carries real Pirolli & Card research,
but its two-level cap is an institutional heuristic resting on unpublished testing. BI vendors still sell
the gauges and traffic lights Few condemned in 2006; the tooling defaults have outlived the critique.
Newsroom practice runs ahead of academic validation: the NYT's sketch-first, three-takeaways discipline is
exactly the ELI10 method this program wants, documented only as interview evidence (Level 6). Google's SRE
line is the reverse case, ground truth that became institutional guidance, and it converges with Few's
perception-derived rules, which is the strongest cross-tradition corroboration in the corpus. Finally, the
field's own professional body (DVS) canonizes both schools' books in one reading list, so the schools' fight
is real but their canon is shared, which answers RQ1's "how do the schools relate" more neatly than any
single source does.

## 5. Research

Findings per subfield. Every citation carries its score band and evidence level; full entries live in the
bibliography (section 7).

### 5.1 Perception & graphical cognition

Cleveland & McGill (1984; keep, Level 2) defined ten elementary perceptual tasks and ranked them by decoding
accuracy: position on a common scale first, then non-aligned position, then length/direction/angle, then
area, volume/curvature, and shading/saturation last. That ranking is why bar charts beat pie charts for
comparison. Heer & Bostock (2010; keep, Level 2) replicated the ranking on Mechanical Turk with far larger
samples, found one divergence (angle vs. length), and added new results: extreme aspect ratios hurt
rectangular-area judgment (directly informing squarified treemaps), and chart size and gridline spacing have
quantifiable effects. Ware (3rd ed. 2012; keep, Level 7) is the synthesis bridge: perception science,
correctly applied, makes important patterns stand out, and disobeying it makes data "incomprehensible or
misleading." Simons & Chabris (1999; keep, Level 2) supply the constraint the encoding papers assume away:
with attention loaded, only 54% of 192 observers noticed the gorilla, similarity to attended objects drove
detection, and proximity did not. Davis et al. (2022; keep, Level 2) closed the loop with Bayesian
multilevel modeling of the classic paradigm: the population ranking largely holds, but as much as 30% of
people are likely not "best with the Bar," so the field should report distributions, not just
average-observer rankings.

### 5.2 Visual encoding & the grammar of graphics

Bertin via Sluis (1967/2016; keep, Level 7) contributes the original vocabulary: two planar variables plus
six retinal variables (size, value, texture, color, orientation, shape), influential everywhere and read
almost nowhere. Munzner (2014; keep, Level 7) modernizes it into marks and channels inside the what-why-how
frame, with the expressiveness principle (show all and only the data) and effectiveness principle (salience
matched to importance); she insists the process is a guide, not a "straightjacket." Wickham (2010; keep,
Level 7) operationalizes Wilkinson's grammar into the layered form that became ggplot2 and its ports in
four-plus languages; the proof is a decade of adoption rather than an experiment. Remshard & Queenborough
(2023; keep, Level 4) draw the tables-vs-charts boundary (precision/lookup vs. pattern/trend) and give
auditable table rules: right-flush numerals, tabular fonts, consistent precision, minimal gridlines, active
titles. Elavsky (2025; keep, Level 7, the batch's weakest keep at roughly 7.1 weighted) runs the contrarian
stress test: the data-ink ratio taken literally produces unreadable charts, minimalism pushed too far
excludes readers, and the Bateman RCT (see 5.7) backs the critique with data.

### 5.3 Interaction & exploration

Shneiderman (1996; keep, Level 7) states the Mantra and the seven-task-by-seven-data-type taxonomy that the
whole subfield descends from; his most-cited paper (5,700+ citations) is design synthesis, not experiment.
Craft & Cairns (2005; keep, Level 6) reviewed the citing literature and found no validation study of the
Mantra, while conceding it "works" for most designers: a call for evidence, not a rebuttal. Cockburn,
Karlson & Bederson (2008; keep, Level 1) is the subfield's strongest evidence artifact, a systematic review
sorting all techniques into overview+detail, zooming, focus+context, and cue-based families, each with
documented failure modes; zooming "is easy to do badly," and the Mac OS X Dock's fisheye measurably harmed
targeting. Mosca, Ottley & Chang (2021; keep, Level 2) ran the falsification check: across two randomized
experiments, adding interaction did not improve Bayesian-reasoning accuracy and sometimes significantly
detracted, with spatial ability moderating the effect. Nielsen (2006; keep band, Supporting decision,
Level 4) contributes progressive disclosure and its two-level ceiling, the corpus's named weakest keep:
high authority, dated, and methodologically thin.

### 5.4 Narrative & explanatory visualization

Segel & Heer (2010; keep, Level 6) coded 58 real examples into seven genres and two tactic families, and
named the field's founding tension: author-driven flow vs. reader-driven discovery. The paper carries an
IEEE Test-of-Time Award. Cairo (2016; borderline, Level 7) supplies the values ordering (truthful, then
functional, then beautiful) and the reading-not-seeing thesis; his book was reachable only through interview
and course material this session, and one named critic calls his statistical casualness "very dangerous."
Schwabish (2018; keep, Level 7) gives the three concrete annotation moves: direct labels instead of legends,
active titles that state the finding, and added on-chart detail, anchored by Amanda Cox ("the annotation
layer is the most important thing we do") and John Burn-Murdoch. Storybench's NYT interview (2022; keep,
Level 6) documents the production discipline: sketch first, pair paragraphs with visuals, spend at least 50%
of the work on detail polish, and cut until "three really solid points" remain. Kosara (2016; borderline,
Level 7) is the deliberate contrarian: continuous scroll mismatches discrete story steps, scroll-jacking and
missing progress indicators are named failure modes, and a stepper usually serves readers better.

### 5.5 Dashboards & operational/monitoring UI

Few (2006/2013; keep, Level 7) defines the artifact: the most important information for an objective,
consolidated on a single screen, monitorable at a glance, with 13 named failure modes and a warning that
cute gauges "lose their spark in a matter of days." Google SRE (2016; keep, Level 5) independently derives
the same shape from operations: four golden signals (latency, traffic, errors, saturation), symptom-based
alerting, pages only for urgent-actionable-user-visible conditions, and everything subcritical pushed to a
dashboard. NN/G's information-foraging article (2019; keep, Level 4) supplies the mechanism: users
satisfice, scent is carried by titles, images, and above-the-fold content, and misaligned scent makes users
abandon a view. Brownlow (2020/2023; borderline, Level 8, the named marginal keep) argues dashboards fail
because they are asked to do incompatible jobs at once, then revises her own diagnosis in 2023 toward
relationships and process; the 250,000+ views and multiple published rebuttals prove the tension is live.
Tariq et al. (2025; keep, Level 1) close the arc with an ACM Computing Surveys review: alert fatigue in
security operations has four major causes and no solved mitigation, and the problem generalizes beyond
security to other command-and-control domains.

### 5.6 Network, hierarchy & graph visualization

Shneiderman (1992; keep, Level 7) invented treemaps to see a chronically full 80MB shared disk: recursive
space-filling rectangles that trade path-tracing for magnitude-at-a-glance. NN/G's Laubheimer (2019; keep,
Level 7) pairs the origin with its critique: area is not preattentive, so treemaps fail precise comparisons
and degrade into "a sea of tiny rectangles." Ghoniem, Fekete & Castagliola (2004/2005; keep, Level 2) ran
the subfield's landmark controlled experiment: past about 20 vertices, matrices beat node-link on most of
seven tasks, except path-finding. Kosara (2012; borderline, Level 7, the run's lowest-scoring keeper)
translates the result for practitioners: bundling, filtering, and layout tricks do not solve the hairball,
so change representation family (matrices, node quilts, PivotGraph). Holten (2006; keep, Level 7)
contributes hierarchical edge bundling, the standard clutter-reduction technique for compound graphs,
evaluated only informally in the original paper. Burch et al. (2021; keep, Level 1) is the meta-check:
replications split the node-link/matrix result by task, bundling helps cluster judgments while hurting path
reading, hybrids beat both pure forms in one study, and mental-map preservation lacks conclusive evidence.

### 5.7 The field itself (schools, history, meta)

Munzner's nested model (2009; keep, Level 4) is the academic tradition's self-description: four nested
levels (domain, abstraction, encoding/interaction, algorithm) where upstream errors cascade downstream,
adopted at 80+ universities. Cairo's *How Charts Lie* via Kosara's review (2019; keep, Level 7) is the
practitioner-skeptic entry: "charts don't lie, people do," a chart is a visual argument, and Tufte's
one-right-way tradition deserves rebellion. Bateman et al. (2010; keep, Level 2) is the empirical shot at
minimalism: embellished charts matched plain ones on accuracy and beat them significantly on 2-3-week
recall, with the authors explicitly cautious about overgeneralizing. Few's "Why Most Dashboards Fail" (2007;
borderline, Level 7) grounds the skeptic case in operational BI: an unhedged, uncited "most fail" claim,
blamed on vendor incentives, kept deliberately as the boots-on-the-ground voice with its evidence weakness
flagged. Makulec's DVS guide (2022; keep, Level 4) is the institutional map: concepts before tools, one tool
deeply before many, and a canon list that independently endorses both Munzner and Cairo.

## 6. Methodology

### 6.1 Search log

All 72 scout queries, verbatim, grouped by track.

**Perception (12 queries)**

| # | Query |
|---|-------|
| 1 | Cleveland McGill graphical perception experiments encoding effectiveness |
| 2 | Cleveland McGill 1984 replication modern study visual encoding accuracy |
| 3 | preattentive processing data visualization Colin Ware practitioner review |
| 4 | change blindness working memory limits visualization criticism debunked |
| 5 | Heer Bostock 2010 crowdsourcing graphical perception Mechanical Turk CHI paper |
| 6 | "risks of ranking" graphical perception individual differences critique Cleveland McGill |
| 7 | Simons Chabris invisible gorilla change blindness sustained inattentional blindness experiment |
| 8 | Munzner Visualization Analysis Design perception chapter channels effectiveness ranking |
| 9 | Heer Bostock "crowdsourcing graphical perception" pdf jeffrey-heer.com OR homes.cs.washington.edu |
| 10 | Colin Ware "Information Visualization" "preattentive" "milliseconds" quote book excerpt |
| 11 | Colin Ware "Information Visualization Perception for Design" review "the choice of" preattentive quote |
| 12 | "Cleveland" "McGill" 1984 "Graphical Perception" JASA abstract "elementary perceptual tasks" pdf |

**Encoding (7 queries)**

| # | Query |
|---|-------|
| 1 | Munzner what why how visualization channels marks book |
| 2 | Bertin semiology of graphics visual variables review critique |
| 3 | when tables beat charts research readability |
| 4 | Tufte data-ink ratio criticism debunked grammar of graphics |
| 5 | Wilkinson "Grammar of Graphics" book ggplot2 Wickham layered grammar |
| 6 | Bateman 2010 useful junk chartjunk memorability study |
| 7 | "Munzner" "expressiveness" "effectiveness" visualization idiom what why how quote |

**Interaction (11 queries)**

| # | Query |
|---|-------|
| 1 | Shneiderman "overview first, zoom and filter, then details-on-demand" mantra visual information seeking |
| 2 | critique of Shneiderman's visual information seeking mantra interaction visualization |
| 3 | brushing and linking focus plus context semantic zoom progressive disclosure visualization |
| 4 | "interaction" visualization "does more harm than good" OR "harmful" evaluation study |
| 5 | Cockburn Karlson Bederson "review of overview+detail, zooming, and focus+context interfaces" |
| 6 | practitioner blog "interactive dashboards" nobody uses filters click-through rate low |
| 7 | Stephen Few interactivity dashboards critique "interaction" overused analytics |
| 8 | Nielsen Norman Group progressive disclosure definition when to use |
| 9 | "Does Interaction Improve Bayesian Reasoning with Visualization" Mosca Wattenberg authors CHI 2021 |
| 10 | Shneiderman 1996 "The Eyes Have It" task by data type taxonomy full text pdf |
| 11 | Nielsen Norman Group "progressive disclosure" article Budiu full text hide options |

**Narrative (11 queries)**

| # | Query |
|---|-------|
| 1 | Segel Heer narrative visualization design space genres storytelling techniques |
| 2 | Alberto Cairo functional art truthful visualization criticism review |
| 3 | scrollytelling design guide best practices data journalism |
| 4 | annotation-first chart design does not work criticism narrative visualization |
| 5 | scrollytelling backlash criticism overused gimmick data journalism |
| 6 | Jonathan Schwabish "Better Data Visualizations" storytelling chapter review |
| 7 | Robert Kosara "story points" narrative visualization definition problems with the term |
| 8 | New York Times Upshot annotated chart design case study visual explanation |
| 9 | eagereyes "The Scrollytelling Scourge" Kosara |
| 10 | "Narrative Visualization: Telling Stories with Data" abstract "we present a1" OR "In this paper we examine" |
| 11 | Cairo "The Truthful Art" quote "visualizations, first and foremost, must be accurate" |

**Dashboards & operational (9 queries)**

| # | Query |
|---|-------|
| 1 | Stephen Few dashboard design principles information display |
| 2 | glanceability research dashboard cognitive load empirical study |
| 3 | "death to dashboards" contrarian dashboards don't work |
| 4 | alerting fatigue status UX information scent monitoring dashboards research |
| 5 | Pirolli Card information scent foraging theory information seeking |
| 6 | Google SRE book "My Philosophy on Alerting" Rob Ewaschuk monitoring distilled |
| 7 | "Dashboards are dead" Taylor Brownlow Count medium |
| 8 | Stephen Few "Information Dashboard Design" "thirteen common mistakes" quote excerpt |
| 9 | "Alert Fatigue in Security Operations Centres" ACM Computing Surveys abstract authors |

**Networks & graphs (10 queries)**

| # | Query |
|---|-------|
| 1 | graph drawing aesthetics criteria readability crossing minimization survey |
| 2 | Holten edge bundling hierarchical compound graphs paper |
| 3 | hairball network visualization critique matrices small multiples alternative |
| 4 | node-link diagrams don't work stop using force-directed graph visualization criticism |
| 5 | Ghoniem Fekete Castagliola readability of graphs using node-link and matrix representations user study |
| 6 | Shneiderman treemap "tree visualization" 1992 space-filling approach |
| 7 | Purchase "graph drawing aesthetics" empirical study which criteria matter most cognition |
| 8 | mental map preservation dynamic graph layout stability survey Beck Burch |
| 9 | treemap criticism problems reading hierarchy usability limitations |
| 10 | Ghoniem readability graphs node-link matrix pdf aviz.fr OR fekete.free.fr |

**Field/meta (12 queries)**

| # | Query |
|---|-------|
| 1 | history of information visualization academic InfoVis subfields taxonomy |
| 2 | Tufte vs Few vs Cairo data visualization philosophy differences |
| 3 | how I learned data visualization career advice practitioner blog |
| 4 | most data visualizations fail readers critique chartjunk misleading charts |
| 5 | "replication crisis" OR "rigor" criticism of information visualization research CHI empirical methods |
| 6 | Alberto Cairo "How Charts Lie" book review key argument |
| 7 | Munzner "Visualization Analysis and Design" nested model textbook review |
| 8 | Bateman Mandryk "Useful Junk" chartjunk memorability study abstract |
| 9 | Munzner "A Nested Process Model for Visualization Design and Validation" 2009 PDF |
| 10 | site:cs.ubc.ca tmm papers nestedModel infovis09 pdf |
| 11 | Stephen Few "most dashboards fail" OR "dashboard design" perceptualedge critique business intelligence |
| 12 | "useful junk" Bateman 2010 abstract "visual embellishment" comprehension memorability |

### 6.2 Evidence-level distribution (36 cards)

| Level | Meaning | Count | Share |
|-------|---------|-------|-------|
| 1 | Systematic review | 3 | 8% |
| 2 | Randomized/controlled experiment | 7 | 19% |
| 4 | Expert consensus / professional-body guidance | 5 | 14% |
| 5 | Practitioner case study with data | 1 | 3% |
| 6 | Qualitative research / structured interview | 3 | 8% |
| 7 | Expert opinion / thought leadership | 16 | 44% |
| 8 | Anecdotal / personal experience | 1 | 3% |

Be frank about that 44%: nearly half the canon is credentialed opinion. That is the field, not a sampling
artifact, and it is exactly why the evidence-level habit in section 1 matters.

### 6.3 Source-category distribution (36 cards)

| Category | Count |
|----------|-------|
| Peer-reviewed papers (journal/conference) | 18 |
| Books (accessed direct or via review/interview) | 6 |
| Institutional guidance (NN/G, DVS, Urban, Google SRE) | 6 |
| Practitioner blogs/essays | 5 |
| Practitioner interview journalism | 1 |

### 6.4 Credibility-band distribution

| Band | Count | Notes |
|------|-------|-------|
| keep | 31 | includes named weakest keeps: Nielsen 2006, Elavsky (~7.1 weighted) |
| borderline | 5 | Cairo Truthful Art, Kosara Scrollytelling, Kosara Hairball, Brownlow, Few Why-Fail |

### 6.5 Perspective-balance matrix

Target: at least 3 of 5 perspective categories per subfield.

| Subfield | Academic | Practitioner | Contrarian | Institutional | Boots-on-ground | Categories |
|----------|----------|--------------|------------|---------------|-----------------|------------|
| Perception | 3 | 1 | 1 | 0 | 0 | 3 of 5 |
| Encoding | 2 | 1 | 1 | 0 | 1 | 4 of 5 |
| Interaction | 3 | 0 | 1 | 1 | 0 | 3 of 5 |
| Narrative | 1 | 1 | 1 | 1 | 1 | 5 of 5 |
| Operational | 1 | 1 | 1 | 1 | 1 | 5 of 5 |
| Networks | 4 | 0 | 1 | 1 | 0 | 3 of 5 |
| Field/meta | 1 | 1 | 1 | 1 | 1 | 5 of 5 |

All seven subfields meet the 3-of-5 bar. Perception, interaction, and networks skew academic because their
load-bearing claims are experimental; the missing categories there are documented rather than papered over
(for example, no boots-on-the-ground perception source surfaced in four search passes that cleared the bar).

### 6.6 Bias-guard summary

Each card records whether the researcher agreed, disagreed, or was neutral toward the source, with scoring
adjusted accordingly (harder on agreement, more generous on disagreement).

| Stance | Count | Notes |
|--------|-------|-------|
| Agree (scored harder on dims 5/6/8) | 20 | includes Brownlow, marked partial agreement |
| Disagree (scored more generously) | 1 | Davis et al.; on reflection its claim proved modest |
| Neutral | 15 | concentrated in the operational and networks tracks |

### 6.7 Verification

Independent citation verification (see verification-report.md): sample size **11 of 36 (30.6%)**, selected
by seeded random draw (seed 20260728). Outcomes: 10 verified, 0 failed, 1 inaccessible (Shneiderman 1996,
gated by IEEE Xplore; quote verified by two independent secondary corroborations instead). Failure count:
**0**. Failure rate: 0 / (10 + 0) = 0.0%, band **<=5%**. All 24 checkable quote strings matched
character-for-character after tolerated normalization, including one faithfully transcribed source-side
typo. Two cards carry imperfect but non-failing location metadata (Simons & Chabris page numbers; Ware
edition ambiguity), flagged for a cleanup pass.

### 6.8 Paywall scan

Nine must-read primaries could not be fetched in full and were carded through legitimate partial access:
Cleveland & McGill 1984 (JASA paywalled; ranking via secondary), Ware's book interior (publisher preview
only), Shneiderman 1996 (IEEE gated; verified by corroboration), Holten 2006 full text (IEEE paywalled;
abstract via TU/e portal), Tariq et al. full text (dl.acm.org 403; CC-BY abstract via Semantic Scholar),
Munzner's VAD book (print; free slides and videos exist), Bertin (out of print; via Sluis retrospective),
Cairo's two books (trade print; via interviews and reviews), and Brownlow's 2020 original (HTTP 410 Gone;
reconstructed from her own 2023 follow-up). Every partial-access case is flagged on its card rather than
concealed.

### 6.9 Limitations, exclusions, and the lowest bar-clearer

This phase tested nothing empirically; every finding is literature-derived. Several foundational texts were
read through secondary lenses (Bertin, both Cairo books, Munzner's textbook), so their interior arguments
are corroborated rather than independently verified. The verification sample covered 30.6% of cards, not all
of them. The corpus skews academic in three subfields (documented in 6.5) and 44% of it is Level 7 opinion.
Scout-proposed curricula were inherited and lightly harmonized rather than re-derived from scratch.

Named exclusions: the Holistics rebuttal "Death to Dashboards, Really?" and Scott Taft's "Killing Dashboards
Isn't the Answer" were found and used as debate context but not carded (secondary rebuttals, below the card
bar); ChartExpo, Luzmo, and wpDataTables hybrid table-chart posts were found in search and excluded as
low-authority vendor content. Lowest-scoring source that cleared the bar: Brownlow's "Dashboards are Dead"
(weighted roughly 5.1, borderline, Level 8), kept deliberately and with its evidence weakness stated,
because cutting it would have left the contrarian pole of RQ3's liveliest dashboard debate unrepresented.

## 7. Bibliography

All 36 included sources. Format: citation. Band / evidence level / inclusion decision. Contribution.

### Perception & graphical cognition

1. Cleveland, W.S. & McGill, R. (1984). "Graphical Perception." JASA 79(387), 531-554. keep / Level 2 /
   Core. Origin paper for the channel-effectiveness ranking every later study replicates or contests.
2. Heer, J. & Bostock, M. (2010). "Crowdsourcing Graphical Perception." CHI 2010. keep / Level 2 / Core.
   Large-sample open-access replication of the 1984 ranking, extended to treemap-area and gridline effects.
3. Ware, C. (2012). *Information Visualization: Perception for Design*, 3rd ed. keep / Level 7 / Core.
   The standard synthesis translating vision science (preattentive processing, working memory) into design.
4. Simons, D.J. & Chabris, C.F. (1999). "Gorillas in Our Midst." *Perception* 28(9). keep / Level 2 / Core.
   Canonical demonstration that attention, not visibility, gates what viewers actually register.
5. Davis, R. et al. (2022). "The Risks of Ranking." IEEE TVCG / VIS 2022. keep / Level 2 / Core.
   The live individual-differences challenge: up to 30% of viewers deviate from the average observer.

### Visual encoding & the grammar of graphics

6. Bertin, J. (1967/1983). *Semiology of Graphics*, via Sluis (2016) retrospective. keep / Level 7 / Core.
   The original visual-variables taxonomy every later encoding framework descends from.
7. Munzner, T. (2014). *Visualization Analysis and Design*, via Romanowski review. keep / Level 7 / Core.
   What-why-how, marks and channels, and the expressiveness/effectiveness principles.
8. Wickham, H. (2010). "A Layered Grammar of Graphics." JCGS 19(1). keep / Level 7 / Core.
   Wilkinson's grammar made practical; the theory underneath ggplot2 and its ports.
9. Remshard, M. & Queenborough, S.A. (2023). "Design of tables..." *Ecology and Evolution* 13(7). keep /
   Level 4 / Core. The peer-reviewed tables-vs-charts boundary plus auditable table-design rules.
10. Elavsky, F. (2025). "Minimalism and the absurdity of the data-to-ink-ratio." frank.computer. keep /
    Level 7 / Core. The contrarian stress test of Tufte's ratio, grounded in the Bateman experiment.

### Interaction & exploration

11. Shneiderman, B. (1996). "The Eyes Have It." IEEE VL'96. keep / Level 7 / Core.
    The Mantra and the task-by-data-type taxonomy the entire subfield responds to.
12. Craft, B. & Cairns, P. (2005). "Beyond Guidelines." IV'05. keep / Level 6 / Core.
    The documented absence of any validation study for the Mantra despite universal citation.
13. Cockburn, A., Karlson, A. & Bederson, B. (2008). "A Review of Overview+Detail, Zooming, and
    Focus+Context Interfaces." ACM Computing Surveys 41(1). keep / Level 1 / Core. The four-family taxonomy
    of interaction mechanisms with per-technique empirical failure modes.
14. Mosca, A., Ottley, A. & Chang, R. (2021). "Does Interaction Improve Bayesian Reasoning with
    Visualization?" CHI 2021. keep / Level 2 / Core. The RCT showing interaction can significantly detract.
15. Nielsen, J. (2006). "Progressive Disclosure." NN/G. keep / Level 4 / Supporting.
    The pattern definition and the two-level usability ceiling; the corpus's named weakest keep.

### Narrative & explanatory visualization

16. Segel, E. & Heer, J. (2010). "Narrative Visualization: Telling Stories with Data." IEEE TVCG 16(6).
    keep / Level 6 / Core. Seven genres, two tactic families, and the author-vs-reader control spectrum.
17. Cairo, A. (2016). *The Truthful Art*, via Cool Infographics interview. borderline / Level 7 /
    Supporting. The values ordering (truthful before functional before beautiful) that bounds technique.
18. Kosara, R. (2016). "The Scrollytelling Scourge." eagereyes.org. borderline / Level 7 / Supporting.
    The sharpest named critique of scroll-driven narrative; the register's scroll-vs-stepper debate.
19. Schwabish, J. (2018). "Three Ways to Annotate Your Graphs." Data@Urban. keep / Level 7 / Core.
    The three concrete annotation moves, anchored by NYT and FT practitioner testimony.
20. Stogniew, A. (2022). "Scrollytelling innovation..." Storybench. keep / Level 6 / Supporting.
    The only end-to-end named production account: sketch-first, 50% polish, three solid takeaways.

### Dashboards & operational/monitoring UI

21. Few, S. (2006/2013). *Information Dashboard Design*. keep / Level 7 / Core.
    The single-screen at-a-glance definition and the 13 dashboard failure modes.
22. Ewaschuk, R. / Google SRE (2016). "Monitoring Distributed Systems." keep / Level 5 / Core.
    Four golden signals, symptom-based alerting, and the alert/dashboard boundary from production practice.
23. Budiu, R. (2019). "Information Foraging." NN/G. keep / Level 4 / Core.
    The cognitive mechanism (scent, satisficing) that explains why glanceability works.
24. Brownlow, T. (2020/2023). "Dashboards are Dead" + "3 Years Later." borderline / Level 8 / Supporting.
    The contrarian over-tasking diagnosis and its author's own honest revision; the named marginal keep.
25. Tariq, S. et al. (2025). "Alert Fatigue in Security Operations Centres." ACM Computing Surveys 57(9).
    keep / Level 1 / Core. Peer-reviewed proof the alert-triage boundary remains unsolved at industry scale.

### Network, hierarchy & graph visualization

26. Shneiderman, B. (1992). "Tree Visualization with Tree-Maps." ACM TOG 11(1). keep / Level 7 / Core.
    The treemap origin paper and its space-for-precision trade.
27. Holten, D. (2006). "Hierarchical Edge Bundles." IEEE TVCG 12(5). keep / Level 7 / Core.
    The standard clutter-reduction technique for compound graphs.
28. Ghoniem, M., Fekete, J-D. & Castagliola, P. (2004/2005). "Readability of Graphs Using Node-Link and
    Matrix-Based Representations." keep / Level 2 / Core. The landmark node-link-vs-matrix experiment and
    the ~20-vertex crossover.
29. Burch, M. et al. (2021). "The State of the Art in Empirical User Evaluation of Graph Visualizations."
    IEEE Access 9. keep / Level 1 / Core. The systematic review that nuances every other networks keeper.
30. Kosara, R. (2012). "Graphs Beyond the Hairball." eagereyes.org. borderline / Level 7 / Supporting.
    The plain-language case for switching representation families; the run's lowest-scoring keeper.
31. Laubheimer, P. (2019). "Treemaps: Data Visualization of Complex Hierarchies." NN/G. keep / Level 7 /
    Supporting. The practitioner critique of treemaps: area is weak, small categories drown.

### The field itself (schools, history, meta)

32. Munzner, T. (2009). "A Nested Model for Visualization Design and Validation." IEEE TVCG 15(6). keep /
    Level 4 / Core. The academic tradition's four-level self-description; upstream errors cascade.
33. Cairo, A. (2019). *How Charts Lie*, via Kosara review + interview. keep / Level 7 / Core.
    The practitioner-skeptic frame: charts are visual arguments, and misuse lives in people.
34. Bateman, S. et al. (2010). "Useful Junk?" CHI 2010. keep / Level 2 / Core.
    The RCT that complicated minimalism: equal accuracy, significantly better delayed recall.
35. Few, S. (2007). "Why Most Dashboards Fail." Perceptual Edge. borderline / Level 7 / Core.
    The boots-on-the-ground operational-failure claim, kept with its lack of measured evidence flagged.
36. Makulec, A. (2022). "Starting Out in Data Visualization Today." Nightingale/DVS. keep / Level 4 / Core.
    The field's own onboarding map; independent confirmation that the two schools share one canon.
