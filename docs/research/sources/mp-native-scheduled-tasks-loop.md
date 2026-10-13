# Source: Claude Code docs, Scheduled tasks and /loop

**Full citation:** Anthropic. "Run prompts on a schedule." Claude Code documentation. https://code.claude.com/docs/en/scheduled-tasks. Live page, accessed 2026-10-13.
**URL:** https://code.claude.com/docs/en/scheduled-tasks
**Date accessed:** 2026-10-13
**Evidence level:** 4 (vendor primary documentation)
**Research topic area:** Native scheduling and resume vs borg-resume (auto-resume after limits)

## Credibility Scores

| # | Dimension | Score | Justification |
|---|-----------|-------|---------------|
| 1 | Authority | 10/10 | Feature owner |
| 2 | Evidence Quality | 8/10 | Full behavior spec |
| 3 | Currency | 10/10 | Live, v2.1.248+ notes |
| 4 | Intent | 7/10 | Product docs |
| 5 | Bias & Objectivity | 8/10 | Limitations listed |
| 6 | Logic & Coherence | 9/10 | Compare table, then detail |
| 7 | Corroboration | 8/10 | Routines, agent-view pages agree |
| 8 | Intellectual Honesty | 9/10 | Jitter, expiry, no catch-up |
| 9 | Specificity | 10/10 | Cron tools, caps, expiry |
| 10 | Relevance | 8/10 | Adjacent to borg-resume |

- Authority and Currency: first-party and live.
- Evidence Quality: precise mechanics (50 tasks per session, jitter rules, seven-day expiry).
- Bias: the Limitations section is plain about what does not survive a closed terminal.
- Logic: opens with a three-way comparison of cloud, desktop, and `/loop` scheduling.
- Corroboration: the routines page gives the same comparison.
- Honesty: no catch-up for missed fires, and recurring tasks expire.
- Specificity: `CronCreate`, `CronList`, `CronDelete`, `ScheduleWakeup`.
- Relevance: this is session-scoped polling; it does not by itself resume crashed or limit-killed work, which is borg-resume's niche.

**Score band:** keep

## Bias Guard Check

- [ ] I agree with this source's conclusions → scored harder on dims 5, 6, 8
- [ ] I disagree with this source's conclusions → scored more generously on dims 5, 6, 8
- [x] Neutral / no strong reaction

## Key Findings

- `/loop` and the cron tools are session-scoped: tasks only fire while Claude Code is running and idle, and recurring tasks expire seven days after creation.
- A scheduled fire only runs skills Claude may invoke on its own; skills marked `disable-model-invocation: true` arrive as plain text. This matters for Matt's user-invoked skills, which cannot be scheduled.
- Durable scheduling is a separate product: cloud Routines, Desktop scheduled tasks, or GitHub Actions.
- Backgrounding a session carries `/loop` tasks over to a session that keeps running without a terminal.
- None of this restarts a session that was killed by a usage limit; workflows have their own limit-wait (v2.1.271+), which is the nearest native counterpart to borg-resume.

## Verified Quote(s)

**Location reference:** Second paragraph under the page intro ("Tasks are session-scoped."); section "Seven-day expiry" first sentence.

> Tasks are session-scoped.

> Recurring tasks automatically expire 7 days after creation.

**Access status:** live

## Inclusion Decision

**Decision:** Supporting
**Rationale:** Establishes that native scheduling does not replace borg-resume; useful as a boundary marker.

**Redundancy check:** The routines card covers durable cloud scheduling; this card covers in-session scheduling.

**Perspective category:** Institutional
