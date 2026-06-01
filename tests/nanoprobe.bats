#!/usr/bin/env bats
# Tests for borg-nanoprobe-log.sh — evidence gate scoring and agents.jsonl logging.

load test_helper/setup

BORG_NANOPROBE_LOG="${BATS_TEST_DIRNAME}/../hooks/borg-nanoprobe-log.sh"

_probe_input() {
    local msg="${1:-}"
    local agent_id="${2:-agent-abc123}"
    local cwd="${3:-${BATS_TEST_TMPDIR}}"
    printf '{"agent_id":"%s","agent_type":"borg-nanoprobe","agent_transcript_path":"","last_assistant_message":"%s","cwd":"%s"}' \
        "$agent_id" "$msg" "$cwd"
}

setup() {
    setup_temp_dirs
    export LOG_FILE="$BORG_DIR/agents.jsonl"
}

# ─── basic logging ────────────────────────────────────────────────────────────

@test "nanoprobe log exits 0 on empty input" {
    run bash "$BORG_NANOPROBE_LOG" <<< ""
    [ "$status" -eq 0 ]
}

@test "nanoprobe log exits 0 with valid input" {
    run bash "$BORG_NANOPROBE_LOG" <<< "$(_probe_input "Work done.")"
    [ "$status" -eq 0 ]
}

@test "nanoprobe log appends one line to agents.jsonl" {
    bash "$BORG_NANOPROBE_LOG" <<< "$(_probe_input "Some work done.")"

    line_count=$(wc -l < "$LOG_FILE" | tr -d ' ')
    [ "$line_count" -eq 1 ]
}

@test "nanoprobe log record contains required fields" {
    bash "$BORG_NANOPROBE_LOG" <<< "$(_probe_input "Work done." "probe-xyz")"

    id=$(jq -r '.id' "$LOG_FILE")
    status=$(jq -r '.status' "$LOG_FILE")
    [ "$id" = "probe-xyz" ]
    [ "$status" = "completed" ]
}

# ─── evidence gate: score 0 (no file references) ─────────────────────────────

@test "evidence_found false when last_assistant_message has no file references" {
    bash "$BORG_NANOPROBE_LOG" <<< "$(_probe_input "I completed the task successfully.")"

    found=$(jq -r '.evidence_found' "$LOG_FILE")
    score=$(jq -r '.evidence_score' "$LOG_FILE")
    [ "$found" = "false" ]
    [ "$score" -eq 0 ]
}

@test "evidence gate prints stderr warning when no evidence found" {
    run bash "$BORG_NANOPROBE_LOG" <<< "$(_probe_input "I completed the task successfully.")"
    [ "$status" -eq 0 ]
    echo "$output" | grep -qi "evidence"
}

# ─── evidence gate: score 1 (bare filename) ───────────────────────────────────

@test "evidence_found true when message mentions a filename with extension" {
    bash "$BORG_NANOPROBE_LOG" \
        <<< "$(_probe_input "I modified borg-hooks.sh to add the helper.")"

    found=$(jq -r '.evidence_found' "$LOG_FILE")
    score=$(jq -r '.evidence_score' "$LOG_FILE")
    [ "$found" = "true" ]
    [ "$score" -ge 1 ]
}

# ─── evidence gate: score 2 (path:line citation) ─────────────────────────────

@test "evidence_score 2 when message contains path:line citation" {
    bash "$BORG_NANOPROBE_LOG" \
        <<< "$(_probe_input "Fixed the bug at lib/borg-hooks.sh:42 — changed the condition.")"

    found=$(jq -r '.evidence_found' "$LOG_FILE")
    score=$(jq -r '.evidence_score' "$LOG_FILE")
    [ "$found" = "true" ]
    [ "$score" -ge 2 ]
}

@test "no stderr warning when evidence is found" {
    run bash "$BORG_NANOPROBE_LOG" \
        <<< "$(_probe_input "Updated hooks/borg-link-up.sh:78 to parse transcript_path.")"
    [ "$status" -eq 0 ]
    ! echo "$output" | grep -q "EVIDENCE WARNING"
}

# ─── evidence gate: score 3 (path:line + git diff) ───────────────────────────

@test "evidence_score 3 when path:line citation and git repo has unstaged changes" {
    local proj_dir="${BATS_TEST_TMPDIR}/proj-with-diff"
    mkdir -p "$proj_dir"
    git -C "$proj_dir" init -q
    git -C "$proj_dir" config user.email "test@test.com"
    git -C "$proj_dir" config user.name "Test"
    echo "original" > "$proj_dir/file.sh"
    git -C "$proj_dir" add file.sh
    git -C "$proj_dir" commit -q -m "initial"
    echo "modified" > "$proj_dir/file.sh"

    bash "$BORG_NANOPROBE_LOG" \
        <<< "$(_probe_input "Fixed lib/hooks.sh:10 in the repo." "agent-git" "$proj_dir")"

    score=$(jq -r '.evidence_score' "$LOG_FILE")
    [ "$score" -eq 3 ]
}

# ─── multiple runs accumulate ─────────────────────────────────────────────────

@test "multiple nanoprobe runs append multiple lines" {
    bash "$BORG_NANOPROBE_LOG" <<< "$(_probe_input "Run 1." "probe-1")"
    bash "$BORG_NANOPROBE_LOG" <<< "$(_probe_input "lib/foo.sh:10" "probe-2")"
    bash "$BORG_NANOPROBE_LOG" <<< "$(_probe_input "Run 3." "probe-3")"

    line_count=$(wc -l < "$LOG_FILE" | tr -d ' ')
    [ "$line_count" -eq 3 ]
}
