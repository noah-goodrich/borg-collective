#!/usr/bin/env bash
# borg-notify.sh — Claude Code Notification hook
# Fires when Claude Code needs user input (session is waiting).
#
# Updates registry: status=waiting
# Fires macOS notification (augments notify.sh, does NOT replace it)
# Registered as a Notification hook in ~/.claude/settings.json alongside notify.sh

set -euo pipefail

BORG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/borg"
BORG_REGISTRY="$BORG_DIR/registry.json"

INPUT=$(cat /dev/stdin 2>/dev/null || true)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // ""' 2>/dev/null || echo "")
CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")

[[ -z "$CWD" ]] && exit 0

PROJECT=$(basename "$CWD")
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Update registry status=waiting if project is tracked
if [[ -f "$BORG_REGISTRY" ]]; then
    TMP="$BORG_REGISTRY.tmp.$$"
    jq \
        --arg p "$PROJECT" \
        --arg now "$NOW" \
        '
        if .projects | has($p) then
            .projects[$p].status = "waiting" |
            .projects[$p].last_activity = $now
        else .
        end
        ' "$BORG_REGISTRY" > "$TMP" && mv "$TMP" "$BORG_REGISTRY"
fi

exit 0
