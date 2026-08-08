---
id: atomic-json-state-write-bash
project: borg-collective
domain: infrastructure
tags:
- bash
- json
- atomic-write
- state-management
- hooks
preconditions: []
steps:
- 'Compute the target path: state_file=$(_borg_state_file "$project_dir")'
- 'Write new JSON to a sibling tmp file: echo "$json" > "${state_file}.tmp"'
- 'Atomically rename: mv "${state_file}.tmp" "$state_file"'
- 'Ensure the .borg/ directory exists before writing: mkdir -p "$(dirname "$state_file")"'
pitfalls:
- If the tmp file and target are on different filesystems, mv is not atomic — keep
  them on the same filesystem (same directory)
- Forgetting mkdir -p causes silent failures when .borg/ doesn't yet exist for a newly
  registered project
- Not handling the case where state.json is absent — readers must default to {} on
  missing file
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 22:41:19.486106+00:00'
updated_at: '2026-06-11 22:41:19.486107+00:00'
---

# atomic-json-state-write-bash

## description

Write JSON state files atomically in bash hooks using a tmp file + mv to prevent partial reads by concurrent hook invocations.
