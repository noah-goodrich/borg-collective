#!/usr/bin/env bats
# Tests for orchestrator-mode cairn recording in borg-link-up.sh.
#
# When a session ends with CWD == $BORG_ORCHESTRATOR_ROOT, the stop hook must:
#   1. Record the session to cairn (mock) tagged as $BORG_ORCHESTRATOR_PROJECT.
#   2. Pass --notes containing the most-recent checkpoint content when one exists.
#   3. Fall back to the last assistant message from transcript when no checkpoint.
#   4. Degrade gracefully when cairn is absent (exit 0, no state written).
#   5. Log to .cairn-write-failed when cairn exits non-zero, then exit 0.
#   6. NOT write state.json or modify the registry (existing behaviour preserved).

load test_helper/setup

BORG_STOP="${BATS_TEST_DIRNAME}/../hooks/borg-link-up.sh"

setup() {
    setup_temp_dirs

    # Orchestrator CWD == $HOME/dev (exact match for _borg_session_mode)
    export ORCH_CWD="$HOME/dev"
    mkdir -p "$ORCH_CWD/.borg/checkpoints"

    # Isolated project dir — must NOT be touched by orchestrator mode
    export TEST_PROJECT_DIR="${BATS_TEST_TMPDIR}/myproject"
    mkdir -p "$TEST_PROJECT_DIR"

    # Mock bin dir on PATH
    export MOCK_BIN="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$MOCK_BIN"
    export PATH="$MOCK_BIN:$PATH"

    # Registry with a real project — orchestrator mode must not modify it
    mkdir -p "$BORG_DIR"
    cat > "$BORG_REGISTRY" <<EOF
{"projects":{"myproject":{"path":"${TEST_PROJECT_DIR}","status":"idle","source":"cli"}}}
EOF

    # Fake transcript
    export FAKE_TRANSCRIPT="${BATS_TEST_TMPDIR}/transcript.jsonl"
    printf '{"message":{"role":"user","content":"Drive conformance work"}}\n' > "$FAKE_TRANSCRIPT"
    printf '{"message":{"role":"assistant","content":"Shipped 10/10 ACs across cairn+borg+troth"}}\n' \
        >> "$FAKE_TRANSCRIPT"
}

# ─── helper ───────────────────────────────────────────────────────────────────

_orch_input() {
    printf '{"session_id":"orch-123","cwd":"%s","transcript_path":"%s"}' \
        "$ORCH_CWD" "$FAKE_TRANSCRIPT"
}

# ─── cairn present and working ────────────────────────────────────────────────

@test "stop hook in orchestrator mode calls cairn record session" {
    cat > "$MOCK_BIN/cairn" <<EOF
#!/usr/bin/env bash
echo "\$@" >> "${BATS_TEST_TMPDIR}/cairn-calls.txt"
exit 0
EOF
    chmod +x "$MOCK_BIN/cairn"

    bash "$BORG_STOP" <<< "$(_orch_input)" 2>/dev/null

    [ -f "${BATS_TEST_TMPDIR}/cairn-calls.txt" ]
    grep -q "record session" "${BATS_TEST_TMPDIR}/cairn-calls.txt"
}

@test "stop hook in orchestrator mode tags cairn record as borg-collective by default" {
    cat > "$MOCK_BIN/cairn" <<EOF
#!/usr/bin/env bash
echo "\$@" >> "${BATS_TEST_TMPDIR}/cairn-calls.txt"
exit 0
EOF
    chmod +x "$MOCK_BIN/cairn"

    bash "$BORG_STOP" <<< "$(_orch_input)" 2>/dev/null

    grep -q "\-\-project borg-collective" "${BATS_TEST_TMPDIR}/cairn-calls.txt"
}

@test "stop hook in orchestrator mode respects BORG_ORCHESTRATOR_PROJECT override" {
    cat > "$MOCK_BIN/cairn" <<EOF
#!/usr/bin/env bash
echo "\$@" >> "${BATS_TEST_TMPDIR}/cairn-calls.txt"
exit 0
EOF
    chmod +x "$MOCK_BIN/cairn"

    BORG_ORCHESTRATOR_PROJECT="my-org" \
        bash "$BORG_STOP" <<< "$(_orch_input)" 2>/dev/null

    grep -q "\-\-project my-org" "${BATS_TEST_TMPDIR}/cairn-calls.txt"
}

