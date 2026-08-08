---
id: obs-20260501-ssr-empty-state-before-import
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- reveal-site
- astro
- ssr
- supabase
- empty-state
category: gotcha
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.268805+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260501-ssr-empty-state-before-import

## content

The SSR gallery on reveal-site deployed successfully but shows an empty state because the reveal import pipeline had not yet completed when the deployment went live. This is expected behavior, but without explicit empty-state UI handling the gallery would appear broken to anyone checking the site before import lands.

## resolution

Empty state UI was confirmed to be implemented correctly. Next session should verify gallery populates after the 13-photo import completes by checking reveal.photo/seen and running smoke_prod.py.
