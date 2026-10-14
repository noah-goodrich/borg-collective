# Source: AI Hero post: Why the Anthropic Ralph plugin sucks (use a bash loop instead)

**Full citation:** Matt Pocock. "Why the Anthropic Ralph plugin sucks (use a bash loop instead)." aihero.dev/why-the-anthropic-ralph-plugin-sucks. Updated 2026-01-22.
**URL:** https://www.aihero.dev/why-the-anthropic-ralph-plugin-sucks
**Date accessed:** 2026-10-13
**Evidence level:** 7 (author's opinion with reasoned argument)
**Research topic area:** WHAT IT IS (primary sources): mattpocock/skills, Sandcastle, AI Hero, Matt's stated philosophy

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 8/10 | Matt is a long-standing teacher of AFK loops, and the post is his own position on a native Anthropic feature. |
| 2 | Evidence Quality | 3/10 | Argument from context-window behaviour; the 40% 'smart zone' figure is asserted as folk consensus, not measured. |
| 3 | Currency | 7/10 | January 2026; the plugin and Claude Code have changed since, so the specific plugin critique may be stale. |
| 4 | Intent | 5/10 | Teaching content that also steers readers to his Ralph guides. |
| 5 | Bias & Objectivity | 4/10 | Strongly opinionated headline; one-sided against the native plugin. |
| 6 | Logic & Coherence | 7/10 | Coherent chain from token count to degraded attention to fresh-context loops. |
| 7 | Corroboration | 5/10 | 'Smart zone' language recurs in the Pragmatic Engineer interview and the AI Engineer talks; no independent measurement cited. |
| 8 | Intellectual Honesty | 5/10 | Concedes that people debate the exact boundary. |
| 9 | Specificity | 7/10 | Shows the exact /ralph-loop command and the bash-loop alternative. |
| 10 | Relevance | 8/10 | Gives Matt's position on native Claude features versus external loops, a core track question. |

**Score band:** borderline

(Intermediate weighted average about 5.8; the disposition is the band word.)

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Matt argues Anthropic's official Ralph plugin intercepts exit attempts and feeds the prompt back into the same session, so context accumulates and the model degrades.
- His claim: each LLM has a smart zone (about the first 40% of context) and a dumb zone; a bash loop that starts a fresh context each iteration keeps the agent in the smart zone.
- This is the same fresh-context-per-task principle behind to-tickets sizing each ticket to fit one context window and behind Sandcastle's iteration model.
- An example of a native Claude Code feature being rejected on first-principles grounds rather than adopted: relevant to how he would rate native features generally.

## Verified Quote(s)

**Location reference:** Quote 1: Section 'What Is The Anthropic Plugin?', first sentence; Quote 2: Section 'The Problem With Anthropic's Ralph Plugin', paragraph after the zone table; Quote 3: Section 'Why A Bash Loop Works', first paragraph

> Anthropic shipped an official Ralph plugin for Claude Code that's designed to automate this loop for you.

> At around the 40% context mark, LLMs start entering the dumb zone.

> Each iteration of Ralph uses a fresh context window

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Borderline band: included as the only primary source where Matt compares a native Anthropic feature to his own method (sole source); evidence is argument, not data.

**Redundancy check:** Unique on native-versus-own; other cards do not cover Ralph.

**Perspective category:** Contrarian
