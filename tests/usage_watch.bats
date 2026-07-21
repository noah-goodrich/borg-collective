#!/usr/bin/env bats
# Tests for bin/borg-usage-watch: the observe-only /usage poller.
# Phase 1 is observe-only — samples + log lines only, never a tmux write.
#
# Self-auditing contract: EVERY poll appends exactly one JSONL row. Silence in the samples file
# means the poller did not run. Rows carry `status`: ok|idle|suspect|error (+`reason` on error).

load test_helper/setup

SCRIPT="${BATS_TEST_DIRNAME}/../bin/borg-usage-watch"
FIXTURE="${BATS_TEST_DIRNAME}/fixtures/usage-output.txt"
IDLE_FIXTURE="${BATS_TEST_DIRNAME}/fixtures/usage-output-idle.txt"
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
    # ─ Phase-2 sweep test scaffolding ─
    # Isolated idempotence state, a captured send-keys sink, and a zeroed inter-key delay so the
    # suite does not sleep. Individual tests opt into the sweep via BORG_USAGE_SWEEP_ENABLED=1.
    export BORG_USAGE_GUARDIAN_STATE="${BATS_TEST_TMPDIR}/usage-guardian.json"
    export SENDKEYS_SINK="${BATS_TEST_TMPDIR}/sendkeys.log"
    export BORG_USAGE_SENDKEYS_DELAY=0
}

# A mock for `tmux send-keys` that records every invocation's argv (one line per call) to
# $SENDKEYS_SINK. Optional arg: a pane id to FAIL on (non-zero exit) — used to prove the sweep is
# fail-safe per pane. Records the argv even on the failing call so the attempt is observable.
_write_mock_sendkeys() {
    local fail_pane="${1:-}"
    {
        printf '#!/usr/bin/env bash\n'
        printf 'printf "%%s\\n" "$*" >> %q\n' "$SENDKEYS_SINK"
        if [ -n "$fail_pane" ]; then
            printf 'for a in "$@"; do [ "$a" = %q ] && exit 1; done\n' "$fail_pane"
        fi
        printf 'exit 0\n'
    } > "$MOCK_BIN/sendkeys-mock"
    chmod +x "$MOCK_BIN/sendkeys-mock"
    export BORG_USAGE_SENDKEYS_CMD="$MOCK_BIN/sendkeys-mock"
}

# Emit raw tmux-format pane lines (pane_id<TAB>cmd<TAB>session<TAB>window<TAB>index) for the given
# pane ids. All are marked as claude/version panes so the sweep targets them; shell panes are the
# caller's job to exclude (see the dedicated filter test).
_panes_env() {
    local out=""
    local i=0
    for pid in "$@"; do
        local cmd="claude"
        (( i % 2 == 1 )) && cmd="2.1.205"   # alternate claude / version-named to exercise both
        out+="${pid}\t${cmd}\tborg\twin${i}\t0\n"
        i=$((i + 1))
    done
    export BORG_USAGE_PANES_CMD="printf '%b' '${out}'"
}

