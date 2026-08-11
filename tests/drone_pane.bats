#!/usr/bin/env bats
# Tests for `drone pane <direction>` — direction→flags mapping, devcontainer-exec-aware pane
# creation, and error cases (invalid direction / not inside tmux).

load test_helper/setup

DRONE="${BATS_TEST_DIRNAME}/../drone.zsh"

setup() {
    setup_temp_dirs
    setup_mock_bin

    export TRACE="${BATS_TEST_TMPDIR}/trace.log"
    : > "$TRACE"

    # Mock tmux: logs every invocation, and returns canned answers for the calls
    # cmd_pane makes (display-message, split-window, show-option, send-keys).
    # PDIR (if exported) is what `show-option -v @project_dir` returns; unset -> empty.
    cat > "$MOCK_BIN/tmux" <<'EOF'
#!/usr/bin/env bash
echo "tmux $*" >> "$TRACE"
case "$1" in
    display-message)
        echo "mywindow" ;;
    split-window)
        echo "%1" ;;
    show-option)
        if [[ -n "${PDIR:-}" ]]; then
            echo "$PDIR"
        else
            exit 1
        fi
        ;;
    send-keys)
        exit 0 ;;
esac
exit 0
EOF
    chmod +x "$MOCK_BIN/tmux"

    # Mock docker so a devcontainer project dir doesn't need a real container.
    cat > "$MOCK_BIN/docker" <<'EOF'
#!/usr/bin/env bash
echo "docker $*" >> "$TRACE"
case "$1" in
    ps)
        echo "sample-devcontainer-1" ;;
    compose)
        shift
        case "$*" in
            *" ps "*|*" ps")
                echo "sample-devcontainer-1" ;;
        esac
        exit 0 ;;
    exec)
        echo "/bin/bash" ;;
esac
exit 0
EOF
    chmod +x "$MOCK_BIN/docker"

    export TMUX="/tmp/tmux-1000/default,1234,0"
}

_split_call() {
    grep '^tmux split-window' "$TRACE"
}

# ─── direction → flags mapping ─────────────────────────────────────────────────

@test "pane top splits -v -b" {
    run "$DRONE" pane top
    [ "$status" -eq 0 ]
    _split_call | grep -q -- '-v -b'
}

@test "pane bottom splits -v" {
    run "$DRONE" pane bottom
    [ "$status" -eq 0 ]
    _split_call | grep -q -- '-v'
    ! (_split_call | grep -q -- '-b')
}

@test "pane left splits -h -b" {
    run "$DRONE" pane left
    [ "$status" -eq 0 ]
    _split_call | grep -q -- '-h -b'
}

@test "pane right splits -h" {
    run "$DRONE" pane right
    [ "$status" -eq 0 ]
    _split_call | grep -q -- '-h'
    ! (_split_call | grep -q -- '-b')
}

# ─── error cases ────────────────────────────────────────────────────────────────

@test "pane with invalid direction errors non-zero" {
    run "$DRONE" pane sideways
    [ "$status" -ne 0 ]
    [[ "$output" == *"Invalid direction"* ]] || false
}

@test "pane with no direction errors non-zero" {
    run "$DRONE" pane
    [ "$status" -ne 0 ]
    [[ "$output" == *"Specify a direction"* ]] || false
}

@test "pane outside tmux errors non-zero" {
    unset TMUX
    run "$DRONE" pane right
    [ "$status" -ne 0 ]
    [[ "$output" == *"Not inside a tmux session"* ]] || false
}

# ─── devcontainer-aware pane creation ──────────────────────────────────────────

@test "pane in a devcontainer project execs into the container shell" {
    export PDIR="${BATS_TEST_TMPDIR}/devproj"
    mkdir -p "$PDIR/.devcontainer"
    touch "$PDIR/.devcontainer/docker-compose.yml"

    run "$DRONE" pane right
    [ "$status" -eq 0 ]
    grep -q "tmux send-keys -t %1 docker compose" "$TRACE"
}

@test "pane in a plain (non-devcontainer) project cds into the project dir" {
    export PDIR="${BATS_TEST_TMPDIR}/plainproj"
    mkdir -p "$PDIR"

    run "$DRONE" pane right
    [ "$status" -eq 0 ]
    grep -q "tmux send-keys -t %1 cd $PDIR" "$TRACE"
}
