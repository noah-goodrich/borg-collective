#!/usr/bin/env zsh
# lib/tmux.zsh — tmux window listing and switching

# Configurable via BORG_TMUX_SESSION env var; defaults to "borg"
BORG_TMUX_SESSION="${BORG_TMUX_SESSION:-borg}"

borg_tmux_alive() {
    tmux has-session -t "$BORG_TMUX_SESSION" 2>/dev/null
}

borg_tmux_windows() {
    borg_tmux_alive || return 0
    tmux list-windows -t "$BORG_TMUX_SESSION" -F '#W' 2>/dev/null
}

borg_tmux_switch() {
    local name="$1"
    if ! borg_tmux_alive; then
        warn "tmux session '$BORG_TMUX_SESSION' not running"
        return 1
    fi
    tmux select-window -t "$BORG_TMUX_SESSION:$name" 2>/dev/null || {
        warn "no tmux window named '$name'"
        return 1
    }
    # Also switch the client to this session if we're in a different one
    tmux switch-client -t "$BORG_TMUX_SESSION" 2>/dev/null || true
}

borg_tmux_current_window() {
    tmux display-message -p '#W' 2>/dev/null || echo ""
}

borg_tmux_current_session() {
    tmux display-message -p '#S' 2>/dev/null || echo ""
}

borg_tmux_window_exists() {
    local name="$1"
    borg_tmux_windows | /usr/bin/grep -qx "$name"
}

# Return last activity timestamp (epoch seconds) for a window
borg_tmux_window_activity() {
    local name="$1"
    borg_tmux_alive || return 0
    tmux list-windows -t "$BORG_TMUX_SESSION" -F '#{window_name} #{window_activity}' 2>/dev/null \
        | /usr/bin/awk -v w="$name" '$1 == w {print $2}'
}
