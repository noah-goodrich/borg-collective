---
id: shell-hook-json-assembly-via-jq-arg
project: borg-collective
domain: testing
tags:
- bash
- jq
- json
- hooks
- borg-link-down
- bats
preconditions: []
steps:
- Collect all conditional context fragments into a single bash variable (e.g. `context_str`),
  appending with plain string concatenation or printf into the variable — not into
  the JSON.
- 'Pass the fully-assembled string as a named arg to jq: `jq -n --arg ctx "$context_str"
  ''{hookSpecificOutput: {additionalContext: $ctx}}''`'
- Never interpolate `$context_str` directly into a jq filter string or a printf JSON
  template.
- Add a BATS test that exercises the hook with fixtures that trigger all conditional
  context branches simultaneously (e.g. state.json with has_uncommitted_changes=true
  AND PROJECT_PLAN.md present) and asserts the output is valid JSON via `echo "$output"
  | jq .`
pitfalls:
- scripts/build-plugin.sh does NOT sync test files from borg-collective into claude-plugins;
  BATS suites in claude-plugins are maintained separately and must be updated manually
  if new test cases are needed there.
- 'The JSON parse error (`jq: parse error: Invalid numeric literal`) from malformed
  additionalContext can look like a numeric/type error but is almost always an unescaped
  special character in the interpolated string.'
- Failures only reproduce under BATS fixtures that activate multiple context branches
  simultaneously; running the hook manually with a simple project cwd may emit valid
  JSON and give a false pass.
cost_estimate: null
times_applied: 0
last_applied: null
confidence: 0.7
source_model: null
source_session: 20260714-1733-borg-collective
superseded_by: null
created_at: '2026-07-14 17:34:17.052185+00:00'
updated_at: '2026-07-14 17:34:17.052186+00:00'
---

# shell-hook-json-assembly-via-jq-arg

## description

When a shell hook must emit a JSON payload that includes dynamically-assembled string fields (e.g. additionalContext built from multiple conditional pieces), assemble the entire string first in a bash variable, then inject it into the JSON object via `jq --arg` or `jq -Rs` rather than printf/string interpolation. This prevents parse errors when the dynamic content contains quotes, newlines, or special characters.
