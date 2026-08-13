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

# ─── REPORT_BIN self-resolution (the path every other test bypasses) ─────────
#
# Regression: every other test in this file exports BORG_MEMORY_GATE_REPORT_BIN in its mock
# helper, so the `if [[ -z "$REPORT_BIN" ]]` self-resolution block never executed under bats.
# It shipped containing `SELF_DIR="${0:A:h}"` — a zsh-only expansion. In this bash script
# under `set -euo pipefail`, bash read it as substring expansion, evaluated `A` as arithmetic,
# and aborted with "A: unbound variable" before the `||` fallback could run. The launchd job
# therefore exited 1 on every single fire while the suite stayed green. These tests drive the
# resolution path with NO env override and NO memory-hits-report on PATH.

@test "self-resolves memory-hits-report as a sibling when not on PATH and no override set" {
    local fake_repo="${BATS_TEST_TMPDIR}/repo/bin"
    mkdir -p "$fake_repo"
    cp "$SCRIPT" "$fake_repo/borg-memory-gate"
    cat > "$fake_repo/memory-hits-report" <<'EOF'
#!/usr/bin/env bash
echo "memory-hits-report — last 30 days"
echo "  reads:    9"
echo "  sessions: 10"
echo "  ratio:    0.900 reads/session"
echo ""
echo "  VERDICT: PASS — sibling resolution worked"
EOF
    chmod +x "$fake_repo/memory-hits-report" "$fake_repo/borg-memory-gate"

    unset BORG_MEMORY_GATE_REPORT_BIN
    run env PATH="/usr/bin:/bin" \
        HOME="$BORG_TEST_HOME" \
        BORG_MEMORY_GATE_VERDICT_FILE="$BORG_MEMORY_GATE_VERDICT_FILE" \
        BORG_MEMORY_GATE_STATE="$BORG_MEMORY_GATE_STATE" \
        BORG_MEMORY_GATE_LOG="$BORG_MEMORY_GATE_LOG" \
        "$fake_repo/borg-memory-gate" --once
    [ "$status" -eq 0 ]
    grep -q 'verdict=PASS' "$BORG_MEMORY_GATE_LOG"
}

@test "self-resolution follows the install symlink to the real bin/ directory" {
    # Mirrors the real install: ~/.local/bin/borg-memory-gate -> <repo>/bin/borg-memory-gate,
    # with memory-hits-report present ONLY next to the real file.
    local fake_repo="${BATS_TEST_TMPDIR}/repo/bin"
    local link_dir="${BATS_TEST_TMPDIR}/localbin"
    mkdir -p "$fake_repo" "$link_dir"
    cp "$SCRIPT" "$fake_repo/borg-memory-gate"
    cat > "$fake_repo/memory-hits-report" <<'EOF'
#!/usr/bin/env bash
echo "memory-hits-report — last 30 days"
echo "  reads:    9"
echo "  sessions: 10"
echo "  ratio:    0.900 reads/session"
echo ""
echo "  VERDICT: PASS — symlink resolution worked"
EOF
    chmod +x "$fake_repo/memory-hits-report" "$fake_repo/borg-memory-gate"
    ln -s "$fake_repo/borg-memory-gate" "$link_dir/borg-memory-gate"

    unset BORG_MEMORY_GATE_REPORT_BIN
    run env PATH="/usr/bin:/bin" \
        HOME="$BORG_TEST_HOME" \
        BORG_MEMORY_GATE_VERDICT_FILE="$BORG_MEMORY_GATE_VERDICT_FILE" \
        BORG_MEMORY_GATE_STATE="$BORG_MEMORY_GATE_STATE" \
        BORG_MEMORY_GATE_LOG="$BORG_MEMORY_GATE_LOG" \
        "$link_dir/borg-memory-gate" --once
    [ "$status" -eq 0 ]
    grep -q 'verdict=PASS' "$BORG_MEMORY_GATE_LOG"
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
