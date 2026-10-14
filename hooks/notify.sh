#!/usr/bin/env bash
# notify.sh — alert when Claude finishes a turn and needs input
set -euo pipefail

# Inside a container the host's Notification Center isn't reachable; borg-notify.sh
# writes status=waiting to the bind-mounted registry and borg-notifyd pops on the host.
[[ -f /.dockerenv ]] && exit 0

# >>> borg-hooks.sh: script-relative first, installed copy second (build-plugin.sh inlines the lib over this block)
_borg_lib_dir="${BASH_SOURCE[0]%/*}"
[[ "$_borg_lib_dir" == "${BASH_SOURCE[0]}" ]] && _borg_lib_dir=.
_borg_lib="$_borg_lib_dir/../lib/borg-hooks.sh"
# The lib sources its reaper.sh sibling unguarded, and on bash 3.2 that failure kills the hook: usable = both files.
[[ -f "$_borg_lib" && -f "${_borg_lib%/*}/reaper.sh" ]] || _borg_lib="${HOME}/.claude/lib/borg-hooks.sh"
# shellcheck source=../lib/borg-hooks.sh
[[ -f "$_borg_lib" && -f "${_borg_lib%/*}/reaper.sh" ]] && source "$_borg_lib" 2>/dev/null || true
# <<< borg-hooks.sh

INPUT=$(cat /dev/stdin 2>/dev/null || true)
CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || true)
REPOSITORY=$(basename "${CWD:-$(pwd)}")

WINDOW="" PANE_TTY=""
if [[ -n "${TMUX:-}" && -n "${TMUX_PANE:-}" ]]; then
    WINDOW=$(tmux display-message -t "$TMUX_PANE" -p "#{window_name}" 2>/dev/null || true)
    PANE_TTY=$(tmux display-message -t "$TMUX_PANE" -p "#{pane_tty}" 2>/dev/null || true)
fi
SUBTITLE="${WINDOW:+$WINDOW — }$REPOSITORY"

# Without the lib there is no helper to post the banner, but the bell below needs nothing from it.
if declare -F _borg_osa_notify >/dev/null; then
    _borg_osa_notify "Claude Code" "$SUBTITLE" "Ready for input"
fi

# tmux visual bell — write directly to the pane's TTY so tmux sees it
[[ -n "$PANE_TTY" ]] && printf '\a' > "$PANE_TTY"

exit 0
