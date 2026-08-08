---
id: archetype-rename-across-monorepo
project: borg-collective
domain: content-architecture
tags:
- archetype-rename
- monorepo
- display-labels
- tradition-names
preconditions: []
steps:
- 'Identify all display surfaces: UI components, static HTML, markdown content files,
  HANDOFF/SKILL docs, design system data files'
- Audit slugs and DB keys — confirm they are opaque identifiers NOT requiring rename
- Update design system data layer first (data.jsx rootedIn arrays, archetypeTradition
  fields) so components inherit correct values
- Update component display logic (remove photographer/tradition split, simplify archetypeLabel)
- 'Update static site content: gallery cards, homepage blockquotes, caption markdown
  files'
- Add canonical disclaimer page (/about/independence) and wire footer link globally
- Deploy and verify all 7 tradition names render correctly in production
- Update documentation (HANDOFF.md rename map, deprecated field annotations in SKILL.md)
pitfalls:
- Slugs look like they need renaming but don't — they are internal keys; renaming
  breaks data integrity
- Markdown caption files (e.g., burtynsky-painterly-epic.md) are easy to miss — grep
  for photographer name strings in /content and /public directories
- Hero images may reference old naming conventions in filename or alt text — audit
  separately
- Design system and app repo can drift if design system is updated but app components
  still import deprecated fields
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.252822+00:00'
updated_at: '2026-06-16 10:27:02.252822+00:00'
---

# archetype-rename-across-monorepo

## description

Propagate a display-label rename (photographer names → tradition names) across a multi-repo system without touching internal identifiers
