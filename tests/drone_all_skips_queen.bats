#!/usr/bin/env bats
# `--all` sweeps repository windows only. The Queen's window ("queen", or "orchestrator" in sessions started
# before the rename) and the "host" window are never touched by `drone fix --all` or `drone restart --all`.
# tmux is a stub on PATH that records every call; the live tmux server is never reached. Names invented.

load test_helper/setup

DRONE="${BATS_TEST_DIRNAME}/../drone.zsh"

setup() {
    setup_temp_dirs
    setup_mock_bin

    export TRACE="${BATS_TEST_TMPDIR}/trace.log"
    export WINDOWS="${BATS_TEST_TMPDIR}/windows"
    : > "$TRACE"
    printf '%s\n' queen orchestrator host alpha beta > "$WINDOWS"
    export BORG_TMUX_SESSION="wtest"
    export TMUX="/tmp/tmux-1000/default,1234,0"
    unset TMUX_PANE

    # Every window has a repository dir and two panes, so a window the command touches shows up in TRACE.
    cat > "$MOCK_BIN/tmux" <<'MOCK'
#!/usr/bin/env bash
echo "tmux $*" >> "$TRACE"
case "$1" in
    has-session) exit 0 ;;
    list-windows) cat "$WINDOWS" ;;
    list-panes) printf '%s\n' "0 %1" "50 %2" ;;
    show-option) mkdir -p "$BATS_TEST_TMPDIR/dir" && echo "$BATS_TEST_TMPDIR/dir" ;;
    display) echo "40" ;;
esac
exit 0
MOCK
    chmod +x "$MOCK_BIN/tmux"
}

# A bare `! cmd` line does not fail a bats test unless it is the last line, so each window gets its own check
# that returns non-zero when tmux was ever aimed at it.
untouched() { ! grep -q "wtest:$1" "$TRACE"; }

@test "fix --all restores the repository windows and never the queen, orchestrator or host" {
    run "$DRONE" fix --all
    [ "$status" -eq 0 ]
    grep -q 'tmux select-layout -t wtest:alpha ' "$TRACE"
    grep -q 'tmux select-layout -t wtest:beta ' "$TRACE"
    untouched queen
    untouched orchestrator
    untouched host
}

@test "restart --all visits the repository windows and never the queen, orchestrator or host" {
    run "$DRONE" restart --all
    [ "$status" -eq 0 ]
    printf '%s\n' "$output" | grep -qF 'alpha: no '
    printf '%s\n' "$output" | grep -qF 'beta: no '
    printf '%s\n' "$output" | grep -qF 'Restarted 2 repository(ies).'
    untouched queen
    untouched orchestrator
    untouched host
}

@test "naming the queen window explicitly is still honoured by fix" {
    run "$DRONE" fix queen
    [ "$status" -eq 0 ]
    grep -q 'tmux select-layout -t wtest:queen ' "$TRACE"
}
