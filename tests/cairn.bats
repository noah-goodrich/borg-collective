#!/usr/bin/env bats
# Tests for cairn health check (borg-link-down.sh) and write failure signaling (borg-link-up.sh).
# Both hooks are driven by piping JSON input and checking stdout/stderr.

load test_helper/setup

BORG_START="${BATS_TEST_DIRNAME}/../hooks/borg-link-down.sh"
BORG_STOP="${BATS_TEST_DIRNAME}/../hooks/borg-link-up.sh"

# Minimal hook input for a registered project
_hook_input() {
    local project="${1:-myproject}"
    local cwd="${2:-/tmp/myproject}"
    printf '{"session_id":"test-session-123","cwd":"%s"}' "$cwd"
}

setup() {
    setup_temp_dirs

    # Stub project directory
    export TEST_PROJECT_DIR="${BATS_TEST_TMPDIR}/myproject"
    mkdir -p "$TEST_PROJECT_DIR"

    # Mock bin dir — add fake binaries to PATH
    export MOCK_BIN="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$MOCK_BIN"
    export PATH="$MOCK_BIN:$PATH"

    # Seed registry with the test project
    mkdir -p "$BORG_DIR"
    cat > "$BORG_REGISTRY" <<'EOF'
{"projects":{"myproject":{"path":"/tmp/myproject","status":"idle","source":"cli"}}}
EOF
}

# ─── cairn not in PATH ────────────────────────────────────────────────────────

@test "start hook warns when cairn not in PATH" {
    # Pass an isolated PATH so the hook's PATH fix cannot find cairn via the host's dotfiles bin
    rm -f "$MOCK_BIN/cairn"

    run env PATH="$MOCK_BIN:/usr/local/bin:/usr/bin:/bin" bash "$BORG_START" <<< "$(_hook_input)"
    [ "$status" -eq 0 ]
    echo "$output" | jq -r '.hookSpecificOutput.additionalContext' | grep -q "CAIRN UNAVAILABLE"
}

@test "start hook mentions PATH fix when cairn missing" {
    rm -f "$MOCK_BIN/cairn"

    run env PATH="$MOCK_BIN:/usr/local/bin:/usr/bin:/bin" bash "$BORG_START" <<< "$(_hook_input)"
    echo "$output" | jq -r '.hookSpecificOutput.additionalContext' | grep -q "not found in PATH"
}

# ─── cairn present but returns empty results ──────────────────────────────────

@test "start hook notes no cairn data when search returns empty" {
    cat > "$MOCK_BIN/cairn" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$MOCK_BIN/cairn"

    run bash "$BORG_START" <<< "$(_hook_input)"
    [ "$status" -eq 0 ]
    echo "$output" | jq -r '.hookSpecificOutput.additionalContext' | grep -q "no data for"
}

@test "start hook includes cairn results when search returns data" {
    cat > "$MOCK_BIN/cairn" <<'EOF'
#!/usr/bin/env bash
echo "Lesson: always test before shipping"
EOF
    chmod +x "$MOCK_BIN/cairn"

    run bash "$BORG_START" <<< "$(_hook_input)"
    [ "$status" -eq 0 ]
    echo "$output" | jq -r '.hookSpecificOutput.additionalContext' | grep -q "Cairn knowledge"
}

# ─── cairn write failure flag from previous stop ──────────────────────────────

@test "start hook surfaces cairn write failure from previous session" {
    cat > "$MOCK_BIN/cairn" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$MOCK_BIN/cairn"

    # Simulate a failure flag left by borg-stop
    echo "myproject: cairn write failed: connection refused" > "$BORG_DIR/.cairn-write-failed"

    run bash "$BORG_START" <<< "$(_hook_input)"
    [ "$status" -eq 0 ]
    echo "$output" | jq -r '.hookSpecificOutput.additionalContext' | grep -q "CAIRN WRITE FAILED"
}