# Mock claude that reports a given session pct with a given reset label (drives the sweep + its
# per-window idempotence key).
_mock_claude_at() {
    local pct="$1" resets="$2"
    _write_mock_claude "echo 'Current session: ${pct}% used · resets ${resets}'; echo 'Current week (all models): 40% used · resets Jul 30 at 7am (America/Denver)'"
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

# ─── synthetic-session marker ────────────────────────────────────────────────
#
# Each poll opens a real Claude Code session, so token-cost's SessionEnd hook appended a zero-token
# record every 120s — 54% of that ledger within 11 hours. BORG_NO_SPEND_RECORD tells the hook to
# skip. It must be set on the `claude` invocation itself, and must NOT leak into the poller's own
# environment (nothing else here should silently stop recording spend).

@test "spend guard: claude is invoked with BORG_NO_SPEND_RECORD=1" {
    _write_mock_claude "printf '%s' \"\${BORG_NO_SPEND_RECORD:-unset}\" > '$BATS_TEST_TMPDIR/marker'; cat '$FIXTURE'"
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    [ "$(cat "$BATS_TEST_TMPDIR/marker")" = "1" ]
}

@test "spend guard: the marker does not leak into the poller's own environment" {
    _write_mock_claude "cat '$FIXTURE'"
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    # If the script had `export`ed it, the variable would still be set after the call returns.
    run grep -c '^export BORG_NO_SPEND_RECORD' "$SCRIPT"
    [ "$output" = "0" ]
}

# ─── session-hooks marker (cairn pollution guard) ────────────────────────────
#
# The poller's launchd plist sets no WorkingDirectory, so this claude -p "/usage" invocation
# inherits cwd="/". That fires borg-link-down.sh's SessionStart hook, which falls through to
# `basename "/"` and spams cairn ("/" project search + presence-open) every 120s.
# BORG_NO_SESSION_HOOKS tells that hook to skip. Same contract as BORG_NO_SPEND_RECORD above.

@test "session-hooks guard: claude is invoked with BORG_NO_SESSION_HOOKS=1" {
    _write_mock_claude "printf '%s' \"\${BORG_NO_SESSION_HOOKS:-unset}\" > '$BATS_TEST_TMPDIR/marker'; cat '$FIXTURE'"
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    [ "$(cat "$BATS_TEST_TMPDIR/marker")" = "1" ]
}

@test "session-hooks guard: the marker does not leak into the poller's own environment" {
    _write_mock_claude "cat '$FIXTURE'"
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    run grep -c '^export BORG_NO_SESSION_HOOKS' "$SCRIPT"
    [ "$output" = "0" ]
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

# ─── 0%-session variant: no "· resets" clause must still parse (not fail) ───
#
# Regression: at session_pct=0 Claude Code renders a bare "Current session: 0% used" with no
# "· resets <time>" suffix. The original regex required that suffix, so every idle 0% poll was
# mis-recorded as parse_failed with session_pct=null (582 of 591 observed failures). A legitimate
# 0% reading must land as an ok row with session_pct=0 and a null resets_at.

@test "0%-session variant: bare 'Current session: 0% used' parses to session_pct=0, not parse_failed" {
    _write_mock_claude "cat '$IDLE_FIXTURE'"
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    [ -f "$BORG_USAGE_SAMPLES" ]
    [ "$(_row_field '.status')" = "ok" ]
    [ "$(_row_field '.session_pct')" = "0" ]
    [ "$(_row_field '.week_pct')" = "0" ]
    [ "$(_row_field '.resets_at')" = "" ] || [ "$(_row_field '.resets_at')" = "null" ]
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

# ─── Phase-2 sweep: DEFAULT-OFF is the safety belt (criterion 1) ──────────────
#
# Replaces the old blanket "script contains no send-keys" invariant. Phase 2 adds send-keys, so the
# guarantee we now pin is stronger and behavioural: with the sweep DISABLED (the default), a poll
# above threshold performs NO delivery and still logs the observe-only warning.

@test "default-OFF: above threshold with sweep disabled performs no send-keys, still warns" {
    _write_mock_sendkeys
    _panes_env paneA paneB
    _mock_claude_at 90 "Jul 9 at 1:20am (America/Denver)"
    # BORG_USAGE_SWEEP_ENABLED intentionally unset (the default).
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    [ "$(_row_field '.status')" = "ok" ]
    [ "$(_row_field '.session_pct')" = "90" ]
    # No delivery happened at all.
    [ ! -f "$SENDKEYS_SINK" ] || [ ! -s "$SENDKEYS_SINK" ]
    grep -q "WARNING.*checkpoint threshold.*sweep disabled" "$BORG_USAGE_LOG"
}

# The separate-Enter rule is also a grep-able source invariant, so a future refactor that bundles
# text+Enter into one send-keys call fails loudly (see the 2026-07-15 delivery-spike finding).
@test "source invariant: sweep never bundles command text with Enter in one send-keys call" {
    # No line should contain both the command text and a trailing Enter argument.
    run grep -nE 'send-keys.*/borg-link-up.*Enter' "$SCRIPT"
    [ "$status" -ne 0 ]
}

# ─── Phase-2 sweep: two-step delivery when ENABLED (criterion 2) ──────────────

@test "enabled: sweep delivers /borg-link-up then a SEPARATE Enter to each claude pane" {
    _write_mock_sendkeys
    _panes_env paneA paneB
    _mock_claude_at 90 "Jul 9 at 1:20am (America/Denver)"
    export BORG_USAGE_SWEEP_ENABLED=1
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    [ -f "$SENDKEYS_SINK" ]
    # Per pane: exactly two calls, text first (no Enter), then a bare Enter.
    run grep -c . "$SENDKEYS_SINK"
    [ "$output" = "4" ]
    # paneA: text call carries the command and NOT Enter; the following call is only Enter.
    grep -qE '^-t paneA /borg-link-up$' "$SENDKEYS_SINK"
    grep -qE '^-t paneA Enter$' "$SENDKEYS_SINK"
    grep -qE '^-t paneB /borg-link-up$' "$SENDKEYS_SINK"
    grep -qE '^-t paneB Enter$' "$SENDKEYS_SINK"
    # Ordering: the text delivery for paneA precedes its Enter.
    text_line=$(grep -nE '^-t paneA /borg-link-up$' "$SENDKEYS_SINK" | head -1 | cut -d: -f1)
    enter_line=$(grep -nE '^-t paneA Enter$' "$SENDKEYS_SINK" | head -1 | cut -d: -f1)
    [ "$text_line" -lt "$enter_line" ]
}

# ─── Phase-2 sweep: idempotence, one sweep per window (criterion 3) ───────────

@test "idempotence: two polls above threshold in one window fire exactly ONE sweep" {
    _write_mock_sendkeys
    _panes_env paneA
    _mock_claude_at 90 "Jul 9 at 1:20am (America/Denver)"
    export BORG_USAGE_SWEEP_ENABLED=1
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    # One sweep = 2 send-keys calls (text + Enter) for the single pane, NOT 4.
    run grep -c . "$SENDKEYS_SINK"
    [ "$output" = "2" ]
    grep -q "already fired for window" "$BORG_USAGE_LOG"
}

@test "idempotence: a new window (changed resets_at) re-arms and sweeps again" {
    _write_mock_sendkeys
    _panes_env paneA
    _mock_claude_at 90 "Jul 9 at 1:20am (America/Denver)"
    export BORG_USAGE_SWEEP_ENABLED=1
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    # New window: different reset label.
    _mock_claude_at 90 "Jul 10 at 2:30am (America/Denver)"
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    # Two sweeps = 4 calls.
    run grep -c . "$SENDKEYS_SINK"
    [ "$output" = "4" ]
}

# ─── Phase-2 sweep: threshold is config, not hard-tuned (criterion 4) ─────────

@test "config threshold: BORG_USAGE_CHECKPOINT_PCT governs the trigger" {
    _write_mock_sendkeys
    _panes_env paneA
    export BORG_USAGE_SWEEP_ENABLED=1
    export BORG_USAGE_CHECKPOINT_PCT=50
    # 60% is below the default 85 but above the configured 50 -> must sweep.
    _mock_claude_at 60 "Jul 9 at 1:20am (America/Denver)"
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    run grep -c . "$SENDKEYS_SINK"
    [ "$output" = "2" ]
}

@test "config threshold: below the configured threshold does not sweep" {
    _write_mock_sendkeys
    _panes_env paneA
    export BORG_USAGE_SWEEP_ENABLED=1
    export BORG_USAGE_CHECKPOINT_PCT=50
    _mock_claude_at 40 "Jul 9 at 1:20am (America/Denver)"
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    [ ! -f "$SENDKEYS_SINK" ] || [ ! -s "$SENDKEYS_SINK" ]
}

# ─── Phase-2 sweep: fail-safe per pane, reaper stance (criterion 5) ───────────

@test "fail-safe: a send-keys failure on one pane does not abort the others or the poll" {
    _write_mock_sendkeys paneA   # paneA's delivery fails; paneB must still be attempted
    _panes_env paneA paneB
    _mock_claude_at 90 "Jul 9 at 1:20am (America/Denver)"
    export BORG_USAGE_SWEEP_ENABLED=1
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    # paneA attempted (its failing text call is recorded) and paneB fully delivered.
    grep -qE '^-t paneA /borg-link-up$' "$SENDKEYS_SINK"
    grep -qE '^-t paneB /borg-link-up$' "$SENDKEYS_SINK"
    grep -qE '^-t paneB Enter$' "$SENDKEYS_SINK"
    grep -qE "WARNING.*send-keys failed for pane=paneA" "$BORG_USAGE_LOG"
}

# ─── Phase-2 sweep: enabled but no panes -> no delivery, window not consumed ──

@test "enabled: threshold reached but zero claude panes -> no send-keys, re-arms next poll" {
    _write_mock_sendkeys
    export BORG_USAGE_PANES_CMD="true"   # no panes
    # A pane must still exist for the poll gate itself; that gate uses BORG_USAGE_PANE_CMD.
    export BORG_USAGE_PANE_CMD="echo claude"
    _mock_claude_at 90 "Jul 9 at 1:20am (America/Denver)"
    export BORG_USAGE_SWEEP_ENABLED=1
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    [ ! -f "$SENDKEYS_SINK" ] || [ ! -s "$SENDKEYS_SINK" ]
    # Because nothing was checkpointed, the window is NOT marked swept.
    run "$SCRIPT" --once
    [ "$status" -eq 0 ]
    # still no state consumed -> guardian state absent or without a swept_window
    if [ -f "$BORG_USAGE_GUARDIAN_STATE" ]; then
        run jq -r '.swept_window // ""' "$BORG_USAGE_GUARDIAN_STATE"
        [ "$output" = "" ]
    fi
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

# ─── plist carries USER (the #1 blindness trap) ──────────────────────────────
#
# `claude -p "/usage"` prints nothing and exits 0 when USER is unset in the launchd environment, so
# the plist MUST export it. Without this the guardian is permanently, silently blind.
@test "plist: launchd EnvironmentVariables sets USER" {
    grep -q '<key>USER</key>' "$PLIST"
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
