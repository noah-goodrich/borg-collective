#!/usr/bin/env bats
# Tests for `borg doctor` — verifies the 4 launchd agents that install.sh bootstraps
# (notifyd, cortex-wake, usage-watch, reap): registered / last exit status / fresh output.

load test_helper/setup

BORG_CMD="${BATS_TEST_DIRNAME}/../borg.zsh"

NOTIFYD_LABEL="com.stillpoint-labs.borg.notifyd"
CORTEX_LABEL="com.stillpoint-labs.borg.cortex-wake"
USAGE_LABEL="com.stillpoint-labs.borg.usage-watch"
REAP_LABEL="com.stillpoint-labs.borg.reap"

setup() {
    setup_temp_dirs
    setup_mock_bin
    # borg.zsh resets PATH from scratch at startup (native-install PATH-safety guard) and only
    # honors BORG_PATH_PREFIX for prepending — plain PATH exports from the test are discarded.
    export BORG_PATH_PREFIX="$MOCK_BIN"

    export XDG_STATE_HOME="${BATS_TEST_TMPDIR}/state"
    export XDG_DATA_HOME="${BATS_TEST_TMPDIR}/data"
    mkdir -p "$XDG_STATE_HOME/borg" "$XDG_DATA_HOME/borg"
    mkdir -p "$HOME/Library/LaunchAgents"

    USAGE_SAMPLES="$XDG_STATE_HOME/borg/usage-samples.jsonl"
    CORTEX_LOG="$XDG_DATA_HOME/borg/cortex-wake.stdout.log"
    REAP_LOG="$XDG_DATA_HOME/borg/reap.stdout.log"

    # Default: all four agents registered, exit 0, fresh output, notifyd has no StartInterval.
    _write_plist "$NOTIFYD_LABEL" ""
    _write_plist "$CORTEX_LABEL" "30"
    _write_plist "$USAGE_LABEL" "120"
    _write_plist "$REAP_LABEL" "3600"

    touch "$CORTEX_LOG" "$REAP_LOG"
    echo '{"ts":"now"}' > "$USAGE_SAMPLES"

    # Real `launchctl list` prints "-" in the PID column for an agent that is not currently
    # running, and a numeric PID only while it is. Interval-driven agents are almost always "-".
    # Fixtures with fake PIDs made every agent look permanently running, which silently disabled
    # the exit-status check these tests exist to exercise.
    _write_launchctl_list "\
- 0 $NOTIFYD_LABEL
- 0 $CORTEX_LABEL
- 0 $USAGE_LABEL
- 0 $REAP_LABEL"
}

# Args: <label> <start-interval-or-empty>
_write_plist() {
    local label="$1" interval="$2"
    local plist="$HOME/Library/LaunchAgents/$label.plist"
    {
        echo '<?xml version="1.0" encoding="UTF-8"?>'
        echo '<plist version="1.0"><dict>'
        echo "<key>Label</key><string>$label</string>"
        if [[ -n "$interval" ]]; then
            echo '<key>StartInterval</key>'
            echo "<integer>$interval</integer>"
        fi
        echo '</dict></plist>'
    } > "$plist"
}

# Writes a mock `launchctl` binary onto PATH that prints the given body for `launchctl list`.
_write_launchctl_list() {
    local body="$1"
    cat > "$MOCK_BIN/launchctl" <<EOF
#!/usr/bin/env bash
if [[ "\$1" == "list" ]]; then
    cat <<'BODY'
$body
BODY
    exit 0
fi
exit 0
EOF
    chmod +x "$MOCK_BIN/launchctl"
}

# ─── all healthy ──────────────────────────────────────────────────────────────

@test "all agents registered, exit 0, fresh output -> doctor exits 0 with OK lines" {
    run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"notifyd"*"OK"* ]]
    [[ "$output" == *"cortex-wake"*"OK"* ]]
    [[ "$output" == *"usage-watch"*"OK"* ]]
    [[ "$output" == *"reap"*"OK"* ]]
}

# ─── nonzero last exit status ─────────────────────────────────────────────────

@test "one agent with nonzero last exit -> doctor exits nonzero, that agent FAILs" {
    _write_launchctl_list "\
- 0 $NOTIFYD_LABEL
- 1 $CORTEX_LABEL
- 0 $USAGE_LABEL
- 0 $REAP_LABEL"
    run "$BORG_CMD" doctor
    [ "$status" -ne 0 ]
    [[ "$output" == *"cortex-wake"*"FAIL"* ]]
}

# ─── missing from launchctl list ──────────────────────────────────────────────

@test "one agent missing from launchctl list -> FAIL" {
    _write_launchctl_list "\
- 0 $NOTIFYD_LABEL
- 0 $USAGE_LABEL
- 0 $REAP_LABEL"
    run "$BORG_CMD" doctor
    [ "$status" -ne 0 ]
    [[ "$output" == *"cortex-wake"*"FAIL"* ]]
}

# ─── a running daemon is healthy, whatever the previous instance's exit was ────
#
# notifyd is a long-lived fswatch daemon. `launchctl kickstart -k` restarts it, and the second
# column then reports the SIGTERM we sent the old instance (-15). Reporting FAIL there is a false
# alarm about a corpse we created ourselves — and a health check that cries wolf gets ignored.

@test "a live PID means OK even when the previous instance was signalled" {
    _write_launchctl_list "\
74574 -15 $NOTIFYD_LABEL
- 0 $CORTEX_LABEL
- 0 $USAGE_LABEL
- 0 $REAP_LABEL"
    run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"notifyd"*"run"*"OK"* ]]
}

@test "a signalled exit with no live PID is WARN, not FAIL" {
    _write_launchctl_list "\
- -15 $NOTIFYD_LABEL
- 0 $CORTEX_LABEL
- 0 $USAGE_LABEL
- 0 $REAP_LABEL"
    run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"notifyd"*"WARN"* ]]
}

# ─── stale output artifact ─────────────────────────────────────────────────────
#
# usage-watch is the only agent contractually required to write on every interval, so it is the
# only one where an old mtime proves breakage. notifyd and cortex-wake are event-driven: a quiet
# hour is not a fault, which is why they carry no artifact.

@test "stale output artifact -> WARN (not silently OK)" {
    # 3x the 120s interval is 360s; back-date the samples file well past that.
    touch -t "202001010000" "$USAGE_SAMPLES"
    run "$BORG_CMD" doctor
    [[ "$output" == *"usage-watch"*"WARN"* ]]
}

# ─── no StartInterval -> freshness n/a, does not FAIL ─────────────────────────

@test "agent with no StartInterval -> freshness prints n/a, does not FAIL" {
    run "$BORG_CMD" doctor
    [ "$status" -eq 0 ]
    [[ "$output" == *"notifyd"*"n/a"*"OK"* ]]
}
