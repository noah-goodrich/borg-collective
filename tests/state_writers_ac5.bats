#!/usr/bin/env bats
# AC5 step c (expand, writers): every WRITER of a project's state.json writes the per-project state-root
# path, never <dir>/.borg/state.json. Read-modify-write sites read new-first-else-legacy, so a legacy-only
# file's fields carry over into the new file; the legacy file is left alone (step d migrates it).
#
# Pinned here: each writer lands at the new path; legacy fields carry over; after a write the reader returns
# the WRITTEN value (no stale shadow from a legacy file); the writer keys a registered project by the registry
# `repo` exactly as the readers do; and a source-level census that no code path writes .borg/state.json.
#
# HOME and every XDG dir are sandboxed by setup_temp_dirs, so no case can touch the real machine.

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
    NEWF="$(state_path_of "$PROJ" "$COMMON")"
    LEGACY="$PROJ/.borg/state.json"
}

_legacy() { mkdir -p "$PROJ/.borg" && printf '%s\n' "$1" > "$LEGACY"; }
_hook_in() { printf '{"session_id":"s1","cwd":"%s","message":"hi"}' "$PROJ"; }
_bash_read() { bash -c 'source "$1/lib/borg-hooks.sh" && _borg_state_read "$2" "$3"' _ "$ROOT" "$PROJ" "$COMMON"; }
_zsh_read() { zsh -c 'source "$1/lib/registry.zsh" && borg_state_read "$2" "$3"' _ "$ROOT" "$PROJ" "$COMMON"; }

# ── hooks ────────────────────────────────────────────────────────────────────

@test "link-down hook writes the new path, carries legacy fields, leaves the legacy file alone" {
    _legacy '{"marker":"from-legacy","status":"idle"}'
    run bash "$START" <<< "$(_hook_in)"
    [ "$status" -eq 0 ]
    [ "$(jq -r .status "$NEWF")" = "active" ]
    [ "$(jq -r .marker "$NEWF")" = "from-legacy" ]
    [ "$(jq -r .status "$LEGACY")" = "idle" ]
}

@test "link-up hook writes the new path, carries legacy fields, leaves the legacy file alone" {
    _legacy '{"marker":"from-legacy","status":"active"}'
    run bash "$STOP" <<< "$(_hook_in)"
    [ "$status" -eq 0 ]
    [ "$(jq -r .status "$NEWF")" = "idle" ]
    [ "$(jq -r .marker "$NEWF")" = "from-legacy" ]
    [ "$(jq -r .status "$LEGACY")" = "active" ]
}

@test "notify hook writes the new path, carries legacy fields, leaves the legacy file alone" {
    _legacy '{"marker":"from-legacy","status":"idle"}'
    run bash "$NOTIFY" <<< "$(_hook_in)"
    [ "$status" -eq 0 ]
    [ "$(jq -r .status "$NEWF")" = "waiting" ]
    [ "$(jq -r .marker "$NEWF")" = "from-legacy" ]
    [ "$(jq -r .status "$LEGACY")" = "idle" ]
}

@test "a hook with NO prior state creates the new dir and never creates .borg/" {
    run bash "$NOTIFY" <<< "$(_hook_in)"
    [ "$status" -eq 0 ]
    [ -f "$NEWF" ]
    [ ! -e "$PROJ/.borg" ]
}

@test "hooks stay quiet: the JSON on stdout is not spliced with stderr" {
    _legacy '{"status":"idle"}'
    run bash -c "bash '$START' <<< '$(_hook_in)' 2>/dev/null | jq -e ."
    [ "$status" -eq 0 ]
}

@test "a registered project with NO repo is keyed path-only, the way the readers key it" {
    printf '{"projects":{"proj":{"path":"%s","status":"idle","source":"cli"}}}\n' "$PROJ" > "$BORG_REGISTRY"
    run bash "$NOTIFY" <<< "$(_hook_in)"
    [ "$status" -eq 0 ]
    [ -f "$(state_path_of "$PROJ" "")" ]
    [ ! -f "$NEWF" ]
}

# ── no stale shadow: the reader returns what the writer wrote ────────────────

@test "after a hook write, the bash, zsh and python readers return the written value, not the legacy one" {
    _legacy '{"status":"STALE-LEGACY"}'
    run bash "$NOTIFY" <<< "$(_hook_in)"
    [ "$status" -eq 0 ]
    [ "$(_bash_read | jq -r .status)" = "waiting" ]
    [ "$(_zsh_read | jq -r .status)" = "waiting" ]
    py="$(PYTHONPATH="$ROOT" python3 -c 'import sys; from borg_core.paths import project_state_read_path as f; print(f(sys.argv[1], sys.argv[2]))' "$PROJ" "$COMMON")"
    [ "$(jq -r .status "$py")" = "waiting" ]
}

