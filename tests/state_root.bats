#!/usr/bin/env bats
# The machine-local state root, one resolver per shell (Python is pinned in borg_core/test_paths.py):
#
#   root = ${XDG_STATE_HOME:-$HOME/.local/state}/borg      (blank XDG_STATE_HOME == unset)
#
# Every case UNSETS XDG_STATE_HOME and derives the default from the sandboxed HOME, so the value
# under test is never pre-supplied by the harness. The set/blank cases set it deliberately.

load test_helper/setup

STATE_LIB_ZSH="${BATS_TEST_DIRNAME}/../lib/state-root.zsh"
STATE_LIB_BASH="${BATS_TEST_DIRNAME}/../lib/borg-hooks.sh"

setup() {
    setup_temp_dirs
    unset XDG_STATE_HOME
}

_zsh() { zsh -c "source '$STATE_LIB_ZSH' && _borg_state_root"; }
_bash() { bash -c "source '$STATE_LIB_BASH' && _borg_state_root"; }

@test "zsh resolver: unset XDG_STATE_HOME derives from HOME" {
    run _zsh
    [ "$status" -eq 0 ]
    [ "$output" = "$HOME/.local/state/borg" ]
}

@test "zsh resolver: XDG_STATE_HOME wins" {
    XDG_STATE_HOME="$BATS_TEST_TMPDIR/xdg" run _zsh
    [ "$output" = "$BATS_TEST_TMPDIR/xdg/borg" ]
}

@test "zsh resolver: blank XDG_STATE_HOME is treated as unset" {
    XDG_STATE_HOME="" run _zsh
    [ "$output" = "$HOME/.local/state/borg" ]
}

@test "bash resolver: unset XDG_STATE_HOME derives from HOME" {
    run _bash
    [ "$status" -eq 0 ]
    [ "$output" = "$HOME/.local/state/borg" ]
}

@test "bash resolver: XDG_STATE_HOME wins" {
    XDG_STATE_HOME="$BATS_TEST_TMPDIR/xdg" run _bash
    [ "$output" = "$BATS_TEST_TMPDIR/xdg/borg" ]
}

@test "bash resolver: blank XDG_STATE_HOME is treated as unset" {
    XDG_STATE_HOME="" run _bash
    [ "$output" = "$HOME/.local/state/borg" ]
}
