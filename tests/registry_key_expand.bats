#!/usr/bin/env bats
# EXPAND phase of the registry file's top-level key rename (projects -> repositories): every shell and
# hook reader accepts either key, and the writers still write `projects`. The wire keys of
# `borg link --json` are a separate contract and are not touched here.

load test_helper/setup

setup() {
    setup_temp_dirs
    mkdir -p "$BORG_TEST_HOME/real"
    OLD='{"projects":{"alpha":{"path":"'"$BORG_TEST_HOME"'/real","tmux_window":"w1"},"beta":{"path":"/nowhere"}}}'
    NEW='{"repositories":{"alpha":{"path":"'"$BORG_TEST_HOME"'/real","tmux_window":"w1"},"beta":{"path":"/nowhere"}}}'
}

_use() {
    printf '%s\n' "$1" > "$BORG_REGISTRY"
}

@test "zsh reader: borg_registry_list names the same repositories for both shapes" {
    _use "$OLD"
    run run_zsh_fn registry borg_registry_list
    [ "$status" -eq 0 ]
    old_out="$output"
    _use "$NEW"
    run run_zsh_fn registry borg_registry_list
    [ "$status" -eq 0 ]
    [ "$output" = "$old_out" ]
    [ "$output" = "$(printf 'alpha\nbeta')" ]
}

@test "zsh reader: get and has agree across both shapes" {
    _use "$OLD"
    run run_zsh_fn registry borg_registry_get alpha
    old_get="$output"
    _use "$NEW"
    run run_zsh_fn registry borg_registry_get alpha
    [ "$output" = "$old_get" ]
    run run_zsh_fn registry borg_registry_has beta
    [ "$status" -eq 0 ]
    run run_zsh_fn registry borg_registry_has gamma
    [ "$status" -ne 0 ]
}

@test "zsh reader: the old shape is read byte-for-byte as before" {
    _use "$OLD"
    run run_zsh_fn registry borg_registry_read
    [ "$output" = "$OLD" ]
}

@test "zsh writer: a write against a new-shape file still writes projects" {
    _use "$NEW"
    run run_zsh_fn registry borg_registry_merge gamma '{"path":"/g"}'
    [ "$status" -eq 0 ]
    run jq -r 'has("projects"), has("repositories"), (.projects | keys | join(","))' "$BORG_REGISTRY"
    [ "$output" = "$(printf 'true\nfalse\nalpha,beta,gamma')" ]
}

@test "zsh reader: the path-containment helper sees both shapes" {
    for doc in "$OLD" "$NEW"; do
        _use "$doc"
        run zsh -c "source '$BORG_HOME/lib/registry.zsh'; BORG_REGISTRY='$BORG_REGISTRY'; jq -r \"\$BORG_REGISTRY_NORM_JQ | .projects[].path // empty\" '$BORG_REGISTRY'"
        [ "$status" -eq 0 ]
        [ "$output" = "$(printf '%s\n/nowhere' "$BORG_TEST_HOME/real")" ]
    done
}

@test "hook reader: _borg_resolve_proj_dir resolves the same directory for both shapes" {
    for doc in "$OLD" "$NEW"; do
        _use "$doc"
        run bash -c 'source "$1/lib/borg-hooks.sh"; _borg_resolve_proj_dir alpha /fallback' _ "$BORG_HOME"
        [ "$status" -eq 0 ]
        [ "$output" = "$BORG_TEST_HOME/real" ]
    done
}

@test "hook reader: _borg_proj_repo reads the entry's repo under both shapes" {
    OLD='{"projects":{"alpha":{"path":"/p","repo":"/r/.git"}}}'
    NEW='{"repositories":{"alpha":{"path":"/p","repo":"/r/.git"}}}'
    for doc in "$OLD" "$NEW"; do
        _use "$doc"
        run bash -c 'source "$1/lib/borg-hooks.sh"; _borg_proj_repo alpha /p; printf "%s" "${_REPO-unset}"' _ "$BORG_HOME"
        [ "$status" -eq 0 ]
        [ "$output" = "/r/.git" ]
    done
}

@test "hook reader: a stale installed lib without the helper degrades to the old key" {
    _use "$OLD"
    run bash -c 'source "$1/lib/borg-hooks.sh"; unset BORG_REGISTRY_NORM_JQ; _borg_resolve_proj_dir alpha /fallback' _ "$BORG_HOME"
    [ "$status" -eq 0 ]
    [ "$output" = "$BORG_TEST_HOME/real" ]
}

@test "notifyd reader: check fires for the same repository under both shapes" {
    export NOTIFY_LOG="$BATS_TEST_TMPDIR/notify.log"
    for key in projects repositories; do
        : > "$NOTIFY_LOG"
        export IDLE_DOC="{\"$key\":{\"alpha\":{\"status\":\"idle\",\"notify_origin\":\"container\"}}}"
        export WAITING_DOC="{\"$key\":{\"alpha\":{\"status\":\"waiting\",\"notify_origin\":\"container\"}}}"
        printf '%s\n' "$IDLE_DOC" > "$BORG_REGISTRY"
        run zsh -c '
            export BORG_NOTIFYD_LIB_ONLY=1
            source "$1/bin/borg-notifyd"
            source "$HOME/.claude/lib/borg-hooks.sh"
            _borg_osa_notify() { print -r -- "$*" >> "$NOTIFY_LOG" }
            check silent
            print -r -- "$WAITING_DOC" > "$BORG_REGISTRY"
            check
            true
        ' _ "$BORG_HOME"
        [ "$status" -eq 0 ]
        [ "$(wc -l < "$NOTIFY_LOG" | tr -d ' ')" = "1" ]
        grep -q 'Claude Code alpha Ready for input' "$NOTIFY_LOG"
    done
}

@test "drone reader: window lookup and registered check accept both shapes" {
    for doc in "$OLD" "$NEW"; do
        _use "$doc"
        run zsh -c '
            source "$1/lib/reaper.sh"
            BORG_DIR="$2"
            eval "$(sed -n "/^_drone_repository_for_window() {/,/^}/p;/^_drone_registered() {/,/^}/p" "$1/drone.zsh")"
            print -r -- "$(_drone_repository_for_window w1)"
            _drone_registered beta && print yes
            _drone_registered gamma || print no
        ' _ "$BORG_HOME" "$BORG_DIR"
        [ "$status" -eq 0 ]
        [ "$output" = "$(printf 'alpha\nyes\nno')" ]
    done
}

@test "registry CLI: migrate-key flips a temp registry, backs it up, and is idempotent" {
    _use "$OLD"
    run env PYTHONPATH="$BORG_HOME" python3 -m borg_core.registry.cli migrate-key --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"would rename"* ]]
    run jq -r 'has("projects")' "$BORG_REGISTRY"
    [ "$output" = "true" ]

    run env PYTHONPATH="$BORG_HOME" python3 -m borg_core.registry.cli migrate-key
    [ "$status" -eq 0 ]
    run jq -r 'has("repositories"), has("projects")' "$BORG_REGISTRY"
    [ "$output" = "$(printf 'true\nfalse')" ]
    [ "$(ls "$BORG_DIR" | grep -c 'registry.json.bak')" = "1" ]

    run env PYTHONPATH="$BORG_HOME" python3 -m borg_core.registry.cli migrate-key
    [[ "$output" == *"already uses"* ]]
    [ "$(ls "$BORG_DIR" | grep -c 'registry.json.bak')" = "1" ]

    run run_zsh_fn registry borg_registry_list
    [ "$output" = "$(printf 'alpha\nbeta')" ]
}
