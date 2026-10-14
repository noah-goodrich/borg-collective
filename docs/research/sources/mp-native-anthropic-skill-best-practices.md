# Source: Anthropic, Skill authoring best practices

**Full citation:** Anthropic. "Skill authoring best practices." Claude Platform documentation. https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices. Live page, accessed 2026-10-13.
**URL:** https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
**Date accessed:** 2026-10-13
**Evidence level:** 4 (vendor authoring guidance)
**Research topic area:** Anthropic's own guidance on skills (size, evaluation, who writes them)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 10/10 | Format originator |
| 2 | Evidence Quality | 6/10 | Guidance, no published data |
| 3 | Currency | 8/10 | Maintained doc, undated body |
| 4 | Intent | 8/10 | Practical authoring help |
| 5 | Bias & Objectivity | 7/10 | Vendor view of good skills |
| 6 | Logic & Coherence | 9/10 | Principle then example pattern |
| 7 | Corroboration | 7/10 | Matches eng blog and Claude Code docs |
| 8 | Intellectual Honesty | 8/10 | Admits no built-in eval runner |
| 9 | Specificity | 9/10 | Limits, line counts, templates |
| 10 | Relevance | 9/10 | Yardstick for any skill library |

- Authority: Anthropic defines the format and the models that consume it.
- Evidence Quality: advice is reasoned and example-driven but cites no measurements.
- Currency: it is a living page; the fetched copy is current, with no visible date, so 8.
- Intent: written to improve skill quality, not to sell.
- Bias: it states a vendor-preferred style (concise, third-person descriptions, gerund names).
- Logic: each principle is paired with good and bad examples.
- Corroboration: the engineering blog and Claude Code docs say the same on progressive disclosure.
- Honesty: it says plainly "There is not currently a built-in way to run these evaluations."
- Specificity: gives hard numbers (500 lines, 64-char names, 1,024-char descriptions).
- Relevance: gives an external yardstick against which Matt's lean skills and borg's heavier skills can be judged.

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Anthropic's stance is "concise is key": the context window is shared, so SKILL.md should only add what Claude does not already know, and stay under 500 lines.
- It recommends evaluation-first skill development: find gaps by running without the skill, write three evals, then write minimal instructions. Matt's own SCOPE.md bar ("observed failure") is the same idea in prose; the Addy-style comparison notes his repo ships no evals.
- Anthropic says Claude can write skills natively, with no special "writing skills" skill needed, which sits in tension with Matt shipping skill-authoring skills (`writing-for-agents` in the current repo).
- The doc advises testing a skill on Haiku, Sonnet, and Opus, the cross-model concern that Matt addresses by saying his skills "work with any model".

## Verified Quote(s)

**Location reference:** Heading "Concise is key" first sentence; heading "Progressive disclosure patterns" bullet list; heading "Build evaluations first" first line; heading "Develop Skills iteratively with Claude" step 3 tip.

> The [context window](https://platform.claude.com/docs/en/build-with-claude/context-windows) is a public good.

> Keep SKILL.md body under 500 lines for optimal performance

> **Create evaluations BEFORE writing extensive documentation.**

> You don't need special system prompts or a "writing skills" skill to get Claude to help create Skills.

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Anthropic's own guidance, the clearest outside yardstick for Matt's and borg's skills.

**Redundancy check:** Complements the skills-runtime doc (mechanics) with quality guidance; the engineering blog card adds the design principle history.

**Perspective category:** Institutional
