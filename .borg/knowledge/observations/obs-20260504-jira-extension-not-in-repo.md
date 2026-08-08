---
id: obs-20260504-jira-extension-not-in-repo
session_date: '2026-06-11'
project: borg-collective
tool: cursor
tags:
- borg-collective
- skill-extensions
- jira
- per-machine-config
- acceptance-criteria
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.394289+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260504-jira-extension-not-in-repo

## content

The JIRA extension that validates the skill-extension protocol is intentionally NOT stored in the borg-collective repo — it lives at ~/.config/borg/extensions/skill-extensions/borg-plan/01-context.md on the work machine. The repo ships the protocol; machine-local config ships the proof. Acceptance criterion #4 cannot be satisfied by CI — it requires a human to run /borg-plan against a real JIRA ticket on the work machine.

## resolution

When evaluating whether the skill-extension project is fully shipped, check both: (a) PR merged + release cut, AND (b) JIRA extension written and exercised on the work machine.
