#!/usr/bin/env bats
# Tests for hooks/borg-plan-promote.sh — auto-promote ExitPlanMode plan to PROJECT_PLAN.md.
#
# Hook behavior:
#   - Project-mode + ExitPlanMode in transcript (since last user turn) + no PROJECT_PLAN → writes file
#   - Project-mode + ExitPlanMode + existing PROJECT_PLAN → no write, exit 0
#   - Project-mode + no ExitPlanMode in transcript → no write, exit 0
#   - Orchestrator-mode (cwd == BORG_ORCHESTRATOR_ROOT) → no write, exit 0
#   - Edit target outside repo → no write, exit 0
#   - ExitPlanMode from prior user turn (not current) → no write, exit 0

load test_helper/setup

HOOK="${BATS_TEST_DIRNAME}/../hooks/borg-plan-promote.sh"
LIB="${BATS_TEST_DIRNAME}/../lib/borg-hooks.sh"

# Build a minimal PreToolUse input JSON for an Edit tool call.
# Arguments: session_id cwd file_path
_make_edit_input() {
    local session_id="$1" cwd="$2" file_path="$3"
    jq -nc \
        --arg sid "$session_id" \
        --arg cwd "$cwd" \
        --arg fp  "$file_path" \
        '{tool_name: "Edit", session_id: $sid, cwd: $cwd, tool_input: {file_path: $fp}}'
}

# Build a minimal PreToolUse input JSON for a Write tool call.
_make_write_input() {
    local session_id="$1" cwd="$2" file_path="$3"
    jq -nc \
        --arg sid "$session_id" \
        --arg cwd "$cwd" \
        --arg fp  "$file_path" \
        '{tool_name: "Write", session_id: $sid, cwd: $cwd, tool_input: {file_path: $fp}}'
}

# Write a fixture JSONL with a single user turn (non-meta) followed by an
# assistant message containing ExitPlanMode.
# Arguments: jsonl_path plan_text
_write_jsonl_with_plan() {
    local path="$1" plan_text="$2"
    mkdir -p "${path%/*}"
    jq -nc --arg plan "$plan_text" '
        {"type":"user","isMeta":false,"uuid":"u1","message":{"role":"user","content":"do the thing"}}
    ' > "$path"
    jq -nc --arg plan "$plan_text" '
        {
            "type": "assistant",
            "uuid": "a1",
            "message": {
                "role": "assistant",
                "content": [
                    {
                        "type": "tool_use",
                        "id": "tu1",
                        "name": "ExitPlanMode",
                        "input": {"plan": $plan}
                    }
                ]
            }
        }
    ' >> "$path"
}

# Write a fixture JSONL with ExitPlanMode in a PRIOR user turn (before a newer user message).
_write_jsonl_plan_prior_turn() {
    local path="$1" plan_text="$2"
    mkdir -p "${path%/*}"
    jq -nc --arg plan "$plan_text" '
        {"type":"user","isMeta":false,"uuid":"u0","message":{"role":"user","content":"plan first"}}
    ' > "$path"
    jq -nc --arg plan "$plan_text" '
        {
            "type": "assistant",
            "uuid": "a0",
            "message": {
                "role": "assistant",
                "content": [
                    {
                        "type": "tool_use",
                        "id": "tu0",
                        "name": "ExitPlanMode",
                        "input": {"plan": $plan}
                    }
                ]
            }
        }
    ' >> "$path"
    jq -nc '{"type":"user","isMeta":false,"uuid":"u1","message":{"role":"user","content":"now implement"}}' >> "$path"
}

# Write a fixture JSONL with NO ExitPlanMode at all.
_write_jsonl_no_plan() {
    local path="$1"
    mkdir -p "${path%/*}"
    jq -nc '{"type":"user","isMeta":false,"uuid":"u1","message":{"role":"user","content":"write stuff"}}' > "$path"
    jq -nc '{"type":"assistant","uuid":"a1","message":{"role":"assistant","content":[{"type":"text","text":"ok"}]}}' >> "$path"
}