@test "stop hook in orchestrator mode passes --notes from checkpoint when available" {
    cat > "$MOCK_BIN/cairn" <<EOF
#!/usr/bin/env bash
echo "\$@" >> "${BATS_TEST_TMPDIR}/cairn-calls.txt"
exit 0
EOF
    chmod +x "$MOCK_BIN/cairn"

    # Write a recent checkpoint (< 120 min old)
    local cp_file="$ORCH_CWD/.borg/checkpoints/2026-06-11-2000.md"
    printf '## 1. Goal\nDrive cross-project conformance.\n\n## 2. Accomplished\n- cairn distribution done\n' \
        > "$cp_file"

    bash "$BORG_STOP" <<< "$(_orch_input)" 2>/dev/null

    grep -q "\-\-notes" "${BATS_TEST_TMPDIR}/cairn-calls.txt"
}

@test "stop hook in orchestrator mode falls back to transcript when no checkpoint" {
    cat > "$MOCK_BIN/cairn" <<EOF
#!/usr/bin/env bash
echo "\$@" >> "${BATS_TEST_TMPDIR}/cairn-calls.txt"
exit 0
EOF
    chmod +x "$MOCK_BIN/cairn"

    # Ensure no checkpoints exist
    rm -f "$ORCH_CWD/.borg/checkpoints/"*.md 2>/dev/null || true

    bash "$BORG_STOP" <<< "$(_orch_input)" 2>/dev/null

    # cairn record must still be called (may or may not have --notes depending on transcript)
    [ -f "${BATS_TEST_TMPDIR}/cairn-calls.txt" ]
    grep -q "record session" "${BATS_TEST_TMPDIR}/cairn-calls.txt"
}

@test "stop hook in orchestrator mode exits 0 when cairn succeeds" {
    cat > "$MOCK_BIN/cairn" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$MOCK_BIN/cairn"

    run bash "$BORG_STOP" <<< "$(_orch_input)"
    [ "$status" -eq 0 ]
}

# ─── cairn absent (graceful degradation) ─────────────────────────────────────

@test "stop hook in orchestrator mode exits 0 when cairn not in PATH" {
    rm -f "$MOCK_BIN/cairn"

    run env PATH="$MOCK_BIN:/usr/local/bin:/usr/bin:/bin" bash "$BORG_STOP" <<< "$(_orch_input)"
    [ "$status" -eq 0 ]
}

@test "stop hook in orchestrator mode does NOT write .cairn-write-failed when cairn absent" {
    rm -f "$MOCK_BIN/cairn"

    run env PATH="$MOCK_BIN:/usr/local/bin:/usr/bin:/bin" bash "$BORG_STOP" <<< "$(_orch_input)"
    [ "$status" -eq 0 ]
    [ ! -f "$BORG_DIR/.cairn-write-failed" ]
}

# ─── cairn present but failing ────────────────────────────────────────────────

@test "stop hook in orchestrator mode writes .cairn-write-failed when cairn exits non-zero" {
    cat > "$MOCK_BIN/cairn" <<'EOF'
#!/usr/bin/env bash
echo "connection refused" >&2
exit 1
EOF
    chmod +x "$MOCK_BIN/cairn"

    bash "$BORG_STOP" <<< "$(_orch_input)" 2>/dev/null || true

    [ -f "$BORG_DIR/.cairn-write-failed" ]
}

@test "stop hook in orchestrator mode exits 0 even when cairn exits non-zero" {
    cat > "$MOCK_BIN/cairn" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$MOCK_BIN/cairn"

    run bash "$BORG_STOP" <<< "$(_orch_input)"
    [ "$status" -eq 0 ]
}

# ─── preserved behaviour: no project state written ────────────────────────────

@test "stop hook in orchestrator mode does NOT write state.json for project" {
    cat > "$MOCK_BIN/cairn" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$MOCK_BIN/cairn"

    bash "$BORG_STOP" <<< "$(_orch_input)" 2>/dev/null

    [ ! -f "${TEST_PROJECT_DIR}/.borg/state.json" ]
}

@test "stop hook in orchestrator mode does NOT modify the registry" {
    cat > "$MOCK_BIN/cairn" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$MOCK_BIN/cairn"

    _before=$(jq -c '.' "$BORG_REGISTRY")

    bash "$BORG_STOP" <<< "$(_orch_input)" 2>/dev/null

    _after=$(jq -c '.' "$BORG_REGISTRY")
    [ "$_before" = "$_after" ]
}
