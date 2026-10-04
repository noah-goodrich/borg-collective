# Source: Lehtinen, Itkonen & Lassenius (2017), what agile teams discuss in retrospectives

**Full citation:** Lehtinen, T. O. A., Itkonen, J., Lassenius, C. "Recurring opinions or productive improvements—what
agile teams actually discuss in retrospectives." Empirical Software Engineering 22, 2409-2452 (2017). DOI
10.1007/s10664-016-9464-2. Published online 3 Nov 2016. Open access.
**URL:** https://link.springer.com/article/10.1007/s10664-016-9464-2
**Date accessed:** 2026-10-03
**Evidence level:** 5 (Longitudinal industrial case study with repository triangulation)
**Research topic area:** T4 feedback and learning: retrospectives, whether findings match evidence, recurrence

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 8/10 | Aalto University researchers; peer-reviewed in Empirical Software Engineering. |
| 2 | Evidence Quality | 5/10 | One organisation, 7 teams, 37 retrospectives; coded statements (kappa 0.55-0.65); two Jira comparisons. |
| 3 | Currency | 4/10 | Published 2016/17; data 2012-2014 (about 12 years old). |
| 4 | Intent | 9/10 | Academic inquiry; authors built the retro tool but sell nothing. |
| 5 | Bias & Objectivity | 8/10 | Reports both a retro topic that matched the data (bugs) and one that did not (estimates). |
| 6 | Logic & Coherence | 7/10 | Hypotheses (Table 12) are labelled hypotheses; some causes ("scapegoat") are interpretive. |
| 7 | Corroboration | 5/10 | Fits Jørgensen & Sjøberg on experience bias and practitioner retro critiques, which are weaker evidence. |
| 8 | Intellectual Honesty | 9/10 | Full validity section; says exact quantities do not generalise; results not verified by participants. |
| 9 | Specificity | 8/10 | Counts, percentages and per-topic tables; Figs. 9-10 compare statements to repository data. |
| 10 | Relevance | 7/10 | 3-5 person Scrum teams, not solo; the bias and recurrence findings transfer to any self-review loop. |

**Score band:** borderline
(Intermediate weighted average ~6.9.) Kept as gap-fill: the only empirical source found on what retrospectives
actually produce and whether their claims match repository data; named as one of the lowest-scoring included sources.

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Data: 37 team-level sprint retrospectives from one distributed Scrum organisation (7 teams, 2012-2014), plus Jira
  bug and estimation records. 445 negative statements led to 180 corrective actions; 66% of actions came from
  negative statements the team voted for. Discussion stays close to the team: sprint planning, implementation and
  testing were 75% of statements.
- Retro content tracks opinion unless evidence is brought in. Statements about open bugs matched the bug repository;
  statements about estimation accuracy contradicted the estimate-vs-actual data, and estimation accuracy did not
  improve despite repeated discussion and actions. The authors say the available bug and estimate data "was not
  used" in the meetings.
- Recurrence: 43 statements recurred; 9% of negative and 23% of positive statements recurred; 19% of all corrective
  actions targeted recurring topics, yet "the statements on the recurring topics kept repeating themselves". Three
  recurring discussions (estimation accuracy, bug-fix state, unclear instructions).
- Process gap: "the recorded outcomes of the previous retrospectives were not used as input for the forthcoming
  retrospective meetings". Root-cause analysis dealt with visible symptoms; items with low team control (cooperation,
  priority, existing product) got few or no actions.
- Correction to the earlier search-snippet note: the "13%" figure is not a retrospective success rate. In the full
  text 13% is the sprint-planning share of statements and the recurrence of two instruction-related statements.
  No overall "share of retros that lead to improvement" is reported.

## Verified Quote(s)

**Location reference:** Journal page numbers as printed (Empirical Software Engineering 22:2409-2452). Quote 1: p. 2409,
Abstract. Quote 2: p. 2417, Section 3.3, last sentence (begins on p. 2416; this quote is its second half). Quote 3: p. 2437, Section
4.3.3, last sentence. Quote 4: p. 2443, Section 4.4.3 "Reflections", first paragraph (second and third sentences).
Quote 5: p. 2445, Section 5.1, "The first viewpoint is bias" paragraph (final sentence).

> However, the discussions might suffer from participant bias, and in cases where they are not supported by hard evidence, they might not reflect reality, but rather the sometimes strong opinions of the participants.

> the recorded outcomes of the previous retrospectives were not used as input for the forthcoming retrospective meetings.

> Despite the developed corrective actions, the statements on the recurring topics kept repeating themselves.

> This analysis revealed that certain discussions, such as remarks on the high or low number of bugs, rather accurately reflected the state of development depicted by the repository data. Other discussions, such as the comments on poor estimation accuracy, did not match the situation reflected by the task repository data on task estimates and actual efforts.

> In this case, the evidence was not used, even though the bug data in particular would have been readily available.

**Access status:** cached/partial
**Access note:** full text read from a user-supplied copy on 2026-10-03; the live URL is bot-blocked. The paper is
open access, so a non-blocked copy may exist; the verifier should treat status as partial rather than live.

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Band is borderline; included as gap-fill (sole empirical study of retrospective outcomes found) and
named as the lowest-scoring included source in this batch. It supports "feed retros with repository facts" and
"track recurrence", not any claim that retrospectives improve outcomes (it did not test that).

**Redundancy check:** Adds measured evidence to the practitioner anti-pattern cards (t4-corry, t4-hn thread,
t4-maric); those assert recurrence and low follow-through, this one measures it in one organisation.

**Perspective category:** Academic
