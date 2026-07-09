#!/usr/bin/env bats
# Tests for bin/borg-usage-watch: the observe-only /usage poller.
# Phase 1 is observe-only — samples + log lines only, never a tmux write.
#
# Self-auditing contract: EVERY poll appends exactly one JSONL row. Silence in the samples file
# means the poller did not run. Rows carry `status`: ok|idle|suspect|error (+`reason` on error).

load test_helper/setup

SCRIPT="${BATS_TEST_DIRNAME}/../bin/borg-usage-watch"
FIXTURE="${BATS_TEST_DIRNAME}/fixtures/usage-output.txt"
PANES_FIXTURE="${BATS_TEST_DIRNAME}/fixtures/tmux-panes.txt"
PLIST="${BATS_TEST_DIRNAME}/../launchd/com.stillpoint-labs.borg.usage-watch.plist"
INSTALL_SH="${BATS_TEST_DIRNAME}/../install.sh"

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

_row_field() {
    # Args: <jq filter> — reads the (only) row from BORG_USAGE_SAMPLES
    jq -r "$1" "$BORG_USAGE_SAMPLES"
}

# ─── format-drift tripwire: parse the real fixture ──────────────────────────

@test "fixture parse: session_pct, week_pct, resets_at extracted correctly" {
    _write_mock_claude "cat '$FIXTURE'"
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    [ -f "$BORG_USAGE_SAMPLES" ]
    [ "$(_row_field '.status')" = "ok" ]
    session_pct=$(_row_field '.session_pct')
    week_pct=$(_row_field '.week_pct')
    resets_at=$(_row_field '.resets_at')
    [ "$session_pct" = "21" ]
    [ "$week_pct" = "39" ]
    [ -n "$resets_at" ]
    [ "$resets_at" != "null" ]
}

# ─── fail-closed: no output → parse failure, but a row IS written ───────────

@test "fail-closed: claude prints nothing -> error row (parse_failed), warning logged" {
    _write_mock_claude ""
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    [ -f "$BORG_USAGE_SAMPLES" ]
    [ "$(_row_field '.status')" = "error" ]
    [ "$(_row_field '.reason')" = "parse_failed" ]
    grep -q "WARNING" "$BORG_USAGE_LOG"
    # An empty-output parse failure is transient; it must NOT be reported as the permanent
    # misconfiguration that a missing binary is.
    ! grep -q "^\[.*\] ERROR" "$BORG_USAGE_LOG"
}

# ─── fail-loud: unresolvable binary is a misconfiguration, not a parse failure ───
#
# Regression: the launchd plist's minimal PATH omitted $HOME/.local/bin, where the native
# installer puts `claude`. The script masked the missing binary as output="" and exited 0, so
# `launchctl list` showed the job healthy while it sampled nothing for every poll.

@test "fail-loud: claude binary not on PATH -> nonzero exit, ERROR logged, error row written" {
    export BORG_USAGE_CLAUDE_BIN="definitely-not-a-real-binary-$$"
    run "$SCRIPT" --once
    [ "$status" -ne 0 ]
    [ -f "$BORG_USAGE_SAMPLES" ]
    [ "$(_row_field '.status')" = "error" ]
    [ "$(_row_field '.reason')" = "binary_not_found" ]
    grep -q "ERROR:.*not found on PATH" "$BORG_USAGE_LOG"
}

@test "PATH includes \$HOME/.local/bin so launchd can resolve the native claude install" {
    grep -q 'PATH="\$HOME/.local/bin:' "$SCRIPT"
}

# ─── fail-closed: garbage / non-numeric ──────────────────────────────────────

@test "fail-closed: claude prints garbage -> error row (parse_failed)" {
    _write_mock_claude "echo 'total nonsense output'"
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    [ -f "$BORG_USAGE_SAMPLES" ]
    [ "$(_row_field '.status')" = "error" ]
    [ "$(_row_field '.reason')" = "parse_failed" ]
    grep -q "WARNING" "$BORG_USAGE_LOG"
}

# ─── idle gate ────────────────────────────────────────────────────────────────

