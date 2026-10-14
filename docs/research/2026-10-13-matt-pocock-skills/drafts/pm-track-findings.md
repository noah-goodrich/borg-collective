# Matt Pocock's PM approach versus borg: track findings (pm)

**Date:** 2026-10-13
**Question:** How does Matt Pocock structure work for agents (PRDs, grill-me, tracer-bullet tickets, human-in-the-loop versus autonomous labels, triage, TDD, planning state in GitHub issues), what do practitioners report, how does it relate to established methods, and where does it cover or miss borg's project-management gaps (stop rule, value ranking, status history, debriefs, delivery numbers)?

Card prefix: `mp-pm-`. Cards are in `docs/research/sources/`. 22 cards: 21 kept or supporting, 1 excluded as reject band.

## Executive summary

- Matt's method is a chain, not a single skill: grill the human, synthesize a spec (the old PRD) into the issue tracker, split it into tracer-bullet tickets with blocking edges, label them for agents, build test-first, review in a fresh context, then run a retro on the environment. The names changed in 2026 (to-prd is now to-spec, to-issues is now to-tickets).
- Planning state lives in the tracker: labels form the state machine, blocking edges are native links, and `wayfinder` keeps a map issue as an index. The skills are frank that state-writing is the weak point: open issues and Matt's own docs say tickets are not reliably closed and maps go stale.
- Against borg's five PM gaps, Matt covers none fully. Partial: a rejected-request memory (`.out-of-scope`) and a retro skill. Not covered: stop rule on stale work, value ranking, status history, delivery numbers.
- Matt is ahead of borg on two things borg has not built: the AFK versus HITL split expressed as labels on the work item, and an explicit vertical-slice check (what can I demo?). Borg is ahead on locked acceptance criteria with `Verify:` lines, cross-project visibility and gates.
- Evidence for the method is practitioner opinion and a few anecdotes. No controlled study of grill-then-spec-then-slice was found; the nearest hard evidence (an RCT) warns that self-reported speed gains are unreliable.

## Findings

### F1. What Matt's PM chain is, and how current it is

- The router describes the main flow: grill-with-docs, optional prototype, then for multi-session work to-spec and to-tickets, then implement per ticket or implement-spec across the whole task graph, code-review, and retro. [mp-pm-repo-ask-matt-router](../../sources/mp-pm-repo-ask-matt-router.md)
- GitHub shows the repo was created 2026-02-03 (not April), with releases v1.2.3 (2026-08-06) and v1.3.0 and v1.3.1 (2026-10-04); the 1.1.0 changelog entry unified the planning skills, renaming to-prd to to-spec and to-issues to to-tickets. [mp-pm-repo-changelog](../../sources/mp-pm-repo-changelog.md)
- The current to-spec skill synthesizes the conversation without a second interview; the interview is the earlier grill step. The spec template has problem, solution, a long user-story list, implementation decisions, testing decisions, and out-of-scope. [mp-pm-repo-to-tickets-skill](../../sources/mp-pm-repo-to-tickets-skill.md) (to-tickets text; the to-spec template was read in the cloned repo and is described on the docs page, not separately carded)
- Matt's own conference talk shows the same sequence, with alignment explicitly human-in-the-loop and the build loop as a "night shift". [mp-pm-aiengineer-workflow-talk-2026](../../sources/mp-pm-aiengineer-workflow-talk-2026.md)
- Confidence: high for the structure (three primary sources agree); the star count (about 289k at access) is a GitHub API value and varies by the day.

### F2. Planning state lives in the issue tracker, with known write gaps

- Triage is a five-state label machine plus bug/enhancement; ready-for-agent means "fully specified, ready for an AFK agent" and ready-for-human means human implementation. [mp-pm-repo-triage-skill](../../sources/mp-pm-repo-triage-skill.md)
- Wayfinder keeps one map issue as an index (Destination, Decisions so far, Not yet specified, Out of scope) and child decision tickets; a ticket is claimed by assigning it. [mp-pm-repo-wayfinder-skill](../../sources/mp-pm-repo-wayfinder-skill.md)
- Practitioners report failures at exactly the write points: finished tickets are never marked done ([mp-pm-issue-508-implement-no-completion](../../sources/mp-pm-issue-508-implement-no-completion.md)), two sessions resolved one ticket a second apart ([mp-pm-issue-476-wayfinder-claim-concurrency](../../sources/mp-pm-issue-476-wayfinder-claim-concurrency.md)), and resolutions leave stale premises in open tickets ([mp-pm-issue-828-wayfinder-stale-premises](../../sources/mp-pm-issue-828-wayfinder-stale-premises.md)).
- Matt's docs page agrees with the first: update ticket state yourself. [mp-pm-aihero-to-tickets-docs](../../sources/mp-pm-aihero-to-tickets-docs.md)
- Confidence: medium-high. Reports are single-user issues on a public tracker, but one is confirmed by the maintainer's docs.

