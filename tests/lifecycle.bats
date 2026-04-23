#!/usr/bin/env bats
# Integration tests for the full session context lifecycle:
#   borg-link-down.sh → context injection (including latest checkpoint) → borg-link-up.sh
#   → registry update + nudge if no recent checkpoint
#
# Note: debrief LLM generation and cairn auto-commit were removed 2026-04-23; these tests
# may have scenarios that no longer apply. Tests referencing those paths should be culled.

load test_helper/setup

BORG_START="${BATS_TEST_DIRNAME}/../hooks/borg-link-down.sh"
BORG_STOP="${BATS_TEST_DIRNAME}/../hooks/borg-link-up.sh"

_start_input() {
    local cwd="${1:-$TEST_CWD}"
    printf '{"session_id":"sess-abc","cwd":"%s"}' "$cwd"
}

_stop_input() {
    local cwd="${1:-$TEST_CWD}"
    local transcript="${2:-$FAKE_TRANSCRIPT}"
    printf '{"session_id":"sess-abc","cwd":"%s","transcript_path":"%s"}' "$cwd" "$transcript"
}

setup() {
    setup_temp_dirs

    # Project directory (real dir for git checks)
    export TEST_CWD="${BATS_TEST_TMPDIR}/myproject"
    mkdir -p "$TEST_CWD"

    # Mock bin dir
    export MOCK_BIN="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$MOCK_BIN"
    export PATH="$MOCK_BIN:$PATH"

    # Fake transcript with one user message and one assistant message
    FAKE_TRANSCRIPT="${BATS_TEST_TMPDIR}/transcript.jsonl"
    printf '{"message":{"role":"user","content":"Fix the login bug"}}\n' > "$FAKE_TRANSCRIPT"
    printf '{"message":{"role":"assistant","content":"I fixed it. Run the tests next."}}\n' >> "$FAKE_TRANSCRIPT"

    # Seed registry
    mkdir -p "$BORG_DIR"
    cat > "$BORG_REGISTRY" <<'EOF'
{"projects":{"myproject":{"path":"/tmp/myproject","status":"idle","source":"cli"}}}
EOF

    # Mock cairn: always succeeds, returns empty search results
    cat > "$MOCK_BIN/cairn" <<'EOF'
#!/usr/bin/env bash
# cairn mock: record always succeeds; search returns nothing
case "$1" in
    record) exit 0 ;;
    search) exit 0 ;;
    *) exit 0 ;;
esac
EOF
    chmod +x "$MOCK_BIN/cairn"

    # Mock claude: generate a fake debrief
    cat > "$MOCK_BIN/claude" <<'EOF'
#!/usr/bin/env bash
cat <<'DEBRIEF'
## Objective
Fix the login bug by correcting the JWT validation logic.

## Outcome
- Modified auth/jwt.py: fixed token expiry check
- All tests passing

## Next Steps
1. Deploy to staging and verify with QA.
DEBRIEF
EOF
    chmod +x "$MOCK_BIN/claude"
}

# ─── start hook registry update ───────────────────────────────────────────────

@test "start hook sets project status to active" {
    bash "$BORG_START" <<< "$(_start_input)" >/dev/null

    status=$(jq -r '.projects.myproject.status' "$BORG_REGISTRY")
    [ "$status" = "active" ]
}

@test "start hook records session_id in registry" {
    bash "$BORG_START" <<< "$(_start_input)" >/dev/null

    sid=$(jq -r '.projects.myproject.claude_session_id' "$BORG_REGISTRY")
    [ "$sid" = "sess-abc" ]
}

@test "start hook exits 0 for unknown project (not in registry)" {
    unknown_cwd="${BATS_TEST_TMPDIR}/unknown-project"
    mkdir -p "$unknown_cwd"
    run bash "$BORG_START" <<< "$(_start_input "$unknown_cwd")"
    [ "$status" -eq 0 ]
}

# ─── start hook context injection ─────────────────────────────────────────────

@test "start hook emits additionalContext JSON" {
    run bash "$BORG_START" <<< "$(_start_input)"
    [ "$status" -eq 0 ]
    echo "$output" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null
}

@test "start hook includes uncommitted-changes reminder when flag set" {
    # Set the flag in registry
    jq '.projects.myproject.has_uncommitted_changes = true' "$BORG_REGISTRY" > "${BORG_REGISTRY}.tmp" \
        && mv "${BORG_REGISTRY}.tmp" "$BORG_REGISTRY"

    run bash "$BORG_START" <<< "$(_start_input)"
    [ "$status" -eq 0 ]
    echo "$output" | jq -r '.hookSpecificOutput.additionalContext' | grep -q "uncommitted changes"
}

# ─── stop hook registry update ────────────────────────────────────────────────

