#!/usr/bin/env bats
# Tests for hooks/borg-cairn-heartbeat.sh — throttled Stop-hook cairn heartbeat,
# and the shared _borg_cairn_health_line helper it (and borg-link-down.sh) call.

load test_helper/setup

HEARTBEAT="${BATS_TEST_DIRNAME}/../hooks/borg-cairn-heartbeat.sh"

setup() {
    setup_temp_dirs

    export MOCK_BIN="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$MOCK_BIN"
    export PATH="$MOCK_BIN:$PATH"

    export BORG_CAIRN_HEARTBEAT_STATE="${BATS_TEST_TMPDIR}/cairn-heartbeat-last"
    rm -f "$BORG_CAIRN_HEARTBEAT_STATE"
}

_stub_cairn_ok() {
    cat > "$MOCK_BIN/cairn" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == "health" ]] && echo '{"status":"ok","db":"reachable","version":"0.5.3"}'
exit 0
EOF
    chmod +x "$MOCK_BIN/cairn"
}

_stub_cairn_down() {
    cat > "$MOCK_BIN/cairn" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == "health" ]] && echo '{"status":"error","db":"unreachable"}'
exit 1
EOF
    chmod +x "$MOCK_BIN/cairn"
}

# ─── _borg_cairn_health_line (shared helper) ─────────────────────────────────

@test "health line: reports healthy when cairn health returns status ok" {
    _stub_cairn_ok
    run bash -c "source '$BORG_TEST_HOME/.claude/lib/borg-hooks.sh'; _borg_cairn_health_line"
    [ "$status" -eq 0 ]
    [[ "$output" == *"cairn: healthy"* ]]
    [[ "$output" == *"recording"* ]]
}

@test "health line: reports last write age when marker file exists" {
    _stub_cairn_ok
    touch "$BORG_DIR/.cairn-last-write"
    run bash -c "source '$BORG_TEST_HOME/.claude/lib/borg-hooks.sh'; _borg_cairn_health_line"
    [ "$status" -eq 0 ]
    [[ "$output" != *"last write never"* ]]
}

@test "health line: reports never when no last-write marker exists" {
    _stub_cairn_ok
    run bash -c "source '$BORG_TEST_HOME/.claude/lib/borg-hooks.sh'; _borg_cairn_health_line"
    [ "$status" -eq 0 ]
    [[ "$output" == *"last write never"* ]]
}

@test "health line: reports DEGRADED when cairn health status is not ok" {
    _stub_cairn_down
    run bash -c "source '$BORG_TEST_HOME/.claude/lib/borg-hooks.sh'; _borg_cairn_health_line"
    [ "$status" -eq 0 ]
    [[ "$output" == *"cairn: DEGRADED"* ]]
    [[ "$output" == *"docker compose"* ]]
}

@test "health line: reports DEGRADED (not in PATH) when cairn binary is absent" {
    rm -f "$MOCK_BIN/cairn"
    run env PATH="$MOCK_BIN:/usr/bin:/bin" \
        bash -c "source '$BORG_TEST_HOME/.claude/lib/borg-hooks.sh'; _borg_cairn_health_line"
    [ "$status" -eq 0 ]
    [[ "$output" == *"cairn: DEGRADED"* ]]
    [[ "$output" == *"not in PATH"* ]]
}

@test "health line: never exits non-zero even when cairn health hangs (fail-open)" {
    cat > "$MOCK_BIN/cairn" <<'EOF'
#!/usr/bin/env bash
sleep 30
EOF
    chmod +x "$MOCK_BIN/cairn"
    run bash -c "source '$BORG_TEST_HOME/.claude/lib/borg-hooks.sh'; BORG_CAIRN_HEALTH_TIMEOUT=1 _borg_cairn_health_line"
    [ "$status" -eq 0 ]
    [[ "$output" == *"cairn: DEGRADED"* ]]
}

# ─── borg-cairn-heartbeat.sh (Stop hook) ─────────────────────────────────────

@test "heartbeat: prints a line on first fire (no throttle state yet)" {
    _stub_cairn_ok
    run bash "$HEARTBEAT" <<< '{}'
    [ "$status" -eq 0 ]
    [[ "$output" == *"cairn: healthy"* ]]
}

@test "heartbeat: writes the throttle state file after firing" {
    _stub_cairn_ok
    bash "$HEARTBEAT" <<< '{}' >/dev/null 2>&1
    [ -f "$BORG_CAIRN_HEARTBEAT_STATE" ]
}

@test "heartbeat: stays silent within the throttle window (default 1800s)" {
    _stub_cairn_ok
    date +%s > "$BORG_CAIRN_HEARTBEAT_STATE"
    run bash "$HEARTBEAT" <<< '{}'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "heartbeat: fires again once the throttle window has elapsed" {
    _stub_cairn_ok
    printf '%s' "$(( $(date +%s) - 2000 ))" > "$BORG_CAIRN_HEARTBEAT_STATE"
    run bash "$HEARTBEAT" <<< '{}'
    [ "$status" -eq 0 ]
    [[ "$output" == *"cairn: healthy"* ]]
}

@test "heartbeat: a custom interval can shrink the throttle window" {
    _stub_cairn_ok
    printf '%s' "$(( $(date +%s) - 5 ))" > "$BORG_CAIRN_HEARTBEAT_STATE"
    run env BORG_CAIRN_HEARTBEAT_INTERVAL_SEC=2 bash "$HEARTBEAT" <<< '{}'
    [ "$status" -eq 0 ]
    [[ "$output" == *"cairn: healthy"* ]]
}

@test "heartbeat: DEGRADED line is loud and still exits 0" {
    _stub_cairn_down
    run bash "$HEARTBEAT" <<< '{}'
    [ "$status" -eq 0 ]
    [[ "$output" == *"cairn: DEGRADED"* ]]
}

@test "heartbeat: master switch disables the hook entirely" {
    _stub_cairn_down
    run env BORG_CAIRN_HEARTBEAT_ENABLED=0 bash "$HEARTBEAT" <<< '{}'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ ! -f "$BORG_CAIRN_HEARTBEAT_STATE" ]
}

@test "heartbeat: never blocks or errors when lib is missing (fail-open)" {
    run env HOME="${BATS_TEST_TMPDIR}/no-claude-dir" bash "$HEARTBEAT" <<< '{}'
    [ "$status" -eq 0 ]
}
