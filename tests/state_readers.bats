#!/usr/bin/env bats
# AC5 step b (expand, readers only): every reader of a project's state.json reads the per-project
# state-root path first, else the legacy <dir>/.borg/state.json. Writers still write the legacy path
# (step c), so every case here seeds the files directly.
#
# Per reader family: legacy-only is read; both present -> the new one wins. Plus the registry-`repo`
# fast path must name the same file as the forking resolver (cross-checked against Python).
#
# HOME and every XDG dir are sandboxed by setup_temp_dirs; the state root is derived from
# XDG_STATE_HOME, so no case can touch the real machine.

load test_helper/setup

ROOT="${BATS_TEST_DIRNAME}/.."
START="$ROOT/hooks/borg-link-down.sh"
STOP="$ROOT/hooks/borg-link-up.sh"
NOTIFY="$ROOT/hooks/borg-notify.sh"

setup() {
    setup_temp_dirs
    PROJ="$BATS_TEST_TMPDIR/proj"
    mkdir -p "$PROJ"
    git -C "$PROJ" init -q
    git -C "$PROJ" commit -q --allow-empty -m x
    COMMON="$(git -C "$PROJ" rev-parse --path-format=absolute --git-common-dir)"
    mkdir -p "$BORG_DIR"
    printf '{"projects":{"proj":{"path":"%s","repo":"%s","status":"idle","source":"cli"}}}\n' "$PROJ" "$COMMON" \
        > "$BORG_REGISTRY"
}

_new_path() { bash -c 'source "$1/lib/borg-hooks.sh" && _borg_project_state_file "$2"' _ "$ROOT" "$PROJ"; }
_legacy() { mkdir -p "$PROJ/.borg" && printf '%s\n' "$1" > "$PROJ/.borg/state.json"; }
_new() { mkdir -p "$(dirname "$(_new_path)")" && printf '%s\n' "$1" > "$(_new_path)"; }

# ── bash: _borg_state_read_path / _borg_state_read ──────────────────────────

_bash_read() { bash -c 'source "$1/lib/borg-hooks.sh" && _borg_state_read "$2" ${3+"$3"}' _ "$ROOT" "$PROJ" "$@"; }

@test "bash read: neither file present yields {}" {
    run _bash_read
    [ "$status" -eq 0 ]
    [ "$(printf '%s' "$output" | jq -c .)" = "{}" ]
}

@test "bash read: legacy-only is read" {
    _legacy '{"status":"legacy"}'
    [ "$(_bash_read | jq -r .status)" = "legacy" ]
}

@test "bash read: both present, the new path wins" {
    _legacy '{"status":"legacy"}'
    _new '{"status":"new"}'
    [ "$(_bash_read | jq -r .status)" = "new" ]
}

@test "bash read: new-only is read" {
    _new '{"status":"new"}'
    [ "$(_bash_read | jq -r .status)" = "new" ]
}

@test "bash read: the registry-repo fast path finds the same file as the forking path" {
    _new '{"status":"new"}'
    _legacy '{"status":"legacy"}'
    [ "$(_bash_read "$COMMON" | jq -r .status)" = "new" ]
}

@test "bash read: a null registry repo is a path-only key, so it does NOT find the git-keyed file" {
    _new '{"status":"new"}'
    _legacy '{"status":"legacy"}'
    [ "$(_bash_read "" | jq -r .status)" = "legacy" ]
}

# ── fast path == forking path, across all three languages ───────────────────

@test "repo fast path names the same file as the forking resolver in bash, zsh and python" {
    forked="$(_new_path)"
    fast_b="$(bash -c 'source "$1/lib/borg-hooks.sh" && _borg_project_state_file "$2" "$3"' _ "$ROOT" "$PROJ" "$COMMON")"
    fast_z="$(zsh -c 'source "$1/lib/state-root.zsh" && _borg_project_state_file "$2" "$3"' _ "$ROOT" "$PROJ" "$COMMON")"
    fast_p="$(PYTHONPATH="$ROOT" python3 -c 'import sys; from borg_core.paths import project_state_file as f; print(f(sys.argv[1], sys.argv[2]))' "$PROJ" "$COMMON")"
    [ "$forked" = "$fast_b" ]
    [ "$forked" = "$fast_z" ]
    [ "$forked" = "$fast_p" ]
}