setup() {
    setup_temp_dirs

    # Create an isolated fake git repo for tests to use as a repo root.
    FAKE_REPO="${BATS_TEST_TMPDIR}/myproject"
    mkdir -p "$FAKE_REPO"
    git -C "$FAKE_REPO" init -q
    git -C "$FAKE_REPO" config user.email "test@test.com"
    git -C "$FAKE_REPO" config user.name "Test"
    touch "$FAKE_REPO/README.md"
    git -C "$FAKE_REPO" add README.md
    git -C "$FAKE_REPO" commit -q -m "init"

    # Session ID used in tests
    SESSION_ID="test-session-$(date +%s)"

    # Construct the Claude projects dir under the fake HOME so the hook can find JSONL.
    # Encoding: replace every / in FAKE_REPO with -
    _encoded="${FAKE_REPO//\//-}"
    JSONL_DIR="${BORG_TEST_HOME}/.claude/projects/${_encoded}"
    JSONL_PATH="${JSONL_DIR}/${SESSION_ID}.jsonl"

    # Make the hook source lib from the fake HOME's installed copy.
    mkdir -p "${BORG_TEST_HOME}/.claude/lib"
    cp "$LIB" "${BORG_TEST_HOME}/.claude/lib/borg-hooks.sh"

    PLAN_PRIMARY="${FAKE_REPO}/docs/plans/PROJECT_PLAN.md"
    PLAN_FALLBACK="${FAKE_REPO}/PROJECT_PLAN.md"
}

# ── Helper to run the hook with controlled HOME ───────────────────────────────

_run_hook() {
    local input="$1"
    HOME="$BORG_TEST_HOME" \
    BORG_ORCHESTRATOR_ROOT="${BORG_TEST_HOME}/dev" \
        run bash "$HOOK" <<< "$input"
}

# ── Tests ─────────────────────────────────────────────────────────────────────

@test "plan_promote: project-mode + ExitPlanMode + no PROJECT_PLAN → writes file, exits 0" {
    _write_jsonl_with_plan "$JSONL_PATH" "# My Plan\n\nDo the thing."

    input=$(_make_edit_input "$SESSION_ID" "$FAKE_REPO" "${FAKE_REPO}/src/main.py")
    _run_hook "$input"

    [ "$status" -eq 0 ]
    [ -f "$PLAN_PRIMARY" ]
    grep -q "My Plan" "$PLAN_PRIMARY"
}

@test "plan_promote: written file includes auto-promotion header comment" {
    _write_jsonl_with_plan "$JSONL_PATH" "# Plan\n\nObjective: ship it."

    input=$(_make_edit_input "$SESSION_ID" "$FAKE_REPO" "${FAKE_REPO}/src/app.py")
    _run_hook "$input"

    [ "$status" -eq 0 ]
    grep -q "auto-promoted" "$PLAN_PRIMARY"
}

@test "plan_promote: stderr message emitted on successful promotion" {
    _write_jsonl_with_plan "$JSONL_PATH" "# Plan\n\nGoal: done."

    input=$(_make_edit_input "$SESSION_ID" "$FAKE_REPO" "${FAKE_REPO}/src/app.py")
    HOME="$BORG_TEST_HOME" \
    BORG_ORCHESTRATOR_ROOT="${BORG_TEST_HOME}/dev" \
        run bash -c "bash '$HOOK' <<< '$input' 2>&1 1>/dev/null"

    [[ "$output" == *"auto-promoted"* ]]
}

@test "plan_promote: Write tool also triggers promotion" {
    _write_jsonl_with_plan "$JSONL_PATH" "# Plan\n\nWrite version."

    input=$(_make_write_input "$SESSION_ID" "$FAKE_REPO" "${FAKE_REPO}/config.yaml")
    _run_hook "$input"

    [ "$status" -eq 0 ]
    [ -f "$PLAN_PRIMARY" ]
}

@test "plan_promote: existing PROJECT_PLAN at docs/plans/ → no overwrite, exits 0" {
    _write_jsonl_with_plan "$JSONL_PATH" "# New Plan\n\nThis should not overwrite."
    mkdir -p "${FAKE_REPO}/docs/plans"
    printf '# Existing Plan\n' > "$PLAN_PRIMARY"

    input=$(_make_edit_input "$SESSION_ID" "$FAKE_REPO" "${FAKE_REPO}/src/main.py")
    _run_hook "$input"

    [ "$status" -eq 0 ]
    grep -q "Existing Plan" "$PLAN_PRIMARY"
    ! grep -q "New Plan" "$PLAN_PRIMARY"
}

