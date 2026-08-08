---
id: 20260611-gitignore-negation-ordering
date: '2026-06-11'
project: borg-collective
domain: code-quality
tags:
- git
- gitignore
- checkpoints
- .borg
alternatives: []
applies_to: []
confidence: 0.9
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260611-1917-borg-collective
created_at: '2026-06-11 22:41:19.340580+00:00'
updated_at: '2026-06-11 22:41:19.340580+00:00'
---

# 20260611-gitignore-negation-ordering

## decision

Remove the `.borg/` ignore line that preceded `!.borg/checkpoints/`, making the negation reachable

## context

The .gitignore had `.borg/` followed by `!.borg/checkpoints/`. Git processes .gitignore rules top-to-bottom and a blanket directory ignore cannot be un-ignored by a later negation — the negation was silently a no-op.

## reasoning

The intent was to track checkpoint files while ignoring other .borg contents. The only correct fix is to remove (or narrow) the blanket ignore so the negation can take effect.
