---
id: obs-20260504-jira-extension-is-proof-of-protocol
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- skill-extensions
- JIRA
- acceptance-criteria
- validation
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.301562+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260504-jira-extension-is-proof-of-protocol

## content

The skill extension protocol has no live validation until the JIRA extension is written and exercised against a real ticket. A protocol that has never been exercised end-to-end carries real risk of subtle load-point ordering bugs or path resolution failures that only manifest at runtime. The acceptance criteria explicitly calls this out as criterion #4.

## resolution

Treat writing and running the first real extension (JIRA 01-context for borg-plan) as a mandatory validation gate before declaring the protocol shipped, not as optional follow-up work.