@test "idle gate: no claude panes, no process -> claude binary never invoked, idle row written" {
    export BORG_USAGE_PANE_CMD="true"
    export BORG_USAGE_PROC_CMD="true"
    local sentinel="${BATS_TEST_TMPDIR}/sentinel-invoked"
    _write_mock_claude "touch '$sentinel'"
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    [ ! -f "$sentinel" ]
    [ -f "$BORG_USAGE_SAMPLES" ]
    [ "$(_row_field '.status')" = "idle" ]
    [ "$(_row_field '.pane_count')" = "0" ]
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
    [ "$(_row_field '.status')" = "ok" ]
    [ "$(_row_field '.session_pct')" = "21" ]
}

@test "idle gate: a legacy pane literally named claude still counts" {
    export BORG_USAGE_PANE_CMD="printf '%s\n' zsh claude"
    _write_mock_claude "cat '${FIXTURE}'"
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    [ -f "$BORG_USAGE_SAMPLES" ]
    [ "$(_row_field '.status')" = "ok" ]
}

@test "pane count fixture: tmux-panes.txt (version pane + non-claude panes) counts 1" {
    export BORG_USAGE_PANE_CMD="cat '$PANES_FIXTURE'"
    _write_mock_claude "cat '${FIXTURE}'"
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    [ "$(_row_field '.pane_count')" = "1" ]
}

# ─── observe-only hard constraint ────────────────────────────────────────────

@test "observe-only: script contains no send-keys" {
    run grep -c send-keys "$SCRIPT"
    [ "$output" = "0" ]
}

# ─── threshold warning ────────────────────────────────────────────────────────

@test "threshold warn: 90 percent session logs warning AND still writes an ok row" {
    _write_mock_claude "echo 'Current session: 90% used · resets Jul 9 at 1:20am (America/Denver)'; echo 'Current week (all models): 50% used · resets Jul 14 at 7am (America/Denver)'"
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    [ -f "$BORG_USAGE_SAMPLES" ]
    [ "$(_row_field '.status')" = "ok" ]
    session_pct=$(_row_field '.session_pct')
    [ "$session_pct" = "90" ]
    grep -q "WARNING" "$BORG_USAGE_LOG"
}

# ─── new self-auditing contract tests ────────────────────────────────────────

@test "contract: idle writes an idle row, never silence" {
    export BORG_USAGE_PANE_CMD="true"
    export BORG_USAGE_PROC_CMD="true"
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    [ -f "$BORG_USAGE_SAMPLES" ]
    [ "$(_row_field '.status')" = "idle" ]
    [ "$(_row_field '.pane_count')" = "0" ]
    [ "$(_row_field '.session_pct')" = "null" ]
    [ "$(_row_field '.week_pct')" = "null" ]
    [ "$(_row_field '.resets_at')" = "null" ]
}

@test "contract: parse failure writes an error row and logs the raw output" {
    _write_mock_claude "echo 'some garbage the parser cannot understand at all'"
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    [ -f "$BORG_USAGE_SAMPLES" ]
    [ "$(_row_field '.status')" = "error" ]
    [ "$(_row_field '.reason')" = "parse_failed" ]
    grep -q "garbage the parser cannot understand" "$BORG_USAGE_LOG"
}

@test "contract: claude exits nonzero -> error row, reason claude_failed" {
    _write_mock_claude "echo 'boom' >&2; exit 3"
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    [ -f "$BORG_USAGE_SAMPLES" ]
    [ "$(_row_field '.status')" = "error" ]
    [ "$(_row_field '.reason')" = "claude_failed" ]
    grep -q "claude exited 3" "$BORG_USAGE_LOG"
}

@test "cross-check: zero panes but a live claude process -> suspect, not idle" {
    export BORG_USAGE_PANE_CMD="true"
    export BORG_USAGE_PROC_CMD="echo 12345"
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    [ -f "$BORG_USAGE_SAMPLES" ]
    [ "$(_row_field '.status')" = "suspect" ]
    [ "$(_row_field '.pane_count')" = "0" ]
    grep -q "WARNING.*pane_count=0.*proc_count=1" "$BORG_USAGE_LOG"
}

@test "cross-check: zero panes and no claude process -> idle" {
    export BORG_USAGE_PANE_CMD="true"
    export BORG_USAGE_PROC_CMD="true"
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    [ "$(_row_field '.status')" = "idle" ]
}