### F3. Tracer-bullet vertical slicing: strong rationale, thin proof

- The rationale: agents build layers in the dark and integrate late; build one thin slice end to end and get feedback. [mp-pm-aihero-tracer-bullets-article](../../sources/mp-pm-aihero-tracer-bullets-article.md)
- The term comes from The Pragmatic Programmer, whose authors define it against specifying everything up front, and keep tracer code while throwing prototypes away. [mp-pm-artima-hunt-thomas-tracer-bullets](../../sources/mp-pm-artima-hunt-thomas-tracer-bullets.md) The Pragmatic Engineer interview records how Matt found the term and that it improved agent output. [mp-pm-pragmatic-engineer-pocock-interview](../../sources/mp-pm-pragmatic-engineer-pocock-interview.md)
- Evidence that it works is one unnamed team's 26-ticket horizontal stack (about twenty agent runs per closed ticket, three quarters rework) quoted on Matt's own docs page. Treat as an anecdote. [mp-pm-aihero-to-tickets-docs](../../sources/mp-pm-aihero-to-tickets-docs.md)
- The slicing rule is not self-enforcing: a user reports the quiz step tends to rubber-stamp a pre-authored cut, and the docs say the skill "still produces" layer-sliced tickets sometimes. [mp-pm-issue-310-to-tickets-rubber-stamp](../../sources/mp-pm-issue-310-to-tickets-rubber-stamp.md)
- Confidence: high on the idea and its provenance; low on outcome evidence.

### F4. Human-in-the-loop versus autonomous is split by phase, and only half of it is a label

- Alignment (grilling) is HITL; wayfinder labels each ticket HITL or AFK and says a grilling agent that answers its own questions has broken the rule. [mp-pm-repo-wayfinder-skill](../../sources/mp-pm-repo-wayfinder-skill.md)
- On build tickets only the AFK side has a label (ready-for-agent, with ready-for-human as the other); the older prd-to-issues variant labelled slices HITL or AFK directly (search-result description only, so not carded). [mp-pm-repo-triage-skill](../../sources/mp-pm-repo-triage-skill.md)
- The skills stop at the artifact: there is no auto-dispatch; you count unblocked tickets and open sessions yourself. The unattended loop is a separate tool (Sandcastle) described in the talk. [mp-pm-aihero-to-tickets-docs](../../sources/mp-pm-aihero-to-tickets-docs.md), [mp-pm-aiengineer-workflow-talk-2026](../../sources/mp-pm-aiengineer-workflow-talk-2026.md)
- Matt concedes agents now write more than people can comfortably review and that passing tests missed a missing table; human QA feeds new issues back. [mp-pm-aiengineer-workflow-talk-2026](../../sources/mp-pm-aiengineer-workflow-talk-2026.md)
- Confidence: medium-high; the talk card is a generated write-up of the talk, flagged in its Authority score.

### F5. Coverage of borg's five PM gaps

