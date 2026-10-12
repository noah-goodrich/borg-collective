#!/usr/bin/env bats
# Untyped (empty / missing agent_type) subagent rows: the SubagentStop log hook skips or marks them,
# `borg nanoprobes` hides the empty ones, and the built plugin wires the hook with matcher .+.

load test_helper/setup

BORG_NANOPROBE_LOG="${BATS_TEST_DIRNAME}/../hooks/borg-nanoprobe-log.sh"
BORG="${BATS_TEST_DIRNAME}/../borg.zsh"
BUILD_PLUGIN="${BATS_TEST_DIRNAME}/../scripts/build-plugin.sh"

setup() {
    setup_temp_dirs
    export XDG_DATA_HOME="${BATS_TEST_TMPDIR}/data"
    export LOG_FILE="$XDG_STATE_HOME/borg/agents.jsonl"
}

row() {
    printf '{"id":"%s-0000-0000-0000-000000000000","agent_type":"borg-nanoprobe","summary":"s","finished_at":"2026-10-11T10:00:00Z","transcript_path":"%s"}\n' "$1" "$2" >> "$BORG_DIR/agents.jsonl"
}

# ─── internal agents (empty agent_type) are skipped ───────────────────────────

@test "nanoprobe log skips an empty agent_type: no row, no warnings" {
    run bash "$BORG_NANOPROBE_LOG" <<< "{\"agent_id\":\"internal-1\",\"agent_type\":\"\",\"agent_transcript_path\":\"\",\"last_assistant_message\":\"Recap of the session.\",\"cwd\":\"${BATS_TEST_TMPDIR}\"}"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ ! -s "$LOG_FILE" ]
}

@test "nanoprobe log records a payload with no agent_type key as agent_type ?" {
    run bash "$BORG_NANOPROBE_LOG" <<< "{\"agent_id\":\"unknown-1\",\"last_assistant_message\":\"x\",\"cwd\":\"${BATS_TEST_TMPDIR}\"}"
    [ "$status" -eq 0 ]
    [ -s "$LOG_FILE" ]
    [ "$(jq -r .agent_type "$LOG_FILE")" = "?" ]
}

# ─── borg nanoprobes hides empty-agent_type rows ──────────────────────────────

@test "nanoprobes: an empty-agent_type row is hidden from the list and from nanoprobe-log" {
    row dddd4444 "/nonexistent/x.jsonl"
    printf '{"id":"eeee5555-0000-0000-0000-000000000000","agent_type":"","summary":"away recap","finished_at":"2026-10-11T11:00:00Z","transcript_path":""}\n' >> "$BORG_DIR/agents.jsonl"
    run zsh "$BORG" nanoprobes
    [ "$status" -eq 0 ]
    [[ "$output" == *"dddd4444"* ]] || false
    [[ "$output" != *"eeee5555"* ]] || false
    [[ "$output" != *"away recap"* ]] || false
    run zsh "$BORG" nanoprobe-log eeee5555
    [ "$status" -ne 0 ]
    run zsh "$BORG" nanoprobe-log dddd4444
    [ "$status" -eq 0 ]
}

@test "nanoprobes: lists typed, ? and no-key rows, hides the empty one, tolerates a non-object line" {
    f="$BORG_DIR/agents.jsonl"
    printf '[1,2]\n' >> "$f"
    printf '{"id":"aaaa0001-0000-0000-0000-000000000000","summary":"nokey-sum","finished_at":"2026-10-11T10:01:00Z","transcript_path":""}\n' >> "$f"
    printf '{"id":"aaaa0002-0000-0000-0000-000000000000","agent_type":"?","summary":"q-sum","finished_at":"2026-10-11T10:02:00Z","transcript_path":""}\n' >> "$f"
    printf '{"id":"aaaa0003-0000-0000-0000-000000000000","agent_type":"","summary":"empty-sum","finished_at":"2026-10-11T10:03:00Z","transcript_path":""}\n' >> "$f"
    printf '{"id":"aaaa0004-0000-0000-0000-000000000000","agent_type":"borg-nanoprobe","summary":"typed-sum","finished_at":"2026-10-11T10:04:00Z","transcript_path":""}\n' >> "$f"
    run zsh "$BORG" nanoprobes
    [ "$status" -eq 0 ]
    [[ "$output" == *"aaaa0001"* ]] || false
    [[ "$output" == *"aaaa0002"* ]] || false
    [[ "$output" == *"aaaa0004"* ]] || false
    [[ "$output" != *"aaaa0003"* ]] || false
}

@test "nanoprobes: an empty-agent_type row that lives only in the rotated agents.jsonl.1 is hidden" {
    printf '{"id":"bbbb0001-0000-0000-0000-000000000000","agent_type":"","summary":"rotated-empty","finished_at":"2026-10-10T10:00:00Z","transcript_path":""}\n' > "$BORG_DIR/agents.jsonl.1"
    row bbbb0002 "/nonexistent/x.jsonl"
    run zsh "$BORG" nanoprobes
    [ "$status" -eq 0 ]
    [[ "$output" == *"bbbb0002"* ]] || false
    [[ "$output" != *"bbbb0001"* ]] || false
}

# ─── plugin wiring ────────────────────────────────────────────────────────────

@test "wiring: the BUILT plugin gives the SubagentStop nanoprobe-log entry matcher .+" {
    export BORG_ORCHESTRATOR_ROOT="${BATS_TEST_TMPDIR}/dev"
    export PLUGIN_DIR_OVERRIDE="${BATS_TEST_TMPDIR}/claude-plugins/borg-collective"
    [[ "$PLUGIN_DIR_OVERRIDE" == "$BATS_TEST_TMPDIR"/* ]] || false
    run bash "$BUILD_PLUGIN"
    [ "$status" -eq 0 ]
    run jq -r '[.hooks.SubagentStop[] | select(any(.hooks[]; .command | contains("borg-nanoprobe-log.sh"))) | .matcher] | join(",")' "$PLUGIN_DIR_OVERRIDE/hooks/hooks.json"
    [ "$status" -eq 0 ]
    [ "$output" = ".+" ]
}
