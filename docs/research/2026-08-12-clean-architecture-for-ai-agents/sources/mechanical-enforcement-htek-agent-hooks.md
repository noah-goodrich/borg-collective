# Source: Agent Hooks — The Secret to Controlling AI Agents in Your Codebase (htek.dev)

**Full citation:** Unattributed author. "Agent Hooks: The Secret to Controlling AI Agents in Your Codebase."
htek.dev. February 20, 2026.
**URL:** https://htek.dev/articles/agent-hooks-controlling-ai-codebase
**Date accessed:** 2026-08-12
**Evidence level:** 8 (Anecdotal/Personal Experience — a single first-person account of one project's
architecture decaying without enforcement, offered as illustrative rather than as data)
**Research topic area:** Mechanical enforcement vs. documented convention for AI agents

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|----------------|
| 1 | Authority | 3/10 | No author name, credentials, or institutional affiliation is disclosed on the piece; personal/independent technical blog with no established track record verifiable from the page itself. |
| 2 | Evidence Quality | 3/10 | A single anecdote from one project, with no data, no measurement, and no attempt at generalization beyond the author's own experience. |
| 3 | Currency | 8/10 | Published February 2026, addresses current agentic-coding tooling (pre-tool-use hooks) directly and currently. |
| 4 | Intent | 7/10 | Reads as genuine shared experience motivating a technique (hook-based enforcement) rather than as a sales pitch for a specific paid product, though it implicitly promotes the author's own hooks-based approach. |
| 5 | Bias & Objectivity | 5/10 | The anecdote is selected and framed specifically to support the author's "hope-based vs. enforcement-based governance" thesis — a natural confirmation-bias risk in a single self-reported case. |
| 6 | Logic & Coherence | 7/10 | The core framing (documentation is hope, hooks are enforcement) is simple and internally consistent, if not deeply argued. |
| 7 | Corroboration | 8/10 | Strongly corroborated by RepoComplianceBench's finding of 0% unaided compliance with restraint/boundary-type documented rules, and by the general enforcement-over-documentation consensus running through every other kept source in this track. |
| 8 | Intellectual Honesty | 7/10 | Presents the story as one illustrative case rather than claiming it proves a general law; doesn't inflate a single incident into a statistic. |
| 9 | Specificity | 9/10 | Vividly concrete: a strict L0-L7 layered architecture, an explicit import-boundary rule, and a precise failure point ("about three commits") before an agent imported infrastructure code directly into a pure type layer. |
| 10 | Relevance | 10/10 | About as directly on-point as a source can be for this specific research project: a first-person account of a Clean-Architecture-style layered system's boundary rule collapsing within days, absent mechanical enforcement. |

**Score band:** borderline

## Bias Guard Check
- [x] I agree with this source's conclusions -> scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions -> scored more generously on dims 5, 6, 8
- [ ] Neutral / no strong reaction

## Key Findings
- Reports that after refactoring a project into a "strict L0-L7 layered architecture" with explicit
  documented import rules between layers, "without enforcement, it lasted about three commits before an AI
  agent decided that directly importing infrastructure code into a pure type layer was perfectly reasonable"
  — a direct, concrete instance of a Clean-Architecture-style layer boundary being violated almost
  immediately once documentation was the only guardrail.
- Frames the core failure mode as "hope-based governance" (relying on the agent to self-police via prompts
  and documentation) versus "enforcement-based governance" (making violations structurally impossible via
  pre-tool-use hooks that intercept and block disallowed actions before code is written).
- Argues the practical fix is not better-written rules but a category change in mechanism: hooks that
  intercept agent tool calls before execution, rather than relying on the agent reading and remembering a
  rule from a configuration file at session start.
- Explicitly frames the underlying dynamic as accumulation: "without enforcement mechanisms, technical debt
  accumulates regardless of how well instructions are documented" — i.e., better prose doesn't change the
  trend line, only the mechanism does.

## Verified Quote(s)

**Location reference:** Opening section of the article, introducing the motivating anecdote.

> "Without enforcement, it lasted about three commits before an AI agent decided that directly importing
> infrastructure code into a pure type layer was perfectly reasonable."

**Access status:** live

## Inclusion Decision
**Decision:** Supporting
**Rationale:** Kept at borderline: evidentiary weight is thin (single anonymous anecdote, no data), which is
exactly why it cannot rank higher than borderline — but no other kept source in this track offers a
first-person, concretely-detailed account of the SPECIFIC failure mode this parent research project cares
about (a layered/Clean-Architecture-style boundary rule collapsing under agent maintenance absent mechanical
enforcement), and its central claim is independently corroborated by the much stronger RepoComplianceBench
academic source. This is the lowest-scoring source kept in this track; it earns its place on relevance and
corroboration, not on independent evidentiary weight.
**Redundancy check:** Not redundant on content — it is the only Boots-on-the-ground perspective in the kept
set, and the only source that names a Clean-Architecture-shaped layer violation specifically rather than
AI-contribution rules in general.
**Perspective category:** Boots-on-the-ground

---
