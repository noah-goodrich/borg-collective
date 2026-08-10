# Source: Tariq et al. — "Alert Fatigue in Security Operations Centres: Research Challenges and Opportunities"

**Full citation:** Tariq, Shahroz; Baruwal Chhetri, Mohan; Nepal, Surya; Paris, Cécile.
"Alert Fatigue in Security Operations Centres: Research Challenges and Opportunities."
*ACM Computing Surveys*, Vol. 57, Issue 9, Article 224, April 2025.
**URL:** https://doi.org/10.1145/3723158
**Date accessed:** 2026-07-28
**Evidence level:** 1 (Systematic Review — the article itself is a structured literature
review of existing alert-fatigue research and industry solutions, aggregating findings
across the SOC alerting literature)
**Research topic area:** Dashboards & operational/monitoring UI — alert fatigue as a
status-UX failure mode

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|----------------|
| 1 | Authority | 9/10 | Authors are affiliated with CSIRO's Data61 (Australia's national science agency), published in ACM Computing Surveys, one of the highest-impact peer-reviewed survey venues in computer science. |
| 2 | Evidence Quality | 8/10 | A structured survey aggregating "existing literature and industry solutions" specifically on alert-fatigue mitigation, rather than a single study — but as with any survey, quality is bounded by the underlying primary studies it aggregates, which were not independently re-verified for this card. |
| 3 | Currency | 10/10 | Published April 2025, squarely within the 1-year-currency band for a fast-moving AI/security-tooling topic. |
| 4 | Intent | 9/10 | Academic inquiry published in a peer-reviewed venue, explicitly framed as identifying "research challenges and opportunities" for the field rather than promoting a product. |
| 5 | Bias & Objectivity | 8/10 | Explicitly frames itself as examining "the shortcomings of existing solutions," i.e., built to surface limitations rather than advocate one vendor or method. |
| 6 | Logic & Coherence | 8/10 | Structured argument: reviews causes of alert fatigue, evaluates existing automation/augmentation/human-AI-collaboration solutions, then derives research gaps — a standard, sound survey structure. |
| 7 | Corroboration | 8/10 | The core claim — that unprioritized, high-volume alerting causes fatigue and burnout and should be triaged/aggregated rather than surfaced raw — directly corroborates the Google SRE monitoring chapter's independent, decade-earlier operational argument for the same design principle in a different domain (production systems vs. security). |
| 8 | Intellectual Honesty | 8/10 | Explicitly built around identifying "shortcomings of existing solutions," signaling the authors do not claim the alert-fatigue problem is solved. |
| 9 | Specificity | 7/10 | Abstract identifies "four major causes of alert fatigue" and organizes solutions along three named lenses (automation, augmentation, human-AI collaboration); full methodological detail was not independently verified because the publisher page (dl.acm.org) returned an HTTP 403 to automated fetch, so this card relies on the open-access (CC BY) abstract rather than the full text. |
| 10 | Relevance | 8/10 | Domain is security-operations alerting specifically, not general dashboard/status UX, so some translation is required, but the mechanism (alert volume/noise causing fatigue and desensitization) is the same one implicated in general monitoring-dashboard design. |

**Score band:** keep (weighted average ≈ 8.5)

## Bias Guard Check

- [x] Neutral / no strong reaction — evaluated the survey on sourcing and structure; no
  prior stance on SOC-specific alerting research to guard against.

## Key Findings

- Real-time alert monitoring and triage is identified as a particularly important SOC
  function, and "recent studies, by both industry and academia, have highlighted the
  problem of alert fatigue and burnout" in that setting.
- The review organizes existing alert-fatigue mitigation approaches along three lenses:
  automation, augmentation, and human-AI collaboration.
- The authors "identify four major causes of alert fatigue" in SOC environments (specific
  causes not independently verified beyond the abstract, since full text was
  inaccessible at review time).
- The paper explicitly finds shortcomings in existing solutions and proposes AI-leveraging
  research directions rather than treating the problem as solved.
- The authors argue the alert-fatigue problem and its proposed research directions
  generalize "not just in SOCs but across other Command and Control (C2) domains,"
  explicitly positioning this as relevant beyond security operations — directly relevant
  to general operational-monitoring dashboard design.

## Verified Quote(s)

**Location reference:** Article abstract, as retrieved via the Semantic Scholar Graph
API record for DOI 10.1145/3723158 (open-access, CC BY license per the API's
`openAccessPdf` metadata; the abstract is authored content published verbatim at the DOI
landing page, which returned HTTP 403 to automated fetch at review time).

> A security operations centre (SOC) is a facility where teams of security professionals,
> supported by advanced technologies and processes, work together to monitor, detect,
> and respond to cybersecurity incidents. [...] Recent studies, by both industry and
> academia, have highlighted the problem of alert fatigue and burnout in SOC.

> we identify four major causes of alert fatigue in SOC. We also examine the
> shortcomings of existing solutions and propose several potential research directions
> leveraging AI.

> We anticipate that it will inspire new research directions for addressing alert
> fatigue not just in SOCs but across other Command and Control (C2) domains as well.

**Access status:** cached/partial — the DOI landing page (dl.acm.org) returned HTTP 403
to automated fetch; the abstract was independently retrieved and verified via the
Semantic Scholar Graph API, which reports the article as open-access (CC BY) at the same
DOI. Full body text was not verified beyond the abstract.

## Inclusion Decision

**Decision:** Core
**Rationale:** Supplies the Academic evidence-hierarchy anchor (a 2025 peer-reviewed
systematic review) for the alert-fatigue theme that the SRE and NN/g cards raise from
operational and applied-UX angles respectively — giving the curriculum a source at the
top of the evidence hierarchy for this specific claim.

**Redundancy check:** Not redundant — this is the only keeper source that is a formal
peer-reviewed systematic review; it corroborates but does not duplicate the SRE
chapter's practitioner-derived alerting philosophy.

**Perspective category:** Academic
