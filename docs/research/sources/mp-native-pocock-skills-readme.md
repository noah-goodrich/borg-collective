# Source: mattpocock/skills README (primary)

**Full citation:** Pocock, Matt. "Skills For Real Engineers" (README), repository mattpocock/skills. https://github.com/mattpocock/skills. Raw README fetched 2026-10-13; repository created 2026-02-03 and last pushed 2026-10-13 per the GitHub API; MIT license; 289,476 stars and 24,301 forks at fetch time.
**URL:** https://raw.githubusercontent.com/mattpocock/skills/main/README.md
**Date accessed:** 2026-10-13
**Evidence level:** 7 (expert practitioner's own product documentation)
**Research topic area:** How Matt's skills relate to native Claude Code features and other harnesses

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 8/10 | Author, widely known TS educator |
| 2 | Evidence Quality | 5/10 | Claims, no measurements |
| 3 | Currency | 10/10 | Pushed today, v1.3.1 |
| 4 | Intent | 5/10 | Newsletter and training funnel |
| 5 | Bias & Objectivity | 5/10 | Self-promoting, rivals framed |
| 6 | Logic & Coherence | 8/10 | Failure mode then fix |
| 7 | Corroboration | 7/10 | Marketplace entry, third parties |
| 8 | Intellectual Honesty | 7/10 | Admits not a rescue |
| 9 | Specificity | 9/10 | Per-skill reference, installs |
| 10 | Relevance | 10/10 | The subject itself |

- Authority: the author is the repository owner and a known TypeScript educator; the README is the primary statement of intent.
- Evidence Quality: justified by engineering-book quotations and personal use, with no evals or measurements.
- Currency: the repo shows commits as recent as 2026-10-13 and a plugin manifest at version 1.3.1.
- Intent: the README funnels to a newsletter of "~60,000" developers and the author runs paid training elsewhere (AI Hero), so commercial interest is real.
- Bias: it explicitly positions against GSD, BMAD and Spec-Kit as frameworks that "take away your control".
- Logic: four named agent failure modes, each paired with the skills that fix it.
- Corroboration: the Anthropic official marketplace carries the plugin; third-party comparison pages describe the same skill set.
- Honesty: it says `/improve-codebase-architecture` is "a survey, not a rescue".
- Specificity: lists each skill by name, one line, user-invoked versus model-invoked.
- Relevance: primary description of the catalog under comparison.

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- The catalog is built on the Agent Skills format and installs three ways: a Claude Code plugin (`claude plugin install mattpocock-skills@claude-plugins-official`), plugin marketplaces for Codex and Copilot, and `npx skills@latest add mattpocock/skills` for editable copies (Cursor, OpenCode, Devin, Windsurf, Amp, pi); Gemini CLI is a manual path install.
- Native-feature dependence is mostly implicit: user-invoked skills are slash commands (native merged commands and skills), model-invoked skills use the native Skill tool, and `implement-spec`, `code-review`, `research`, and `wayfinder` depend on native subagents, background agents, and worktrees.
- The split is stated as a rule: "A user-invoked skill may invoke model-invoked skills, but never another user-invoked one", an architectural convention layered on `disable-model-invocation`.
- The skill set targets pre-code alignment (grilling), shared language (`GLOSSARY.md`, ADRs), feedback loops (`tdd`, `diagnosing-bugs`), and design depth (`improve-codebase-architecture`); it has no session-visibility, cross-project, or deploy layer, which is where borg operates.
- Stars of 289,476 on 2026-10-13 are an outlier relative to earlier reports (74,500 on May 15 in one blog); the live GitHub API figure is used here.

## Verified Quote(s)

**Location reference:** Paragraph two under the top-level heading "Skills For Real Engineers"; "Reference" section intro paragraph beginning "These split on one axis".

> Approaches like GSD, BMAD, and Spec-Kit try to help by owning the process. But while doing so, they take away your control and make bugs in the process hard to resolve.

> These skills are designed to be small, easy to adapt, and composable. They work with any model.

> A user-invoked skill may invoke model-invoked skills, but never another user-invoked one.

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Primary description of the thing under comparison; scored down on intent and bias but essential.

**Redundancy check:** Other tracks cover the catalog and PM skills; this card is used only for native-feature relations and install breadth.

**Perspective category:** Practitioner
