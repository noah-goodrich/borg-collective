#!/usr/bin/env bash
# tool-count-nudge.sh — PostToolUse hook: remind to check progress after sustained work.
# Counts tool calls per session. After 75 calls, injects a review reminder.
# Always exits 0 — reminder only, never blocks.

set -euo pipefail

INPUT=$(cat /dev/stdin 2>/dev/null || true)
SID=$(printf '%s' "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")

COUNTER_FILE="/tmp/borg-tool-count-${SID}"
COUNT=0
[[ -f "$COUNTER_FILE" ]] && COUNT=$(cat "$COUNTER_FILE")
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

if (( COUNT >= 75 )); then
    echo "0" > "$COUNTER_FILE"
    jq -n '{
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": "SESSION CHECK-IN: 75+ tool calls this session. Consider running /borg-review to check progress against the plan, or /checkpoint-enhanced if this is a good save point."
        }
    }'
fi

exit 0
