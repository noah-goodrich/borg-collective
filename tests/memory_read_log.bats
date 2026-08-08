#!/usr/bin/env bats
# Tests for hooks/borg-memory-read-log.sh — PostToolUse(Read) instrument for auto-memory.
#
# Purpose: cairn's decommission (see ~/dev/cairn/docs/research/README.md) leaves Claude Code
# project-memory files as the sole cross-session knowledge layer. This hook is the hit log that
# proves whether that fallback is actually read, matching the shape of cairn-hits.log. Contract:
# logs a tab-separated row (timestamp, session_id, project dir, filename, bytes) to
# $BORG_DIR/memory-hits.log for any Read whose file_path is under
# ~/.claude/projects/<dir>/memory/*.md, and is a silent no-op for every other Read. Never blocks
# (always exits 0) — this is passive observation, not a gate.

load test_helper/setup

HOOK="${BATS_TEST_DIRNAME}/../hooks/borg-memory-read-log.sh"

setup() {
    setup_temp_dirs
}

_run_hook() {
    local file_path="$1" session_id="${2:-test-session-abc}"
    local payload_file="${BATS_TEST_TMPDIR}/payload.json"
    jq -n --arg f "$file_path" --arg s "$session_id" \
        '{session_id:$s, tool_input:{file_path:$f}}' > "$payload_file"
    run bash -c "bash '$HOOK' < '$payload_file'"
}

@test "logs a read of a project memory file" {
    local mem_dir="$HOME/.claude/projects/-Users-noah-dev-cairn/memory"
    mkdir -p "$mem_dir"
    printf 'content' > "$mem_dir/MEMORY.md"

    _run_hook "$mem_dir/MEMORY.md"
    [ "$status" -eq 0 ]

    [ -f "$BORG_DIR/memory-hits.log" ]
    run cat "$BORG_DIR/memory-hits.log"
    [[ "$output" == *$'\t'"test-session-abc"$'\t'"-Users-noah-dev-cairn"$'\t'"MEMORY.md"$'\t'"7" ]]
}

@test "does not log a read of a non-memory file" {
    _run_hook "/Users/noah/dev/cairn/src/cairn/db.py"
    [ "$status" -eq 0 ]
    [ ! -f "$BORG_DIR/memory-hits.log" ]
}

@test "does not log a read outside .claude/projects" {
    local other_dir="$HOME/some-other-place/memory"
    mkdir -p "$other_dir"
    printf 'x' > "$other_dir/note.md"

    _run_hook "$other_dir/note.md"
    [ "$status" -eq 0 ]
    [ ! -f "$BORG_DIR/memory-hits.log" ]
}

@test "does not log a read of a project file that merely contains 'memory' in its name" {
    local proj_dir="$HOME/.claude/projects/-Users-noah-dev-cairn"
    mkdir -p "$proj_dir"
    printf 'x' > "$proj_dir/memory-notes.md"

    _run_hook "$proj_dir/memory-notes.md"
    [ "$status" -eq 0 ]
    [ ! -f "$BORG_DIR/memory-hits.log" ]
}

@test "extracts the project dir segment correctly for nested memory paths" {
    local mem_dir="$HOME/.claude/projects/-Users-noah-dev-borg-collective/memory"
    mkdir -p "$mem_dir"
    printf 'hi' > "$mem_dir/project_cairn_overview.md"

    _run_hook "$mem_dir/project_cairn_overview.md"
    run cat "$BORG_DIR/memory-hits.log"
    [[ "$output" == *$'\t'"-Users-noah-dev-borg-collective"$'\t'"project_cairn_overview.md"$'\t'"2" ]]
}

@test "appends multiple reads across separate invocations" {
    local mem_dir="$HOME/.claude/projects/-Users-noah-dev-cairn/memory"
    mkdir -p "$mem_dir"
    printf 'a' > "$mem_dir/a.md"
    printf 'bb' > "$mem_dir/b.md"

    _run_hook "$mem_dir/a.md"
    _run_hook "$mem_dir/b.md"

    run wc -l < "$BORG_DIR/memory-hits.log"
    [[ "${output// /}" == "2" ]]
}

@test "handles missing session_id gracefully" {
    local mem_dir="$HOME/.claude/projects/-Users-noah-dev-cairn/memory"
    mkdir -p "$mem_dir"
    printf 'x' > "$mem_dir/MEMORY.md"

    local payload_file="${BATS_TEST_TMPDIR}/payload.json"
    jq -n --arg f "$mem_dir/MEMORY.md" '{tool_input:{file_path:$f}}' > "$payload_file"
    run bash -c "bash '$HOOK' < '$payload_file'"

    [ "$status" -eq 0 ]
    run cat "$BORG_DIR/memory-hits.log"
    [[ "$output" == *$'\t'"unknown"$'\t'* ]]
}

@test "never blocks: exits 0 even with empty stdin" {
    run bash -c "echo '' | bash '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "never blocks: exits 0 with malformed JSON" {
    run bash -c "echo 'not json' | bash '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "never blocks: exits 0 when file_path is missing from tool_input" {
    run bash -c "echo '{\"session_id\":\"x\",\"tool_input\":{}}' | bash '$HOOK'"
    [ "$status" -eq 0 ]
    [ ! -f "$BORG_DIR/memory-hits.log" ]
}