Borg gaps are from the internal PM research (the stacked PR #252 pillars audit, 14 of 24; and PR #262 build, adopt or outsource, pick: enforce first, measure second). Those internal documents are cited as internal and are not source cards.

| Borg gap | Matt covers? |
|---|---|
| Stop rule | Partly: per-item only |
| Value ranking | No |
| Status history | No |
| Debriefs | Partly: retro |
| Delivery numbers | No |

- Stop rule: Matt has `wontfix` with an `.out-of-scope/` memory for rejected enhancements, and wayfinder closes out-of-scope work so it never graduates. This stops items by decision, one at a time. There is no review date, no lapse of unstarted work, and no appetite or time budget; the only size limit is one context window. [mp-pm-repo-triage-skill](../../sources/mp-pm-repo-triage-skill.md), [mp-pm-repo-wayfinder-skill](../../sources/mp-pm-repo-wayfinder-skill.md), [mp-pm-shape-up-set-boundaries](../../sources/mp-pm-shape-up-set-boundaries.md) (appetite is the missing idea)
- Value ranking: order comes only from the blocking graph (the frontier) and triage state; no scoring or ordering by worth. Borg's own research also concluded value ranking should stay manual in v1, so this is a shared gap, not a borg deficit. [mp-pm-repo-to-tickets-skill](../../sources/mp-pm-repo-to-tickets-skill.md)
- Status history: state is the current label or open/closed bit on the tracker; no transitions are logged by the skills, and the open issues show even the closed bit is unreliable. [mp-pm-issue-508-implement-no-completion](../../sources/mp-pm-issue-508-implement-no-completion.md)
- Debriefs: `retro` reviews a session and proposes changes to the agent's environment (checks, standards, navigation pointers), with mechanical mistakes turned into deterministic checks. It is a useful model for borg's debrief step, but it has no action-closure tracking and is not tied to a plan's outcome. [mp-pm-repo-ask-matt-router](../../sources/mp-pm-repo-ask-matt-router.md), [mp-pm-repo-changelog](../../sources/mp-pm-repo-changelog.md)
- Delivery numbers: none in the repo or the talk; DORA's 2025 framing (AI as an amplifier of the organisation's system) is the outside reference for what those numbers mean. [mp-pm-dora-2025-ai-amplifier](../../sources/mp-pm-dora-2025-ai-amplifier.md)
- Where borg is ahead: locked acceptance criteria with `Verify:` lines (Matt's criteria can pass before any work is done, per his own docs page), a single cross-project view (no cross-project skill was found in the repo listing), and blocking gates before ship. Where Matt is ahead: AFK/HITL as a label on the item and an explicit demo test per slice. Confidence: medium; the borg side is read from the internal docs, the Matt side from primary files.

### F6. Relation to established methods

- Tracer bullets: Matt applies the term to tickets; the original authors used it for an evolving skeleton and set it against up-front specification, so a PRD-first step is in tension with the term's origin. [mp-pm-artima-hunt-thomas-tracer-bullets](../../sources/mp-pm-artima-hunt-thomas-tracer-bullets.md)
- Spec vocabulary: all spec-driven tools are spec-first; few keep the spec over time. Matt's to-spec is spec-first, and his doc-rot rule (close stale PRDs) deliberately avoids spec-anchoring. [mp-pm-fowler-boeckeler-sdd-tools](../../sources/mp-pm-fowler-boeckeler-sdd-tools.md), [mp-pm-aiengineer-workflow-talk-2026](../../sources/mp-pm-aiengineer-workflow-talk-2026.md)
- Contrarian view: spec-driven flows repeat Waterfall's big up-front design. Matt's flow differs (a short synthesis after a live interview, with vertical slices that give early feedback) but is still PRD-first, so the critique applies in part. [mp-pm-marmelab-sdd-waterfall](../../sources/mp-pm-marmelab-sdd-waterfall.md)
- Shape Up: appetite ("start with a number, end with a design") has no counterpart in Matt's skills. [mp-pm-shape-up-set-boundaries](../../sources/mp-pm-shape-up-set-boundaries.md)
- User stories: to-spec asks for an extensive user-story list; the user-story format is carried over without a prioritization method (read from the cloned to-spec text, not a card).
- Confidence: medium; mapping to established methods is the researcher's synthesis, flagged as such.

### F7. Practitioner evidence is mostly promotional or secondary

- Third-party write-ups are summaries of Matt's own material with no measurements; one concedes the full chain is too long for a two-line fix. [mp-pm-contextstudios-pocock-workflow](../../sources/mp-pm-contextstudios-pocock-workflow.md)
- A competing collection's comparison says Matt's set is strong on Define and Build and ships no in-repo evals (interested party). [mp-pm-addy-osmani-skills-comparison](../../sources/mp-pm-addy-osmani-skills-comparison.md)
- The nearest controlled evidence is an RCT of AI use, which found a 19 percent slowdown against a 20 percent believed speedup, so claims of improved speed from any structured workflow need measurement. [mp-pm-metr-ai-slowdown-rct](../../sources/mp-pm-metr-ai-slowdown-rct.md)
- One aggregator comparison with Superpowers was cut as reject band. [mp-pm-besthub-grill-with-docs-vs-superpowers](../../sources/mp-pm-besthub-grill-with-docs-vs-superpowers.md)
- Confidence: high that no independent outcome evidence exists in what was found; absence is limited to the searches logged below.

## Search log

| # | Query (short) | Framing |
|---|---|---|
| 1 | Matt Pocock skills to-prd to-issues grill-me review | factual |
| 2 | skills tracer bullet tickets experience | experiential |
| 3 | Matt Pocock skills criticism overengineered | contrarian |
| 4 | aihero ready-for-agent AFK HITL triage labels | factual |
| 5 | Matt Pocock tracer bullet Pragmatic Programmer | factual |
| 6 | Hacker News Matt Pocock skills grill-me | experiential |
| 7 | skills vs Superpowers vs spec-kit skeptic | contrarian |
| 8 | Fowler Boeckeler spec-driven critique waterfall | evaluative |
| 9 | Matt Pocock skills reddit weeks of use | experiential |
| 10 | DORA 2025 small batches AI amplifier | factual |
| 11 | aihero tracer bullets Matt Pocock article | factual |
| 12 | Pragmatic Programmer tracer code excerpt | factual |
| 13 | spec-driven waterfall Marmelab critique | contrarian |
| 14 | Shape Up appetite AI coding agents | evaluative |
| 15 | Sandcastle Ralph loop AFK planner merger | factual |
| 16 | wayfinder skill review practitioner | evaluative |
| 17 | Matt Pocock workflow review burden ceremony | contrarian |
| 18 | repo issue search: tickets, wayfinder | experiential |
| 19 | GitHub API and releases for repo and Sandcastle | factual |

## Triage-out log

- Medium hands-on review (joe.njenga): HTTP 403, inaccessible to the tools.
- skillselion map and guide pages, dev.to copy: aggregator pages with no extractable body; derivative of the repo.
- conffab "waterfall" excerpt: 403 to fetch tools and an excerpt of another site; Marmelab covers the argument fully.
- Chinese-language write-ups (juejin, csdn, gitcode): translations of the repo; redundant.
- Tessl skill reviews: automated quality scores of the wrapper; not about PM.
- aitoolly news items: auto-generated news summaries.
- Mirror and listing pages (skills.sh, claudeskills.info, mcp.directory, moltchat wiki, nexscope, claude.com plugin listing): copies of repo text or marketing.
- Experiment comparing Superpowers and agent-skills: does not include Matt's skills.
- AI Hero Ralph getting-started guide and Sandcastle README: AFK-loop how-to and tooling, redundant with the talk or owned by another track.
- Cloudstar, Morphllm, Scott Logic pieces: surfaced only in search snippets and redundant with Marmelab and Boeckeler.
- Pasquale Pillitteri wayfinder article: descriptive mirror of the repo text.
- BestHub Superpowers comparison: carded and scored reject (unattributed, one project).

## Evidence gaps and uncertainties

- No independent outcome study of the grill, spec, slice chain; no adoption survey. Star counts vary across sources and days (about 289k at access via the GitHub API).
- The `${LR}/report.md` file named in the brief was not found at the expected location, so it was not used.
- The AI Engineer talk card is a generated write-up of the talk, not the transcript text; Matt's wording on the AFK label and doc rot should be re-checked against the video if cited publicly.
- Whether `to-spec` or `to-tickets` appear in the older install base under the old names varies by third-party page; the repo is the authority.
- Internal borg documents were read from PR branches (#252, #262) and are cited as internal, not carded.

## Paywalled must-reads

Paywall scan: no high-value paywalled candidates identified. No file written.

## Sources index

| # | Card |
|---|---|
| 1 | mp-pm-repo-to-tickets-skill |
| 2 | mp-pm-repo-triage-skill |
| 3 | mp-pm-repo-wayfinder-skill |
| 4 | mp-pm-repo-ask-matt-router |
| 5 | mp-pm-repo-changelog |
| 6 | mp-pm-aihero-to-tickets-docs |
| 7 | mp-pm-aihero-tracer-bullets-article |
| 8 | mp-pm-aiengineer-workflow-talk-2026 |
| 9 | mp-pm-pragmatic-engineer-pocock-interview |
| 10 | mp-pm-contextstudios-pocock-workflow |
| 11 | mp-pm-besthub-grill-with-docs-vs-superpowers (excluded) |
| 12 | mp-pm-addy-osmani-skills-comparison |
| 13 | mp-pm-marmelab-sdd-waterfall |
| 14 | mp-pm-fowler-boeckeler-sdd-tools |
| 15 | mp-pm-shape-up-set-boundaries |
| 16 | mp-pm-artima-hunt-thomas-tracer-bullets |
| 17 | mp-pm-dora-2025-ai-amplifier |
| 18 | mp-pm-metr-ai-slowdown-rct |
| 19 | mp-pm-issue-508-implement-no-completion |
| 20 | mp-pm-issue-476-wayfinder-claim-concurrency |
| 21 | mp-pm-issue-828-wayfinder-stale-premises |
| 22 | mp-pm-issue-310-to-tickets-rubber-stamp |
