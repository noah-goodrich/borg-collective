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
    export LOG_FILE="$XDG_STATE_HOME/borg/agents.jsonl"
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

# ─── warnings reach the user: systemMessage JSON on stdout ───────────────────
# A SubagentStop hook that exits 0 has stderr sent to the debug log only (Claude Code hooks
# reference, "Exit code 0"), so these warnings used to be invisible. The channel is ONE JSON object
# on stdout. Directive: docs/plans/directives/2026-10-04-stop-hook-warnings-are-invisible.md

# A non-final `[[ ]]` does not fail a test on bash 3.2 (macOS), so assert through functions.
_has() { [[ "$1" == *"$2"* ]] || { echo "missing: $2"; return 1; }; }
_lacks() { [[ "$1" != *"$2"* ]] || { echo "unexpected: $2"; return 1; }; }

_run_split() {
    HOOK_OUT=$(bash "$BORG_NANOPROBE_LOG" <<< "$1" 2>"${BATS_TEST_TMPDIR}/hook.err")
    HOOK_RC=$?
}

# A clone with an upstream and nothing ahead of it: the zero-commit condition.
_empty_branch_repo() {
    local origin="${BATS_TEST_TMPDIR}/origin.git" work="${BATS_TEST_TMPDIR}/work"
    git init -q --bare "$origin"
    git clone -q "$origin" "$work" 2>/dev/null
    git -C "$work" config user.email "test@test.com"
    git -C "$work" config user.name "Test"
    echo a > "$work/a.txt"
    git -C "$work" add a.txt
    git -C "$work" commit -q -m init
    git -C "$work" push -q origin HEAD 2>/dev/null
    git -C "$work" branch -q --set-upstream-to="origin/$(git -C "$work" rev-parse --abbrev-ref HEAD)" 2>/dev/null
    printf '%s' "$work"
}

@test "nanoprobe warnings: missing evidence arrives as systemMessage JSON on stdout, stderr empty" {
    _run_split "$(_probe_input "I completed the task successfully." "agent-noev1234")"
    [ "$HOOK_RC" -eq 0 ]
    printf '%s' "$HOOK_OUT" | jq -e . >/dev/null
    [ "$(printf '%s' "$HOOK_OUT" | jq -r 'keys | join(",")')" = "systemMessage" ]
    _has "$(printf '%s' "$HOOK_OUT" | jq -r .systemMessage)" "NANOPROBE EVIDENCE WARNING: agent-no"
    [ ! -s "${BATS_TEST_TMPDIR}/hook.err" ]
}

@test "nanoprobe warnings: zero-commit arrives as systemMessage, plain text" {
    local work
    work=$(_empty_branch_repo)
    _run_split "$(_probe_input "Edited lib/foo.sh:10 nothing landed." "agent-zero1234" "$work")"
    [ "$HOOK_RC" -eq 0 ]
    local msg
    msg=$(printf '%s' "$HOOK_OUT" | jq -r .systemMessage)
    _has "$msg" "NANOPROBE ZERO-COMMIT: agent-ze"
    _lacks "$msg" "EVIDENCE WARNING"
    [ ! -s "${BATS_TEST_TMPDIR}/hook.err" ]
}

@test "nanoprobe warnings: both conditions yield ONE object carrying both, with no ANSI" {
    local work
    work=$(_empty_branch_repo)
    _run_split "$(_probe_input "All done." "agent-both1234" "$work")"
    [ "$HOOK_RC" -eq 0 ]
    [ "$(printf '%s' "$HOOK_OUT" | jq -s length)" -eq 1 ]
    local msg esc
    msg=$(printf '%s' "$HOOK_OUT" | jq -r .systemMessage)
    _has "$msg" "EVIDENCE WARNING"
    _has "$msg" "ZERO-COMMIT"
    esc=$'\033'
    _lacks "$HOOK_OUT" "$esc"
    _lacks "$msg" "$esc"
    [ ! -s "${BATS_TEST_TMPDIR}/hook.err" ]
}

@test "nanoprobe warnings: evidence present and no git means empty stdout, exit 0, log still written" {
    _run_split "$(_probe_input "Updated hooks/borg-link-up.sh:78 to parse transcript_path.")"
    [ "$HOOK_RC" -eq 0 ]
    [ -z "$HOOK_OUT" ]
    [ ! -s "${BATS_TEST_TMPDIR}/hook.err" ]
    [ "$(wc -l < "$LOG_FILE" | tr -d ' ')" -eq 1 ]
}

@test "nanoprobe warnings: warning case still writes the JSONL record" {
    _run_split "$(_probe_input "All done." "agent-log12345")"
    [ "$(jq -r .id "$LOG_FILE")" = "agent-log12345" ]
    [ "$(jq -r .evidence_found "$LOG_FILE")" = "false" ]
}
