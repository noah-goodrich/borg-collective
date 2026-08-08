---
id: borg-collective-version-release-cycle
project: borg-collective
domain: infrastructure
tags:
- versioning
- homebrew
- formula
- release
- sha256
preconditions: []
steps:
- Make functional changes (e.g., bash-guard.sh, SKILL.md updates)
- Commit functional changes with descriptive message
- Bump version in relevant version file, commit as separate 'version bump' commit
- 'Tag the commit: git tag v0.x.y && git push origin main --tags'
- Compute new sha256 of the release tarball
- Update Formula/borg-collective.rb with new version string and sha256
- Commit formula update separately
- Manually sync any installed skill files that bash-guard prevents Claude from touching
  (e.g., cp .../SKILL.md ~/.claude/skills/.../SKILL.md)
pitfalls:
- The installed skill copy at ~/.claude/skills/ goes stale after SKILL.md updates
  — bash-guard correctly blocks Claude from writing to ~/.claude/, so the cp must
  be run manually by the human after each release
- Forgetting the formula sha256 update will cause Homebrew installs to fail checksum
  verification on the next brew upgrade
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.420488+00:00'
updated_at: '2026-06-11 22:41:19.420489+00:00'
---

# borg-collective-version-release-cycle

## description

Full release cycle for borg-collective: code change → version bump → tag → push → update Homebrew formula with new sha256.
