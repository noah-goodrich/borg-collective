---
id: 20260616-pane-position-left-anchor
date: '2026-06-16'
project: borg-collective
domain: infrastructure
tags:
- tmux
- drone
- pane-layout
- claude-code
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.416895+00:00'
updated_at: '2026-06-16 10:27:02.416895+00:00'
---

# 20260616-pane-position-left-anchor

## decision

Claude pane anchored to left in drone.zsh horizontal splits; shell pane on right

## context

Previous layout had Claude on the right, which was inconsistent with how users read left-to-right and made the primary AI pane feel secondary

## reasoning

Left pane is the natural focal point for horizontal splits; sorting by pane_left ascending is a reliable, index-independent way to identify it
