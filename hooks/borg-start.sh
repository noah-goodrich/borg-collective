#!/usr/bin/env bash
# borg-start.sh — Claude Code SessionStart hook
# Fires when a Claude Code session begins.
#
# Updates registry: status=active, last_activity=now, claude_session_id=<id>
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

# Require registry to exist
[[ -f "$BORG_REGISTRY" ]] || exit 0

# Atomic registry update
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

exit 0
