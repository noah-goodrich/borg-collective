---
id: obs-20260616-plugin-repo-separate-pr
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- plugin
- claude-plugins
- multi-repo
- workflow
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.506672+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-plugin-repo-separate-pr

## content

Changes to `claude-plugins` (the plugin distribution repo) require a separate commit, push, and PR in that repo. It is easy to complete all work in `borg-collective`, consider the session done, and leave `claude-plugins` with committed-but-unpushed changes. This happened in the `directives-02-06` branch.

## resolution

The session notes explicitly called this out as a 'don't forget' item. Add a checklist step at the end of any borg-collective PR that touches SKILL.md or hook files: 'Did you run sync-plugin.sh and open a PR in claude-plugins?'
