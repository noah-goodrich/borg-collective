#!/usr/bin/env bats
# Tests for bin/borg-usage-watch: the observe-only /usage poller.
# Phase 1 is observe-only — samples + log lines only, never a tmux write.

load test_helper/setup

SCRIPT="${BATS_TEST_DIRNAME}/../bin/borg-usage-watch"
FIXTURE="${BATS_TEST_DIRNAME}/fixtures/usage-output.txt"

setup() {
    setup_temp_dirs
    export MOCK_BIN="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$MOCK_BIN"
    export BORG_USAGE_SAMPLES="${BATS_TEST_TMPDIR}/usage-samples.jsonl"
    export BORG_USAGE_LOG="${BATS_TEST_TMPDIR}/usage-watch.log"
    export BORG_USAGE_PANE_CMD="echo claude"
}

_write_mock_claude() {
    # Args: <script body>
    printf '#!/usr/bin/env bash\n%s\n' "$1" > "$MOCK_BIN/claude-mock"
    chmod +x "$MOCK_BIN/claude-mock"
    export BORG_USAGE_CLAUDE_BIN="$MOCK_BIN/claude-mock"
}

# ─── format-drift tripwire: parse the real fixture ──────────────────────────

@test "fixture parse: session_pct, week_pct, resets_at extracted correctly" {
    _write_mock_claude "cat '$FIXTURE'"
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    [ -f "$BORG_USAGE_SAMPLES" ]
    session_pct=$(jq -r '.session_pct' "$BORG_USAGE_SAMPLES")
    week_pct=$(jq -r '.week_pct' "$BORG_USAGE_SAMPLES")
    resets_at=$(jq -r '.resets_at' "$BORG_USAGE_SAMPLES")
    [ "$session_pct" = "21" ]
    [ "$week_pct" = "39" ]
    [ -n "$resets_at" ]
    [ "$resets_at" != "null" ]
}

# ─── fail-closed: no output ──────────────────────────────────────────────────

@test "fail-closed: claude prints nothing -> no sample row, warning logged" {
    _write_mock_claude ""
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    [ ! -f "$BORG_USAGE_SAMPLES" ]
    grep -q "WARNING" "$BORG_USAGE_LOG"
    ! grep -q '"session_pct":0' "$BORG_USAGE_LOG"
    # An empty-output parse failure is transient; it must NOT be reported as the permanent
    # misconfiguration that a missing binary is.
    ! grep -q "ERROR" "$BORG_USAGE_LOG"
}

# ─── fail-loud: unresolvable binary is a misconfiguration, not a parse failure ───
#
# Regression: the launchd plist's minimal PATH omitted $HOME/.local/bin, where the native
# installer puts `claude`. The script masked the missing binary as output="" and exited 0, so
# `launchctl list` showed the job healthy while it sampled nothing for every poll.

@test "fail-loud: claude binary not on PATH -> nonzero exit, ERROR logged, no sample row" {
    export BORG_USAGE_CLAUDE_BIN="definitely-not-a-real-binary-$$"
    run "$SCRIPT" --once
    [ "$status" -ne 0 ]
    [ ! -f "$BORG_USAGE_SAMPLES" ]
    grep -q "ERROR:.*not found on PATH" "$BORG_USAGE_LOG"
}

@test "PATH includes \$HOME/.local/bin so launchd can resolve the native claude install" {
    grep -q 'PATH="\$HOME/.local/bin:' "$SCRIPT"
}

# ─── fail-closed: garbage / non-numeric ──────────────────────────────────────

@test "fail-closed: claude prints garbage -> UNKNOWN, no sample row" {
    _write_mock_claude "echo 'total nonsense output'"
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    [ ! -f "$BORG_USAGE_SAMPLES" ]
    grep -q "WARNING" "$BORG_USAGE_LOG"
}

# ─── idle gate ────────────────────────────────────────────────────────────────

@test "idle gate: no claude panes -> claude binary never invoked, no sample row" {
    export BORG_USAGE_PANE_CMD="true"
    local sentinel="${BATS_TEST_TMPDIR}/sentinel-invoked"
    _write_mock_claude "touch '$sentinel'"
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    [ ! -f "$sentinel" ]
    [ ! -f "$BORG_USAGE_SAMPLES" ]
}

# A native-install Claude pane reports pane_current_command as its VERSION ("2.1.205"), never
# "claude". A gate matching only /^claude$/ counts zero on every real machine and the poller
# goes silently idle forever. This test pins that; do not narrow the regex.
@test "idle gate: a version-named pane (2.1.205) counts as an active claude pane" {
    export BORG_USAGE_PANE_CMD="printf '%s\n' zsh 2.1.205 zsh"
    _write_mock_claude "cat '${FIXTURE}'"
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    [ -f "$BORG_USAGE_SAMPLES" ]
    run jq -r '.session_pct' "$BORG_USAGE_SAMPLES"
    [ "$output" = "21" ]
}

@test "idle gate: a legacy pane literally named claude still counts" {
    export BORG_USAGE_PANE_CMD="printf '%s\n' zsh claude"
    _write_mock_claude "cat '${FIXTURE}'"
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    [ -f "$BORG_USAGE_SAMPLES" ]
}

# ─── observe-only hard constraint ────────────────────────────────────────────

@test "observe-only: script contains no send-keys" {
    run grep -c send-keys "$SCRIPT"
    [ "$output" = "0" ]
}

# ─── threshold warning ────────────────────────────────────────────────────────

@test "threshold warn: 90 percent session logs warning AND still writes a sample row" {
    _write_mock_claude "echo 'Current session: 90% used · resets Jul 9 at 1:20am (America/Denver)'; echo 'Current week (all models): 50% used · resets Jul 14 at 7am (America/Denver)'"
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    [ -f "$BORG_USAGE_SAMPLES" ]
    session_pct=$(jq -r '.session_pct' "$BORG_USAGE_SAMPLES")
    [ "$session_pct" = "90" ]
    grep -q "WARNING" "$BORG_USAGE_LOG"
}
