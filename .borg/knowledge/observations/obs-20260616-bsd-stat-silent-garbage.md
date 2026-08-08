---
id: obs-20260616-bsd-stat-silent-garbage
session_date: '2026-06-16'
project: borg-collective
tool: claude-code
tags:
- bash
- stat
- bsd
- gnu
- portability
- ci
- reaper
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.543460+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260616-bsd-stat-silent-garbage

## content

lib/reaper.sh:88 used BSD-first stat -f which returns garbage (not an error) on GNU/Linux. main CI had been silently RED since PR #46 without anyone noticing. The same bug class existed in research-tools and in claude-plugins (also a locale-sensitive en-dash regex issue in the same pass).

## resolution

Fixed with OS-detection guard in lib/reaper.sh. Applied the same fix in research-tools. claude-plugins PR #14 added 54 BATS and verified 39/39 pass on both OS types.
