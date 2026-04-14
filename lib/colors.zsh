#!/usr/bin/env zsh
# lib/colors.zsh — project tmux window color helpers

_BORG_COLOR_PALETTE=(cyan green yellow magenta blue red white)

# Return the tmux color for a project (registry → hash fallback).
_borg_project_color() {
    local project="$1" color
    color=$(borg_registry_read | jq -r --arg p "$project" '.projects[$p].color // empty' 2>/dev/null)
    if [[ -z "$color" ]]; then
        local hash=0 c
        for c in ${(s::)project}; do hash=$(( (hash * 31 + #c) % ${#_BORG_COLOR_PALETTE} )); done
        color="${_BORG_COLOR_PALETTE[$((hash + 1))]}"
    fi
    echo "$color"
}

# Apply a color to a named window in the borg tmux session.
_borg_apply_window_color() {
    local window="$1" color="$2"
    tmux set-option -t "$BORG_TMUX_SESSION:$window" window-status-style "fg=$color" 2>/dev/null || true
    tmux set-option -t "$BORG_TMUX_SESSION:$window" window-status-current-style "fg=$color,bold" 2>/dev/null || true
}