# ── zsh writers ──────────────────────────────────────────────────────────────

@test "borg_registry_set_status: legacy fields carry over, the write lands on the new path" {
    _legacy '{"marker":"from-legacy","status":"idle"}'
    run zsh -c 'source "$1/lib/registry.zsh"; BORG_REGISTRY="$2"; borg_registry_set_status proj active' _ "$ROOT" "$BORG_REGISTRY"
    [ "$status" -eq 0 ]
    [ "$(jq -r .status "$NEWF")" = "active" ]
    [ "$(jq -r .marker "$NEWF")" = "from-legacy" ]
    [ "$(jq -r .status "$LEGACY")" = "idle" ]
    [ "$(_zsh_read | jq -r .status)" = "active" ]
}

_reap_fixture() {
    export BORG_PATH_PREFIX="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$BATS_TEST_TMPDIR/bin"
    printf '#!/usr/bin/env bash\nexit 1\n' > "$BATS_TEST_TMPDIR/bin/tmux"
    chmod +x "$BATS_TEST_TMPDIR/bin/tmux"
}

@test "borg reap: a LEGACY-ONLY stale project is downgraded into the new path, legacy untouched" {
    _reap_fixture
    _legacy '{"marker":"from-legacy","status":"active","last_activity":"2020-01-01T00:00:00Z"}'
    run zsh "$ROOT/borg.zsh" reap
    [ "$status" -eq 0 ]
    [[ "$output" == *"proj"* ]] || false
    [ "$(jq -r .status "$NEWF")" = "idle" ]
    [ "$(jq -r .marker "$NEWF")" = "from-legacy" ]
    [ "$(jq -r .status "$LEGACY")" = "active" ]
}

@test "borg reap: a NEW-ONLY stale project is downgraded (the guard accepts either location)" {
    _reap_fixture
    mkdir -p "$(dirname "$NEWF")"
    printf '{"status":"active","last_activity":"2020-01-01T00:00:00Z"}\n' > "$NEWF"
    run zsh "$ROOT/borg.zsh" reap
    [ "$status" -eq 0 ]
    [ "$(jq -r .status "$NEWF")" = "idle" ]
    [ ! -e "$PROJ/.borg" ]
}

@test "borg reap: a project with no state file in either location is not created by the reaper" {
    _reap_fixture
    run zsh "$ROOT/borg.zsh" reap
    [ "$status" -eq 0 ]
    [ ! -e "$NEWF" ]
    [ ! -e "$PROJ/.borg" ]
}

# ── census: nothing writes .borg/state.json any more ─────────────────────────

@test "census: no source file redirects into, or names as a write target, <dir>/.borg/state.json" {
    cd "$ROOT"
    # Shell: a redirection (> or >>) whose target mentions .borg/state.json, or tee/mv/cp INTO it.
    run bash -c "grep -rnE '(>>?[[:space:]]*[\"'\\'']?[^ |&;]*\\.borg/state\\.json)|((tee|mv|cp)[^#]*\\.borg/state\\.json)' \
        hooks lib bin borg.zsh drone.zsh install.sh 2>/dev/null | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#'"
    echo "$output" >&2
    [ -z "$output" ]
}

@test "census: the legacy-path helpers are READ-only -- no writer references _borg_state_file/borg_state_file" {
    cd "$ROOT"
    run bash -c "grep -rnE '(_borg_state_file|borg_state_file)\\b' hooks lib bin borg.zsh drone.zsh | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#'"
    # Only the definitions and the read-path fallbacks may mention them.
    [ "$(printf '%s\n' "$output" | grep -cE 'state_write|> ')" = "0" ]
    local bad
    bad="$(printf '%s\n' "$output" | grep -vE '_borg_state_file\(\)|borg_state_file\(\)|_borg_state_file "\$1"|borg_state_file "\$1"|printf .%s/.borg/state.json' || true)"
    echo "$bad" >&2
    [ -z "$bad" ]
}

@test "census: borg_core has no Python writer of <dir>/.borg/state.json" {
    cd "$ROOT"
    run bash -c "grep -rnE '\\.borg.*state\\.json' borg_core --include=*.py | grep -vE 'test_|#|\"\"\"|^[^:]+:[0-9]+:[[:space:]]+[A-Za-z\`(\"].* (is|the|a|an|as|per|and)\\b' | grep -E 'write|open\\(.*w|dump|replace\\(' || true"
    [ -z "$output" ]
}
