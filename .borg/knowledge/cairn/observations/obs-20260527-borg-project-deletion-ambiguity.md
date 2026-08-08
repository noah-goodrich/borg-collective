---
id: obs-20260527-borg-project-deletion-ambiguity
session_date: '2026-05-27'
project: cairn
tool: cursor
tags:
- borg
- git
- project-marker
- accidental-deletion
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1925-cairn
superseded_by: null
created_at: '2026-06-11 20:31:18.008902+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260527-borg-project-deletion-ambiguity

## content

The file `.borg-project` (contents: `cairn`) is the marker that registers a repo with borg's project enumeration. It was found deleted but uncommitted on the feat branch. Two plausible causes: (a) intentional removal because Cairn is now an MCP service and the developer wanted to de-register it from borg tracking, or (b) an accidental `rm` that hit too many files. The intent could not be determined from the session context alone.

## resolution

Do not restore or stage the deletion without confirming intent with the developer. Document the ambiguity in the PR description when opening the feat branch PR. Options: restore the file and commit it on the feat branch, or delete it with an explicit commit message explaining why Cairn no longer needs borg tracking.
