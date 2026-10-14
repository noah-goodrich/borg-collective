#!/usr/bin/env bats
# Every hook that needs lib/borg-hooks.sh resolves it script-relative first (<hook dir>/../lib), the installed copy
# (~/.claude/lib) second, and never dies when neither exists. The four hooks that used to source the installed copy
# unguarded are the subjects: borg-notify.sh, borg-link-up.sh, borg-link-down.sh and notify.sh.
#
# Each case lays out a real <tree>/hooks + <tree>/lib pair under the test tmpdir, so "script-relative" is exercised by
# where the hook file physically sits, and controls the installed copy (setup_temp_dirs pre-populates it) per case.
# The library the hook ends up using is observed through its work (state.json written, osascript called), not
# supplied: only the library NOT meant to be chosen is a stub.

load test_helper/setup

REPO_ROOT="${BATS_TEST_DIRNAME}/.."

setup() {
    setup_temp_dirs
    BASH_BIN=/bin/bash
    [ -x "$BASH_BIN" ] || BASH_BIN=bash

    export TEST_CWD="${BATS_TEST_TMPDIR}/myrepo"
    mkdir -p "$TEST_CWD" "$BORG_DIR"
    printf '{"projects":{"myrepo":{"path":"%s","status":"idle","source":"cli"}}}\n' "$TEST_CWD" > "$BORG_REGISTRY"

    export MOCK_BIN="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$MOCK_BIN"
    export PATH="$MOCK_BIN:$PATH"

    TREE="${BATS_TEST_TMPDIR}/tree"
    mkdir -p "$TREE/hooks" "$TREE/lib"
    for h in borg-notify borg-link-up borg-link-down notify; do
        cp "$REPO_ROOT/hooks/$h.sh" "$TREE/hooks/$h.sh"
    done
}

_tree_has_lib() {
    cp "$REPO_ROOT/lib/borg-hooks.sh" "$REPO_ROOT/lib/reaper.sh" "$TREE/lib/"
}

