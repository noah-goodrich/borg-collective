#!/usr/bin/env bats
# borg-resume probe (slice S0c): sample `claude -p /usage` through the absolute claude binary, parse the session
# percentage, cache it. The command is stubbed (BORG_RESUME_USAGE_CMD or a stub claude); no real quota is spent.

load test_helper/setup

setup() {
    setup_temp_dirs
    export BORG_RESUME_DIR="${BATS_TEST_TMPDIR}/resume"
    export BORG_RESUME_LIBDIR="${BATS_TEST_DIRNAME}/../lib/borg"
    BR="${BATS_TEST_DIRNAME}/../bin/borg-resume"
    STUBDIR="${BATS_TEST_TMPDIR}/stub"
    mkdir -p "$STUBDIR"
    cat >"$STUBDIR/claude" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >> "$STUB_LOG"
printf 'Current session: 37%% used · resets 4pm (America/Denver)\nCurrent week (all models): 12%% used\n'
STUB
    chmod +x "$STUBDIR/claude"
    export STUB_LOG="${BATS_TEST_TMPDIR}/stub.log"
    unset BORG_RESUME_USAGE_CMD BORG_CLAUDE_BIN
}

@test "probe prints the session percent from a stub claude and exits 0" {
    BORG_CLAUDE_BIN="$STUBDIR/claude" run "$BR" probe
    [ "$status" -eq 0 ]
    [ "$output" = "37" ]
    grep -q -- "-p /usage" "$STUB_LOG"
}

@test "probe works under env -i with a minimal PATH and no TMUX" {
    run env -i PATH=/usr/bin:/bin HOME="$BATS_TEST_TMPDIR" BORG_RESUME_DIR="$BORG_RESUME_DIR" \
        BORG_RESUME_LIBDIR="$BORG_RESUME_LIBDIR" BORG_CLAUDE_BIN="$STUBDIR/claude" STUB_LOG="$STUB_LOG" "$BR" probe
    [ "$status" -eq 0 ]
    [ "$output" = "37" ]
}

@test "BORG_RESUME_USAGE_CMD stubs the sampler" {
    BORG_RESUME_USAGE_CMD='printf "Current session: 0%% used\n"' run "$BR" probe
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}

@test "a second probe inside 120s reads the cache and does not call claude again" {
    BORG_CLAUDE_BIN="$STUBDIR/claude" run "$BR" probe
    BORG_CLAUDE_BIN="$STUBDIR/claude" run "$BR" probe
    [ "$output" = "37" ]
    [ "$(wc -l <"$STUB_LOG" | tr -d ' ')" = "1" ]
    [ -f "$BORG_RESUME_DIR/usage-probe.json" ]
    run jq -e '.session_pct == 37 and (.at | type == "number")' "$BORG_RESUME_DIR/usage-probe.json"
    [ "$status" -eq 0 ]
}

@test "a stale cache is refreshed" {
    BORG_CLAUDE_BIN="$STUBDIR/claude" "$BR" probe
    jq '.at = 1' "$BORG_RESUME_DIR/usage-probe.json" >"$BATS_TEST_TMPDIR/c.json"
    mv "$BATS_TEST_TMPDIR/c.json" "$BORG_RESUME_DIR/usage-probe.json"
    BORG_CLAUDE_BIN="$STUBDIR/claude" run "$BR" probe
    [ "$output" = "37" ]
    [ "$(wc -l <"$STUB_LOG" | tr -d ' ')" = "2" ]
}

@test "missing claude binary fails non-zero with a clear message" {
    run env -i PATH=/usr/bin:/bin HOME="$BATS_TEST_TMPDIR" BORG_CLAUDE_SEARCH_DIRS="$BATS_TEST_TMPDIR/none" \
        BORG_RESUME_DIR="$BORG_RESUME_DIR" BORG_RESUME_LIBDIR="$BORG_RESUME_LIBDIR" "$BR" probe
    [ "$status" -ne 0 ]
    [[ "$output" == *"claude binary not found"* ]]
}

@test "unparseable output fails non-zero and is not cached" {
    BORG_RESUME_USAGE_CMD="echo nothing useful" run "$BR" probe
    [ "$status" -ne 0 ]
    [[ "$output" == *"could not parse"* ]]
    [ ! -f "$BORG_RESUME_DIR/usage-probe.json" ]
}

@test "claude exiting non-zero fails with a clear message" {
    BORG_RESUME_USAGE_CMD="exit 3" run "$BR" probe
    [ "$status" -ne 0 ]
    [[ "$output" == *"exited"* ]]
}
