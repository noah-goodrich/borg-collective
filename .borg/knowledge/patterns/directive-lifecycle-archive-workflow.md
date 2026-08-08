---
id: directive-lifecycle-archive-workflow
project: borg-collective
domain: process
tags:
- docs
- directives
- workflow
- git
preconditions: []
steps:
- Confirm implementation is fully merged to main (check PRs closed, tests passing).
- git checkout -b chore/archive-directive-<slug>
- git mv docs/plans/directives/<file>.md docs/plans/assimilated/<file>.md
- 'Prepend ''# Shipped: YYYY-MM-DD'' (or equivalent front-matter) to the moved file.'
- 'git commit -m ''chore(docs): archive Directive <X> as assimilated (Shipped: YYYY-MM-DD)'''
- Open PR and merge.
pitfalls:
- Easy to forget the archive step after a large implementation PR — the directive
  file stays in directives/ indefinitely, making the open-work list misleading.
- If the shipped date in the file header diverges from the actual merge date, future
  archaeology becomes confusing. Use the main-branch merge date, not the session date.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.494015+00:00'
updated_at: '2026-06-11 22:41:19.494015+00:00'
---

# directive-lifecycle-archive-workflow

## description

Workflow for archiving a shipped directive: move the file from docs/plans/directives/ to docs/plans/assimilated/, prepend a 'Shipped: YYYY-MM-DD' line, commit as chore(docs).
