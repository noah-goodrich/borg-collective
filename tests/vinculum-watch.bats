#!/usr/bin/env bats

load test_helper/setup

BORG_CMD="${BATS_TEST_DIRNAME}/../borg.zsh"
WATCH_CMD="${BATS_TEST_DIRNAME}/../bin/borg-vinculum-watch"

setup() {
    setup_temp_dirs
    export XDG_DATA_HOME="${BATS_TEST_TMPDIR}/data"
    unset TMUX_PANE
}

# Helper: path to the vinculum channel log
vinc_log()    { echo "${XDG_DATA_HOME}/borg/vinculum/${1}/log.jsonl"; }
vinc_cursor() { echo "${XDG_DATA_HOME}/borg/vinculum/${1}/cursors/${2}"; }

# ── Test a: published message is WOULD-SEND with correct preamble ─────────────

@test "watcher DRY_RUN delivers published message with vinculum preamble" {
    "$BORG_CMD" vinculum --as paneA sub watchchan

    "$BORG_CMD" vinculum --as tester pub watchchan "hello watcher"

    run env DRY_RUN=1 "$WATCH_CMD" watchchan --pane "%1" --as paneA --once
    [ "$status" -eq 0 ]
    [[ "$output" == *"WOULD-SEND"* ]]
    [[ "$output" == *"-t %1:"* ]]
    [[ "$output" == *"[vinculum:watchchan ← tester]"* ]]
    [[ "$output" == *"hello watcher"* ]]
}

# ── Test b: message from own subId is NOT delivered (self-echo filter) ─────────

@test "watcher filters out messages whose from equals own subId" {
    "$BORG_CMD" vinculum --as paneA sub selfchan

    # Publish as paneA (same id the watcher will use)
    "$BORG_CMD" vinculum --as paneA pub selfchan "self message"

    run env DRY_RUN=1 "$WATCH_CMD" selfchan --pane "%1" --as paneA --once
    [ "$status" -eq 0 ]
    # No WOULD-SEND output for a self-echo
    [[ "$output" != *"WOULD-SEND"* ]]
}

# ── Test c: cursor advances so each message delivers exactly once ─────────────

@test "watcher advances cursor so second run delivers nothing" {
    "$BORG_CMD" vinculum --as paneA sub idxchan

    "$BORG_CMD" vinculum --as tester pub idxchan "once only"

    # First run: delivers the message
    run env DRY_RUN=1 "$WATCH_CMD" idxchan --pane "%2" --as paneA --once
    [ "$status" -eq 0 ]
    [[ "$output" == *"WOULD-SEND"* ]]

    # Cursor must now be 1 (one line consumed)
    local cur
    cur="$(cat "$(vinc_cursor idxchan paneA)" | tr -d '[:space:]')"
    [ "$cur" -eq 1 ]

    # Second run: cursor already at end, nothing delivered
    run env DRY_RUN=1 "$WATCH_CMD" idxchan --pane "%2" --as paneA --once
    [ "$status" -eq 0 ]
    [[ "$output" != *"WOULD-SEND"* ]]
}

# ── Test d: body embedded newlines are collapsed to spaces ────────────────────

@test "watcher collapses embedded newlines in message body" {
    local ch_dir="${XDG_DATA_HOME}/borg/vinculum/nlchan"
    mkdir -p "$ch_dir/cursors"

    # Write subscriber record and cursor at 0
    printf 'paneA\n' > "$ch_dir/subscribers"
    printf '0\n'     > "$ch_dir/cursors/paneA"

    # Write a JSON message whose body contains the JSON escape sequence for newline.
    # Single-quoted printf: \\n → backslash-n in output (valid JSON \n escape).
    printf '{"id":"x1","ts":"2024-01-01T00:00:00Z","from":"tester","body":"line1\\nline2"}\n' \
        > "$ch_dir/log.jsonl"

    run env DRY_RUN=1 "$WATCH_CMD" nlchan --pane "%3" --as paneA --once
    [ "$status" -eq 0 ]
    [[ "$output" == *"WOULD-SEND"* ]]
    # Newline must be collapsed to a space
    [[ "$output" == *"line1 line2"* ]]
}