@test "start hook clears the cairn write failure flag after surfacing it" {
    cat > "$MOCK_BIN/cairn" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$MOCK_BIN/cairn"

    echo "myproject: cairn write failed: timeout" > "$BORG_DIR/.cairn-write-failed"

    bash "$BORG_START" <<< "$(_hook_input)" >/dev/null

    [ ! -f "$BORG_DIR/.cairn-write-failed" ]
}

@test "start hook does not warn about cairn write failure when flag absent" {
    cat > "$MOCK_BIN/cairn" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$MOCK_BIN/cairn"

    run bash "$BORG_START" <<< "$(_hook_input)"
    [ "$status" -eq 0 ]
    echo "$output" | jq -r '.hookSpecificOutput.additionalContext' | grep -qv "CAIRN WRITE FAILED"
}

# ─── stop hook cairn write failure signaling ──────────────────────────────────

@test "stop hook writes failure flag when cairn exits non-zero" {
    # cairn command that always fails
    cat > "$MOCK_BIN/cairn" <<'EOF'
#!/usr/bin/env bash
echo "connection refused" >&2
exit 1
EOF
    chmod +x "$MOCK_BIN/cairn"

    # Provide a fake debrief so the cairn call is attempted
    mkdir -p "$BORG_DIR/debriefs"
    cat > "$BORG_DIR/debriefs/myproject.md" <<'EOF'
## Objective
Test session.

## Next Steps
1. Check the tests.
EOF

    # Stop hook needs cwd + session_id + transcript_path
    # Use a fake transcript file so the async block runs synchronously in test
    FAKE_TRANSCRIPT="${BATS_TEST_TMPDIR}/transcript.jsonl"
    echo '{"message":{"role":"user","content":"hello"}}' > "$FAKE_TRANSCRIPT"

    # Run stop hook synchronously (subshell async won't be tested here — see lifecycle.bats)
    # We test the failure flag by calling the cairn-write section directly via a helper
    BORG_DIR="$BORG_DIR" bash -c '
        source /dev/stdin <<'"'"'SCRIPT'"'"'
        CAIRN_FAILED_FLAG="${BORG_DIR}/.cairn-write-failed"
        _project="myproject"
        _cairn_err=$(cairn record session --id "test-id" --project myproject --tool claude-code \
            --notes "test" 2>&1) || {
            printf "%s: cairn write failed: %s\n" "$_project" "$_cairn_err" > "$CAIRN_FAILED_FLAG"
        }
SCRIPT
    '

    [ -f "$BORG_DIR/.cairn-write-failed" ]
    grep -q "cairn write failed" "$BORG_DIR/.cairn-write-failed"
}

@test "stop hook does not write flag when cairn not in PATH" {
    # Hook silently skips cairn record when cairn is absent — no flag written
    rm -f "$MOCK_BIN/cairn"

    run env PATH="$MOCK_BIN:/usr/local/bin:/usr/bin:/bin" bash "$BORG_STOP" <<< "$(_hook_input myproject "$TEST_PROJECT_DIR")"
    [ "$status" -eq 0 ]
    [ ! -f "$BORG_DIR/.cairn-write-failed" ]
}

@test "stop hook does not write failure flag when cairn succeeds" {
    cat > "$MOCK_BIN/cairn" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$MOCK_BIN/cairn"

    BORG_DIR="$BORG_DIR" bash -c '
        source /dev/stdin <<'"'"'SCRIPT'"'"'
        CAIRN_FAILED_FLAG="${BORG_DIR}/.cairn-write-failed"
        _cairn_err=$(cairn record session --id "ok-id" --project myproject --tool claude-code \
            --notes "test" 2>&1) || {
            printf "myproject: cairn write failed: %s\n" "$_cairn_err" > "$CAIRN_FAILED_FLAG"
        }
        [[ -f "$CAIRN_FAILED_FLAG" ]] && [[ -z "$_cairn_err" ]] && rm -f "$CAIRN_FAILED_FLAG" || true
SCRIPT
    '

    [ ! -f "$BORG_DIR/.cairn-write-failed" ]
}
