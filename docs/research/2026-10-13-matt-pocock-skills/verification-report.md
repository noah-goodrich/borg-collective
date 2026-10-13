# Verification report (round 1)

**Synthesis agent ID:** wf-research-matt-pocock/evidence-tracks
**Verifier agent ID:** wf-research-matt-pocock/verifier-round-1

**Sample size:** 30 of 98 mp-* cards (30.6%; floor is 30%, rounded up = 30)
**Sample-selection method:** random draw (sort -R shuffle, first 30) over all 98 mp-* cards in the sources directory. Each card's URL was fetched live (curl, plus the .md rendering for the Snowflake docs page and a WebFetch rendering for the JavaScript-rendered Snowflake blog); every verbatim quote was matched after normalizing smart quotes, whitespace, backticks and markdown-link rendering.

## Sampled filenames and outcomes

| filename | outcome | notes |
|---|---|---|
| mp-cortex-agentskills-spec.md | verified |  |
| mp-cortex-coco-skills-repo.md | verified |  |
| mp-cortex-plugins-docs.md | verified | Q1 matched on the .md rendering named in the card |
| mp-cortex-snowflake-blog-dbt-benchmark.md | verified | Card declared cached/partial; page was fetchable and both quotes matched exactly via rendered fetch |
| mp-cortex-subagent-cortex-code-repo.md | verified | Both quotes matched in README raw text |
| mp-cortex-vercel-skills-agent-table.md | verified | Table row matched exactly in README raw text |
| mp-native-agentskills-open-standard.md | verified | Q2 matched (link markup rendered as plain text); Q3 matched in embedded client list |
| mp-native-besthub-grill-vs-superpowers.md | verified |  |
| mp-native-chatbotkit-skills-expensive-rag.md | verified |  |
| mp-native-commands-bundled-skills.md | verified |  |
| mp-native-cross-session-messaging.md | verified |  |
| mp-native-official-marketplace-listing.md | verified |  |
| mp-pm-addy-osmani-skills-comparison.md | verified |  |
| mp-pm-aiengineer-workflow-talk-2026.md | verified |  |
| mp-pm-aihero-to-tickets-docs.md | verified |  |
| mp-pm-fowler-boeckeler-sdd-tools.md | verified |  |
| mp-pm-issue-828-wayfinder-stale-premises.md | verified |  |
| mp-pm-marmelab-sdd-waterfall.md | verified |  |
| mp-pm-repo-to-tickets-skill.md | verified |  |
| mp-reception-claude-marketplace-listing.md | verified | Description matched; Installs value 1,745 present in page data |
| mp-reception-glean-switching-from-superpowers.md | verified |  |
| mp-reception-hn-ai-coding-agent-skills-thread.md | verified |  |
| mp-reception-hn-comment-prior-art-marketing.md | verified |  |
| mp-reception-skill-induced-failures-arxiv.md | verified |  |
| mp-reception-zenn-superpowers-vs-pocock.md | verified |  |
| mp-what-hn-skills-thread.md | verified |  |
| mp-what-pragmatic-engineer-interview.md | verified |  |
| mp-what-sandcastle-readme.md | verified |  |
| mp-what-skills-readme.md | verified |  |
| mp-what-skills-scope-out-of-scope.md | verified | Q1 on SCOPE.md; Q2/Q3 matched in .out-of-scope/*.md files, same github.com repo, as the location reference states |

## Aggregate

- verified: 30
- failed: 0
- inaccessible: 0
- Failure rate = failed / (verified + failed) = 0 / 30 = 0%
- Failure-rate band: <=5%
