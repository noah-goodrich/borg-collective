#!/usr/bin/env bats
# borg-resume ledger core (slice S1): the record path, the SessionStart-only registry, pause/unpause, the kill
# switches. Everything runs against a sandbox BORG_RESUME_DIR; no hook is registered and no real tmux is touched.

load test_helper/setup

SID="00000000-0000-4000-8000-000000000001"

setup() {
    setup_temp_dirs
    command -v jq >/dev/null 2>&1 || skip "jq not installed"
    export BORG_RESUME_DIR="${BATS_TEST_TMPDIR}/resume"
    export BORG_RESUME_LIBDIR="${BATS_TEST_DIRNAME}/../lib/borg"
    unset BORG_RESUME_DISABLE BORG_NO_SESSION_HOOKS BORG_IN_CONTAINER TMUX_PANE
    BR="${BATS_TEST_DIRNAME}/../bin/borg-resume"
    EV="$BORG_RESUME_DIR/events/$SID.jsonl"
    REG="$BORG_RESUME_DIR/sessions/$SID.json"
    # A fake tmux on PATH: logs every call, answers display with one tab-separated line.
    FAKEBIN="${BATS_TEST_TMPDIR}/fakebin"
    mkdir -p "$FAKEBIN"
    cat >"$FAKEBIN/tmux" <<'STUB'
#!/bin/sh
printf '%s\n' "$*" >> "$TMUX_STUB_LOG"
case "$1" in
    display) printf '%%12\t41200\tborg\texample\t3\t1\t/work/example\n' ;;
esac
exit 0
STUB
    chmod +x "$FAKEBIN/tmux"
    export TMUX_STUB_LOG="${BATS_TEST_TMPDIR}/tmux.log"
}

payload() {
    printf '{"session_id":"%s","cwd":"%s","source":"startup","hook_event_name":"SessionStart"}' "${1:-$SID}" "${2:-/work/example}"
}

# ---------- record: event append ----------

@test "record: appends exactly one valid JSON line per event" {
    run bash -c "printf '%s' '{\"session_id\":\"$SID\",\"error\":\"rate_limit\",\"last_assistant_message\":\"hit your limit\"}' | '$BR' record stop_failure"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ "$(wc -l <"$EV" | tr -d ' ')" -eq 1 ]
    run jq -e '.ev == "stop_failure" and .sid == "'"$SID"'" and .scope == "main" and .error == "rate_limit" and (.t | type) == "number"' "$EV"
    [ "$status" -eq 0 ]
}

@test "record: an agent_id makes the scope agent:<id>; msg is capped at 600 chars" {
    long="$(printf 'x%.0s' $(seq 1 900))"
    run bash -c "printf '%s' '{\"session_id\":\"$SID\",\"agent_id\":\"a1\",\"last_assistant_message\":\"$long\"}' | '$BR' record agent_stop"
    [ "$status" -eq 0 ]
    run jq -e '.scope == "agent:a1" and .agent_id == "a1" and (.msg | length) == 600' "$EV"
    [ "$status" -eq 0 ]
}

@test "record: newlines in payload text stay inside one line" {
    run bash -c "printf '%s' '{\"session_id\":\"$SID\",\"last_assistant_message\":\"a\\nb\\nc\"}' | '$BR' record stop_failure"
    [ "$status" -eq 0 ]
    [ "$(wc -l <"$EV" | tr -d ' ')" -eq 1 ]
    run jq -e '.msg == "a\nb\nc"' "$EV"
    [ "$status" -eq 0 ]
}

@test "record: 50 concurrent appends all land as parseable lines" {
    for i in $(seq 1 50); do
        ( printf '{"session_id":"%s","last_assistant_message":"msg %s"}' "$SID" "$i" | "$BR" record agent_start ) &
    done
    wait
    [ "$(wc -l <"$EV" | tr -d ' ')" -eq 50 ]
    run jq -e -s 'length == 50 and (map(.msg) | unique | length) == 50' "$EV"
    [ "$status" -eq 0 ]
}

@test "record: bad input is swallowed with exit 0 and no output" {
    run bash -c "printf 'not json' | '$BR' record stop_failure"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    run bash -c "printf '' | '$BR' record stop_failure"
    [ "$status" -eq 0 ]
    run bash -c "printf '{\"session_id\":\"../../etc/x\"}' | '$BR' record stop_failure"
    [ "$status" -eq 0 ]
    run bash -c "printf '{\"session_id\":\"%s\"}' '$SID' | '$BR' record no_such_event"
    [ "$status" -eq 0 ]
    run bash -c "'$BR' record"
    [ "$status" -eq 0 ]
    [ ! -e "$BORG_RESUME_DIR/events/$SID.jsonl" ]
    [ ! -e "$BORG_RESUME_DIR/events/../../etc/x.jsonl" ]
}

