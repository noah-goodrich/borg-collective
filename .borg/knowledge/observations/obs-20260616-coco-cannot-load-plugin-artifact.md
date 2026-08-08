---
id: obs-20260616-coco-cannot-load-plugin-artifact
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- coco
- claude-plugins
- borg-collective
- plugin-loading
- architecture
category: domain_knowledge
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.545302+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-coco-cannot-load-plugin-artifact

## content

CoCo (Claude Code) cannot load a .plugin artifact directly. It requires source files. This means any skill or agent that needs to be available in CoCo must have its source in borg-collective, not only in the claude-plugins build output.

## resolution

Captured in memory project_borg_source_of_truth. borg-collective is canonical; claude-plugins is distribution-only. Plan sections that assumed CoCo could load from claude-plugins were deleted.