_no_installed_lib() {
    rm -f "$BORG_TEST_HOME"/.claude/lib/*
}

# An installed lib that must LOSE to a script-relative one: it classifies every session as the Queen, which makes
# borg-notify.sh and borg-link-up.sh exit before writing state.
_stub_installed_lib() {
    rm -f "$BORG_TEST_HOME"/.claude/lib/*
    printf '_borg_session_mode() { printf orchestrator; }\n' > "$BORG_TEST_HOME/.claude/lib/borg-hooks.sh"
}

_notify_input() {
    printf '{"session_id":"s1","cwd":"%s","message":"needs you"}' "$TEST_CWD"
}

_state_status() {
    jq -r '.status // ""' "$(state_path_of "$TEST_CWD" "")" 2>/dev/null
}

# ── script-relative lib is used ──────────────────────────────────────────────────────────────────

@test "borg-notify: the script-relative lib does the work when no installed lib exists" {
    _tree_has_lib
    _no_installed_lib
    run "$BASH_BIN" "$TREE/hooks/borg-notify.sh" <<< "$(_notify_input)"
    [ "$status" -eq 0 ]
    [ "$(_state_status)" = "waiting" ]
}

@test "borg-notify: the script-relative lib wins over an installed one" {
    _tree_has_lib
    _stub_installed_lib
    run "$BASH_BIN" "$TREE/hooks/borg-notify.sh" <<< "$(_notify_input)"
    [ "$status" -eq 0 ]
    [ "$(_state_status)" = "waiting" ]
}

@test "borg-notify: the installed lib is the fallback when the tree has none" {
    _stub_installed_lib
    run "$BASH_BIN" "$TREE/hooks/borg-notify.sh" <<< "$(_notify_input)"
    [ "$status" -eq 0 ]
    [ -z "$(_state_status)" ]
}

@test "borg-link-up: the script-relative lib does the work when no installed lib exists" {
    _tree_has_lib
    _no_installed_lib
    run "$BASH_BIN" "$TREE/hooks/borg-link-up.sh" <<< "$(_notify_input)"
    [ "$status" -eq 0 ]
    [ "$(_state_status)" = "idle" ]
}

@test "borg-link-down: the script-relative lib does the work when no installed lib exists" {
    _tree_has_lib
    _no_installed_lib
    run "$BASH_BIN" "$TREE/hooks/borg-link-down.sh" <<< "$(_notify_input)"
    [ "$status" -eq 0 ]
    [ "$(_state_status)" = "active" ]
    printf '%s' "$output" | jq -e '.hookSpecificOutput.additionalContext | contains("QUEEN")' >/dev/null
}

# ── a missing lib never aborts ───────────────────────────────────────────────────────────────────

@test "borg-notify: no lib anywhere exits 0, silently, and writes nothing" {
    _no_installed_lib
    run "$BASH_BIN" "$TREE/hooks/borg-notify.sh" <<< "$(_notify_input)"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ -z "$(_state_status)" ]
}

@test "borg-link-up: no lib anywhere exits 0, silently, and writes nothing" {
    _no_installed_lib
    run "$BASH_BIN" "$TREE/hooks/borg-link-up.sh" <<< "$(_notify_input)"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ -z "$(_state_status)" ]
}

@test "borg-link-down: no lib anywhere exits 0 with no injection" {
    _no_installed_lib
    run "$BASH_BIN" "$TREE/hooks/borg-link-down.sh" <<< "$(_notify_input)"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ -z "$(_state_status)" ]
}

# lib/borg-hooks.sh sources reaper.sh unguarded; on bash 3.2 that failure is fatal to the SOURCING hook, so a half-installed
# lib (borg-hooks.sh without its sibling) must count as absent rather than be sourced.
@test "borg-notify: a lib without its reaper.sh sibling counts as absent and does not abort" {
    cp "$REPO_ROOT/lib/borg-hooks.sh" "$TREE/lib/"
    _no_installed_lib
    run "$BASH_BIN" "$TREE/hooks/borg-notify.sh" <<< "$(_notify_input)"
    [ "$status" -eq 0 ]
    [ -z "$(_state_status)" ]
}

@test "borg-notify: a half-installed script-relative lib falls back to a complete installed one" {
    cp "$REPO_ROOT/lib/borg-hooks.sh" "$TREE/lib/"
    cp "$REPO_ROOT/lib/borg-hooks.sh" "$REPO_ROOT/lib/reaper.sh" "$BORG_TEST_HOME/.claude/lib/"
    run "$BASH_BIN" "$TREE/hooks/borg-notify.sh" <<< "$(_notify_input)"
    [ "$status" -eq 0 ]
    [ "$(_state_status)" = "waiting" ]
}

# notify.sh: the banner needs the lib, the tmux bell does not.
_mock_notify_env() {
    [ -f /.dockerenv ] && skip "notify.sh exits early inside a container"
    printf '#!/bin/sh\necho "$@" >> "%s/osa.log"\n' "$BATS_TEST_TMPDIR" > "$MOCK_BIN/osascript"
    printf '#!/bin/sh\nprintf "%s/tty"\n' "$BATS_TEST_TMPDIR" > "$MOCK_BIN/tmux"
    chmod +x "$MOCK_BIN/osascript" "$MOCK_BIN/tmux"
    export TMUX=mock TMUX_PANE=%1
}

@test "notify: the script-relative lib posts the banner, and the bell still rings" {
    _mock_notify_env
    _tree_has_lib
    _no_installed_lib
    run "$BASH_BIN" "$TREE/hooks/notify.sh" <<< "$(_notify_input)"
    [ "$status" -eq 0 ]
    [ -s "$BATS_TEST_TMPDIR/osa.log" ]
    [ -s "$BATS_TEST_TMPDIR/tty" ]
}

@test "notify: no lib anywhere skips the banner but exits 0 and still rings the bell" {
    _mock_notify_env
    _no_installed_lib
    run "$BASH_BIN" "$TREE/hooks/notify.sh" <<< "$(_notify_input)"
    [ "$status" -eq 0 ]
    [ ! -e "$BATS_TEST_TMPDIR/osa.log" ]
    [ -s "$BATS_TEST_TMPDIR/tty" ]
}

# ── the plugin build still inlines the lib over the resolution block ─────────────────────────────

_build_plugin() {
    PLUGIN="${BATS_TEST_TMPDIR}/plugin"
    mkdir -p "$PLUGIN/.claude-plugin"
    echo '{"version": "0.1.0"}' > "$PLUGIN/.claude-plugin/plugin.json"
    PLUGIN_DIR_OVERRIDE="$PLUGIN" bash "$REPO_ROOT/scripts/build-plugin.sh" >/dev/null 2>&1
}

@test "build-plugin: built hooks carry the inlined functions and none of the resolution lines" {
    _build_plugin
    for h in notify borg-notify borg-link-up borg-link-down borg-plan-promote; do
        bash -n "$PLUGIN/hooks/$h.sh"
        grep -q '^_borg_session_mode()' "$PLUGIN/hooks/$h.sh"
        run grep -qE '_borg_lib|claude/lib|>>> borg-hooks|<<< borg-hooks' "$PLUGIN/hooks/$h.sh"
        [ "$status" -ne 0 ]
    done
}

@test "build-plugin: a built hook works with no lib anywhere" {
    _build_plugin
    printf '#!/bin/sh\nexit 0\n' > "$MOCK_BIN/borg"
    chmod +x "$MOCK_BIN/borg"
    _no_installed_lib
    run "$BASH_BIN" "$PLUGIN/hooks/borg-notify.sh" <<< "$(_notify_input)"
    [ "$status" -eq 0 ]
    [ "$(_state_status)" = "waiting" ]
}

@test "build-plugin: an opening marker with no closing one refuses to build" {
    local src="${BATS_TEST_TMPDIR}/srctree"
    mkdir -p "$src/scripts" "$src/lib" "$src/hooks"
    cp "$REPO_ROOT/scripts/build-plugin.sh" "$src/scripts/"
    cp "$REPO_ROOT/lib/borg-hooks.sh" "$REPO_ROOT/lib/reaper.sh" "$src/lib/"
    printf '#!/usr/bin/env bash\n# >>> borg-hooks.sh\nsource x\necho kept\n' > "$src/hooks/notify.sh"
    mkdir -p "${BATS_TEST_TMPDIR}/plugin2"
    PLUGIN_DIR_OVERRIDE="${BATS_TEST_TMPDIR}/plugin2" run bash "$src/scripts/build-plugin.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"no '# <<< borg-hooks.sh'"* ]]
    [ ! -e "${BATS_TEST_TMPDIR}/plugin2/hooks/notify.sh" ]
}
