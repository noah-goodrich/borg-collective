# Verification report (round 3)

**Synthesis agent ID:** synthesis-tracks-wffcea4944
**Verifier agent ID:** verifier-round3-closeout

**Earlier rounds:** round 1 checked 30 of 98 mp-* cards (0 failed). This round-3 audit is the reported one; it was drawn fresh from the cards round 1 left out.

**Sample size:** 34 of 106 cards (32.1%; floor is 30%, rounded up = 32). The 106 is every card file in the sources directory (98 mp-* cards plus 8 deployment-primitive cards); the draw was taken from the mp-* cards only.
**Sample-selection method:** random draw (sort -R shuffle, first 34) over the 68 mp-* cards that were not in the round-1 sample. Each card's URL was fetched live with curl (plus the raw.githubusercontent.com rendering for github.com blob pages and the .md rendering for docs pages); HTML was stripped and every verbatim quote was matched after normalizing smart quotes, whitespace, backticks, markdown-link rendering and the stray spaces that link or emphasis markup leaves in rendered text. Quotes that missed on the first pass were re-checked by hand against the raw text.

## Sampled filenames and outcomes

| filename | outcome | notes |
|---|---|---|
| mp-cortex-changelog.md | verified |  |
| mp-cortex-claude-skills-docs.md | verified |  |
| mp-cortex-extensibility-docs.md | verified |  |
| mp-cortex-mattpocock-readme.md | verified | Install-block quote matched in README raw text (angle-bracket placeholder was stripped by HTML removal on the first pass) |
| mp-cortex-pocock-git-guardrails-skill.md | verified |  |
| mp-native-agent-teams.md | verified |  |
| mp-native-anthropic-engineering-blog-skills.md | verified |  |
| mp-native-anthropic-skill-best-practices.md | verified |  |
| mp-native-claude-skills-docs.md | verified |  |
| mp-native-dynamic-workflows.md | verified |  |
| mp-native-pocock-out-of-scope-harness.md | verified | Q1/Q2 on the card URL; Q3/Q4 matched in subagent-recursion.md and harness-name-collisions.md, same github.com repo, as the location reference states |
| mp-native-sandcastle-readme.md | verified |  |
| mp-native-scheduled-tasks-loop.md | verified |  |
| mp-pm-besthub-grill-with-docs-vs-superpowers.md | verified |  |
| mp-pm-contextstudios-pocock-workflow.md | verified |  |
| mp-pm-dora-2025-ai-amplifier.md | verified |  |
| mp-pm-issue-310-to-tickets-rubber-stamp.md | verified |  |
| mp-pm-pragmatic-engineer-pocock-interview.md | verified |  |
| mp-pm-repo-ask-matt-router.md | verified |  |
| mp-pm-repo-changelog.md | verified |  |
| mp-pm-repo-triage-skill.md | verified |  |
| mp-pm-repo-wayfinder-skill.md | verified |  |
| mp-reception-devto-yim-review.md | verified |  |
| mp-reception-every-case-against-skills.md | verified | Both quotes present in free portion; first-pass miss was only link-markup spacing |
| mp-reception-github-issue-1071-skill-bloat.md | verified |  |
| mp-reception-hn-comment-agents-too-complicated.md | verified |  |
| mp-reception-hn-comment-ceremony-fast-lane.md | verified |  |
| mp-reception-kaizen-critical-guide.md | verified |  |
| mp-reception-repo-out-of-scope-native-question-tool.md | verified |  |
| mp-what-aie-agent-skills-talk.md | verified |  |
| mp-what-aie-fundamentals-talk.md | verified |  |
| mp-what-aihero-cohort-page.md | verified |  |
| mp-what-aihero-ralph-plugin-post.md | verified | Q2 present; first-pass miss was emphasis-markup spacing around dumb zone |
| mp-what-skills-changelog.md | verified |  |

## Aggregate

- verified: 34
- failed: 0
- inaccessible: 0
- Failure rate = failed / (verified + failed) = 0 / 34 = 0%
- Failure-rate band: <=5%
