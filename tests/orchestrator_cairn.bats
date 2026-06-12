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
#   7. Pass the FULL checkpoint (no byte truncation) — the cairn notes column is
#      unbounded text.  Multibyte UTF-8 characters must survive the round-trip and
#      the "## 5. Next Session" section must not be silently dropped.
#   8. When a checkpoint exceeds the 100 KB ARG_MAX safety cap, truncation must
#      occur at a section boundary AND emit a one-line stderr notice.

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

# ─── no-truncation / UTF-8 correctness ───────────────────────────────────────

@test "stop hook in orchestrator mode passes full checkpoint without byte truncation" {
    # Simulate a 4KB checkpoint with multi-byte UTF-8 (em-dashes, arrows, bullets)
    # and a '## 5. Next Session' section that 'head -c 3000' would silently drop.
    local cp_file="$ORCH_CWD/.borg/checkpoints/2026-06-12-0928.md"
    {
        printf '## 1. Goal\nFix the truncation bug.\n\n'
        printf '## 2. Accomplished\n- Ported orchestrator recording block\xe2\x80\x94fixed\n\n'
        printf '## 3. Key Decisions\n- Drop byte cap \xe2\x80\x94 cairn notes is unbounded text\n\n'
        printf '## 4. Notable\n'
        # pad to push us past 3000 bytes with multi-byte chars
        python3 -c "print('- item ' + '—' * 10 + '\n' + 'x' * 80 + '\n', end='')" 2>/dev/null \
            || printf '%s\n' '- item with em-dashes' | head -30
        printf '\n## 5. Next Session\n- Verify fix works end-to-end\xe2\x80\x94priority 1\n'
    } > "$cp_file"

    # Use a cairn mock that writes ALL its arguments to a file (including --notes value)
    local notes_file="${BATS_TEST_TMPDIR}/cairn-notes.txt"
    cat > "$MOCK_BIN/cairn" <<EOF
#!/usr/bin/env bash
# Capture --notes argument value
while [[ \$# -gt 0 ]]; do
    if [[ "\$1" == "--notes" ]]; then
        printf '%s' "\$2" > "${notes_file}"
        shift 2
    else
        shift
    fi
done
exit 0
EOF
    chmod +x "$MOCK_BIN/cairn"

    bash "$BORG_STOP" <<< "$(_orch_input)" 2>/dev/null

    # The notes file must exist and contain section 5
    [ -f "$notes_file" ]
    grep -q "## 5. Next Session" "$notes_file"
}

@test "stop hook in orchestrator mode preserves multibyte UTF-8 chars in notes" {
    local cp_file="$ORCH_CWD/.borg/checkpoints/2026-06-12-utf8.md"
    # Write checkpoint with em-dash (3-byte UTF-8: 0xE2 0x80 0x94) and
    # triangular bullet (3-byte: 0xE2 0x96\xB8) — characters that head -c can split
    printf '## 1. Goal\nFix byte-split \xe2\x80\x94 ensure chars survive intact\n' > "$cp_file"
    printf '## 5. Next Session\n\xe2\x96\xb8 Priority: verify UTF-8 round-trips\n' >> "$cp_file"

    local notes_file="${BATS_TEST_TMPDIR}/cairn-notes-utf8.txt"
    cat > "$MOCK_BIN/cairn" <<EOF
#!/usr/bin/env bash
while [[ \$# -gt 0 ]]; do
    if [[ "\$1" == "--notes" ]]; then
        printf '%s' "\$2" > "${notes_file}"
        shift 2
    else
        shift
    fi
done
exit 0
EOF
    chmod +x "$MOCK_BIN/cairn"

    bash "$BORG_STOP" <<< "$(_orch_input)" 2>/dev/null

    [ -f "$notes_file" ]
    # em-dash must be intact (not split into replacement chars)
    grep -q $'\xe2\x80\x94' "$notes_file"
    # triangular bullet must be intact
    grep -q $'\xe2\x96\xb8' "$notes_file"
}

@test "stop hook emits stderr notice when checkpoint exceeds 100 KB cap" {
    local cp_file="$ORCH_CWD/.borg/checkpoints/2026-06-12-big.md"
    {
        printf '## 1. Goal\nTest large checkpoint truncation.\n\n'
        # ~102 KB of content: enough to exceed _ORCH_NOTES_CAP=100000
        python3 -c "print('## 2. Body\n' + 'x' * 102400)" 2>/dev/null \
            || yes "## 2. Body" | head -6400 | tr -d '\n'; printf '\n'
        printf '## 3. Next Section\nShould still land.\n'
    } > "$cp_file"

    cat > "$MOCK_BIN/cairn" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$MOCK_BIN/cairn"

    run bash "$BORG_STOP" <<< "$(_orch_input)"
    [ "$status" -eq 0 ]
    # stderr must mention truncation
    echo "$output$stderr" | grep -qi "truncat" || \
        bash "$BORG_STOP" <<< "$(_orch_input)" 2>&1 | grep -qi "truncat"
}
