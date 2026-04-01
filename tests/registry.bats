#!/usr/bin/env bats

load test_helper/setup

setup() {
    setup_temp_dirs
}

@test "borg_registry_init creates registry file" {
    run run_zsh_fn registry borg_registry_init
    [ "$status" -eq 0 ]
    [ -f "$BORG_REGISTRY" ]
    run jq -r '.projects | keys | length' "$BORG_REGISTRY"
    [ "$output" = "0" ]
}

@test "borg_registry_init is idempotent" {
    run_zsh_fn registry borg_registry_init
    echo '{"projects":{"existing":{"status":"active"}}}' > "$BORG_REGISTRY"
    run_zsh_fn registry borg_registry_init
    run jq -r '.projects | has("existing")' "$BORG_REGISTRY"
    [ "$output" = "true" ]
}

@test "borg_registry_read returns valid JSON" {
    run_zsh_fn registry borg_registry_init
    run run_zsh_fn registry borg_registry_read
    [ "$status" -eq 0 ]
    echo "$output" | jq -e . >/dev/null
}

@test "borg_registry_list returns project names" {
    run_zsh_fn registry borg_registry_init
    echo '{"projects":{"alpha":{},"beta":{}}}' > "$BORG_REGISTRY"
    run run_zsh_fn registry borg_registry_list
    [ "$status" -eq 0 ]
    [[ "$output" == *"alpha"* ]]
    [[ "$output" == *"beta"* ]]
}

@test "borg_registry_list returns empty for no projects" {
    run_zsh_fn registry borg_registry_init
    run run_zsh_fn registry borg_registry_list
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "borg_registry_get returns project entry" {
    run_zsh_fn registry borg_registry_init
    echo '{"projects":{"myproj":{"status":"active","path":"/dev/myproj"}}}' > "$BORG_REGISTRY"
    run run_zsh_fn registry borg_registry_get myproj
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.status == "active"'
    echo "$output" | jq -e '.path == "/dev/myproj"'
}

@test "borg_registry_get returns empty for missing project" {
    run_zsh_fn registry borg_registry_init
    run run_zsh_fn registry borg_registry_get nonexistent
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "borg_registry_has returns 0 for existing project" {
    run_zsh_fn registry borg_registry_init
    echo '{"projects":{"myproj":{}}}' > "$BORG_REGISTRY"
    run run_zsh_fn registry borg_registry_has myproj
    [ "$status" -eq 0 ]
}

@test "borg_registry_has returns non-zero for missing project" {
    run_zsh_fn registry borg_registry_init
    run run_zsh_fn registry borg_registry_has nonexistent
    [ "$status" -ne 0 ]
}

@test "borg_registry_set writes a field" {
    run_zsh_fn registry borg_registry_init
    echo '{"projects":{"myproj":{"status":"idle"}}}' > "$BORG_REGISTRY"
    run_zsh_fn registry borg_registry_set myproj status '"active"'
    run jq -r '.projects.myproj.status' "$BORG_REGISTRY"
    [ "$output" = "active" ]
}

@test "borg_registry_merge upserts without overwriting" {
    run_zsh_fn registry borg_registry_init
    echo '{"projects":{"myproj":{"status":"idle","path":"/old"}}}' > "$BORG_REGISTRY"
    run_zsh_fn registry borg_registry_merge myproj '{"status":"active","summary":"working"}'
    run jq -r '.projects.myproj.status' "$BORG_REGISTRY"
    [ "$output" = "active" ]
    run jq -r '.projects.myproj.path' "$BORG_REGISTRY"
    [ "$output" = "/old" ]
    run jq -r '.projects.myproj.summary' "$BORG_REGISTRY"
    [ "$output" = "working" ]
}

@test "borg_registry_remove deletes a project" {
    run_zsh_fn registry borg_registry_init
    echo '{"projects":{"keep":{},"remove":{}}}' > "$BORG_REGISTRY"
    run_zsh_fn registry borg_registry_remove remove
    run jq -r '.projects | has("remove")' "$BORG_REGISTRY"
    [ "$output" = "false" ]
    run jq -r '.projects | has("keep")' "$BORG_REGISTRY"
    [ "$output" = "true" ]
}

@test "borg_registry_set_status updates status and timestamp" {
    run_zsh_fn registry borg_registry_init
    echo '{"projects":{"myproj":{"status":"idle"}}}' > "$BORG_REGISTRY"
    run_zsh_fn registry borg_registry_set_status myproj active
    run jq -r '.projects.myproj.status' "$BORG_REGISTRY"
    [ "$output" = "active" ]
    run jq -r '.projects.myproj.last_activity' "$BORG_REGISTRY"
    [[ "$output" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T ]]
}
