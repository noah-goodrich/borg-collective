# Source: Context Engineering: A Practical Guide for AI Agents

**Full citation:** Tanner, Matt. "Context Engineering: A Practical Guide for AI Agents (2026)." Sourcegraph
Blog. May 28, 2026.
**URL:** https://sourcegraph.com/blog/context-engineering
**Date accessed:** 2026-08-12
**Evidence level:** 5 (Practitioner Case Study w/ data — cites Sourcegraph's own internal CodeScaleBench
benchmark with real recall/precision/F1 numbers, but the benchmark is self-reported by a vendor and not
independently audited or peer-reviewed)
**Research topic area:** Context engineering and agent navigation cost — quantified corroboration, from a
second independent industry player, that context size/precision (not just presence) affects agent outcomes;
included for corroboration even though it does not directly test codebase layering depth

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|----------------|
| 1 | Authority | 7/10 | Sourcegraph is an established code-intelligence company (SCIP indexing, MCP server used by real clients including Stripe and Amp per the article); real product and retrieval-infrastructure expertise, though this is vendor content, not independent research. |
| 2 | Evidence Quality | 6/10 | Cites a named internal benchmark (CodeScaleBench, run March 2026) with specific recall/precision/F1 deltas and a task-completion time figure — quantified, but self-reported by the vendor whose product it showcases, with no third-party replication. |
| 3 | Currency | 10/10 | Published May 2026, references a February 2026 product release and a March 2026 benchmark — as current as any source in this track. |
| 4 | Intent | 5/10 | Explicitly hybrid: genuine technical education about context-size effects, embedded in and "naturally funneling" toward promotion of Sourcegraph's own MCP server and retrieval product. |
| 5 | Bias & Objectivity | 5/10 | Vendor-published, self-reported benchmark comparing the vendor's own product against a baseline; no independent verification of the CodeScaleBench numbers is available from this source alone. |
| 6 | Logic & Coherence | 8/10 | Clean, well-organized argument connecting context size to specific failure modes ("context overload, context distraction, context confusion") with concrete supporting numbers for each. |
| 7 | Corroboration | 8/10 | Its central claim — that a large, unfocused context summary underperforms a small, targeted retrieval on the same task — independently corroborates both Anthropic's "smallest high-signal token set" principle and the Formal Architecture Descriptors paper's navigation-reduction findings, from a third, unrelated organization. |
| 8 | Intellectual Honesty | 6/10 | Publishes specific, checkable numbers (0.127 to 0.277 file recall, 0.140 to 0.478 Precision@5) rather than vague marketing superlatives, which is more falsifiable than typical vendor copy, but the comparison baseline and methodology are not fully detailed in the article. |
| 9 | Specificity | 8/10 | Concrete, named benchmark with multiple specific metrics (recall, Precision@5, F1@5, an 89-second Kubernetes-monorepo task completion time). |
| 10 | Relevance | 5/10 | On-topic for the general "context size and retrieval precision affect agent outcomes" thesis this track cares about, but does NOT address codebase layering/architecture depth specifically — it is about retrieval-tool quality (MCP-backed search vs. baseline), not Clean Architecture's domain/usecase/infrastructure separation. |

**Score band:** borderline
**Named reason for inclusion:** Included despite the relevance gap because it is the only source in this track
supplying independently-sourced, numeric benchmark data (not narrative argument) that corroborates the
"unfocused/oversized context degrades agent performance" claim from a second industry player unconnected to
Anthropic or the arXiv paper's author — a genuine, non-redundant contribution to the evidence base's weight of
corroboration, even though its own intervention (retrieval tooling) is adjacent to, not identical with, this
track's specific layering question.

## Bias Guard Check
- [x] I agree with this source's conclusions -> scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions -> scored more generously on dims 5, 6, 8
- [ ] Neutral / no strong reaction

## Key Findings
- States plainly, from direct product experience, that "we've seen agents perform worse with a 100K-token
  codebase summary than with a 5K-token targeted retrieval on the same task" — bulk context is not simply
  neutral-to-helpful, it can actively degrade performance relative to a smaller, well-targeted context.
- Names three distinct failure modes tied to context size and quality: context overload, context distraction,
  and context confusion, treating them as separable diagnosable problems rather than one generic issue.
- Reports internal CodeScaleBench benchmark deltas from adding MCP-backed retrieval versus baseline: file recall
  rose from 0.127 to 0.277, Precision@5 from 0.140 to 0.478, and F1@5 from 0.099 to 0.262.
- Reports a concrete task-completion example: a Kubernetes-monorepo task completed in 89 seconds when the agent
  used MCP-backed retrieval, offered as a proof point for retrieval quality mattering as much as retrieval
  presence.
- Frames the industry-wide shift toward "just-in-time" context loading (echoing Anthropic's terminology
  independently) as now standard practice across Claude Code, Cursor, Windsurf, Devin, and Cline.

## Verified Quote(s)
**Location reference:** Section "Context Overload, Context Distraction, and Context Confusion."

> We've seen agents perform worse with a 100K-token codebase summary than with a 5K-token targeted retrieval on
> the same task.

**Location reference:** CodeScaleBench results discussion (baseline vs. MCP comparison).

> File recall rose from 0.127 to 0.277, Precision@5 from 0.140 to 0.478, and F1@5 from 0.099 to 0.262.

**Access status:** live

## Inclusion Decision
**Decision:** Supporting
**Rationale:** Does not test the specific Clean-Architecture-layering tradeoff this track targets, so it cannot
carry the argument alone, but it is the only kept source with independently-sourced quantitative benchmark data
corroborating the shared "context size/precision matters, not just context presence" thesis from a second
unrelated industry player — real corroborative weight, explicitly flagged as adjacent rather than central.
**Redundancy check:** Non-redundant on evidence type: Anthropic's post asserts the same general principle
qualitatively; this source is the only vendor-benchmark numeric corroboration of it.
**Perspective category:** Institutional

---