@test "a null repo is the path-only key in all three languages, and equals the non-git resolver" {
    plain="$BATS_TEST_TMPDIR/plain"
    mkdir -p "$plain"
    forked="$(bash -c 'source "$1/lib/borg-hooks.sh" && _borg_project_state_file "$2"' _ "$ROOT" "$plain")"
    [[ "$forked" == */projects/local-*/state.json ]]
    fast_b="$(bash -c 'source "$1/lib/borg-hooks.sh" && _borg_project_state_file "$2" ""' _ "$ROOT" "$plain")"
    fast_z="$(zsh -c 'source "$1/lib/state-root.zsh" && _borg_project_state_file "$2" ""' _ "$ROOT" "$plain")"
    fast_p="$(PYTHONPATH="$ROOT" python3 -c 'import sys; from borg_core.paths import project_state_file as f; print(f(sys.argv[1], None))' "$plain")"
    [ "$forked" = "$fast_b" ]
    [ "$forked" = "$fast_z" ]
    [ "$forked" = "$fast_p" ]
}

# ── zsh: borg_registry_with_state / borg_state_read ─────────────────────────

_zsh_overlay() {
    zsh -c 'source "$1/lib/registry.zsh"; BORG_REGISTRY="$2" BORG_NO_REAP=1 borg_registry_with_state' _ "$ROOT" "$BORG_REGISTRY" \
        | jq -r '.projects.proj.status'
}

@test "zsh overlay: legacy-only is read" {
    _legacy '{"status":"waiting"}'
    [ "$(_zsh_overlay)" = "waiting" ]
}

@test "zsh overlay: both present, the new path wins" {
    _legacy '{"status":"waiting"}'
    _new '{"status":"active"}'
    [ "$(_zsh_overlay)" = "active" ]
}

@test "zsh overlay: the registry repo spares the git fork (a git shim on PATH is never called)" {
    mkdir -p "$BATS_TEST_TMPDIR/shim"
    printf '#!/bin/sh\necho called >> "%s/git-calls"\nexit 1\n' "$BATS_TEST_TMPDIR" > "$BATS_TEST_TMPDIR/shim/git"
    chmod +x "$BATS_TEST_TMPDIR/shim/git"
    _new '{"status":"active"}'
    [ "$(PATH="$BATS_TEST_TMPDIR/shim:$PATH" _zsh_overlay)" = "active" ]
    [ ! -e "$BATS_TEST_TMPDIR/git-calls" ]
}

@test "zsh overlay: a registry entry with no repo field still reads the legacy file" {
    printf '{"projects":{"proj":{"path":"%s","status":"idle"}}}\n' "$PROJ" > "$BORG_REGISTRY"
    _legacy '{"status":"waiting"}'
    [ "$(_zsh_overlay)" = "waiting" ]
}

@test "zsh overlay: a project with an empty path does not shift the repo column or kill the loop" {
    printf '{"projects":{"nopath":{"path":""},"proj":{"path":"%s","repo":"%s"}}}\n' "$PROJ" "$COMMON" > "$BORG_REGISTRY"
    _new '{"status":"active"}'
    [ "$(_zsh_overlay)" = "active" ]
}

@test "zsh borg_state_read: legacy-only, then both (new wins)" {
    _legacy '{"status":"legacy"}'
    [ "$(zsh -c 'source "$1/lib/registry.zsh"; borg_state_read "$2"' _ "$ROOT" "$PROJ" | jq -r .status)" = "legacy" ]
    _new '{"status":"new"}'
    [ "$(zsh -c 'source "$1/lib/registry.zsh"; borg_state_read "$2"' _ "$ROOT" "$PROJ" | jq -r .status)" = "new" ]
}

# ── hooks ───────────────────────────────────────────────────────────────────

_start() { bash "$START" <<< "$(printf '{"session_id":"s1","cwd":"%s"}' "${1:-$PROJ}")"; }

@test "link-down hook: legacy-only uncommitted flag is read" {
    _legacy '{"has_uncommitted_changes":true}'
    run _start
    [ "$status" -eq 0 ]
    echo "$output" | jq -r '.hookSpecificOutput.additionalContext' | grep -q "uncommitted changes"
}

@test "link-down hook: both present, a new-path false beats a legacy true" {
    _legacy '{"has_uncommitted_changes":true}'
    _new '{"has_uncommitted_changes":false}'
    run _start
    [ "$status" -eq 0 ]
    ! echo "$output" | jq -r '.hookSpecificOutput.additionalContext' | grep -q "uncommitted changes"
}

