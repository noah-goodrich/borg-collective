#!/usr/bin/env bats
# Tests for per-project state.json helpers in lib/borg-hooks.sh (bash) and
# lib/registry.zsh (zsh). Covers _borg_state_{file,read,write} and
# borg_registry_with_state / borg_registry_get_with_state.

load test_helper/setup

setup() {
    setup_temp_dirs

    export TEST_PROJ="${BATS_TEST_TMPDIR}/myproject"
    mkdir -p "$TEST_PROJ"

    # Seed registry with a real path so state helpers can resolve it
    mkdir -p "$BORG_DIR"
    cat > "$BORG_REGISTRY" <<EOF
{"projects":{"myproject":{"path":"${TEST_PROJ}","source":"cli","summary":null}}}
EOF
}

# ─── bash helpers (_borg_state_file / _borg_state_read / _borg_state_write) ───

@test "_borg_state_file returns expected path" {
    result=$(bash -c "
        source '${BORG_HOME}/lib/borg-hooks.sh'
        _borg_state_file '${TEST_PROJ}'
    ")
    [ "$result" = "${TEST_PROJ}/.borg/state.json" ]
}

@test "_borg_state_read returns {} when file does not exist" {
    result=$(bash -c "
        source '${BORG_HOME}/lib/borg-hooks.sh'
        _borg_state_read '${TEST_PROJ}'
    ")
    [ "$result" = "{}" ]
}

@test "_borg_state_write creates state.json atomically" {
    bash -c "
        source '${BORG_HOME}/lib/borg-hooks.sh'
        _borg_state_write '${TEST_PROJ}' '{\"status\":\"active\",\"last_activity\":\"2026-01-01T00:00:00Z\"}'
    "
    [ -f "${TEST_PROJ}/.borg/state.json" ]
    status=$(jq -r '.status' "${TEST_PROJ}/.borg/state.json")
    [ "$status" = "active" ]
}

@test "_borg_state_read returns existing state.json content" {
    mkdir -p "${TEST_PROJ}/.borg"
    echo '{"status":"waiting","waiting_reason":"Input needed"}' > "${TEST_PROJ}/.borg/state.json"

    result=$(bash -c "
        source '${BORG_HOME}/lib/borg-hooks.sh'
        _borg_state_read '${TEST_PROJ}'
    ")
    status=$(printf '%s' "$result" | jq -r '.status')
    [ "$status" = "waiting" ]
}

@test "_borg_state_write rejects empty json" {
    run bash -c "
        source '${BORG_HOME}/lib/borg-hooks.sh'
        _borg_state_write '${TEST_PROJ}' ''
    "
    [ ! -f "${TEST_PROJ}/.borg/state.json" ]
}

@test "_borg_state_write creates parent .borg/ dir if absent" {
    # Ensure .borg/ doesn't exist
    rm -rf "${TEST_PROJ}/.borg"
    bash -c "
        source '${BORG_HOME}/lib/borg-hooks.sh'
        _borg_state_write '${TEST_PROJ}' '{\"status\":\"idle\"}'
    "
    [ -f "${TEST_PROJ}/.borg/state.json" ]
}

# ─── zsh helpers (borg_state_file / borg_state_read / borg_state_write) ───────

@test "borg_state_file (zsh) returns expected path" {
    result=$(run_zsh_fn registry borg_state_file "$TEST_PROJ")
    [ "$result" = "${TEST_PROJ}/.borg/state.json" ]
}

@test "borg_state_read (zsh) returns {} when file absent" {
    result=$(run_zsh_fn registry borg_state_read "$TEST_PROJ")
    [ "$result" = "{}" ]
}

@test "borg_state_write (zsh) creates state.json" {
    run_zsh_fn registry borg_state_write "$TEST_PROJ" '{"status":"idle","has_uncommitted_changes":false}'
    [ -f "${TEST_PROJ}/.borg/state.json" ]
    flag=$(jq -r '.has_uncommitted_changes' "${TEST_PROJ}/.borg/state.json")
    [ "$flag" = "false" ]
}

# ─── borg_registry_with_state / borg_registry_get_with_state ─────────────────

@test "borg_registry_with_state returns registry data when no state.json" {
    result=$(run_zsh_fn registry borg_registry_with_state)
    name=$(printf '%s' "$result" | jq -r '.projects | keys[0]')
    [ "$name" = "myproject" ]
}

@test "borg_registry_with_state overlays state.json fields" {
    mkdir -p "${TEST_PROJ}/.borg"
    echo '{"status":"active","last_activity":"2026-05-27T12:00:00Z","claude_session_id":"sess-xyz"}' \
        > "${TEST_PROJ}/.borg/state.json"

    result=$(run_zsh_fn registry borg_registry_with_state)
    status=$(printf '%s' "$result" | jq -r '.projects.myproject.status')
    sid=$(printf '%s' "$result" | jq -r '.projects.myproject.claude_session_id')
    [ "$status" = "active" ]
    [ "$sid" = "sess-xyz" ]
}

@test "borg_registry_with_state preserves stable registry fields" {
    mkdir -p "${TEST_PROJ}/.borg"
    echo '{"status":"active"}' > "${TEST_PROJ}/.borg/state.json"

    result=$(run_zsh_fn registry borg_registry_with_state)
    src=$(printf '%s' "$result" | jq -r '.projects.myproject.source')
    path=$(printf '%s' "$result" | jq -r '.projects.myproject.path')
    [ "$src" = "cli" ]
    [ "$path" = "${TEST_PROJ}" ]
}

@test "borg_registry_get_with_state returns merged project entry" {
    mkdir -p "${TEST_PROJ}/.borg"
    echo '{"status":"waiting","waiting_reason":"Needs review"}' \
        > "${TEST_PROJ}/.borg/state.json"

    result=$(run_zsh_fn registry borg_registry_get_with_state myproject)
    status=$(printf '%s' "$result" | jq -r '.status')
    reason=$(printf '%s' "$result" | jq -r '.waiting_reason')
    [ "$status" = "waiting" ]
    [ "$reason" = "Needs review" ]
}

@test "borg_registry_get_with_state returns empty for unknown project" {
    result=$(run_zsh_fn registry borg_registry_get_with_state nonexistent)
    [ -z "$result" ]
}
