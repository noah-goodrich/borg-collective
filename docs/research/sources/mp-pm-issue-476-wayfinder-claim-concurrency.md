# Source: mattpocock/skills issue 476: wayfinder claim protocol fails under concurrent sessions

**Full citation:** mattiasthalen. "wayfinder: claim protocol fails under concurrent sessions (double-resolution + map lost-update)..." GitHub issue #476, mattpocock/skills, opened 2026-07-08 (open). https://github.com/mattpocock/skills/issues/476. Accessed 2026-10-13.
**URL:** https://github.com/mattpocock/skills/issues/476
**Date accessed:** 2026-10-13
**Evidence level:** 5 (practitioner case report with timeline, n=1)
**Research topic area:** PM / planning: how Matt Pocock structures work for agents (PRD/spec, grilling, tracer-bullet tickets, HITL/AFK labels, triage, TDD loop) and how it relates to established methods and to borg

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 3/10 | Unknown user, but a detailed first-hand report. |
| 2 | Evidence Quality | 4/10 | One real multi-session run with timestamps; no repeat trials. |
| 3 | Currency | 10/10 | July 2026; open. |
| 4 | Intent | 8/10 | Bug report meant to improve the skill. |
| 5 | Bias & Objectivity | 7/10 | Reports exactly what happened and which identities were involved. |
| 6 | Logic & Coherence | 8/10 | Root-cause analysis is coherent (claim by assignee is invisible to bot identities). |
| 7 | Corroboration | 5/10 | Related issues #828 and #1174 describe adjacent stale-state faults; not independent replication. |
| 8 | Intellectual Honesty | 8/10 | Labels its two failures separately and says which are skill gaps. |
| 9 | Specificity | 9/10 | Minute-level timeline (two resolutions one second apart). |
| 10 | Relevance | 9/10 | Shows where assignee-as-claim breaks for parallel agents, relevant to borg's per-project drones. |

**Score band:** borderline (weighted average about 6.00). Included with a named reason, see Inclusion Decision.

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- Two sessions resolved the same wayfinder ticket one second apart; one ran as a bot identity that could not assign itself, so the claim was invisible.
- Claim-by-assignee is the only signal, and sessions driven by one human all assign the same user, so a session cannot tell its own claim from another's.
- There is no re-verification between claim and resolve, so the time-of-check/time-of-use window is long.

## Verified Quote(s)

**Location reference:** Issue body, 'Failure 1: two sessions resolved the same ticket', timeline item 3 and the first bullet under 'Why the skill's claim protocol didn't prevent it'.

> Both sessions posted resolution comments one second apart

> Claim-by-assignee is the only signal, and some sessions can't emit it.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Borderline on authority; included as the strongest first-hand report of coordination failure in a GitHub-issue-based plan, directly relevant to multi-session work.

**Redundancy check:** Distinct from #828: concurrency and claims versus stale premises.

**Perspective category:** Boots-on-the-ground