@test "plan_promote: existing PROJECT_PLAN at repo root → no write, exits 0" {
    _write_jsonl_with_plan "$JSONL_PATH" "# New Plan\n\nShould not write."
    printf '# Root Plan\n' > "$PLAN_FALLBACK"

    input=$(_make_edit_input "$SESSION_ID" "$FAKE_REPO" "${FAKE_REPO}/src/main.py")
    _run_hook "$input"

    [ "$status" -eq 0 ]
    [ ! -f "$PLAN_PRIMARY" ]
}

@test "plan_promote: no ExitPlanMode in transcript → no write, exits 0" {
    _write_jsonl_no_plan "$JSONL_PATH"

    input=$(_make_edit_input "$SESSION_ID" "$FAKE_REPO" "${FAKE_REPO}/src/main.py")
    _run_hook "$input"

    [ "$status" -eq 0 ]
    [ ! -f "$PLAN_PRIMARY" ]
}

@test "plan_promote: orchestrator-mode → no write, exits 0" {
    _write_jsonl_with_plan "$JSONL_PATH" "# Orchestrator Plan"

    input=$(_make_edit_input "$SESSION_ID" "${BORG_TEST_HOME}/dev" "${BORG_TEST_HOME}/dev/something.py")
    HOME="$BORG_TEST_HOME" \
    BORG_ORCHESTRATOR_ROOT="${BORG_TEST_HOME}/dev" \
        run bash "$HOOK" <<< "$input"

    [ "$status" -eq 0 ]
    [ ! -f "$PLAN_PRIMARY" ]
}

@test "plan_promote: edit target outside repo → no write, exits 0" {
    _write_jsonl_with_plan "$JSONL_PATH" "# Outside Plan"

    OUTSIDE="${BATS_TEST_TMPDIR}/outside/file.py"
    input=$(_make_edit_input "$SESSION_ID" "$FAKE_REPO" "$OUTSIDE")
    _run_hook "$input"

    [ "$status" -eq 0 ]
    [ ! -f "$PLAN_PRIMARY" ]
}

@test "plan_promote: ExitPlanMode from prior user turn (new user msg follows) → no write" {
    _write_jsonl_plan_prior_turn "$JSONL_PATH" "# Old Plan"

    input=$(_make_edit_input "$SESSION_ID" "$FAKE_REPO" "${FAKE_REPO}/src/main.py")
    _run_hook "$input"

    [ "$status" -eq 0 ]
    [ ! -f "$PLAN_PRIMARY" ]
}

@test "plan_promote: missing JSONL file → no write, exits 0 (never blocks)" {
    input=$(_make_edit_input "nonexistent-session" "$FAKE_REPO" "${FAKE_REPO}/src/main.py")
    _run_hook "$input"

    [ "$status" -eq 0 ]
    [ ! -f "$PLAN_PRIMARY" ]
}

@test "plan_promote: empty session_id in input → exits 0 cleanly" {
    input='{"tool_name":"Edit","session_id":"","cwd":"'"$FAKE_REPO"'","tool_input":{"file_path":"'"${FAKE_REPO}/src/x.py"'"}}'
    _run_hook "$input"

    [ "$status" -eq 0 ]
}

@test "plan_promote: edit targeting .claude global config → no write, exits 0" {
    _write_jsonl_with_plan "$JSONL_PATH" "# Should not write for .claude edit"

    input=$(_make_edit_input "$SESSION_ID" "$FAKE_REPO" "${BORG_TEST_HOME}/.claude/settings.json")
    _run_hook "$input"

    [ "$status" -eq 0 ]
    [ ! -f "$PLAN_PRIMARY" ]
}

@test "plan_promote: docs/plans/ directory created if missing" {
    _write_jsonl_with_plan "$JSONL_PATH" "# Plan\n\nCreate the dir."
    [ ! -d "${FAKE_REPO}/docs/plans" ]

    input=$(_make_edit_input "$SESSION_ID" "$FAKE_REPO" "${FAKE_REPO}/src/main.py")
    _run_hook "$input"

    [ "$status" -eq 0 ]
    [ -d "${FAKE_REPO}/docs/plans" ]
    [ -f "$PLAN_PRIMARY" ]
}
