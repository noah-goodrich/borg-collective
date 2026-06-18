#!/usr/bin/env bats
# Tests for `borg cairn-brief` (AC3: cairn-warm brief wired into dispatch).
#
# The command pre-loads task-relevant cairn knowledge for a nanoprobe brief. It must:
#   1. Degrade quietly (exit 0 + fallback line) when cairn is NOT on PATH.
#   2. Degrade quietly (exit 0 + fallback line) when cairn returns empty.
#   3. Print results under the pre-loaded heading when cairn returns hits.
#   4. Query cairn with the TASK text (not the project name) and keep --project for scoping.
#   5. Error with a usage message when no project is supplied.

load test_helper/setup

BORG_CMD="${BATS_TEST_DIRNAME}/../borg.zsh"

setup() {
    setup_temp_dirs
    setup_mock_bin
    # borg.zsh rebuilds PATH from scratch but honors BORG_PATH_PREFIX — use it to inject the mock.
    export BORG_PATH_PREFIX="$MOCK_BIN"
}

# ─── degrade: cairn absent ────────────────────────────────────────────────────

@test "cairn-brief exits 0 and prints fallback when cairn not on PATH" {
    # No cairn mock and no prefix → borg.zsh's self-built PATH has no cairn in the isolated HOME,
    # so `command -v cairn` fails and the command must degrade quietly.
    rm -f "$MOCK_BIN/cairn"
    run env -u BORG_PATH_PREFIX "$BORG_CMD" cairn-brief borg-collective "spend optimization"
    [ "$status" -eq 0 ]
    [[ "$output" == *"no cairn knowledge"* ]]
    [[ "$output" != *"Cairn knowledge (pre-loaded"* ]]
}

# ─── degrade: cairn present but empty ─────────────────────────────────────────

@test "cairn-brief exits 0 and prints fallback when cairn returns empty" {
    cat > "$MOCK_BIN/cairn" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
    chmod +x "$MOCK_BIN/cairn"

    run "$BORG_CMD" cairn-brief borg-collective "spend optimization"
    [ "$status" -eq 0 ]
    [[ "$output" == *"no cairn knowledge"* ]]
}

# ─── happy path: cairn returns hits ───────────────────────────────────────────

@test "cairn-brief prints results under the pre-loaded heading when cairn has hits" {
    cat > "$MOCK_BIN/cairn" <<'EOF'
#!/usr/bin/env bash
echo "## Decisions"
echo "- [some-decision] orchestrator-first spend optimization"
exit 0
EOF
    chmod +x "$MOCK_BIN/cairn"

    run "$BORG_CMD" cairn-brief borg-collective "spend optimization"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Cairn knowledge (pre-loaded"* ]]
    [[ "$output" == *"orchestrator-first spend optimization"* ]]
}

# ─── query shape: task is the search string, project scopes ───────────────────

@test "cairn-brief queries with the task text and passes --project for scoping" {
    cat > "$MOCK_BIN/cairn" <<EOF
#!/usr/bin/env bash
echo "\$@" > "${BATS_TEST_TMPDIR}/cairn-args.txt"
echo "## Decisions"
echo "- hit"
exit 0
EOF
    chmod +x "$MOCK_BIN/cairn"

    run "$BORG_CMD" cairn-brief borg-collective "shrink the main loop"
    [ "$status" -eq 0 ]
    # The search string must be the task, not the project name.
    grep -q "search shrink the main loop" "${BATS_TEST_TMPDIR}/cairn-args.txt"
    # --project must still scope to the project.
    grep -q -- "--project borg-collective" "${BATS_TEST_TMPDIR}/cairn-args.txt"
}

# ─── usage guard ──────────────────────────────────────────────────────────────

@test "cairn-brief errors when no project is supplied" {
    run "$BORG_CMD" cairn-brief
    [ "$status" -ne 0 ]
    [[ "$output" == *"usage"* ]]
}

# ─── help + dispatch wiring ───────────────────────────────────────────────────

@test "borg help lists cairn-brief" {
    run "$BORG_CMD" help
    [ "$status" -eq 0 ]
    [[ "$output" == *"cairn-brief"* ]]
}
