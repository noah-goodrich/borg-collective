# Source: Google SRE — "Monitoring Distributed Systems"

**Full citation:** Ewaschuk, Rob (author), Beyer, Betsy (ed.). "Chapter 6: Monitoring
Distributed Systems." In *Site Reliability Engineering: How Google Runs Production
Systems*, eds. Beyer, Jones, Petoff, Murphy. O'Reilly Media, 2016. Companion essay:
Ewaschuk, Rob. "My Philosophy on Alerting" (unpublished internal doc, later folded into
the SRE book chapter).
**URL:** https://sre.google/sre-book/monitoring-distributed-systems/ (companion doc:
https://docs.google.com/document/d/199PqyG3UsyXlwieHaqbGiWVa8eMWi8zzAn0YfcApr8Q/mobilebasic)
**Date accessed:** 2026-07-28
**Evidence level:** 5 (Practitioner Case Study with Data — synthesized from years of
production incident/on-call experience across Google's fleet, not a controlled study)
**Research topic area:** Dashboards & operational/monitoring UI — alerting philosophy and
the dashboard/alert boundary

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|----------------|
| 1 | Authority | 9/10 | Written by a Google SRE and edited into Google's own published SRE book — direct operational authority over some of the largest production monitoring systems in the world. |
| 2 | Evidence Quality | 7/10 | Grounded in real incident/on-call experience at scale over many years, but presented as distilled principles rather than a formal dataset with methodology. |
| 3 | Currency | 8/10 | Published 2016; the "four golden signals" and alert-vs-dashboard philosophy are treated as durable operational principles (timeless bonus applied) and remain the industry-standard framing as of 2026. |
| 4 | Intent | 9/10 | Published free by Google as an industry knowledge-sharing exercise, not to sell a product; no paywall, no lead-gen. |
| 5 | Bias & Objectivity | 7/10 | Strongly opinionated ("every page should be actionable") but explicitly frames itself as "my philosophy," acknowledging it is one engineer's synthesis rather than universal law. |
| 6 | Logic & Coherence | 9/10 | Argues from first principles (symptom-based vs. cause-based alerting, pager fatigue) to concrete rules, with explicit test questions for any proposed alert. |
| 7 | Corroboration | 8/10 | The "avoid alert-flooding, push subcritical signal to dashboards" principle is independently echoed by the ACM SOC alert-fatigue survey and by NN/g's alert-fatigue guidance (see companion cards). |
| 8 | Intellectual Honesty | 8/10 | Explicitly distinguishes "urgent and actionable" from merely interesting signals, and warns against over-alerting on causes rather than symptoms — acknowledges failure modes of its own prior practice. |
| 9 | Specificity | 9/10 | Concrete, named framework (four golden signals: latency, traffic, errors, saturation) plus explicit alert-quality test questions. |
| 10 | Relevance | 10/10 | Directly addresses the dashboard/alert boundary and status-UX design questions central to this subfield. |

**Score band:** keep (weighted average ≈ 8.25 — the strongest card in this set)

## Bias Guard Check

- [x] Neutral / no strong reaction — evaluated the alert/dashboard split on its
  explanatory merits rather than pre-existing agreement or disagreement.

## Key Findings

- The "four golden signals" (latency, traffic, errors, saturation) are proposed as the
  minimum viable metric set for monitoring a user-facing system.
- Alerting should be symptom-based (user-visible impact), not cause-based, because
  symptoms "capture more problems more comprehensively and robustly with less effort."
- Every page (interrupt-driven alert) must clear three bars: it is urgent, it is
  actionable, and it requires human judgment — "every page should be actionable" and
  "every page response should require intelligence."
- Explicitly assigns dashboards a distinct role from alerts: subcritical, non-urgent
  signal belongs on a dashboard, not in an interrupting notification channel — "you
  should favor a dashboard that monitors all ongoing subcritical problems for the sort
  of information that typically ends up in email alerts."
- Warns that low-value alert channels (e.g., email alerts) "tend to easily become
  overrun with noise," an early articulation of what the alert-fatigue literature later
  formalizes.

## Verified Quote(s)

**Location reference:** sre.google/sre-book/monitoring-distributed-systems/, section
"The Four Golden Signals" and section "Tying These Principles Together" / "Conclusion."

> The four golden signals of monitoring are latency, traffic, errors, and saturation. If
> you can only measure four metrics of your user-facing system, focus on these four.

> Does this rule detect an otherwise undetected condition that is urgent, actionable,
> and actively or imminently user-visible?

> Email alerts are of very limited value and tend to easily become overrun with noise;
> instead, you should favor a dashboard that monitors all ongoing subcritical problems
> for the sort of information that typically ends up in email alerts.

**Access status:** live (fetched directly from sre.google; quotes verified against
section headings as located)

## Inclusion Decision

**Decision:** Core
**Rationale:** This is the field's clearest "boots-on-the-ground" operational
counterpart to Few's design-theory canon — it comes from people who run monitoring
dashboards under real incident pressure at scale, and it independently derives the same
single-screen/glanceable-summary logic from an alerting-fatigue angle rather than a
perceptual-psychology angle, giving the curriculum a second, independent line of
evidence.

**Redundancy check:** Not redundant with Few — Few argues from perceptual psychology
for dashboard design; this source argues from operational incident response for the
alert/dashboard boundary specifically. Both converge on "push subcritical signal to a
glanceable summary," which is a corroboration point worth flagging in synthesis.

**Perspective category:** Boots-on-the-ground
