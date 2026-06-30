#!/usr/bin/env bats

load test_helper/setup

BORG_CMD="${BATS_TEST_DIRNAME}/../borg.zsh"

setup() {
    setup_temp_dirs
    export XDG_DATA_HOME="${BATS_TEST_TMPDIR}/data"
    unset TMUX_PANE
}

# Helper: path to the vinculum channel log
vinc_log() { echo "${XDG_DATA_HOME}/borg/vinculum/${1}/log.jsonl"; }
vinc_cursor() { echo "${XDG_DATA_HOME}/borg/vinculum/${1}/cursors/${2}"; }
vinc_subs() { echo "${XDG_DATA_HOME}/borg/vinculum/${1}/subscribers"; }

# ── Test 1: pub creates log and appends a JSON line ───────────────────────────

@test "pub creates log.jsonl and appends one JSON line" {
    run "$BORG_CMD" vinculum --as tester pub testchan hello world
    [ "$status" -eq 0 ]

    local log
    log="$(vinc_log testchan)"
    [ -f "$log" ]
    [ "$(wc -l < "$log" | tr -d ' ')" -eq 1 ]

    local line
    line="$(head -1 "$log")"
    [[ "$line" == *'"body":"hello world"'* ]]
    [[ "$line" == *'"from":"tester"'* ]]
    [[ "$line" == *'"id":'* ]]
    [[ "$line" == *'"ts":'* ]]
}

@test "pub appends multiple lines on successive calls" {
    "$BORG_CMD" vinculum --as tester pub chan2 first
    "$BORG_CMD" vinculum --as tester pub chan2 second
    "$BORG_CMD" vinculum --as tester pub chan2 third

    local log
    log="$(vinc_log chan2)"
    [ "$(wc -l < "$log" | tr -d ' ')" -eq 3 ]
}

# ── Test 2: sub before any messages → pull returns nothing ───────────────────

@test "sub with empty channel then pull returns nothing" {
    run "$BORG_CMD" vinculum --as paneA sub emptychan
    [ "$status" -eq 0 ]
    [[ "$output" == *"Subscribed"* ]]

    run "$BORG_CMD" vinculum --as paneA pull emptychan
    [ "$status" -eq 0 ]
    [ -z "$output" ]

    local cur
    cur="$(cat "$(vinc_cursor emptychan paneA)" | tr -d '[:space:]')"
    [ "$cur" -eq 0 ]
}

# ── Test 3: pub after sub → pull delivers the message; second pull is empty ──

@test "pub after sub delivers exactly one message, second pull empty" {
    "$BORG_CMD" vinculum --as paneA sub msgchan

    "$BORG_CMD" vinculum --as tester pub msgchan "hello from test"

    run "$BORG_CMD" vinculum --as paneA pull msgchan
    [ "$status" -eq 0 ]
    [ "$output" = "hello from test" ]

    run "$BORG_CMD" vinculum --as paneA pull msgchan
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "pull --json returns full JSON objects" {
    "$BORG_CMD" vinculum --as paneA sub jsonchan
    "$BORG_CMD" vinculum --as tester pub jsonchan "json body"

    run "$BORG_CMD" vinculum --as paneA pull jsonchan --json
    [ "$status" -eq 0 ]
    [[ "$output" == *'"body":"json body"'* ]]
    [[ "$output" == *'"id":'* ]]
}

# ── Test 4: two distinct subIds keep independent cursors ─────────────────────

@test "two subscribers maintain independent cursors" {
    "$BORG_CMD" vinculum --as paneA sub multichan
    "$BORG_CMD" vinculum --as paneB sub multichan

    "$BORG_CMD" vinculum --as tester pub multichan "shared message"

    run "$BORG_CMD" vinculum --as paneA pull multichan
    [ "$status" -eq 0 ]
    [ "$output" = "shared message" ]

    run "$BORG_CMD" vinculum --as paneB pull multichan
    [ "$status" -eq 0 ]
    [ "$output" = "shared message" ]

    run "$BORG_CMD" vinculum --as paneA pull multichan
    [ "$status" -eq 0 ]
    [ -z "$output" ]

    run "$BORG_CMD" vinculum --as paneB pull multichan
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# ── Test 5: ls shows channel with correct counts ─────────────────────────────

@test "ls without args lists channels with msg and sub counts" {
    "$BORG_CMD" vinculum --as tester pub lschan "msg1"
    "$BORG_CMD" vinculum --as tester pub lschan "msg2"
    "$BORG_CMD" vinculum --as paneA sub lschan

    run "$BORG_CMD" vinculum ls
    [ "$status" -eq 0 ]
    [[ "$output" == *"lschan"* ]]
    [[ "$output" == *"2 msgs"* ]]
    [[ "$output" == *"1 subs"* ]]
}

@test "ls <channel> shows subscribers with correct unread counts" {
    "$BORG_CMD" vinculum --as paneA sub unreadchan
    "$BORG_CMD" vinculum --as tester pub unreadchan "msg after sub"

    run "$BORG_CMD" vinculum ls unreadchan
    [ "$status" -eq 0 ]
    [[ "$output" == *"paneA"* ]]
    [[ "$output" == *"1 unread"* ]]

    "$BORG_CMD" vinculum --as paneA pull unreadchan

    run "$BORG_CMD" vinculum ls unreadchan
    [ "$status" -eq 0 ]
    [[ "$output" == *"paneA"* ]]
    [[ "$output" == *"0 unread"* ]]
}

# ── Test 6: unsub removes subscriber from ls ─────────────────────────────────

@test "unsub removes subscriber from ls output" {
    "$BORG_CMD" vinculum --as paneA sub subchan
    "$BORG_CMD" vinculum --as paneB sub subchan

    run "$BORG_CMD" vinculum ls subchan
    [[ "$output" == *"paneA"* ]]
    [[ "$output" == *"paneB"* ]]

    "$BORG_CMD" vinculum --as paneA unsub subchan

    run "$BORG_CMD" vinculum ls subchan
    [ "$status" -eq 0 ]
    [[ "$output" != *"paneA"* ]]
    [[ "$output" == *"paneB"* ]]

    local subs_file
    subs_file="$(vinc_subs subchan)"
    ! grep -qxF "paneA" "$subs_file"
}

@test "unsub is idempotent" {
    "$BORG_CMD" vinculum --as paneA sub idemchan
    "$BORG_CMD" vinculum --as paneA unsub idemchan

    run "$BORG_CMD" vinculum --as paneA unsub idemchan
    [ "$status" -eq 0 ]
}

@test "sub is idempotent (no duplicate entries)" {
    "$BORG_CMD" vinculum --as paneA sub idem2chan
    "$BORG_CMD" vinculum --as paneA sub idem2chan
    "$BORG_CMD" vinculum --as paneA sub idem2chan

    local subs_file
    subs_file="$(vinc_subs idem2chan)"
    [ "$(wc -l < "$subs_file" | tr -d ' ')" -eq 1 ]
}

@test "vinc alias routes to vinculum" {
    run "$BORG_CMD" vinc help
    [ "$status" -eq 0 ]
    [[ "$output" == *"vinculum"* ]]
}