@test "every poll appends exactly one row across mixed conditions" {
    export BORG_USAGE_PANE_CMD="true"
    export BORG_USAGE_PROC_CMD="true"
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]

    export BORG_USAGE_PANE_CMD="echo claude"
    _write_mock_claude "cat '${FIXTURE}'"
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]

    _write_mock_claude "echo garbage"
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]

    lines=$(wc -l < "$BORG_USAGE_SAMPLES" | tr -d ' ')
    [ "$lines" = "3" ]
}

# ─── hostile-env tests: the script's own environment boundaries, no mock override ───
#
# These two tests deliberately do NOT set BORG_USAGE_CLAUDE_BIN. That override is the escape
# hatch that hid every one of the four blind-poller bugs this suite failed to catch: setup()
# and _write_mock_claude() are the script's only two environment boundaries, and mocking both
# unconditionally made this class of bug untestable by construction.

_launchd_path_value() {
    # Parse install.sh's USAGE_PATH_VALUE assignment (the plist itself is a template — it holds
    # the literal token "{{PATH_VALUE}}", not a real PATH; install.sh substitutes it at install
    # time). Grep from install.sh so the test and install.sh cannot drift apart. If the grep
    # finds nothing, fail loudly rather than falling back to a hardcoded default — a silent
    # fallback would recreate the exact blind-poller bug class this suite exists to catch.
    grep -q '{{PATH_VALUE}}' "$PLIST"
    grep -oE 'USAGE_PATH_VALUE="[^"]*"' "$INSTALL_SH" | head -1 | sed -E 's/^USAGE_PATH_VALUE="(.*)"$/\1/'
}

# Rationale: USAGE_PATH_VALUE in install.sh intentionally omits $HOME/.local/bin — the script's
# own PATH prepend (line ~24) is the single source of truth that resolves the native install. If
# someone later "fixes" this by adding .local/bin to the plist/install.sh PATH instead, this test
# fails and forces a decision about which layer owns the resolution, rather than silently letting
# two sources of truth drift and re-creating the blind-poller bug class.
@test "tripwire: install.sh's launchd PATH does not contain \$HOME/.local/bin" {
    local launchd_path
    launchd_path=$(_launchd_path_value)
    [ -n "$launchd_path" ]
    case "$launchd_path" in
        *.local/bin*) false ;;
        *) true ;;
    esac
}

@test "hostile env: claude resolved from \$HOME/.local/bin under launchd's PATH" {
    local fake_home="${BATS_TEST_TMPDIR}/fakehome"
    mkdir -p "$fake_home/.local/bin"
    printf '#!/usr/bin/env bash\ncat "%s"\n' "$FIXTURE" > "$fake_home/.local/bin/claude"
    chmod +x "$fake_home/.local/bin/claude"

    local launchd_path
    launchd_path=$(_launchd_path_value)
    [ -n "$launchd_path" ]

    run env -i \
        USER=test \
        HOME="$fake_home" \
        PATH="$launchd_path" \
        BORG_USAGE_SAMPLES="$BORG_USAGE_SAMPLES" \
        BORG_USAGE_LOG="$BORG_USAGE_LOG" \
        BORG_USAGE_PANE_CMD="echo claude" \
        "$SCRIPT" --once
    [ "$status" -eq 0 ]
    [ -f "$BORG_USAGE_SAMPLES" ]
    [ "$(_row_field '.status')" = "ok" ]
}

@test "hostile env: USER unset still resolves and samples" {
    local fake_home="${BATS_TEST_TMPDIR}/fakehome2"
    mkdir -p "$fake_home/.local/bin"
    printf '#!/usr/bin/env bash\ncat "%s"\n' "$FIXTURE" > "$fake_home/.local/bin/claude"
    chmod +x "$fake_home/.local/bin/claude"

    local launchd_path
    launchd_path=$(_launchd_path_value)
    [ -n "$launchd_path" ]

    run env -i \
        HOME="$fake_home" \
        PATH="$launchd_path" \
        BORG_USAGE_SAMPLES="$BORG_USAGE_SAMPLES" \
        BORG_USAGE_LOG="$BORG_USAGE_LOG" \
        BORG_USAGE_PANE_CMD="echo claude" \
        "$SCRIPT" --once
    [ "$status" -eq 0 ]
    [ -f "$BORG_USAGE_SAMPLES" ]
    [ "$(_row_field '.status')" = "ok" ]
}
