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
MESSAGE=$(echo "$INPUT" | jq -r '.message // ""' 2>/dev/null || echo "")

[[ -z "$CWD" ]] && exit 0

# shellcheck source=../lib/borg-hooks.sh
source "${HOME}/.claude/lib/borg-hooks.sh"

PROJECT=$(basename "$CWD")
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Origin tag lets borg-notifyd suppress its own popup when notify.sh already fired on the host.
# Container sessions have no local terminal-notifier, so they rely on the daemon to pop on the host.
ORIGIN=host
_borg_is_container && ORIGIN=container

# Update registry: status=waiting + capture notification message as waiting_reason
if [[ -f "$BORG_REGISTRY" ]]; then
    TMP="$BORG_REGISTRY.tmp.$$"
    jq \
        --arg p "$PROJECT" \
        --arg now "$NOW" \
        --arg msg "$MESSAGE" \
        --arg origin "$ORIGIN" \
        '
        if .projects | has($p) then
            .projects[$p].status = "waiting" |
            .projects[$p].last_activity = $now |
            .projects[$p].notify_origin = $origin |
            (if $msg != "" then .projects[$p].waiting_reason = $msg else . end)
        else .
        end
        ' "$BORG_REGISTRY" | _borg_strip_ctl > "$TMP" && mv "$TMP" "$BORG_REGISTRY"
fi

exit 0
