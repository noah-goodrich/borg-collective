---
id: 20260513-orchestrator-root-rename
date: '2026-06-11'
project: borg-collective
domain: architecture
tags:
- shell
- environment-variables
- naming
- borg-collective
- orchestrator-mode
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.427270+00:00'
updated_at: '2026-06-11 22:41:19.427270+00:00'
---

# 20260513-orchestrator-root-rename

## decision

Rename BORG_ROOT to BORG_ORCHESTRATOR_ROOT for workspace-root semantics, repurpose BORG_ROOT as install-path semantics in install.sh

## context

The variable BORG_ROOT was overloaded — it meant both 'where borg is installed' and 'the workspace root where orchestrator mode activates'. This caused confusion when reasoning about session classification, since ~/dev/borg-collective (the project) lives inside ~/dev (the orchestrator root).

## reasoning

Splitting the two meanings into distinct variables eliminates the conflation. BORG_ORCHESTRATOR_ROOT clearly signals 'the root from which orchestrator mode is detected', while BORG_ROOT retains its natural meaning as the installation path. 8 sites updated; install.sh exports new BORG_ROOT as install path.
