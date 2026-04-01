#!/usr/bin/env bash
# notify.sh — alert when Claude finishes a turn and needs input
set -euo pipefail

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

# macOS notification + sound (backgrounded to avoid blocking Claude's turn transition)
osascript -e "display notification \"Ready for input\" with title \"Claude Code\" subtitle \"$SUBTITLE\"" 2>/dev/null || true
afplay /System/Library/Sounds/Glass.aiff 2>/dev/null &

# tmux visual bell — write directly to the pane's TTY so tmux sees it
[[ -n "$PANE_TTY" ]] && printf '\a' > "$PANE_TTY"

exit 0
