# Source: mattpocock/skills .out-of-scope decisions (harness-neutrality)

**Full citation:** Pocock, Matt. ".out-of-scope/native-question-tool.md", ".out-of-scope/subagent-recursion.md", ".out-of-scope/harness-name-collisions.md", repository mattpocock/skills. https://github.com/mattpocock/skills/tree/main/.out-of-scope. Fetched 2026-10-13.
**URL:** https://raw.githubusercontent.com/mattpocock/skills/main/.out-of-scope/native-question-tool.md
**Date accessed:** 2026-10-13
**Evidence level:** 7 (maintainer's recorded design decisions)
**Research topic area:** How Matt deliberately handles native features (question tool, subagent limits, name clashes)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 8/10 | Maintainer decisions |
| 2 | Evidence Quality | 6/10 | Cites real issue numbers |
| 3 | Currency | 9/10 | In current main branch |
| 4 | Intent | 7/10 | Scope control |
| 5 | Bias & Objectivity | 6/10 | One owner's stance |
| 6 | Logic & Coherence | 9/10 | Reasoned per decision |
| 7 | Corroboration | 7/10 | Native docs confirm facts |
| 8 | Intellectual Honesty | 8/10 | Lists prior requests |
| 9 | Specificity | 9/10 | Names tools, issues |
| 10 | Relevance | 10/10 | Direct native-vs-skill |

- Authority: the repository owner records why requests were declined.
- Evidence Quality: each decision lists the prior issue numbers (for example #19, #643, #840, #1107, #1152 for the question tool), which are checkable.
- Currency: the files are in main, referenced from the current SCOPE.md.
- Intent: designed to deflect repeated requests, not to market.
- Bias: a single owner's design preferences, stated as such ("I've tried the `AskUserQuestion` UI and don't want it").
- Logic: rationale follows from harness-neutral skills.
- Corroboration: the native docs confirm that `/code-review` and `/prototype` now exist as built-ins, which is why the collisions arose.
- Honesty: lists the contrary requests rather than hiding them.
- Specificity: names `AskUserQuestion`, `/mattpocock-skills:research`, and issue numbers.
- Relevance: the most direct primary evidence of how the skill set treats native features.

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Matt keeps skills harness-neutral: he refuses to call Claude Code's `AskUserQuestion` in grilling, because structured pickers push toward multiple-choice answers and each harness has a different (or no) question tool; users are told to set that in their own CLAUDE.md or AGENTS.md.
- He assigns subagent-recursion safety to the harness, not to skill text; a native-feature dependency he chooses to rely on rather than duplicate.
- He will not rename skills when a harness ships a built-in of the same name; the answer is namespaced invocation (`/mattpocock-skills:code-review`).
- Evidence of overlap: user-reported issues #423, #483, and #1019 record `/code-review` and `/prototype` colliding with Claude Code built-ins.
- Net: skills are portable text; every harness feature (questions, subagent limits, worktrees) is left to the host, so they gain from native improvements but cannot assume them.

## Verified Quote(s)

**Location reference:** native-question-tool.md, section "Why this is out of scope", paragraph 1 and paragraph 2; subagent-recursion.md same section paragraph 1; harness-name-collisions.md same section paragraph 1.

> The skills are harness-neutral text.

> I've tried the `AskUserQuestion` UI and don't want it in these skills.

> The harness should be responsible for stopping infinite subagent loops, not skills.

> Harnesses add built-ins all the time, and each harness picks its own names.

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Direct primary evidence on native-feature stance; quotes from the two sibling files are on the same host and same repo path.

**Redundancy check:** Not covered by the README; unique design-decision record.

**Perspective category:** Practitioner
