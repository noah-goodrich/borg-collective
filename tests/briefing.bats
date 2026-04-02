#!/usr/bin/env bats
# Tests for _borg_print_briefing and the `borg briefing` subcommand.

load test_helper/setup

BORG_CMD="${BATS_TEST_DIRNAME}/../borg.zsh"

setup() {
    setup_temp_dirs

    # Mock bin dir — borg.zsh resets PATH, so use BORG_PATH_PREFIX to inject mocks
    export MOCK_BIN="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$MOCK_BIN"
    export BORG_PATH_PREFIX="$MOCK_BIN"

    # Seed registry: one waiting project (recent) + one inactive
    local recent
    recent=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    cat > "$BORG_REGISTRY" <<EOF
{
  "projects": {
    "my-active-project": {
      "path": "/tmp/my-active-project",
      "status": "waiting",
      "source": "cli",
      "last_activity": "$recent",
      "summary": "Working on the login feature.",
      "waiting_reason": "Blocked on design review"
    },
    "old-project": {
      "path": "/tmp/old-project",
      "status": "idle",
      "source": "cli",
      "last_activity": "2020-01-01T00:00:00Z",
      "summary": "Old work."
    }
  }
}
EOF

    # Default: stub claude to fail (simulates not-logged-in)
    cat > "$MOCK_BIN/claude" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
    chmod +x "$MOCK_BIN/claude"
}

# ── Fallback (claude unavailable) ─────────────────────────────────────────────

@test "briefing: fallback shows active project when claude fails" {
    run "$BORG_CMD" briefing
    [ "$status" -eq 0 ]
    [[ "$output" == *"my-active-project"* ]]
}

@test "briefing: fallback shows project status" {
    run "$BORG_CMD" briefing
    [ "$status" -eq 0 ]
    [[ "$output" == *"waiting"* ]]
}

@test "briefing: inactive projects appear under inactive header" {
    run "$BORG_CMD" briefing
    [ "$status" -eq 0 ]
    [[ "$output" == *"Inactive"* ]]
    [[ "$output" == *"old-project"* ]]
}

@test "briefing: no debug variable lines in output" {
    run "$BORG_CMD" briefing
    [ "$status" -eq 0 ]
    # Should not contain shell variable assignment traces
    [[ "$output" != *"entry='"* ]]
    [[ "$output" != *"proj_status="* ]]
    [[ "$output" != *"last_activity="* ]]
    [[ "$output" != *"rel_time='"* ]]
}

# ── Error message filtering ────────────────────────────────────────────────────

@test "briefing: 'Not logged in' from claude triggers fallback" {
    cat > "$MOCK_BIN/claude" <<'EOF'
#!/usr/bin/env bash
echo "Not logged in · Please run /login"
exit 0
EOF
    run "$BORG_CMD" briefing
    [ "$status" -eq 0 ]
    # Error message must NOT appear in output
    [[ "$output" != *"Not logged in"* ]]
    # Fallback project listing must appear instead
    [[ "$output" == *"my-active-project"* ]]
}

@test "briefing: API error from claude triggers fallback" {
    cat > "$MOCK_BIN/claude" <<'EOF'
#!/usr/bin/env bash
echo "Error: API error 401 Unauthorized"
exit 1
EOF
    run "$BORG_CMD" briefing
    [ "$status" -eq 0 ]
    [[ "$output" != *"Error:"* ]]
    [[ "$output" == *"my-active-project"* ]]
}

# ── LLM briefing (claude succeeds) ────────────────────────────────────────────

@test "briefing: LLM output is shown when claude succeeds" {
    cat > "$MOCK_BIN/claude" <<'EOF'
#!/usr/bin/env bash
echo "my-active-project  [waiting, just now]"
echo "  Last: Working on the login feature."
echo "  Next: Finish the design review."
echo "  Blocked: Blocked on design review"
echo ""
echo "Focus: my-active-project — waiting on design review"
EOF
    run "$BORG_CMD" briefing
    [ "$status" -eq 0 ]
    [[ "$output" == *"my-active-project"* ]]
    [[ "$output" == *"Focus:"* ]]
}

# ── Empty registry ─────────────────────────────────────────────────────────────

@test "briefing: empty registry shows scan hint" {
    echo '{"projects":{}}' > "$BORG_REGISTRY"
    run "$BORG_CMD" briefing
    [ "$status" -eq 0 ]
    [[ "$output" == *"borg scan"* ]]
}
