---
id: jq-tmpfile-safe-write-pattern
project: borg-collective
domain: shell-scripting
tags:
- zsh
- jq
- tmp-files
- error-handling
- idempotency
preconditions: []
steps:
- 'Create a tmp file: tmp=$(mktemp)'
- 'Run jq transformation, writing to tmp: jq ''...'' input.json > "$tmp"'
- 'On jq failure, clean up and return: || { rm -f "$tmp"; return 1; }'
- 'On success, move tmp over the target atomically: mv "$tmp" target.json'
- For every future jq call added to the same function, repeat the || { rm -f "$tmp";
  return 1; } guard
pitfalls:
- Omitting the failure guard leaves stale tmp files in /tmp on jq errors (the exact
  bug hit this session before the refactor fix)
- Using >> or appending to tmp instead of > means a retry after partial failure produces
  corrupt JSON
- mv is not atomic across filesystems; if tmp and target are on different mounts,
  use cp + rm instead
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260611-1917-borg-collective
superseded_by: null
created_at: '2026-06-11 20:39:24.988724+00:00'
updated_at: '2026-06-11 20:39:24.988725+00:00'
---

# jq-tmpfile-safe-write-pattern

## description

Safe pattern for using jq to transform a JSON file in-place via a tmp file, ensuring the tmp file is cleaned up on both success and failure.
