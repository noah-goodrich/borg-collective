---
id: obs-20260714-build-script-no-test-sync
session_date: '2026-07-14'
project: borg-collective
tool: claude-code
tags:
- build-pipeline
- bats
- claude-plugins
- scripts/build-plugin.sh
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260714-1733-borg-collective
superseded_by: null
created_at: '2026-07-14 17:34:17.055830+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260714-build-script-no-test-sync

## content

scripts/build-plugin.sh copies hook source files from borg-collective into claude-plugins but does NOT copy test files. The BATS suite at `<claude-plugins>/borg-collective/hooks/test/borg-link-down.bats` (274 lines) is maintained independently inside the claude-plugins repo. A developer who fixes a hook source bug and adds a regression test in borg-collective's own test directory will NOT automatically see that test run in claude-plugins CI — they must also update the claude-plugins copy manually.

## resolution

When adding regression tests for hook bugs, check whether the same test case needs to be added to the claude-plugins BATS suite separately. Consider whether build-plugin.sh should be extended to sync test files, or whether the two test suites should be kept intentionally separate.
