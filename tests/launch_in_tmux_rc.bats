#!/usr/bin/env bats
# _borg_launch_in_tmux (in-tmux branch) must return the launched command's own status, whether or not it
# had a temp prompt file to clean up. The function is extracted from borg.zsh by name, so the test runs
# the shipped code and not a copy.

load test_helper/setup

BORG_SRC="${BATS_TEST_DIRNAME}/../borg.zsh"

setup() {
    setup_temp_dirs
    export TMPDIR="$BATS_TEST_TMPDIR"
    export BORG_ORCHESTRATOR_ROOT="$BATS_TEST_TMPDIR"
    export TMUX=fake
}

# Run the extracted function in zsh with the given args; prints nothing, exit status is the function's.
launch() {
    zsh -c '
        eval "$(sed -n "/^_borg_launch_in_tmux() {/,/^}/p" "$1")"
        shift
        _borg_launch_in_tmux "$@"
    ' zsh "$BORG_SRC" "$@"
}

@test "_borg_launch_in_tmux: success with no prompt file returns 0" {
    run launch true
    [ "$status" -eq 0 ]
}

@test "_borg_launch_in_tmux: failure with no prompt file returns non-zero" {
    run launch false
    [ "$status" -eq 1 ]
}

@test "_borg_launch_in_tmux: failure with a prompt file returns non-zero and removes the file" {
    local pf="$BATS_TEST_TMPDIR/borg-orchestrator-prompt.test"
    : > "$pf"
    run launch "$pf" false
    [ "$status" -eq 1 ]
    [ ! -e "$pf" ]
}

@test "_borg_launch_in_tmux: success with a prompt file returns 0 and removes the file" {
    local pf="$BATS_TEST_TMPDIR/borg-orchestrator-prompt.test"
    : > "$pf"
    run launch "$pf" true
    [ "$status" -eq 0 ]
    [ ! -e "$pf" ]
}
