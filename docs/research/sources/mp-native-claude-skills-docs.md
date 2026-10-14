# Source: Claude Code docs, Skills

**Full citation:** Anthropic. "Extend Claude with skills." Claude Code documentation. https://code.claude.com/docs/en/skills. Live page, versions referenced up to v2.1.28x. Accessed 2026-10-13.
**URL:** https://code.claude.com/docs/en/skills
**Date accessed:** 2026-10-13
**Evidence level:** 4 (vendor primary documentation, professional-body-equivalent guidance)
**Research topic area:** Claude Code native features vs Matt Pocock's skills (Agent Skills format, invocation control, subagent fork)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 10/10 | First-party spec owner |
| 2 | Evidence Quality | 8/10 | Normative docs, exact fields |
| 3 | Currency | 10/10 | Live, versioned 2026 |
| 4 | Intent | 7/10 | Vendor docs, some product pull |
| 5 | Bias & Objectivity | 7/10 | Describes own product only |
| 6 | Logic & Coherence | 9/10 | Consistent, cross-linked |
| 7 | Corroboration | 9/10 | agentskills.io, repo behavior |
| 8 | Intellectual Honesty | 8/10 | States limits and versions |
| 9 | Specificity | 10/10 | Field-level, per-version detail |
| 10 | Relevance | 10/10 | Defines the skill runtime |

- Authority: Anthropic builds Claude Code and originated the Agent Skills format, so this is the authoritative statement of what a `SKILL.md` can do in this harness.
- Evidence Quality: it is normative reference documentation with exact frontmatter fields and behaviors rather than studies, hence 8 not 10.
- Currency: the page is live and cites 2026 version numbers; the fetched copy was over 100k characters of current text.
- Intent: written to drive adoption of the skills feature, a mild product pull but also genuinely instructional.
- Bias: it only describes Claude Code, so cross-agent claims must be checked elsewhere.
- Logic: structured, with a frontmatter reference table and consistent cross-links.
- Corroboration: matches agentskills.io (standard) and Matt Pocock's repo, which uses `disable-model-invocation` in skills such as `implement-spec` and `handoff`.
- Honesty: it flags which behaviors need minimum versions and which are Claude Code extensions beyond the standard.
- Specificity: it names exact fields (`context: fork`, `agent`, `disable-model-invocation`).
- Relevance: this is the runtime layer Matt's skills sit on.

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Claude Code skills follow the Agent Skills open standard and add Claude Code extensions: invocation control, subagent execution, and dynamic context injection.
- Custom slash commands were merged into skills: `.claude/commands/x.md` and `.claude/skills/x/SKILL.md` both create `/x`.
- `disable-model-invocation: true` makes a skill user-only; it also keeps the skill out of subagent preloading and out of scheduled-task fires. This is the native primitive behind Matt's "user-invoked" versus "model-invoked" split.
- `context: fork` plus `agent:` runs a skill in an isolated subagent, which is the native counterpart to skills that tell the agent to spawn workers.
- Native skills are plumbing, not process: nothing in the page prescribes a planning, ticketing, or verification workflow.

## Verified Quote(s)

**Location reference:** Page intro (second sentence of the second paragraph under the title block); heading "Custom commands have been merged into skills" callout; frontmatter reference table row for `disable-model-invocation`.

> Claude Code skills follow the [Agent Skills](https://agentskills.io) open standard, which works across multiple AI tools.

> **Custom commands have been merged into skills.**

> Add `context: fork` to your frontmatter when you want a skill to run in isolation.

> Set to `true` to prevent Claude from automatically loading this skill.

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Primary spec for the runtime that Matt's skills and borg's skills both run on; needed to classify which of his skill mechanics are native.

**Redundancy check:** Distinct from agentskills.io (cross-agent standard) and the best-practices card (authoring guidance); this one covers Claude Code extensions.

**Perspective category:** Institutional
