---
id: 20260501-archetype-slug-rename
date: '2026-06-16'
project: borg-collective
domain: code-quality
tags:
- reveal
- naming-conventions
- archetypes
- assets
alternatives: []
applies_to: []
confidence: 0.7
status: active
superseded_by: null
cost_to_produce: null
source_tool: null
source_model: null
source_session: 20260616-0347-orchestrator
created_at: '2026-06-16 10:27:02.264571+00:00'
updated_at: '2026-06-16 10:27:02.264571+00:00'
---

# 20260501-archetype-slug-rename

## decision

Rename archetype example JPEGs from photographer slugs to tradition slugs (e.g., adams_zone_system_0.jpg → zone-system-bw.jpg) and remove photographer display names from UI components

## context

Archetype example images and UI labels were keyed on photographer names (e.g., 'after Joel Sternfeld', 'adams_zone_system'). A compliance sweep was needed to remove all photographer-name references from the codebase and assets.

## reasoning

Tradition-slug naming decouples assets from specific artist attribution, avoids potential IP/branding concerns, and aligns with the independence messaging added to reveal-site. UI components referencing photographer names would leak private attribution choices to end users.
