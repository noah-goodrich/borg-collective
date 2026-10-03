#!/usr/bin/env bats
# borg's window lookups accept a live window under EITHER form: the registry's `tmux_window` (the short
# name) or the project name (a window opened before short names existed). Covers `borg switch`, the
# reap overlay and `borg color`. Project names are invented.

load test_helper/setup

BORG="${BATS_TEST_DIRNAME}/../borg.zsh"

setup() {
    setup_temp_dirs
    setup_mock_bin
    export BORG_PATH_PREFIX="$MOCK_BIN"
    export BORG_TMUX_SESSION="wtest"
    export TRACE="${BATS_TEST_TMPDIR}/tmux-trace.log"
    : > "$TRACE"
    cat > "$MOCK_BIN/tmux" <<'MOCK'
#!/usr/bin/env bash
echo "tmux $*" >> "$TRACE"
case "$1" in
    has-session) exit 0 ;;
    list-windows) printf '%s\n' "${LIVE_WINDOWS:-}" ;;
    list-panes) echo "0 %1" ;;
    display-message) echo "mock-window" ;;
esac
exit 0
MOCK
    chmod +x "$MOCK_BIN/tmux"
}

_seed() {  # json
    printf '%s' "$1" > "$BORG_REGISTRY"
}

@test "switch: finds a live window under the short registry name" {
    _seed '{"projects":{"widget-factory":{"path":null,"source":"cli","tmux_window":"wf"}}}'
    export LIVE_WINDOWS="wf"
    run zsh "$BORG" switch widget-factory
    [ "$status" -eq 0 ]
    grep -q "select-window -t wtest:wf" "$TRACE"
}

@test "switch: finds a live LONG-named window when the registry holds the short name" {
    _seed '{"projects":{"widget-factory":{"path":null,"source":"cli","tmux_window":"wf"}}}'
    export LIVE_WINDOWS="widget-factory"
    run zsh "$BORG" switch widget-factory
    [ "$status" -eq 0 ]
    grep -q "select-window -t wtest:widget-factory" "$TRACE"
}

@test "switch: still clears a tmux_window equal to the session name" {
    _seed '{"projects":{"widget-factory":{"path":null,"source":"cli","tmux_window":"wtest"}}}'
    export LIVE_WINDOWS="wtest"
    run zsh "$BORG" switch widget-factory
    [[ "$output" == *"same as session name"* ]] || false
    [ "$(jq -r '.projects["widget-factory"].tmux_window' "$BORG_REGISTRY")" = "null" ]
}

@test "reap: a project whose SHORT-named window is live is not downgraded" {
    export BORG_REAP_STALE_HOURS=12
    _seed '{"projects":{"widget-factory":{"path":"/tmp/wf","status":"active","last_activity":"2020-01-01T00:00:00Z","tmux_window":"wf"}}}'
    export LIVE_WINDOWS="wf"
    run zsh -c "source '$BORG_HOME/lib/reaper.sh'; source '$BORG_HOME/lib/registry.zsh'; source '$BORG_HOME/lib/tmux.zsh'; cat '$BORG_REGISTRY' | borg_reap_overlay | jq -r '.projects[\"widget-factory\"].status'"
    [ "$output" = "active" ]
}

@test "reap: a project whose LONG-named window is live is not downgraded, and a dead one still is" {
    export BORG_REAP_STALE_HOURS=12
    _seed '{"projects":{"widget-factory":{"path":"/tmp/wf","status":"active","last_activity":"2020-01-01T00:00:00Z","tmux_window":"wf"}}}'
    local cmd="source '$BORG_HOME/lib/reaper.sh'; source '$BORG_HOME/lib/registry.zsh'; source '$BORG_HOME/lib/tmux.zsh'; cat '$BORG_REGISTRY' | borg_reap_overlay | jq -r '.projects[\"widget-factory\"].status'"
    export LIVE_WINDOWS="widget-factory"
    run zsh -c "$cmd"
    [ "$output" = "active" ]
    export LIVE_WINDOWS="unrelated"
    run zsh -c "$cmd"
    [ "$output" = "idle" ]
}

@test "color: targets the short-named live window" {
    _seed '{"projects":{"widget-factory":{"path":"/tmp/wf","tmux_window":"wf"}}}'
    export LIVE_WINDOWS="wf"
    run zsh "$BORG" color widget-factory green
    [ "$status" -eq 0 ]
    [[ "$output" == *"Applied to live tmux window."* ]] || false
    grep -q "^tmux set-option -t wtest:wf window-status-style" "$TRACE"
    ! grep -q "set-option.*widget-factory" "$TRACE"
}
