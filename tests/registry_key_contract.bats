#!/usr/bin/env bats
# CONTRACT phase of the registry file's top-level key rename (projects -> repositories): the old key is no
# longer read anywhere. A file that still has only `projects` fails loudly (never reads as empty, never gets
# overwritten), `borg setup` migrates it, a new file is born with `repositories`, and doctor FAILs on it
# (that case lives in tests/doctor.bats beside doctor's other sandbox setup). The wire keys of
# `borg link --json` are a separate contract and are not touched here.

load test_helper/setup

setup() {
    setup_temp_dirs
    mkdir -p "$BORG_TEST_HOME/real" "$BORG_TEST_HOME/newrepo"
    OLD='{"projects":{"alpha":{"path":"'"$BORG_TEST_HOME"'/real","tmux_window":"w1"},"beta":{"path":"/nowhere"}}}'
    NEW='{"repositories":{"alpha":{"path":"'"$BORG_TEST_HOME"'/real","tmux_window":"w1"},"beta":{"path":"/nowhere"}}}'
}

_use() {
    printf '%s\n' "$1" > "$BORG_REGISTRY"
}

# Runs borg.zsh's real _borg_py and _borg_migrate_registry_key, the exact step cmd_setup calls.
_run_setup_step() {
    run zsh -c '
        warn() { print -r -- "WARN: $*"; }
        BORG_HOME="$1"; BORG_DIR="$2"; BORG_REGISTRY="$3"
        eval "$(sed -n "/^_borg_py() {/,/^}/p;/^_borg_migrate_registry_key() {/,/^}/p" "$1/borg.zsh")"
        _borg_migrate_registry_key
    ' _ "$BORG_HOME" "$BORG_DIR" "$BORG_REGISTRY"
}

_backups() {
    ls "$BORG_DIR" | grep -c 'registry.json.bak' || true
}

# ── the readers refuse the retired key ──────────────────────────────────────

@test "zsh reader: a projects-only file errors loudly naming migrate-key, and is not read as empty" {
    _use "$OLD"
    run run_zsh_fn registry borg_registry_read
    [ "$status" -ne 0 ]
    [[ "$output" == *"retired 'projects' key"* ]]
    [[ "$output" == *"migrate-key"* ]]
    [[ "$output" == *"borg setup"* ]]
    run run_zsh_fn registry borg_registry_list
    [[ "$output" != *alpha* ]]
    [[ "$output" == *"migrate-key"* ]]
}

@test "zsh writer: a write against a projects-only file changes nothing" {
    _use "$OLD"
    before="$(cat "$BORG_REGISTRY")"
    run run_zsh_fn registry borg_registry_merge gamma '{"path":"/g"}'
    [ "$status" -ne 0 ]
    run run_zsh_fn registry borg_registry_remove alpha
    [ "$status" -ne 0 ]
    [ "$(cat "$BORG_REGISTRY")" = "$before" ]
}

@test "borg CLI: a projects-only registry fails loudly for a reading command and is left untouched" {
    _use "$OLD"
    before="$(cat "$BORG_REGISTRY")"
    run zsh "$BORG_HOME/borg.zsh" link
    [ "$status" -ne 0 ]
    [[ "$output" == *"migrate-key"* ]]
    [[ "$output" != *"No repositories registered"* ]]
    run zsh "$BORG_HOME/borg.zsh" add "$BORG_TEST_HOME/newrepo"
    [ "$status" -ne 0 ]
    [ "$(cat "$BORG_REGISTRY")" = "$before" ]
}

@test "python reader: borg_core.registry.cli add refuses a projects-only file and leaves it untouched" {
    _use "$OLD"
    before="$(cat "$BORG_REGISTRY")"
    run env PYTHONPATH="$BORG_HOME" python3 -m borg_core.registry.cli add "$BORG_TEST_HOME/newrepo" --name gamma
    [ "$status" -ne 0 ]
    [[ "$output" == *"migrate-key"* ]]
    [ "$(cat "$BORG_REGISTRY")" = "$before" ]
}

