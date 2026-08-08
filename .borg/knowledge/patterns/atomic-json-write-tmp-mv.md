---
id: atomic-json-write-tmp-mv
project: borg-collective
domain: infrastructure
tags:
- bash
- json
- atomic-write
- state.json
preconditions: []
steps:
- 'Compute the target path: `state_file=$(_borg_state_file "$project_dir")`'
- 'Write new JSON content to a temp file in the same directory: `tmp=$(mktemp "${state_file}.XXXXXX")`'
- 'Write content: `echo "$json" > "$tmp"`'
- 'Atomically replace: `mv "$tmp" "$state_file"`'
pitfalls:
- mktemp must create the file in the same filesystem as the target to guarantee mv
  is atomic (same partition)
- If the .borg/ directory doesn't exist yet, the mktemp call will fail — ensure directory
  creation precedes first write
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260616-0347-orchestrator
superseded_by: null
created_at: '2026-06-16 10:27:02.449434+00:00'
updated_at: '2026-06-16 10:27:02.449435+00:00'
---

# atomic-json-write-tmp-mv

## description

Write JSON state files atomically in bash using a tmp file + mv to prevent partial-write corruption if a hook is interrupted mid-write.
