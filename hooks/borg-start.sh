#!/usr/bin/env bash
# borg-start.sh — Claude Code SessionStart hook
# Fires when a Claude Code session begins.
#
# Updates registry: status=active, last_activity=now, claude_session_id=<id>
# Injects last session debrief as additionalContext if available.
# Registered as a SessionStart hook in ~/.claude/settings.json

set -euo pipefail

BORG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/borg"
BORG_REGISTRY="$BORG_DIR/registry.json"

INPUT=$(cat /dev/stdin 2>/dev/null || true)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || echo "")
CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")

[[ -z "$CWD" ]] && exit 0

PROJECT=$(basename "$CWD")
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Atomic registry update
if [[ -f "$BORG_REGISTRY" ]]; then
    TMP="$BORG_REGISTRY.tmp.$$"
    jq \
        --arg p "$PROJECT" \
        --arg sid "$SESSION_ID" \
        --arg now "$NOW" \
        '
        if .projects | has($p) then
            .projects[$p].status = "active" |
            .projects[$p].last_activity = $now |
            (if $sid != "" then .projects[$p].claude_session_id = $sid else . end)
        else .
        end
        ' "$BORG_REGISTRY" > "$TMP" && mv "$TMP" "$BORG_REGISTRY"
fi

# Build context from debrief + cairn knowledge
CONTEXT_PARTS=()

DEBRIEF_FILE="$BORG_DIR/debriefs/${PROJECT}.md"
if [[ -f "$DEBRIEF_FILE" ]]; then
    DEBRIEF=$(head -c 4000 "$DEBRIEF_FILE" 2>/dev/null || true)
    if [[ -n "$DEBRIEF" ]]; then
        CONTEXT_PARTS+=("Last session debrief for $PROJECT:

$DEBRIEF")
    fi
fi

if command -v cairn >/dev/null 2>&1; then
    CAIRN_OUT=$(timeout 5 cairn search "$PROJECT" --project "$PROJECT" --max 5 2>/dev/null || true)
    if [[ -n "$CAIRN_OUT" ]]; then
        CONTEXT_PARTS+=("Cairn knowledge for $PROJECT:

$CAIRN_OUT")
    fi
fi

if (( ${#CONTEXT_PARTS[@]} > 0 )); then
    FULL_CTX="${CONTEXT_PARTS[0]}"
    for _part in "${CONTEXT_PARTS[@]:1}"; do
        FULL_CTX="${FULL_CTX}

---

${_part}"
    done
    jq -n --arg ctx "$FULL_CTX" '{
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": $ctx
        }
    }'
fi

exit 0
