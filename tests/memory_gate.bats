#!/usr/bin/env bats
# Tests for bin/borg-memory-gate: Phase 1.6 of the cairn-decommission directive.
# Wraps bin/memory-hits-report's VERDICT line and delivers it through a channel that
# interrupts (notification + verdict file), only on a state transition.

load test_helper/setup

SCRIPT="${BATS_TEST_DIRNAME}/../bin/borg-memory-gate"

setup() {
    setup_temp_dirs
    export MOCK_BIN="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$MOCK_BIN"
    export BORG_MEMORY_GATE_VERDICT_FILE="${BATS_TEST_TMPDIR}/memory-gate-verdict.json"
    export BORG_MEMORY_GATE_STATE="${BATS_TEST_TMPDIR}/memory-gate-state.json"
    export BORG_MEMORY_GATE_LOG="${BATS_TEST_TMPDIR}/memory-gate.log"

    # Mock notification sink: overwrite the copied borg-hooks.sh with a version whose
    # _borg_osa_notify just records its args, so tests don't touch real osascript.
    export NOTIFY_SINK="${BATS_TEST_TMPDIR}/notify.log"
    cat > "$BORG_TEST_HOME/.claude/lib/borg-hooks.sh" <<EOF
_borg_osa_notify() { printf '%s\t%s\t%s\n' "\$1" "\$2" "\$3" >> "$NOTIFY_SINK"; }
EOF
}

_mock_report() {
    local verdict="$1" ratio="$2"
    cat > "$MOCK_BIN/mock-report" <<EOF
#!/usr/bin/env bash
echo "memory-hits-report — last 30 days"
echo "  reads:    1"
echo "  sessions: 10"
echo "  ratio:    ${ratio} reads/session"
echo ""
echo "  VERDICT: ${verdict} — placeholder text"
EOF
    chmod +x "$MOCK_BIN/mock-report"
    export BORG_MEMORY_GATE_REPORT_BIN="$MOCK_BIN/mock-report"
}

_mock_report_no_data() {
    cat > "$MOCK_BIN/mock-report" <<'EOF'
#!/usr/bin/env bash
echo "memory-hits-report: no data yet"
EOF
    chmod +x "$MOCK_BIN/mock-report"
    export BORG_MEMORY_GATE_REPORT_BIN="$MOCK_BIN/mock-report"
}

@test "FAIL verdict writes verdict file and delivers one notification" {
    _mock_report "FAIL" "0.100"
    run bash "$SCRIPT" --once
    [ "$status" -eq 0 ]
    [ -f "$BORG_MEMORY_GATE_VERDICT_FILE" ]
    grep -q '"verdict":"FAIL"' "$BORG_MEMORY_GATE_VERDICT_FILE"
    [ -f "$NOTIFY_SINK" ]
    [ "$(wc -l < "$NOTIFY_SINK" | tr -d ' ')" = "1" ]
}

@test "repeated FAIL does not re-notify (idempotent on same verdict)" {
    _mock_report "FAIL" "0.100"
    bash "$SCRIPT" --once
    bash "$SCRIPT" --once
    [ "$(wc -l < "$NOTIFY_SINK" | tr -d ' ')" = "1" ]
}

@test "PASS clears a prior FAIL verdict file and does not notify" {
    _mock_report "FAIL" "0.100"
    bash "$SCRIPT" --once
    [ -f "$BORG_MEMORY_GATE_VERDICT_FILE" ]

    _mock_report "PASS" "0.500"
    bash "$SCRIPT" --once
    [ ! -f "$BORG_MEMORY_GATE_VERDICT_FILE" ]
    # No PASS notification is ever sent — only the one FAIL notification from before.
    [ "$(wc -l < "$NOTIFY_SINK" | tr -d ' ')" = "1" ]
}

@test "no data yet: exits 0, no verdict file, no notification" {
    _mock_report_no_data
    run bash "$SCRIPT" --once
    [ "$status" -eq 0 ]
    [ ! -f "$BORG_MEMORY_GATE_VERDICT_FILE" ]
    [ ! -f "$NOTIFY_SINK" ]
}
