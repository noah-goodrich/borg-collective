# Source: When Linting Is Not Enough (Sonar)

**Full citation:** Peru, Nicolas (SVP Code Quality, Sonar). "When linting is not enough." sonarsource.com
Blog. April 27, 2026.
**URL:** https://www.sonarsource.com/blog/linting-ai-assisted-development/
**Date accessed:** 2026-08-12
**Evidence level:** 7 (Expert Opinion/Thought Leadership — an informed technical argument from a static-
analysis vendor's senior technical leader, citing one external study statistic but not itself a study)
**Research topic area:** Mechanical enforcement vs. documented convention for AI agents (granularity: what
KIND of enforcement works)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|----------------|
| 1 | Authority | 8/10 | Author is SVP Code Quality at Sonar, maker of SonarQube — one of the most established static-analysis vendors, giving direct subject-matter authority on the linter-vs-deeper-analysis distinction. |
| 2 | Evidence Quality | 6/10 | Cites one concrete external statistic (a 61% functional-correctness vs. 10.5% security-compliance gap) but the underlying study is not clearly sourced/linked in the piece; otherwise the argument is conceptual rather than data-driven. |
| 3 | Currency | 8/10 | Published April 2026, addresses current-generation agentic coding tools directly. |
| 4 | Intent | 5/10 | Sonar sells the deeper static-analysis tooling this piece argues is necessary beyond "mere" linting — a direct commercial interest in the conclusion reached. |
| 5 | Bias & Objectivity | 6/10 | The core technical claim (linters are syntactic/AST-based and miss semantic, cross-file, and security issues) is standard, verifiable computer-science fact independent of the vendor angle, which partially offsets the conflict of interest. |
| 6 | Logic & Coherence | 8/10 | Clear layered taxonomy: linters (syntax) -> static analysis engines (control/data/taint flow) -> architecture-as-code enforcement -> quality gates, each addressing a different failure class. |
| 7 | Corroboration | 7/10 | Corroborated by Factory.ai's parallel claim that "prose can't verify cross-file imports, architectural boundaries, or error semantics"; extends rather than duplicates RepoComplianceBench's finding that some rule types need enforcement "outside the agent." |
| 8 | Intellectual Honesty | 6/10 | Honestly scopes what linters CAN'T do (a claim against Sonar's own basic-tier product, in a sense) but does not equally scrutinize the limits of its own recommended deeper-analysis approach. |
| 9 | Specificity | 8/10 | Concrete taxonomy of enforcement mechanism types plus one specific cited statistic distinguishing functional correctness from security compliance. |
| 10 | Relevance | 9/10 | Directly answers the track's explicit granularity question — what kind of mechanical enforcement works best — with a stratified rather than binary (enforced vs. not) answer. |

**Score band:** keep

## Bias Guard Check
- [ ] I agree with this source's conclusions -> scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions -> scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings
- Argues linters operate only at the syntax-tree (AST) level and therefore cannot catch the class of defects
  AI agents most often introduce — semantic, cross-file, and architectural issues — meaning "passes lint"
  is a much weaker signal of AI-generated-code quality than it appears.
- Distinguishes four escalating tiers of mechanical enforcement relevant to the track's granularity question:
  linters (fast, syntactic only), static analysis engines (control-flow/data-flow/taint analysis, catching
  things like SQL injection and null-pointer dereferences), architecture-as-code enforcement (programmatically
  verifying component/layer boundaries), and quality gates (automated reviewers blocking PRs on new
  vulnerabilities, architectural violations, or duplication above a threshold).
- Cites a stark example of the gap between surface compliance and real correctness: AI-generated code reached
  a "61% functional correctness rate" that "dropped to 10.5% security compliance" in the cited study —
  functional correctness and security are explicitly "not correlated."
- Explicitly names "architecture-as-code enforcement" as a distinct mechanical layer beyond linting — directly
  relevant to whether Clean-Architecture-style layer boundaries need their own dedicated enforcement mechanism
  (e.g. import-boundary checkers) rather than being covered by a general linter or type checker.

## Verified Quote(s)

**Location reference:** "What Linters Do" section and "Deep Bugs" section.

> "A linter parses source code into an abstract syntax tree (AST) and applies rules against its structure"

> "Functional correctness and security are not correlated: code that works is not necessarily code that is
> safe"

**Access status:** live

## Inclusion Decision
**Decision:** Supporting
**Rationale:** This is the clearest available source addressing the track's explicit sub-question of WHICH
kind of mechanical enforcement matters — establishing that "linter" is not a monolithic category and that
architectural-boundary enforcement is a functionally distinct mechanism from both linting and general static
analysis, which matters directly for evaluating layer-boundary enforcement in Clean Architecture specifically.
**Redundancy check:** No other kept source stratifies enforcement mechanisms this granularly; the vendor
conflict of interest is real but the underlying technical taxonomy is independently verifiable and adds
information no other source provides.
**Perspective category:** Institutional

---
