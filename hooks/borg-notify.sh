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

# >>> borg-hooks.sh: script-relative first, installed copy second (build-plugin.sh inlines the lib over this block)
_borg_lib_dir="${BASH_SOURCE[0]%/*}"
[[ "$_borg_lib_dir" == "${BASH_SOURCE[0]}" ]] && _borg_lib_dir=.
_borg_lib="$_borg_lib_dir/../lib/borg-hooks.sh"
# The lib sources its reaper.sh sibling unguarded, and on bash 3.2 that failure kills the hook: usable = both files.
[[ -f "$_borg_lib" && -f "${_borg_lib%/*}/reaper.sh" ]] || _borg_lib="${HOME}/.claude/lib/borg-hooks.sh"
# shellcheck source=../lib/borg-hooks.sh
[[ -f "$_borg_lib" && -f "${_borg_lib%/*}/reaper.sh" ]] && source "$_borg_lib" 2>/dev/null || true
# <<< borg-hooks.sh
# Fail open: every write below goes through the lib's state helpers, so without it there is nothing to do.
declare -F _borg_session_mode >/dev/null || exit 0

# Orchestrator-mode sessions do not flip status=waiting on any repository.
if [[ "$(_borg_session_mode "$CWD")" == "orchestrator" ]]; then
    exit 0
fi

REPOSITORY=$(_borg_find_repository "$CWD")
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Origin tag lets borg-notifyd suppress its own popup when notify.sh already fired on the host.
# Container sessions have no local terminal-notifier, so they rely on the daemon to pop on the host.
ORIGIN=host
_borg_is_container && ORIGIN=container

PROJ_DIR=$(_borg_resolve_proj_dir "$REPOSITORY" "$CWD")

# Write status=waiting + notification context to state.json.
_borg_proj_repo "$REPOSITORY" "$PROJ_DIR"
_cur_state=$(_borg_state_read "$PROJ_DIR" ${_REPO+"$_REPO"})
_new_state=$(printf '%s' "$_cur_state" | jq \
    --arg now "$NOW" \
    --arg msg "$MESSAGE" \
    --arg origin "$ORIGIN" \
    '.status = "waiting" | .last_activity = $now | .notify_origin = $origin |
     (if $msg != "" then .waiting_reason = $msg else . end)')
_borg_state_write "$PROJ_DIR" "$_new_state" ${_REPO+"$_REPO"} || true

exit 0
