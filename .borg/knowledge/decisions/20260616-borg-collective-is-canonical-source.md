---
id: 20260616-borg-collective-is-canonical-source
date: '2026-06-16'
project: borg-collective
domain: architecture
tags:
- borg-collective
- claude-plugins
- skills
- source-of-truth
- coco
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.539496+00:00'
updated_at: '2026-06-16 10:27:02.539497+00:00'
---

# 20260616-borg-collective-is-canonical-source

## decision

Skills/agents live in borg-collective (canonical source); claude-plugins is strictly the build-plugin.sh output artifact. No skills are moved out of borg-collective.

## context

An initial plan draft proposed moving skills out of borg-collective into claude-plugins. A 16-agent adversarial review identified this as built on an inverted premise.

## reasoning

CoCo cannot load a .plugin file directly — it requires source. borg-collective is what gets installed and loaded at runtime. claude-plugins exists solely as a distribution artifact produced by build-plugin.sh. Moving skills to claude-plugins would break CoCo loading and invert the dependency direction.
