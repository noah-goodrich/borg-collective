---
id: obs-20260418-debrief-written-to-template-tree
session_date: '2026-04-18'
project: borg-collective
tool: cursor
tags:
- borg
- debriefs
- checkpoints
- file-placement
- templates
category: gotcha
files_involved: []
confidence: 0.9
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:25.070952+00:00'
updated_at: '2026-07-24 03:52:21.933874+00:00'
---

# obs-20260418-debrief-written-to-template-tree

## content

The April 16 session debrief was written to `templates/supabase/.borg/debriefs/<uuid>.md` instead of `.borg/debriefs/<uuid>.md` at the repo root. The `templates/supabase/` subtree is a scaffold template for downstream projects; placing live project state there means it is (a) semantically wrong, (b) untracked, and (c) risks being copied into scaffolded projects if the template is ever rendered without filtering `.borg/`.


## resolution

Move the debrief to `.borg/debriefs/` at the repo root, then delete `templates/supabase/.borg/`. Add a note to the scaffold render step to strip `.borg/` from template output if not already guarded.

