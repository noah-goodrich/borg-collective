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

borg_tmux_bottom_pane() {
    local session="${1:-$BORG_TMUX_SESSION}" wname="$2"
    tmux list-panes -t "$session:$wname" -F '#{pane_top} #{pane_id}' 2>/dev/null \
        | sort -rn | head -1 | awk '{print $2}'
}

# The pane to focus after a window switch: the one running claude, else cortex, else the bottom pane. Panes
# sitting side by side share a pane_top, so the fallback breaks ties on the LOWEST pane_index, never on the
# pane id string.
borg_tmux_agent_pane() {
    local session="${1:-$BORG_TMUX_SESSION}" wname="$2"
    tmux list-panes -t "$session:$wname" \
        -F '#{pane_top} #{pane_index} #{pane_id} #{pane_current_command}' 2>/dev/null \
        | awk '
            $4 == "claude" && !c { c = $3 }
            $4 == "cortex" && !x { x = $3 }
            !b || $1 > bt || ($1 == bt && $2 < bi) { b = $3; bt = $1; bi = $2 }
            END { print (c ? c : (x ? x : b)) }'
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
    # Focus the agent pane (claude, else cortex, else the bottom pane)
    local agent_pane
    agent_pane=$(borg_tmux_agent_pane "$BORG_TMUX_SESSION" "$name") || true
    [[ -n "$agent_pane" ]] && tmux select-pane -t "$agent_pane" 2>/dev/null || true
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
    # -F: a window name is data, never a pattern. See lib/registry.zsh's reap overlay for the full
    # rationale — without it, `troth.site` matches a live `troth-site`.
    borg_tmux_windows | /usr/bin/grep -qxF "$name"
}

# The LIVE tmux window for a project under EITHER form: the registry's short name ($2, optional) or
# the project name (windows opened before short names existed). Prints it and returns 0; returns 1
# when neither is live. Short name wins when both are live. Python twin: link.core.window_is_live.
borg_tmux_find_window() {
    local project="$1" short="${2:-}"
    if [[ -n "$short" && "$short" != "null" ]] && borg_tmux_window_exists "$short"; then
        print -r -- "$short"
    elif borg_tmux_window_exists "$project"; then
        print -r -- "$project"
    else
        return 1
    fi
}

# Return last activity timestamp (epoch seconds) for a window
borg_tmux_window_activity() {
    local name="$1"
    borg_tmux_alive || return 0
    tmux list-windows -t "$BORG_TMUX_SESSION" -F '#{window_name} #{window_activity}' 2>/dev/null \
        | /usr/bin/awk -v w="$name" '$1 == w {print $2}'
}
