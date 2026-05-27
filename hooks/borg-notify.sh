#!/usr/bin/env bash
# borg-notify.sh — Claude Code Notification hook
# Fires when Claude Code needs user input (session is waiting).
#
# Updates state.json: status=waiting
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

# Orchestrator-mode sessions do not flip status=waiting on any project.
if [[ "$(_borg_session_mode "$CWD")" == "orchestrator" ]]; then
    exit 0
fi

PROJECT=$(_borg_find_project "$CWD")
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Origin tag lets borg-notifyd suppress its own popup when notify.sh already fired on the host.
# Container sessions have no local terminal-notifier, so they rely on the daemon to pop on the host.
ORIGIN=host
_borg_is_container && ORIGIN=container

PROJ_DIR=$(_borg_resolve_proj_dir "$PROJECT" "$CWD")

# Write status=waiting + notification context to state.json.
_cur_state=$(_borg_state_read "$PROJ_DIR")
_new_state=$(printf '%s' "$_cur_state" | jq \
    --arg now "$NOW" \
    --arg msg "$MESSAGE" \
    --arg origin "$ORIGIN" \
    '.status = "waiting" | .last_activity = $now | .notify_origin = $origin |
     (if $msg != "" then .waiting_reason = $msg else . end)')
_borg_state_write "$PROJ_DIR" "$_new_state" || true

exit 0