@test "record: exits 0 even when the state dir is unwritable" {
    mkdir -p "$BORG_RESUME_DIR"
    : >"$BORG_RESUME_DIR/events"
    run bash -c "printf '%s' '{\"session_id\":\"$SID\"}' | '$BR' record stop_failure"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "record: exits 0 when the lib directory is missing" {
    run bash -c "printf '%s' '{\"session_id\":\"$SID\"}' | BORG_RESUME_LIBDIR=/nonexistent '$BR' record stop_failure"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "record: BORG_RESUME_NOW_EPOCH pins the timestamp" {
    run bash -c "printf '%s' '{\"session_id\":\"$SID\"}' | BORG_RESUME_NOW_EPOCH=1791800000 '$BR' record idle_prompt"
    [ "$status" -eq 0 ]
    run jq -e '.t == 1791800000 and .ev == "idle_prompt"' "$EV"
    [ "$status" -eq 0 ]
}

# ---------- registry ----------

@test "registry: written only by session_start" {
    for ev in dispatch_intent dispatch_bound agent_start agent_stop stop_failure session_end idle_prompt permission_prompt native_resume; do
        printf '{"session_id":"%s","cwd":"/work/example"}' "$SID" | "$BR" record "$ev"
    done
    [ ! -e "$REG" ]
    [ ! -d "$BORG_RESUME_DIR/sessions" ] || [ -z "$(ls "$BORG_RESUME_DIR/sessions")" ]
    payload | "$BR" record session_start
    [ -f "$REG" ]
    run jq -e '.session_id == "'"$SID"'" and .source == "startup" and .cwd == "/work/example" and .project == "example"' "$REG"
    [ "$status" -eq 0 ]
}

@test "registry: a second session_start replaces it atomically and leaves no tmp files" {
    payload "$SID" /work/one | "$BR" record session_start
    run jq -r '.cwd' "$REG"
    [ "$output" = "/work/one" ]
    payload "$SID" /work/two | "$BR" record session_start
    run jq -r '.cwd' "$REG"
    [ "$output" = "/work/two" ]
    [ "$(wc -l <"$EV" | tr -d ' ')" -eq 2 ]
    [ -z "$(ls "$BORG_RESUME_DIR/sessions" | grep tmp || true)" ]
}

@test "registry: the orchestrator root is mode orchestrator, other cwd is plain" {
    export BORG_ORCHESTRATOR_ROOT="/work/root"
    payload "$SID" /work/root | "$BR" record session_start
    run jq -r '.mode' "$REG"
    [ "$output" = "orchestrator" ]
    payload "$SID" /work/root/sub | "$BR" record session_start
    run jq -r '.mode' "$REG"
    [ "$output" = "plain" ]
}

@test "registry: concurrent registry upserts and watcher counter updates lose neither" {
    . "$BORG_RESUME_LIBDIR/resume-paths.sh"
    STATE="$BORG_RESUME_DIR/state/$SID.json"
    (
        for i in $(seq 1 25); do
            payload "$SID" "/work/p$i" | "$BR" record session_start
        done
    ) &
    (
        for i in $(seq 1 25); do
            printf '{"consecutive":0,"resumed_total":%s}\n' "$i" | borg_resume_write_atomic "$STATE"
        done
    ) &
    wait
    run jq -e '.session_id == "'"$SID"'" and (.cwd | startswith("/work/p"))' "$REG"
    [ "$status" -eq 0 ]
    run jq -e '.resumed_total == 25' "$STATE"
    [ "$status" -eq 0 ]
    [ "$(wc -l <"$EV" | tr -d ' ')" -eq 25 ]
}

# ---------- tmux pane facts ----------

@test "pane: session_start with TMUX_PANE records pane facts and sets @borg_sid" {
    run bash -c "PATH='$FAKEBIN':\$PATH TMUX_PANE=%12 '$BR' record session_start <<'EOF'
$(payload)
EOF"
    [ "$status" -eq 0 ]
    run jq -e '.tmux.pane_id == "%12" and .tmux.pane_pid == 41200 and .tmux.session == "borg" and .tmux.window == "example" and .tmux.window_index == 3 and .tmux.pane_index == 1 and .tmux.project_dir == "/work/example" and .in_container == false' "$REG"
    [ "$status" -eq 0 ]
    run grep -F "set-option -p -t %12 @borg_sid $SID" "$TMUX_STUB_LOG"
    [ "$status" -eq 0 ]
}

@test "pane: no TMUX_PANE means no tmux call and tmux is null" {
    run bash -c "PATH='$FAKEBIN':\$PATH '$BR' record session_start <<'EOF'
$(payload)
EOF"
    [ "$status" -eq 0 ]
    [ ! -e "$TMUX_STUB_LOG" ]
    run jq -e '.tmux == null and .session_id == "'"$SID"'"' "$REG"
    [ "$status" -eq 0 ]
}

@test "pane: non-session_start events never call tmux" {
    run bash -c "PATH='$FAKEBIN':\$PATH TMUX_PANE=%12 '$BR' record stop_failure <<'EOF'
$(payload)
EOF"
    [ "$status" -eq 0 ]
    [ ! -e "$TMUX_STUB_LOG" ]
}

@test "container: BORG_IN_CONTAINER=1 records no pane and no pid, never calls tmux" {
    run bash -c "PATH='$FAKEBIN':\$PATH TMUX_PANE=%12 BORG_IN_CONTAINER=1 '$BR' record session_start <<'EOF'
$(payload)
EOF"
    [ "$status" -eq 0 ]
    [ ! -e "$TMUX_STUB_LOG" ]
    run jq -e '.in_container == true and .mode == "drone" and .tmux == null and .claude_pid == null' "$REG"
    [ "$status" -eq 0 ]
    [ -f "$EV" ]
}

# ---------- kill switch ----------

@test "kill switch: BORG_RESUME_DISABLE=1 records nothing and exits 0" {
    run bash -c "BORG_RESUME_DISABLE=1 '$BR' record session_start <<'EOF'
$(payload)
EOF"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ ! -e "$EV" ]
    [ ! -e "$REG" ]
}

@test "kill switch: BORG_RESUME_DISABLE other than 1 does not disable" {
    run bash -c "BORG_RESUME_DISABLE=0 '$BR' record session_start <<'EOF'
$(payload)
EOF"
    [ "$status" -eq 0 ]
    [ -f "$EV" ]
}

@test "kill switch: pause creates the sentinel, recording continues, unpause removes it" {
    run "$BR" pause
    [ "$status" -eq 0 ]
    [ -e "$BORG_RESUME_DIR/DISABLED" ]
    payload | "$BR" record session_start
    [ -f "$EV" ]
    [ -f "$REG" ]
    . "$BORG_RESUME_LIBDIR/resume-paths.sh"
    borg_resume_paused
    run "$BR" unpause
    [ "$status" -eq 0 ]
    [ ! -e "$BORG_RESUME_DIR/DISABLED" ]
    run borg_resume_paused
    [ "$status" -ne 0 ]
}

@test "kill switch: unpause with no sentinel is a no-op success" {
    run "$BR" unpause
    [ "$status" -eq 0 ]
}

@test "kill switch: BORG_NO_SESSION_HOOKS suppresses recording" {
    run bash -c "BORG_NO_SESSION_HOOKS=1 '$BR' record session_start <<'EOF'
$(payload)
EOF"
    [ "$status" -eq 0 ]
    [ ! -e "$EV" ]
    [ ! -e "$REG" ]
}

@test "paths: default state dir is under XDG_STATE_HOME/borg/resume" {
    unset BORG_RESUME_DIR
    . "$BORG_RESUME_LIBDIR/resume-paths.sh"
    [ "$(borg_resume_dir)" = "${XDG_STATE_HOME}/borg/resume" ]
}

@test "paths: unknown subcommand prints usage and exits 2" {
    run "$BR" frobnicate
    [ "$status" -eq 2 ]
}

# ---------- bash 3.2 ----------

@test "bash 3.2: borg-resume and resume-paths.sh parse under /bin/bash -n" {
    [ -x /bin/bash ] || skip "/bin/bash not present"
    run /bin/bash -n "$BR"
    [ "$status" -eq 0 ]
    run /bin/bash -n "$BORG_RESUME_LIBDIR/resume-paths.sh"
    [ "$status" -eq 0 ]
}

@test "bash 3.2: the record path runs under /bin/bash" {
    [ -x /bin/bash ] || skip "/bin/bash not present"
    run bash -c "printf '%s' '{\"session_id\":\"$SID\"}' | /bin/bash '$BR' record stop_failure"
    [ "$status" -eq 0 ]
    [ "$(wc -l <"$EV" | tr -d ' ')" -eq 1 ]
}