@test "link-down hook: new-path-only uncommitted flag is read" {
    _new '{"has_uncommitted_changes":true}'
    run _start
    echo "$output" | jq -r '.hookSpecificOutput.additionalContext' | grep -q "uncommitted changes"
}

_orch_overview() {
    mkdir -p "$HOME/dev"
    bash "$START" <<< "$(printf '{"session_id":"o1","cwd":"%s"}' "$HOME/dev")" \
        | jq -r '.hookSpecificOutput.additionalContext'
}

@test "link-down orchestrator overview: legacy-only status is shown" {
    _legacy '{"status":"waiting","last_activity":"2026-01-01T00:00:00Z"}'
    [[ "$(_orch_overview)" == *"proj [waiting]"* ]]
}

@test "link-down orchestrator overview: both present, the new status wins" {
    _legacy '{"status":"waiting","last_activity":"2026-01-01T00:00:00Z"}'
    _new '{"status":"active","last_activity":"2026-02-01T00:00:00Z"}'
    [[ "$(_orch_overview)" == *"proj [active]"* ]]
}

@test "link-down orchestrator overview: a project with an empty path keeps every column" {
    printf '{"projects":{"nopath":{"path":""},"proj":{"path":"%s","repo":"%s"}}}\n' "$PROJ" "$COMMON" > "$BORG_REGISTRY"
    _new '{"status":"active","last_activity":"2026-02-01T00:00:00Z"}'
    out="$(_orch_overview)"
    [[ "$out" == *"proj [active]"* ]]
    [[ "$out" == *"nopath [idle]"* ]]
}

@test "link-down capacity count: reads new-then-legacy through the registry repo" {
    printf 'BORG_MAX_ACTIVE=0\n' > "$BORG_DIR/config.zsh"
    printf '{"projects":{"proj":{"path":"%s","repo":"%s"}}}\n' "$PROJ" "$COMMON" > "$BORG_REGISTRY"
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    _legacy '{"status":"idle"}'
    _new "{\"status\":\"active\",\"last_activity\":\"$now\"}"
    mkdir -p "$BATS_TEST_TMPDIR/other"
    run _start "$BATS_TEST_TMPDIR/other"
    [[ "$output" == *"CAPACITY WARNING"* ]]
}

@test "link-up hook (read-modify-write): the READ is new-first; the write still lands on the legacy path" {
    _new '{"marker":"from-new"}'
    _legacy '{"marker":"from-legacy"}'
    run bash "$STOP" <<< "$(printf '{"session_id":"s1","cwd":"%s"}' "$PROJ")"
    [ "$status" -eq 0 ]
    [ "$(jq -r .marker "$PROJ/.borg/state.json")" = "from-new" ]
    [ "$(jq -r .status "$PROJ/.borg/state.json")" = "idle" ]
}

@test "notify hook (read-modify-write): the READ is new-first; the write still lands on the legacy path" {
    _new '{"marker":"from-new"}'
    _legacy '{"marker":"from-legacy"}'
    run bash "$NOTIFY" <<< "$(printf '{"session_id":"s1","cwd":"%s","message":"hi"}' "$PROJ")"
    [ "$status" -eq 0 ]
    [ "$(jq -r .marker "$PROJ/.borg/state.json")" = "from-new" ]
    [ "$(jq -r .status "$PROJ/.borg/state.json")" = "waiting" ]
}

# ── Python: borg link's collector ───────────────────────────────────────────

_py_state() {
    PYTHONPATH="$ROOT" python3 -c '
import json, sys
from borg_core.link import shell
reg = json.load(open(sys.argv[1]))
print(json.dumps(shell.collect_states(reg), sort_keys=True))' "$BORG_REGISTRY"
}

@test "python collector: legacy-only is read" {
    _legacy '{"status":"legacy"}'
    [ "$(_py_state | jq -r .proj.status)" = "legacy" ]
}

@test "python collector: both present, the new path wins" {
    _legacy '{"status":"legacy"}'
    _new '{"status":"new"}'
    [ "$(_py_state | jq -r .proj.status)" = "new" ]
}

@test "python collector: an entry with no repo field reads the legacy file" {
    printf '{"projects":{"proj":{"path":"%s"}}}\n' "$PROJ" > "$BORG_REGISTRY"
    _legacy '{"status":"legacy"}'
    _new '{"status":"new"}'
    [ "$(_py_state | jq -r .proj.status)" = "legacy" ]
}
