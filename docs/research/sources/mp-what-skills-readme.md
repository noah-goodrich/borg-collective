# Source: mattpocock/skills README (install paths, skill catalogue, philosophy)

**Full citation:** Matt Pocock. "Skills For Real Engineers" (README.md, mattpocock/skills). GitHub. Live 2026-10-13 (repo pushed 2026-10-13).
**URL:** https://github.com/mattpocock/skills
**Date accessed:** 2026-10-13
**Evidence level:** 7 (author's own primary documentation / thought leadership)
**Research topic area:** WHAT IT IS (primary sources): mattpocock/skills, Sandcastle, AI Hero, Matt's stated philosophy

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 9/10 | Matt Pocock is the repo's author and its sole significant committer (499 of 545 commits), so this is the authoritative statement of what the repo is. |
| 2 | Evidence Quality | 6/10 | Documentation of intent and structure, not evidence of outcomes; the factual claims (install commands, skill list) are checkable against the repo tree and are accurate. |
| 3 | Currency | 10/10 | Fetched live on the access date; the repo was pushed the same day. No timeless bonus needed. |
| 4 | Intent | 6/10 | Open-source documentation, but also the funnel to a ~60,000-person newsletter and paid AI Hero training, which the README itself links. |
| 5 | Bias & Objectivity | 5/10 | Strongly opinionated and competitor-positioning (names GSD, BMAD, Spec-Kit as taking control away); no counter-arguments presented. |
| 6 | Logic & Coherence | 8/10 | Four named failure modes map cleanly to named skills; reasoning is coherent and consistently cited to classic books. |
| 7 | Corroboration | 8/10 | Install commands and skill list corroborated by the Anthropic marketplace listing, the AI Hero catalogue, and the CHANGELOG (with lag noted in those). |
| 8 | Intellectual Honesty | 6/10 | States design intent plainly, including that skills are 'small' and meant to be adapted, and that the plugin and skills.sh routes are alternatives not additive. |
| 9 | Specificity | 9/10 | Exact install commands per agent, every skill with a one-line job, and the user-invoked versus model-invoked axis are all specified. |
| 10 | Relevance | 10/10 | Directly answers the track question: what the repo is, how it installs, what each skill does. |

**Score band:** keep

(Intermediate weighted average about 7.6; the disposition is the band word.)

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- The README catalogues 27 skills (my count of the listed bullets: Engineering 11 user-invoked plus 9 model-invoked, Productivity 5 plus 2), split on one axis: who can invoke them (user-invoked orchestrators versus model-invoked reusable disciplines).
- Install routes today: Claude Code plugin (claude plugin install mattpocock-skills@claude-plugins-official, self-updating), Codex, GitHub Copilot, Gemini CLI, and npx skills@latest add for Cursor, OpenCode, Devin, Windsurf, Amp, Pi; the README warns to pick one route per agent or every skill installs twice.
- One-time per-repo setup via /setup-matt-pocock-skills (issue tracker: GitHub, GitLab, local files or other; triage labels; docs location).
- Stated positioning: skills are small, composable and model-agnostic, explicitly contrasted with GSD, BMAD and Spec-Kit which 'own the process'.
- Four failure modes mapped to fixes: misalignment (grilling), verbosity (shared GLOSSARY.md language), broken code (tdd, diagnosing-bugs), ball of mud (to-spec module quiz, improve-codebase-architecture).

## Verified Quote(s)

**Location reference:** Quote 1: Opening paragraph under the title 'Skills For Real Engineers'; Quote 2: Second paragraph under the title; Quote 3: Section 'Installation (30-second setup)', first paragraph

> My agent skills that I use every day to do real engineering - not vibe coding.

> Approaches like GSD, BMAD, and Spec-Kit try to help by owning the process. But while doing so, they take away your control and make bugs in the process hard to resolve.

> Pick one per agent, because installing both gives you every skill twice.

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Highest-authority primary source for the track question; sole source for install paths and skill inventory. Weakness (promotional and one-sided) is mitigated by triangulation with the contrarian cards.

**Redundancy check:** Not redundant: only source for the full inventory and install matrix. The AI Hero catalogue and Anthropic listing partially duplicate it but lag (21 vs 27 skills).

**Perspective category:** Practitioner
