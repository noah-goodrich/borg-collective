#!/usr/bin/env bash
# notify.sh — alert when Claude finishes a turn and needs input
set -euo pipefail

# Inside a container terminal-notifier is unavailable; registry write in borg-notify.sh
# handles the host-side notification via borg-notifyd. Exit cleanly so the hook doesn't error.
[[ -f /.dockerenv ]] && exit 0

INPUT=$(cat /dev/stdin 2>/dev/null || true)
CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || true)
PROJECT=$(basename "${CWD:-$(pwd)}")

# Resolve tmux window name and pane TTY for notification context + visual bell
WINDOW="" PANE_TTY=""
if [[ -n "${TMUX:-}" && -n "${TMUX_PANE:-}" ]]; then
    WINDOW=$(tmux display-message -t "$TMUX_PANE" -p "#{window_name}" 2>/dev/null || true)
    PANE_TTY=$(tmux display-message -t "$TMUX_PANE" -p "#{pane_tty}" 2>/dev/null || true)
fi
SUBTITLE="${WINDOW:+$WINDOW — }$PROJECT"

# macOS notification — clicking activates Ghostty and switches to the right tmux window/pane
terminal-notifier \
    -title "Claude Code" \
    -subtitle "$SUBTITLE" \
    -message "Ready for input" \
    -sound Glass \
    -activate com.mitchellh.ghostty \
    -execute "$HOME/.claude/hooks/notify-focus.sh '$WINDOW'" \
    2>/dev/null || true

# tmux visual bell — write directly to the pane's TTY so tmux sees it
[[ -n "$PANE_TTY" ]] && printf '\a' > "$PANE_TTY"

exit 0
