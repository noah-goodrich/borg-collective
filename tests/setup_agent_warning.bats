#!/usr/bin/env bats
# `borg setup` warns when a shipped launchd plist is not loaded, and never installs one (issue #424).
# launchctl is a stub on PATH: the real one would report this machine's agents, not the case under test.

load test_helper/setup

setup() {
    setup_temp_dirs
    export FAKE_HOME_SRC="${BATS_TEST_TMPDIR}/src"
    export STUB_BIN="${BATS_TEST_TMPDIR}/stubbin"
    export LOADED_FILE="${BATS_TEST_TMPDIR}/loaded"
    mkdir -p "$FAKE_HOME_SRC/launchd" "$STUB_BIN"
    : > "$FAKE_HOME_SRC/launchd/borg.notifyd.plist"
    : > "$FAKE_HOME_SRC/launchd/borg.resume-watch.plist"
    : > "$FAKE_HOME_SRC/launchd/borg.reap.plist"
    printf '#!/bin/sh\n[ "$1" = list ] || exit 2\ngrep -qx "$2" "$LOADED_FILE"\n' > "$STUB_BIN/launchctl"
    chmod +x "$STUB_BIN/launchctl"
    unset LAUNCHD_LABEL_PREFIX
}

_warn() {
    PATH="$STUB_BIN:$PATH" run zsh -c "
        source '$BORG_HOME/lib/launchd-label.zsh'
        source '$BORG_HOME/lib/launchd-agents.zsh'
        warn() { print -r -- \"WARN: \$*\"; }
        BORG_HOME='$FAKE_HOME_SRC'
        _borg_warn_unloaded_agents
    "
}

@test "setup warning: names the agents that are not loaded, in one line" {
    printf 'borg.notifyd\nborg.reap\n' > "$LOADED_FILE"
    _warn
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 1 ]
    [[ "$output" == *"launchd agents not loaded: resume-watch."* ]] || false
    [[ "$output" == *"./install.sh"* ]] || false
}

@test "setup warning: resolves labels through the prefix" {
    printf 'acme.borg.notifyd\nacme.borg.reap\n' > "$LOADED_FILE"
    LAUNCHD_LABEL_PREFIX=acme _warn
    [[ "$output" == *"not loaded: resume-watch."* ]] || false
    printf 'borg.notifyd\nborg.reap\n' > "$LOADED_FILE"
    LAUNCHD_LABEL_PREFIX=acme _warn
    [[ "$output" == *"not loaded: notifyd, reap, resume-watch."* ]] || false
}

@test "setup warning: silent when every shipped agent is loaded" {
    printf 'borg.notifyd\nborg.resume-watch\nborg.reap\n' > "$LOADED_FILE"
    _warn
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "setup warning: silent when launchctl is not on PATH" {
    rm "$STUB_BIN/launchctl"
    run zsh -c "
        source '$BORG_HOME/lib/launchd-label.zsh'
        source '$BORG_HOME/lib/launchd-agents.zsh'
        warn() { print -r -- \"WARN: \$*\"; }
        BORG_HOME='$FAKE_HOME_SRC'
        PATH='$STUB_BIN'
        _borg_warn_unloaded_agents
    "
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}
