---
id: obs-20260527-prior-decision-not-in-handoff
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- session-continuity
- dispatch
- knowledge-loss
- source-of-truth
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.454915+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260527-prior-decision-not-in-handoff

## content

A significant architectural decision (canonical repo + privacy boundary) was made in a Dispatch session (f9ef8d07, 2026-05-24) but was never captured in a handoff doc or checkpoint. A subsequent session then re-opened the question and spent time re-deriving the answer. The original session commit was the only record.

## resolution

After finding the original commit, the decision was backfilled into a handoff doc and the directive doc was corrected. Going forward, cross-repo architectural decisions should be captured in docs/plans/handoff/ at the time they are made, not left only in commit messages.
