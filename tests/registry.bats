#!/usr/bin/env bats

load test_helper/setup

setup() {
    setup_temp_dirs
}

@test "borg_registry_init creates registry file" {
    run run_zsh_fn registry borg_registry_init
    [ "$status" -eq 0 ]
    [ -f "$BORG_REGISTRY" ]
    run jq -r '.repositories | keys | length' "$BORG_REGISTRY"
    [ "$output" = "0" ]
}

@test "borg_registry_init is idempotent" {
    run_zsh_fn registry borg_registry_init
    echo '{"repositories":{"existing":{"status":"active"}}}' > "$BORG_REGISTRY"
    run_zsh_fn registry borg_registry_init
    run jq -r '.repositories | has("existing")' "$BORG_REGISTRY"
    [ "$output" = "true" ]
}

@test "borg_registry_read returns valid JSON" {
    run_zsh_fn registry borg_registry_init
    run run_zsh_fn registry borg_registry_read
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null
}

@test "borg_registry_list returns repository names" {
    run_zsh_fn registry borg_registry_init
    echo '{"repositories":{"alpha":{},"beta":{}}}' > "$BORG_REGISTRY"
    run run_zsh_fn registry borg_registry_list
    [ "$status" -eq 0 ]
    [[ "$output" == *"alpha"* ]] || false
    [[ "$output" == *"beta"* ]] || false
}

@test "borg_registry_list returns empty for no repositories" {
    run_zsh_fn registry borg_registry_init
    run run_zsh_fn registry borg_registry_list
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "borg_registry_get returns repository entry" {
    run_zsh_fn registry borg_registry_init
    echo '{"repositories":{"myproj":{"status":"active","path":"/dev/myproj"}}}' > "$BORG_REGISTRY"
    run run_zsh_fn registry borg_registry_get myproj
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.status == "active"'
    echo "$output" | jq -e '.path == "/dev/myproj"'
}

@test "borg_registry_get returns empty for missing repository" {
    run_zsh_fn registry borg_registry_init
    run run_zsh_fn registry borg_registry_get nonexistent
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "borg_registry_has returns 0 for existing repository" {
    run_zsh_fn registry borg_registry_init
    echo '{"repositories":{"myproj":{}}}' > "$BORG_REGISTRY"
    run run_zsh_fn registry borg_registry_has myproj
    [ "$status" -eq 0 ]
}

@test "borg_registry_has returns non-zero for missing repository" {
    run_zsh_fn registry borg_registry_init
    run run_zsh_fn registry borg_registry_has nonexistent
    [ "$status" -ne 0 ]
}

@test "borg_registry_set writes a field" {
    run_zsh_fn registry borg_registry_init
    echo '{"repositories":{"myproj":{"status":"idle"}}}' > "$BORG_REGISTRY"
    run_zsh_fn registry borg_registry_set myproj status '"active"'
    run jq -r '.repositories.myproj.status' "$BORG_REGISTRY"
    [ "$output" = "active" ]
}

@test "borg_registry_merge upserts without overwriting" {
    run_zsh_fn registry borg_registry_init
    echo '{"repositories":{"myproj":{"status":"idle","path":"/old"}}}' > "$BORG_REGISTRY"
    run_zsh_fn registry borg_registry_merge myproj '{"status":"active","summary":"working"}'
    run jq -r '.repositories.myproj.status' "$BORG_REGISTRY"
    [ "$output" = "active" ]
    run jq -r '.repositories.myproj.path' "$BORG_REGISTRY"
    [ "$output" = "/old" ]
    run jq -r '.repositories.myproj.summary' "$BORG_REGISTRY"
    [ "$output" = "working" ]
}

@test "borg_registry_remove deletes a repository" {
    run_zsh_fn registry borg_registry_init
    echo '{"repositories":{"keep":{},"remove":{}}}' > "$BORG_REGISTRY"
    run_zsh_fn registry borg_registry_remove remove
    run jq -r '.repositories | has("remove")' "$BORG_REGISTRY"
    [ "$output" = "false" ]
    run jq -r '.repositories | has("keep")' "$BORG_REGISTRY"
    [ "$output" = "true" ]
}

@test "borg_registry_set_status writes status and timestamp to state.json" {
    local proj_dir="${BATS_TEST_TMPDIR}/myproj"
    mkdir -p "$proj_dir"
    run_zsh_fn registry borg_registry_init
    printf '{"repositories":{"myproj":{"path":"%s","source":"cli"}}}' "$proj_dir" > "$BORG_REGISTRY"
    run_zsh_fn registry borg_registry_set_status myproj active
    run jq -r '.status' "$(state_path_of "$proj_dir" "")"
    [ "$output" = "active" ]
    run jq -r '.last_activity' "$(state_path_of "$proj_dir" "")"
    [[ "$output" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]] || false
    [ ! -e "${proj_dir}/.borg/state.json" ]
}

# ─── borg_scan_path_should_skip ───────────────────────────────────────────────

@test "borg_scan_path_should_skip: skips empty path" {
    run_zsh_fn registry borg_registry_init
    run run_zsh_fn registry borg_scan_path_should_skip ""
    [ "$status" -eq 0 ]
}

@test "borg_scan_path_should_skip: skips nonexistent path (renamed/deleted folder)" {
    run_zsh_fn registry borg_registry_init
    run run_zsh_fn registry borg_scan_path_should_skip "${BATS_TEST_TMPDIR}/does-not-exist"
    [ "$status" -eq 0 ]
}

@test "borg_scan_path_should_skip: skips workspace root" {
    run_zsh_fn registry borg_registry_init
    mkdir -p "${BATS_TEST_TMPDIR}/workspace"
    BORG_ORCHESTRATOR_ROOT="${BATS_TEST_TMPDIR}/workspace" run run_zsh_fn registry borg_scan_path_should_skip "${BATS_TEST_TMPDIR}/workspace"
    [ "$status" -eq 0 ]
}

@test "borg_scan_path_should_skip: skips subpath of registered repository" {
    run_zsh_fn registry borg_registry_init
    mkdir -p "${BATS_TEST_TMPDIR}/proj/nested"
    echo "{\"repositories\":{\"proj\":{\"path\":\"${BATS_TEST_TMPDIR}/proj\"}}}" > "$BORG_REGISTRY"
    run run_zsh_fn registry borg_scan_path_should_skip "${BATS_TEST_TMPDIR}/proj/nested"
    [ "$status" -eq 0 ]
}

@test "borg_scan_path_should_skip: registers genuine new repository" {
    run_zsh_fn registry borg_registry_init
    mkdir -p "${BATS_TEST_TMPDIR}/newproj"
    run run_zsh_fn registry borg_scan_path_should_skip "${BATS_TEST_TMPDIR}/newproj"
    [ "$status" -eq 1 ]
}

@test "borg_scan_path_should_skip: does NOT skip sibling of a registered repository" {
    run_zsh_fn registry borg_registry_init
    mkdir -p "${BATS_TEST_TMPDIR}/proj-a" "${BATS_TEST_TMPDIR}/proj-b"
    echo "{\"repositories\":{\"proj-a\":{\"path\":\"${BATS_TEST_TMPDIR}/proj-a\"}}}" > "$BORG_REGISTRY"
    run run_zsh_fn registry borg_scan_path_should_skip "${BATS_TEST_TMPDIR}/proj-b"
    [ "$status" -eq 1 ]
}
