---
id: obs-20260618-snowfort-ui-actions-not-automatable
session_date: '2026-06-18'
project: cairn
tool: claude-code
tags:
- github
- pages
- sponsors
- secrets
- snowfort
- manual-steps
category: domain_knowledge
files_involved: []
confidence: 0.7
source_model: null
source_session: 20260618-0029-cairn
superseded_by: null
created_at: '2026-06-18 00:30:17.389113+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260618-snowfort-ui-actions-not-automatable

## content

Four GitHub UI actions (merge PR #22, enable Pages, enable Sponsors with 3 tiers, add ANTHROPIC_API_KEY secret) cannot be automated via CLI or API without elevated OAuth scopes that aren't available in the standard gh CLI session. These block downstream pipeline verification.

## resolution

These must be performed manually in the GitHub web UI by the repo owner. Maintain a persistent checklist in session notes (as 'snowfort' items) so they are not re-identified every session as new blockers. Once completed, remove from the standing checklist.