@test "zsh reader: the new shape reads and a write round-trips repositories" {
    _use "$NEW"
    run run_zsh_fn registry borg_registry_list
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf 'alpha\nbeta')" ]
    run run_zsh_fn registry borg_registry_merge gamma '{"path":"/g"}'
    [ "$status" -eq 0 ]
    run jq -r 'has("projects"), has("repositories"), (.repositories | keys | join(","))' "$BORG_REGISTRY"
    [ "$output" = "$(printf 'false\ntrue\nalpha,beta,gamma')" ]
    run run_zsh_fn registry borg_registry_set alpha color '"red"'
    [ "$status" -eq 0 ]
    run jq -r 'has("projects"), .repositories.alpha.color' "$BORG_REGISTRY"
    [ "$output" = "$(printf 'false\nred')" ]
    run run_zsh_fn registry borg_registry_remove gamma
    run jq -r 'has("projects"), (.repositories | keys | join(","))' "$BORG_REGISTRY"
    [ "$output" = "$(printf 'false\nalpha,beta')" ]
}

# ── a new file is born with repositories ───────────────────────────────────────

@test "zsh writer: a brand-new registry is created with repositories" {
    /bin/rm -f "$BORG_REGISTRY"
    run run_zsh_fn registry borg_registry_merge gamma '{"path":"/g"}'
    [ "$status" -eq 0 ]
    run jq -r 'has("projects"), has("repositories")' "$BORG_REGISTRY"
    [ "$output" = "$(printf 'false\ntrue')" ]
}

@test "python writer: a brand-new registry is created with repositories" {
    /bin/rm -f "$BORG_REGISTRY"
    run env PYTHONPATH="$BORG_HOME" python3 -m borg_core.registry.cli add "$BORG_TEST_HOME/newrepo" --name gamma
    [ "$status" -eq 0 ]
    run jq -r 'has("projects"), has("repositories"), (.repositories | keys | join(","))' "$BORG_REGISTRY"
    [ "$output" = "$(printf 'false\ntrue\ngamma')" ]
}

# ── borg setup migrates ───────────────────────────────────────────────────────

@test "setup: a projects-only file comes out as repositories, with a backup and the same entries" {
    _use "$OLD"
    original="$(cat "$BORG_REGISTRY")"
    _run_setup_step
    [ "$status" -eq 0 ]
    [[ "$output" == *"renamed 'projects' to 'repositories'"* ]]
    run jq -S -c '.repositories' "$BORG_REGISTRY"
    expected="$(printf '%s' "$OLD" | jq -S -c '.projects')"
    [ "$output" = "$expected" ]
    run jq -r 'has("projects")' "$BORG_REGISTRY"
    [ "$output" = "false" ]
    [ "$(_backups)" = "1" ]
    [ "$(cat "$BORG_DIR"/registry.json.bak.*)" = "$original" ]
}

@test "setup: a second run is a no-op (no rewrite, no second backup)" {
    _use "$OLD"
    _run_setup_step
    migrated="$(cat "$BORG_REGISTRY")"
    _run_setup_step
    [ "$status" -eq 0 ]
    [[ "$output" == *"already uses 'repositories'"* ]]
    [ "$(cat "$BORG_REGISTRY")" = "$migrated" ]
    [ "$(_backups)" = "1" ]
}

@test "setup: a registry already on repositories is untouched and makes no backup" {
    _use "$NEW"
    _run_setup_step
    [ "$status" -eq 0 ]
    [ "$(_backups)" = "0" ]
}

@test "setup: with no registry the step creates nothing" {
    /bin/rm -f "$BORG_REGISTRY"
    _run_setup_step
    [ "$status" -eq 0 ]
    [ ! -e "$BORG_REGISTRY" ]
}

@test "setup: cmd_setup runs the migration step before anything reads the registry" {
    run sed -n '/^cmd_setup() {/,/^}/p' "$BORG_HOME/borg.zsh"
    first_call="$(printf '%s\n' "$output" | grep -n '_borg_migrate_registry_key' | head -1 | cut -d: -f1)"
    [ -n "$first_call" ]
    [ "$first_call" -le 12 ]
}

@test "setup then read: a projects-only file is readable again after the step" {
    _use "$OLD"
    run run_zsh_fn registry borg_registry_read
    [ "$status" -ne 0 ]
    _run_setup_step
    run run_zsh_fn registry borg_registry_list
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf 'alpha\nbeta')" ]
}

# ── migrate then write ───────────────────────────────────────────────────────

