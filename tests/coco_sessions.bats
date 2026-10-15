#!/usr/bin/env bats
# Tests for lib/coco.zsh session discovery (docs/plans/directives/2026-10-15-borg-in-cortex.md, AC3).
#
# Cortex Code CLI stores one `<uuid>.json` (metadata with `working_directory`) and one `<uuid>.history.jsonl` per
# session in ~/.snowflake/cortex/conversations/. Every fixture here is synthetic, built under the sandboxed HOME
# that setup_temp_dirs provides; no case reads a real Cortex directory.

load test_helper/setup

setup() {
    setup_temp_dirs
    CONV="$BORG_TEST_HOME/.snowflake/cortex/conversations"
}

# _session <uuid> <cwd> <touch -t stamp> [session_type]
_session() {
    mkdir -p "$CONV"
    printf '{"session_id":"%s","working_directory":"%s","session_type":"%s","last_updated":"2026-01-01T00:00:00Z"}' \
        "$1" "$2" "${4:-main}" > "$CONV/$1.json"
    printf '{"role":"user"}\n' > "$CONV/$1.history.jsonl"
    touch -t "$3" "$CONV/$1.json"
}

@test "a session is found by its working directory and its history path is derived" {
    _session aaaa1111 /work/alpha 202601010100
    run run_zsh_fn coco borg_coco_latest_session_id /work/alpha
    [ "$status" -eq 0 ]
    [ "$output" = "aaaa1111" ]
    run run_zsh_fn coco borg_coco_latest_jsonl /work/alpha
    [ "$output" = "$CONV/aaaa1111.history.jsonl" ]
    [ -f "$output" ]
}

@test "the newest session wins per repository, and a trailing slash does not matter" {
    _session old00001 /work/alpha 202601010100
    _session new00002 /work/alpha 202603010100
    _session mid00003 /work/alpha 202602010100
    _session other004 /work/beta 202604010100
    run run_zsh_fn coco borg_coco_latest_session_id /work/alpha/
    [ "$output" = "new00002" ]
    run run_zsh_fn coco borg_coco_latest_session_id /work/beta
    [ "$output" = "other004" ]
}

@test "a subagent session never counts as the repository's session" {
    _session main0001 /work/alpha 202601010100
    _session sub00002 /work/alpha 202605010100 subagent
    run run_zsh_fn coco borg_coco_latest_session_id /work/alpha
    [ "$output" = "main0001" ]
}

@test "the scan lists each main-session working directory once" {
    _session aaaa1111 /work/alpha 202601010100
    _session bbbb2222 /work/alpha 202601020100
    _session cccc3333 /work/beta 202601030100
    _session dddd4444 /work/gamma 202601040100 subagent
    run run_zsh_fn coco borg_coco_scan_session_log
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf '/work/alpha\n/work/beta')" ]
}

@test "a malformed or cwd-less file is skipped silently" {
    _session good0001 /work/alpha 202601010100
    mkdir -p "$CONV"
    printf '{not json' > "$CONV/bad00002.json"
    printf '{"session_id":"nocwd003"}' > "$CONV/nocwd003.json"
    printf '' > "$CONV/empty004.json"
    printf '[1,2]' > "$CONV/array005.json"
    touch -t 202612010100 "$CONV/bad00002.json" "$CONV/nocwd003.json" "$CONV/empty004.json" "$CONV/array005.json"
    run run_zsh_fn coco borg_coco_latest_session_id /work/alpha
    [ "$status" -eq 0 ]
    [ "$output" = "good0001" ]
    run run_zsh_fn coco borg_coco_scan_session_log
    [ "$status" -eq 0 ]
    [ "$output" = "/work/alpha" ]
}

@test "an absent conversations directory yields nothing and no error" {
    [ ! -e "$CONV" ]
    run run_zsh_fn coco borg_coco_latest_session_id /work/alpha
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    run run_zsh_fn coco borg_coco_scan_session_log
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    run run_zsh_fn coco borg_coco_latest_jsonl /work/alpha
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "borg scan registers a Cortex-only repository with the coco source" {
    mkdir -p "$BORG_TEST_HOME/dev/cortexonly" "$BORG_DIR"
    _session cccc9999 "$BORG_TEST_HOME/dev/cortexonly" 202601010100
    printf '{"projects":{}}' > "$BORG_REGISTRY"
    run zsh "$BORG_HOME/borg.zsh" scan --no-llm
    [ "$status" -eq 0 ]
    run jq -r '.projects.cortexonly.source' "$BORG_REGISTRY"
    [ "$output" = "coco" ]
}
