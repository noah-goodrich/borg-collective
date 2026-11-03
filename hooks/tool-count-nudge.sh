#!/usr/bin/env bash
# tool-count-nudge.sh — PostToolUse hook: remind to check progress after sustained work.
#
# Primary trigger (#503): CONTEXT SIZE, because that is what drives cost (a long session re-reads its whole history
# every turn). Hooks get no context-size field, so `bin/borg-statusline` writes {session_id, total_input_tokens,
# used_percentage} to ${XDG_CACHE_HOME:-$HOME/.cache}/borg/context/<session_id>.json and this hook reads it. It nudges
# when the context first reaches BORG_CONTEXT_NUDGE_TOKENS (default 120000), then again at every +40000 above that.
# The "already nudged" level is kept per session, and it resets when the context shrinks below it (a compaction).
#
# Fallback: with no context file (statusline not installed, first call of a session) it counts tool calls and nudges
# at 75, exactly as before.
# Always exits 0 — reminder only, never blocks.

set -euo pipefail

INPUT=$(cat /dev/stdin 2>/dev/null || true)
SID=$(printf '%s' "$INPUT" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")

# User-owned cache dir, not /tmp (SA4): a predictable path in world-writable /tmp is
# symlink-plantable by any local user. Low stakes, but hygiene is free here.
SAFE_SID="${SID//[^A-Za-z0-9_-]/_}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/borg"
mkdir -p "$CACHE_DIR" 2>/dev/null || exit 0

_nudge() {
    jq -n --arg msg "$1" '{
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": $msg
        }
    }'
}

CONTEXT_FILE="$CACHE_DIR/context/${SAFE_SID}.json"
if [[ -f "$CONTEXT_FILE" ]]; then
    TOKENS=$(jq -r '.total_input_tokens // empty' "$CONTEXT_FILE" 2>/dev/null || true)
    BASE="${BORG_CONTEXT_NUDGE_TOKENS:-120000}"
    STEP=40000
    # Both must be plain integers; anything else (a half-written file, a bad env value) falls through to the count.
    if [[ "$TOKENS" =~ ^[0-9]+$ && "$BASE" =~ ^[0-9]+$ ]]; then
        LEVEL_FILE="$CACHE_DIR/context-nudged-${SAFE_SID}"
        LAST=-1
        [[ -f "$LEVEL_FILE" ]] && LAST=$(cat "$LEVEL_FILE" 2>/dev/null || echo -1)
        [[ "$LAST" =~ ^-?[0-9]+$ ]] || LAST=-1
        # A context smaller than the last nudged level means it was compacted or cleared: start over.
        if (( TOKENS < LAST )); then
            LAST=-1
        fi
        if (( TOKENS >= BASE )); then
            LEVEL=$(( BASE + (TOKENS - BASE) / STEP * STEP ))
            if (( LEVEL > LAST )); then
                echo "$LEVEL" > "$LEVEL_FILE"
                _nudge "SESSION CHECK-IN: context is $((TOKENS / 1000))k tokens. Run /borg-review to check progress. If this is a save point, run /borg-link-up and then start a fresh session: the checkpoint carries the work over, and a long session re-reads its whole history every turn."
            fi
        else
            echo "$LAST" > "$LEVEL_FILE"
        fi
        exit 0
    fi
fi

COUNTER_FILE="$CACHE_DIR/tool-count-${SAFE_SID}"
COUNT=0
[[ -f "$COUNTER_FILE" ]] && COUNT=$(cat "$COUNTER_FILE")
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

if (( COUNT >= 75 )); then
    echo "0" > "$COUNTER_FILE"
    _nudge "SESSION CHECK-IN: 75+ tool calls. Run /borg-review to check progress. If this is a save point, run /borg-link-up and then start a fresh session: the checkpoint carries the work over, and a long session re-reads its whole history every turn."
fi

exit 0