@test "migrate then write: migrate-key, borg add and a hook flip leave repositories with the same entries" {
    export TEST_CWD="$BORG_TEST_HOME/real"
    _use "$OLD"
    run env PYTHONPATH="$BORG_HOME" python3 -m borg_core.registry.cli migrate-key
    [ "$status" -eq 0 ]
    run env PYTHONPATH="$BORG_HOME" python3 -m borg_core.registry.cli add "$BORG_TEST_HOME/newrepo" --name gamma
    [ "$status" -eq 0 ]
    run run_zsh_fn registry borg_registry_set beta color '"blue"'
    [ "$status" -eq 0 ]
    start_in="$(printf '{"session_id":"sess-abc","cwd":"%s"}' "$TEST_CWD")"
    run bash -c 'bash "$1" <<< "$2" >/dev/null; true' _ "$BORG_HOME/hooks/borg-link-down.sh" "$start_in"
    run jq -r 'has("projects"), has("repositories"), (.repositories | keys | join(",")), .repositories.alpha.tmux_window, .repositories.beta.color' "$BORG_REGISTRY"
    [ "$output" = "$(printf 'false\ntrue\nalpha,beta,gamma\nw1\nblue')" ]
}

@test "hooks: a status flip against a repositories registry leaves repositories in place" {
    export TEST_CWD="$BORG_TEST_HOME/real"
    printf '{"repositories":{"alpha":{"path":"%s","status":"idle"}}}\n' "$TEST_CWD" > "$BORG_REGISTRY"
    start_in="$(printf '{"session_id":"sess-abc","cwd":"%s"}' "$TEST_CWD")"
    stop_in="$(printf '{"session_id":"sess-abc","cwd":"%s","transcript_path":"/nonexistent"}' "$TEST_CWD")"
    run bash -c 'bash "$1" <<< "$2" >/dev/null; bash "$3" <<< "$4" >/dev/null; true' _ \
        "$BORG_HOME/hooks/borg-link-down.sh" "$start_in" "$BORG_HOME/hooks/borg-link-up.sh" "$stop_in"
    run jq -r 'has("projects"), has("repositories"), (.repositories | keys | join(","))' "$BORG_REGISTRY"
    [ "$output" = "$(printf 'false\ntrue\nalpha')" ]
}

# ── the direct-file readers read repositories ──────────────────────────────────

@test "hook reader: _borg_resolve_proj_dir and _borg_proj_repo read repositories" {
    _use "$NEW"
    run bash -c 'source "$1/lib/borg-hooks.sh"; _borg_resolve_proj_dir alpha /fallback' _ "$BORG_HOME"
    [ "$status" -eq 0 ]
    [ "$output" = "$BORG_TEST_HOME/real" ]
    _use '{"repositories":{"alpha":{"path":"/p","repo":"/r/.git"}}}'
    run bash -c 'source "$1/lib/borg-hooks.sh"; _borg_proj_repo alpha /p; printf "%s" "${_REPO-unset}"' _ "$BORG_HOME"
    [ "$status" -eq 0 ]
    [ "$output" = "/r/.git" ]
}

@test "notifyd reader: check fires for a repositories registry" {
    export NOTIFY_LOG="$BATS_TEST_TMPDIR/notify.log"
    : > "$NOTIFY_LOG"
    export IDLE_DOC='{"repositories":{"alpha":{"status":"idle","notify_origin":"container"}}}'
    export WAITING_DOC='{"repositories":{"alpha":{"status":"waiting","notify_origin":"container"}}}'
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
}

@test "drone reader: window lookup and registered check read repositories" {
    _use "$NEW"
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
}

@test "drone CLI: a projects-only registry fails loudly before any command runs" {
    _use "$OLD"
    run zsh "$BORG_HOME/drone.zsh" link
    [ "$status" -ne 0 ]
    [[ "$output" == *"migrate-key"* ]]
}

@test "path-containment helper: borg_scan_path_should_skip sees a repositories registry" {
    _use "$NEW"
    mkdir -p "$BORG_TEST_HOME/real/sub"
    run run_zsh_fn registry borg_scan_path_should_skip "$BORG_TEST_HOME/real/sub"
    [ "$status" -eq 0 ]
    run run_zsh_fn registry borg_scan_path_should_skip "$BORG_TEST_HOME/newrepo"
    [ "$status" -eq 1 ]
}

# ── migrate-key itself ───────────────────────────────────────────────────────

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
    [ "$(_backups)" = "1" ]

    run env PYTHONPATH="$BORG_HOME" python3 -m borg_core.registry.cli migrate-key
    [[ "$output" == *"already uses"* ]]
    [ "$(_backups)" = "1" ]

    run run_zsh_fn registry borg_registry_list
    [ "$output" = "$(printf 'alpha\nbeta')" ]
}
