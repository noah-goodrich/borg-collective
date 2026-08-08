---
id: plugin-version-drift-resolution
project: borg-collective
domain: infrastructure
tags:
- versioning
- claude-plugins
- borg-collective
- build-pipeline
preconditions: []
steps:
- Check current VERSION in borg-collective and current version in claude-plugins plugin.json.
- If plugin.json version >= VERSION, bump VERSION to plugin.json version + 1 patch
  (e.g. plugin.json=0.8.7, VERSION=0.8.6 → bump VERSION to 0.8.8).
- Merge the VERSION bump PR to main before running scripts/build-plugin.sh.
- Run scripts/build-plugin.sh; confirm plugin.json now reflects the new version.
pitfalls:
- Bumping to exactly the published version (0.8.7 in this case) would produce a same-version
  rebuild that deployment tooling might ignore or treat as a no-op.
- VERSION drift can silently accumulate if plugin rebuilds are done without merging
  VERSION bumps first.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260714-1733-borg-collective
superseded_by: null
created_at: '2026-07-14 17:34:17.053019+00:00'
updated_at: '2026-07-14 17:34:17.053020+00:00'
---

# plugin-version-drift-resolution

## description

When the VERSION file in borg-collective drifts behind the version already published in claude-plugins plugin.json, bump VERSION past the published version before rebuilding, so the rebuild produces a strictly newer version number.
