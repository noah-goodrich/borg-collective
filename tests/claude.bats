#!/usr/bin/env bats

load test_helper/setup

setup() {
    setup_temp_dirs
}

@test "borg_claude_encode_path encodes absolute path" {
    run run_zsh_fn claude borg_claude_encode_path /Users/noah/dev/cairn
    [ "$status" -eq 0 ]
    [ "$output" = "-Users-noah-dev-cairn" ]
}

@test "borg_claude_encode_path strips trailing slash" {
    run run_zsh_fn claude borg_claude_encode_path /Users/noah/dev/cairn/
    [ "$status" -eq 0 ]
    [ "$output" = "-Users-noah-dev-cairn" ]
}

@test "borg_claude_encode_path handles root path" {
    run run_zsh_fn claude borg_claude_encode_path /
    [ "$status" -eq 0 ]
    [ "$output" = "" ]
}

@test "borg_claude_project_dir returns correct path" {
    run run_zsh_fn claude borg_claude_project_dir /Users/noah/dev/cairn
    [ "$status" -eq 0 ]
    [[ "$output" == *"/.claude/projects/-Users-noah-dev-cairn" ]]
}

@test "borg_claude_latest_session_id returns empty for missing dir" {
    run run_zsh_fn claude borg_claude_latest_session_id /nonexistent/project
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "borg_claude_latest_session_id finds newest JSONL" {
    local proj_dir="$HOME/.claude/projects/-test-project"
    mkdir -p "$proj_dir"
    touch "$proj_dir/aaa-old.jsonl"
    sleep 1
    touch "$proj_dir/bbb-new.jsonl"

    run run_zsh_fn claude borg_claude_latest_session_id /test/project
    [ "$status" -eq 0 ]
    [ "$output" = "bbb-new" ]
}

@test "borg_claude_session_jsonl returns correct path" {
    run run_zsh_fn claude borg_claude_session_jsonl /Users/noah/dev/cairn abc-123
    [ "$status" -eq 0 ]
    [[ "$output" == *"/-Users-noah-dev-cairn/abc-123.jsonl" ]]
}

@test "borg_claude_scan_session_log returns empty when log missing" {
    run run_zsh_fn claude borg_claude_scan_session_log
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "borg_claude_scan_session_log parses session log format" {
    mkdir -p "$HOME/.claude"
    cat > "$HOME/.claude/session-log.md" <<'LOG'
- 2026-03-17 08:25 | /Users/noah/dev/cairn | session:abc-123
- 2026-03-17 09:30 | /Users/noah/dev/borg | session:def-456
- 2026-03-17 10:00 | /Users/noah/dev/cairn | session:ghi-789
LOG

    run run_zsh_fn claude borg_claude_scan_session_log
    [ "$status" -eq 0 ]
    [[ "$output" == *"/Users/noah/dev/cairn"* ]]
    [[ "$output" == *"/Users/noah/dev/borg"* ]]
    # Should deduplicate
    local count
    count=$(echo "$output" | grep -c "cairn" || true)
    [ "$count" -eq 1 ]
}
