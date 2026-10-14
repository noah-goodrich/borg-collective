# Source: mattpocock/skills CHANGELOG (versions 1.0.0 to 1.3.1)

**Full citation:** Matt Pocock and changesets bot. "CHANGELOG.md" (package mattpocock-skills 1.3.1). GitHub. Live 2026-10-13.
**URL:** https://github.com/mattpocock/skills/blob/main/CHANGELOG.md
**Date accessed:** 2026-10-13
**Evidence level:** 5 (practitioner record with dated, specific change data)
**Research topic area:** WHAT IT IS (primary sources): mattpocock/skills, Sandcastle, AI Hero, Matt's stated philosophy

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 9/10 | Written by the repo owner at the time of each change; it is the primary record of what changed. |
| 2 | Evidence Quality | 8/10 | Each entry cites PR numbers and commit SHAs, so every claim is independently checkable in the repo. |
| 3 | Currency | 10/10 | Current through 1.3.1 (2026-10-04); the repo was pushed on the access date. |
| 4 | Intent | 7/10 | Release notes for users; low commercial motive beyond keeping users informed. |
| 5 | Bias & Objectivity | 7/10 | Self-reported changes, but includes candid entries about its own breakage (for example unquoted YAML that made skills.sh skip six skills). |
| 6 | Logic & Coherence | 8/10 | Changes are internally consistent and cross-referenced (renames propagated across skills). |
| 7 | Corroboration | 8/10 | GitHub Releases API dates and the AI Hero changelog page agree on version dates (v1.1.0 2026-07-08, v1.3 2026-10-05). |
| 8 | Intellectual Honesty | 8/10 | Documents mistakes and removals ('nothing replaces it') rather than only wins. |
| 9 | Specificity | 10/10 | Names exact skills, PRs, commits and migration steps (git mv CONTEXT.md GLOSSARY.md). |
| 10 | Relevance | 10/10 | Answers the version-history and to-tickets consolidation questions directly. |

**Score band:** keep

(Intermediate weighted average about 8.5; the disposition is the band word.)

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- v1.1.0 (PR 464, merged 2026-07-08) unified the planning skills: to-prd renamed to to-spec, and to-plan plus to-issues merged into one to-tickets skill (to-issues deleted). This verifies the novelty-probe lead, with the correction that to-prd was renamed (not merged) and to-plan was also folded in.
- to-tickets writes tracer-bullet vertical slices that each declare blocking edges; edges are text in a local file, or native blocking links on a real tracker, so any ticket whose blockers are done is on the 'frontier' and several agents can run at once.
- v1.3.0 (2026-10-04) graduated implement-spec, pr and retro into Engineering, renamed the CONTEXT.md convention to GLOSSARY.md, and removed resolving-merge-conflicts with 'nothing replaces' it.
- v1.0.0/1.0.1 shipped 2026-06-17 and the plugin was added in v1.2.x (August); the file records breaking renames shipped as minor versions, so consumers pinning behaviour must read it before updating.
- Several entries are bug-fixes to cross-skill references (for example skills trying to call user-invoked skills through the Skill tool), showing the cost of the composition model.

## Verified Quote(s)

**Location reference:** Quote 1: Section '1.1.0', Minor Changes, PR 464 entry (first sentence); Quote 2: Section '1.1.0', Minor Changes, PR 464 entry, second paragraph; Quote 3: Section '1.3.0', Minor Changes, the entry that removes resolving-merge-conflicts

> Unify the planning skills.

> That one artifact reads two ways depending on the tracker

> It's no longer needed, and nothing replaces it: the agent works through an in-progress merge or rebase conflict without a dedicated skill.

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Authoritative, dated, checkable version history; sole source for the to-tickets consolidation detail.

**Redundancy check:** Complements the GitHub API card (dates) and AI Hero catalogue (marketing summaries); neither carries the detail.

**Perspective category:** Practitioner
