# Source: mattpocock/skills: CHANGELOG.md (renames, graduations, v1.1.0 to v1.3.1)

**Full citation:** Matt Pocock and contributors. "CHANGELOG.md", repository mattpocock/skills, main branch, accessed 2026-10-13. Releases v1.3.0 and v1.3.1 published 2026-10-04.
**URL:** https://raw.githubusercontent.com/mattpocock/skills/main/CHANGELOG.md
**Date accessed:** 2026-10-13
**Evidence level:** 5 (dated public change record; practitioner case with traceable commits)
**Research topic area:** PM / planning: how Matt Pocock structures work for agents (PRD/spec, grilling, tracer-bullet tickets, HITL/AFK labels, triage, TDD loop) and how it relates to established methods and to borg

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 8/10 | The maintainer's own change record; each entry links a PR and commit. |
| 2 | Evidence Quality | 5/10 | Verifiable history of what changed and why, though not outcomes. |
| 3 | Currency | 10/10 | Latest entry is the Oct 2026 v1.3.1 release. |
| 4 | Intent | 8/10 | Release notes written to explain behaviour changes to users. |
| 5 | Bias & Objectivity | 7/10 | Maintainer-authored, but includes candid corrections (stale hand-offs, invalid YAML skipped by the installer). |
| 6 | Logic & Coherence | 8/10 | Chronological, changeset-structured. |
| 7 | Corroboration | 8/10 | GitHub API (created 2026-02-03, tags v1.2.3 to v1.3.1) and the open-issue tracker agree with it. |
| 8 | Intellectual Honesty | 9/10 | Records reversals openly (removes resolving-merge-conflicts, removes a diagnosing-bugs hand-off). |
| 9 | Specificity | 9/10 | PR numbers, commit hashes and exact skill names for each change. |
| 10 | Relevance | 8/10 | Shows the to-prd/to-issues to to-spec/to-tickets rename and retro/implement-spec graduation, which fixes the novelty-probe naming confusion. |

**Score band:** keep (weighted average about 7.60).

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- to-prd was renamed to to-spec and to-issues became to-tickets in the 1.1.0 'Unify the planning skills' change; 'spec' is now the single term.
- v1.3.0 graduated implement-spec, pr and retro into the Engineering bucket; implement-spec treats tickets as a task graph, runs implementers in worktrees across the frontier, and lands on one integration branch.
- The repo moves fast: GitHub shows the repository created 2026-02-03 (not April), with tagged releases v1.2.3 (2026-08-06) and v1.3.0 and v1.3.1 (2026-10-04), a glossary file rename (CONTEXT.md to GLOSSARY.md) in 1.3.0, and a docs rule against reintroducing em-dashes.
- Cross-skill calls were rewritten to explicit 'call the Skill tool' wording because prose references 'do not reliably cause it to load'; this is a real-world reliability limit on skill chaining.

## Verified Quote(s)

**Location reference:** Entry '## 1.1.0' (Minor Changes, the 'Unify the planning skills' bullet, #464) and entry '## 1.3.0' (Minor Changes, the retro bullet and the implement-spec bullet).

> Unify the planning skills. **`to-prd` is renamed to `to-spec`**

> `retro` (user-invoked) looks back at a coding session and suggests changes to the agent's environment rather than the code

> The goal is now the integration branch, not a PR.

**Access status:** live

## Inclusion Decision

**Decision:** Core
**Rationale:** Dated, linkable record that grounds the naming history and the speed of change; resolves the 'to-prd/to-issues versus to-spec/to-tickets' ambiguity from the probe.

**Redundancy check:** Only source with the rename history and release dates.

**Perspective category:** Practitioner