@test "stop hook sets project status to idle" {
    # First mark project as active
    jq '.projects.myproject.status = "active"' "$BORG_REGISTRY" > "${BORG_REGISTRY}.tmp" \
        && mv "${BORG_REGISTRY}.tmp" "$BORG_REGISTRY"

    bash "$BORG_STOP" <<< "$(_stop_input)" 2>/dev/null

    status=$(jq -r '.projects.myproject.status' "$BORG_REGISTRY")
    [ "$status" = "idle" ]
}

@test "stop hook records session_id in registry" {
    bash "$BORG_STOP" <<< "$(_stop_input)" 2>/dev/null

    sid=$(jq -r '.projects.myproject.claude_session_id' "$BORG_REGISTRY")
    [ "$sid" = "sess-abc" ]
}

@test "stop hook exits 0 when cwd missing from input" {
    run bash "$BORG_STOP" <<< '{"session_id":"test"}'
    [ "$status" -eq 0 ]
}

@test "stop hook exits 0 when registry does not exist" {
    rm -f "$BORG_REGISTRY"
    run bash "$BORG_STOP" <<< "$(_stop_input)"
    [ "$status" -eq 0 ]
}

# ─── stop hook uncommitted changes detection ──────────────────────────────────

@test "stop hook sets has_uncommitted_changes false for non-git directory" {
    bash "$BORG_STOP" <<< "$(_stop_input)" 2>/dev/null

    flag=$(jq -r '.projects.myproject.has_uncommitted_changes' "$BORG_REGISTRY")
    [ "$flag" = "false" ]
}

@test "stop hook sets has_uncommitted_changes true for git repo with dirty state" {
    git -C "$TEST_CWD" init -q
    git -C "$TEST_CWD" config user.email "test@test.com"
    git -C "$TEST_CWD" config user.name "Test"
    # Commit a file first, then modify it — shows as "M " (tracked change, not "??")
    echo "original" > "$TEST_CWD/tracked.txt"
    git -C "$TEST_CWD" add tracked.txt
    git -C "$TEST_CWD" commit -q -m "initial"
    echo "modified" > "$TEST_CWD/tracked.txt"

    bash "$BORG_STOP" <<< "$(_stop_input "$TEST_CWD")" 2>/dev/null

    flag=$(jq -r '.projects.myproject.has_uncommitted_changes' "$BORG_REGISTRY")
    [ "$flag" = "true" ]
}

# ─── .borg-project marker resolution ─────────────────────────────────────────

@test "start hook resolves project from .borg-project marker in CWD" {
    # Simulate a container path whose basename != registry key
    local container_dir="${BATS_TEST_TMPDIR}/snowfort-audit"
    mkdir -p "$container_dir"
    echo "snowfort" > "$container_dir/.borg-project"

    # Registry uses the canonical name "snowfort"
    cat > "$BORG_REGISTRY" <<'EOF'
{"projects":{"snowfort":{"path":"/dev/snowfort","status":"idle","source":"cli"}}}
EOF

    bash "$BORG_START" <<< "$(_start_input "$container_dir")" >/dev/null

    status=$(jq -r '.projects.snowfort.status' "$BORG_REGISTRY")
    [ "$status" = "active" ]
}

@test "start hook resolves project from .borg-project marker in ancestor dir" {
    # Simulate Claude CWD being a subdirectory (e.g. src/api) inside the mount
    local container_dir="${BATS_TEST_TMPDIR}/snowfort-audit"
    local sub_dir="$container_dir/src/api"
    mkdir -p "$sub_dir"
    echo "snowfort" > "$container_dir/.borg-project"

    cat > "$BORG_REGISTRY" <<'EOF'
{"projects":{"snowfort":{"path":"/dev/snowfort","status":"idle","source":"cli"}}}
EOF

    bash "$BORG_START" <<< "$(_start_input "$sub_dir")" >/dev/null

    status=$(jq -r '.projects.snowfort.status' "$BORG_REGISTRY")
    [ "$status" = "active" ]
}

@test "stop hook resolves project from .borg-project marker in ancestor dir" {
    local container_dir="${BATS_TEST_TMPDIR}/snowfort-audit"
    local sub_dir="$container_dir/src/api"
    mkdir -p "$sub_dir"
    echo "snowfort" > "$container_dir/.borg-project"

    cat > "$BORG_REGISTRY" <<'EOF'
{"projects":{"snowfort":{"path":"/dev/snowfort","status":"active","source":"cli"}}}
EOF

    bash "$BORG_STOP" <<< "$(_stop_input "$sub_dir")" 2>/dev/null

    status=$(jq -r '.projects.snowfort.status' "$BORG_REGISTRY")
    [ "$status" = "idle" ]
}

@test "start hook falls back to basename when no .borg-project marker exists" {
    # Standard host session: no marker, basename matches registry key
    bash "$BORG_START" <<< "$(_start_input)" >/dev/null

    status=$(jq -r '.projects.myproject.status' "$BORG_REGISTRY")
    [ "$status" = "active" ]
}

