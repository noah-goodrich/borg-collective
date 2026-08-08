---
id: obs-20260420-bin-launchd-dirs-not-scaffolded
session_date: '2026-04-20'
project: borg-collective
tool: cursor
tags:
- scaffolding
- borg
- launchd
- project-plan
- gap
category: error_encountered
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.084439+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260420-bin-launchd-dirs-not-scaffolded

## content

PROJECT_PLAN.md references bin/borg-notifyd and launchd/com.stillpoint-labs.borg.notifyd.plist but neither directory nor file exists in the repo. Any script or CI step that assumes these paths exist will fail silently or with a confusing 'no such file' error.

## resolution

Next implementation session must mkdir -p bin/ launchd/ and create both files before referencing them in install.sh or any test. Consider adding a repo-structure smoke test to catch dangling references in PROJECT_PLAN.md.
