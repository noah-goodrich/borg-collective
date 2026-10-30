# Source Record: Claude blog, "Improving skill-creator: Test, measure, and refine Agent Skills"

- **Full citation:** Anthropic, "Improving skill-creator: Test, measure, and refine Agent Skills," Claude blog, March 3, 2026.
- **URL:** https://claude.com/blog/improving-skill-creator-test-measure-and-refine-agent-skills
- **Date accessed:** 2026-10-30
- **Evidence level:** vendor documentation (product announcement)
- **Track:** t2 tooling landscape

## Verified Quote(s)

1. "Skill-creator now helps you write evals, which are tests that check Claude does what you expect for a given prompt."
2. "We've also added a benchmark mode that runs a standardized assessment using your evals."
3. "It tracks eval pass rate, elapsed time, and token usage."
4. "We've also added comparator agents for A/B comparisons: two skill versions, or skill vs. no skill."
5. "They judge outputs without knowing which is which, so you can tell whether a change actually helped."
6. "it analyzes your current description against sample prompts and suggests edits that cut both false positives and false negatives."

Location: body of the post; date line reads "March 3, 2026".

## Key finding

Anthropic positions skill-creator as the in-session loop for skill authors: evals, a benchmark mode tracking pass rate, time and tokens, blind A/B comparator agents, and description tuning for trigger precision/recall. It is an interactive, agent-driven workflow rather than a scriptable CI runner.

Access status: live
