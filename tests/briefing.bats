#!/usr/bin/env bats
# Tests for _borg_print_briefing via the `borg link --brief` subcommand.

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
    run "$BORG_CMD" link --brief
    [ "$status" -eq 0 ]
    [[ "$output" == *"my-active-project"* ]] || false
}

@test "briefing: fallback shows project status" {
    run "$BORG_CMD" link --brief
    [ "$status" -eq 0 ]
    [[ "$output" == *"waiting"* ]] || false
}

@test "briefing: inactive projects appear under inactive header" {
    run "$BORG_CMD" link --brief
    [ "$status" -eq 0 ]
    [[ "$output" == *"Inactive"* ]] || false
    [[ "$output" == *"old-project"* ]] || false
}

@test "briefing: no debug variable lines in output" {
    run "$BORG_CMD" link --brief
    [ "$status" -eq 0 ]
    # Should not contain shell variable assignment traces
    [[ "$output" != *"entry='"* ]] || false
    [[ "$output" != *"proj_status="* ]] || false
    [[ "$output" != *"last_activity="* ]] || false
    [[ "$output" != *"rel_time='"* ]] || false
}

# ── Error message filtering ────────────────────────────────────────────────────

@test "briefing: 'Not logged in' from claude triggers fallback" {
    cat > "$MOCK_BIN/claude" <<'EOF'
#!/usr/bin/env bash
echo "Not logged in · Please run /login"
exit 0
EOF
    run "$BORG_CMD" link --brief
    [ "$status" -eq 0 ]
    # Error message must NOT appear in output
    [[ "$output" != *"Not logged in"* ]] || false
    # Fallback project listing must appear instead
    [[ "$output" == *"my-active-project"* ]] || false
}

@test "briefing: API error from claude triggers fallback" {
    cat > "$MOCK_BIN/claude" <<'EOF'
#!/usr/bin/env bash
echo "Error: API error 401 Unauthorized"
exit 1
EOF
    run "$BORG_CMD" link --brief
    [ "$status" -eq 0 ]
    [[ "$output" == *"my-active-project"* ]] || false
}

# ── Fallback provenance (2026-08-10 directive: silent fallback is the core defect) ────────────

@test "briefing: fallback with nonzero exit prints a reason line naming the exit code" {
    cat > "$MOCK_BIN/claude" <<'EOF'
#!/usr/bin/env bash
echo "Error: API error 401 Unauthorized" >&2
exit 1
EOF
    run "$BORG_CMD" link --brief
    [ "$status" -eq 0 ]
    [[ "$output" == *"narrative unavailable"* ]] || false
    [[ "$output" == *"exited 1"* ]] || false
    # The captured stderr text must actually surface, not be swallowed like the old /dev/null path.
    [[ "$output" == *"API error 401 Unauthorized"* ]] || false
}

@test "briefing: fallback distinguishes the not-logged-in case from a generic exit" {
    cat > "$MOCK_BIN/claude" <<'EOF'
#!/usr/bin/env bash
echo "Not logged in · Please run /login"
exit 0
EOF
    run "$BORG_CMD" link --brief
    [ "$status" -eq 0 ]
    [[ "$output" == *"narrative unavailable"* ]] || false
    [[ "$output" == *"not logged in"* ]] || false
}

@test "briefing: successful LLM output prints no fallback-reason line" {
    cat > "$MOCK_BIN/claude" <<'EOF'
#!/usr/bin/env bash
echo "Focus: my-active-project — waiting on design review"
EOF
    run "$BORG_CMD" link --brief
    [ "$status" -eq 0 ]
    [[ "$output" != *"narrative unavailable"* ]] || false
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
    run "$BORG_CMD" link --brief
    [ "$status" -eq 0 ]
    [[ "$output" == *"my-active-project"* ]] || false
    [[ "$output" == *"Focus:"* ]] || false
}

# ── Field-collapse regression (2026-08-10 directive defect 2) ─────────────────────────────────
#
# A project with summary=null and waiting_reason set. Before the \x1f delimiter fix, tab (IFS
# whitespace) collapsed the empty summary field and shifted waiting_reason into its place — the
# fallback line would print the waiting_reason string as if it were the summary. It must never
# print as the summary, and project_path (last field) must remain populated so the checkpoint
# block still fires.

@test "briefing: empty summary + set waiting_reason never displays waiting_reason as the summary" {
    local recent
    recent=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    cat > "$BORG_REGISTRY" <<EOF
{
  "projects": {
    "field-collapse-project": {
      "path": "/tmp/field-collapse-project",
      "status": "waiting",
      "source": "cli",
      "last_activity": "$recent",
      "summary": null,
      "waiting_reason": "Claude is waiting for your input"
    }
  }
}
EOF
    run "$BORG_CMD" link --brief
    [ "$status" -eq 0 ]
    [[ "$output" == *"field-collapse-project"* ]] || false
    # The waiting_reason text must not appear on the fallback's summary line (indented 4 spaces,
    # per fallback_text's `printf "  %-22s..."` header + `echo "    $summary"` body).
    [[ "$output" != *"    Claude is waiting for your input"* ]] || false
}

# ── Empty registry ─────────────────────────────────────────────────────────────

@test "briefing: empty registry shows scan hint" {
    echo '{"projects":{}}' > "$BORG_REGISTRY"
    run "$BORG_CMD" link --brief
    [ "$status" -eq 0 ]
    [[ "$output" == *"borg scan"* ]] || false
}
