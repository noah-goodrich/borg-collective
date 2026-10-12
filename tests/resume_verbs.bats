#!/usr/bin/env bats
# S7b (borg-resume): ack/defer verbs, their fold in the watcher, and the immediate classify in `record`.
# Directive: docs/plans/directives/2026-10-12-borg-resume-any-interruption.md (Detection step 1, Records, S7b).
# Synthetic only: BORG_RESUME_DIR under BATS_TEST_TMPDIR, clock pinned with BORG_RESUME_NOW_EPOCH.

setup() {
    BIN="${BATS_TEST_DIRNAME}/../bin/borg-resume"
    command -v jq >/dev/null || skip "jq not installed"
    export BORG_RESUME_DIR="${BATS_TEST_TMPDIR}/resume"
    export BORG_RESUME_PROJECTS_DIR="${BATS_TEST_TMPDIR}/projects"
    export BORG_IN_CONTAINER=0
    export BORG_RESUME_PANES_CMD=true BORG_RESUME_TMUX_CMD=false BORG_RESUME_DOCKER_CMD=true
    # 2026-10-12 12:00:00 UTC
    export BORG_RESUME_NOW_EPOCH=1791806400
    unset BORG_RESUME_DISABLE BORG_NO_SESSION_HOOKS BORG_RESUME_DEFER_SEC
    RD="$BORG_RESUME_DIR"
    SID="00000000-0000-4000-8000-0000000000aa"
    EV="$RD/events/$SID.jsonl"
    mkdir -p "$RD/sessions" "$RD/events" "$RD/pending" "$RD/done" "$BORG_RESUME_PROJECTS_DIR"
}

# mk_rec <rid> <state> [dir]
mk_rec() {
    jq -n --arg rid "$1" --arg sid "$SID" --arg st "$2" '{rid:$rid, sid:$sid, scope:"main", class:"transient",
        action:"backoff", error:"server_error", detected_by:["scan"], evidence:{uuid:"e-1", uuids:["e-1"]},
        first_seen:1791790000, resume_at:1791790045, attempt:0, state:$st, state_log:[[$st,1791790001]],
        inject_tries:0, notified:false}' >"$RD/${3:-pending}/$1.json"
}

mk_confirmed() { # <rid> <confirmed_at>
    mk_rec "$1" confirmed
    local f="$RD/pending/$1.json"
    jq -c --argjson at "$2" '.confirmed_at = $at | .confirmed_lines = 0
        | .state_log += [["injected", ($at - 30)], ["confirmed", $at]]' "$f" >"$f.t" && mv "$f.t" "$f"
}

# ---- ack ---------------------------------------------------------------------------------------

@test "ack appends one ack event naming the rid, sid, scope and time" {
    mk_rec r_aaaaaa confirmed
    run "$BIN" ack r_aaaaaa
    [ "$status" -eq 0 ]
    [ "$(wc -l <"$EV" | tr -d ' ')" = 1 ]
    run jq -e --arg s "$SID" '.ev == "ack" and .rid == "r_aaaaaa" and .sid == $s and .scope == "main"
        and .t == 1791806400' "$EV"
    [ "$status" -eq 0 ]
}

@test "ack of an unknown rid fails and appends nothing" {
    run "$BIN" ack r_nope00
    [ "$status" -eq 1 ]
    [ ! -f "$EV" ]
}

@test "ack finds a record that already moved to done/" {
    mk_rec r_dddddd done "done"
    run "$BIN" ack r_dddddd
    [ "$status" -eq 0 ]
    [ "$(jq -r .ev "$EV")" = ack ]
}

@test "ack with a bad or missing rid is a usage error" {
    run "$BIN" ack
    [ "$status" -eq 2 ]
    run "$BIN" ack '../x'
    [ "$status" -eq 2 ]
    [ ! -f "$EV" ]
}

@test "BORG_RESUME_DISABLE=1 makes ack a silent no-op" {
    mk_rec r_aaaaaa confirmed
    BORG_RESUME_DISABLE=1 run "$BIN" ack r_aaaaaa
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    [ ! -f "$EV" ]
}

@test "ack then watch moves a confirmed record to done with reason ack" {
    mk_confirmed r_cccccc $((BORG_RESUME_NOW_EPOCH - 60))
    run "$BIN" ack r_cccccc
    [ "$status" -eq 0 ]
    run "$BIN" watch --once
    [ "$status" -eq 0 ]
    [ ! -f "$RD/pending/r_cccccc.json" ]
    [ "$(jq -r .state "$RD/done/r_cccccc.json")" = done ]
    [ "$(jq -r .done_reason "$RD/done/r_cccccc.json")" = ack ]
}

@test "an ack older than the injection does not close the record" {
    mk_confirmed r_cccccc $((BORG_RESUME_NOW_EPOCH + 60))
    BORG_RESUME_NOW_EPOCH=$((BORG_RESUME_NOW_EPOCH - 600)) run "$BIN" ack r_cccccc
    run "$BIN" watch --once
    [ "$(jq -r .state "$RD/pending/r_cccccc.json")" = confirmed ]
}

@test "an ack that lands before the watcher's first confirmation pass still closes it" {
    mk_rec r_cccccc confirmed
    f="$RD/pending/r_cccccc.json"
    jq -c --argjson t "$BORG_RESUME_NOW_EPOCH" '.state_log += [["injected", ($t - 120)]]' "$f" >"$f.t" && mv "$f.t" "$f"
    BORG_RESUME_NOW_EPOCH=$((BORG_RESUME_NOW_EPOCH - 100)) run "$BIN" ack r_cccccc
    [ "$status" -eq 0 ]
    run "$BIN" watch --once
    [ "$(jq -r .done_reason "$RD/done/r_cccccc.json")" = ack ]
    [ "$(jq -r '.consecutive // 0' "$RD/state/$SID.json")" = 0 ]
}

@test "a garbage line in events does not hide an ack" {
    mk_confirmed r_cccccc $((BORG_RESUME_NOW_EPOCH - 60))
    printf 'not json\n' >"$EV"
    "$BIN" ack r_cccccc
    "$BIN" watch --once
    [ "$(jq -r .done_reason "$RD/done/r_cccccc.json")" = ack ]
}

# ---- defer: command syntax ---------------------------------------------------------------------

@test "defer accepts exactly the form the prompt renderer emits (--reason word)" {
    mk_rec r_aaaaaa confirmed
    run "$BIN" defer r_aaaaaa --reason denied
    [ "$status" -eq 0 ]
    run jq -e '.ev == "defer" and .rid == "r_aaaaaa" and .reason == "denied" and (has("until") | not)' "$EV"
    [ "$status" -eq 0 ]
}

@test "defer takes a positional epoch, a relative +N unit, or --until" {
    mk_rec r_aaaaaa confirmed
    run "$BIN" defer r_aaaaaa 1791810000
    [ "$status" -eq 0 ]
    run "$BIN" defer r_aaaaaa +2h
    [ "$status" -eq 0 ]
    run "$BIN" defer r_aaaaaa --until +30m --reason x
    [ "$status" -eq 0 ]
    want="[1791810000,$((BORG_RESUME_NOW_EPOCH + 7200)),$((BORG_RESUME_NOW_EPOCH + 1800))]"
    [ "$(jq -s -c 'map(.until)' "$EV")" = "$want" ]
}

@test "defer rejects a malformed until and an unknown rid" {
    mk_rec r_aaaaaa confirmed
    run "$BIN" defer r_aaaaaa tomorrow
    [ "$status" -eq 2 ]
    run "$BIN" defer r_nope00 +1h
    [ "$status" -eq 1 ]
    [ ! -f "$EV" ]
}

# ---- defer: watcher fold -----------------------------------------------------------------------

@test "defer of a confirmed record reschedules it as deferred and clears the confirmation" {
    mk_confirmed r_cccccc $((BORG_RESUME_NOW_EPOCH - 60))
    "$BIN" defer r_cccccc 1791810000 --reason dispatch_guard
    run "$BIN" watch --once
    [ "$status" -eq 0 ]
    f="$RD/pending/r_cccccc.json"
    [ "$(jq -r .state "$f")" = deferred ]
    [ "$(jq -r .resume_at "$f")" = 1791810000 ]
    [ "$(jq -r .defer_reason "$f")" = dispatch_guard ]
    [ "$(jq -r '.confirmed_at // "none"' "$f")" = none ]
    [ "$(jq -r '.state_log[-1][0]' "$f")" = deferred ]
}

@test "defer without until uses now plus the default backoff" {
    mk_rec r_aaaaaa scheduled
    "$BIN" defer r_aaaaaa --reason denied
    "$BIN" watch --once
    [ "$(jq -r .resume_at "$RD/pending/r_aaaaaa.json")" = $((BORG_RESUME_NOW_EPOCH + 900)) ]
}

@test "defer until in the past is raised to now" {
    mk_rec r_aaaaaa scheduled
    "$BIN" defer r_aaaaaa 1000
    "$BIN" watch --once
    [ "$(jq -r .resume_at "$RD/pending/r_aaaaaa.json")" = "$BORG_RESUME_NOW_EPOCH" ]
}

@test "a second watch pass does not re-apply a defer" {
    mk_rec r_aaaaaa scheduled
    "$BIN" defer r_aaaaaa 1791810000
    "$BIN" watch --once
    n1="$(jq -r '.state_log | length' "$RD/pending/r_aaaaaa.json")"
    "$BIN" watch --once
    [ "$(jq -r '.state_log | length' "$RD/pending/r_aaaaaa.json")" = "$n1" ]
    [ "$(jq -r .defer_count "$RD/pending/r_aaaaaa.json")" = 1 ]
}

@test "defer is capped: the fourth defer closes the record and every defer bumps consecutive" {
    mk_rec r_aaaaaa scheduled
    for i in 1 2 3; do
        "$BIN" defer r_aaaaaa --reason dispatch_guard
        "$BIN" watch --once
    done
    f="$RD/pending/r_aaaaaa.json"
    [ "$(jq -r .defer_count "$f")" = 3 ]
    [ "$(jq -r .consecutive "$RD/state/$SID.json")" = 3 ]
    "$BIN" defer r_aaaaaa --reason dispatch_guard
    "$BIN" watch --once
    [ ! -f "$f" ]
    [ "$(jq -r .state "$RD/done/r_aaaaaa.json")" = capped ]
}

@test "non-limit defer is clamped to first_seen plus 48h, a limit-class one gets 7 days" {
    mk_rec r_aaaaaa deferred
    "$BIN" defer r_aaaaaa $((BORG_RESUME_NOW_EPOCH + 30 * 86400))
    "$BIN" watch --once
    [ "$(jq -r .resume_at "$RD/pending/r_aaaaaa.json")" = $((1791790000 + 48 * 3600)) ]
    mk_rec r_bbbbbb deferred
    jq -c '.class = "usage_limit"' "$RD/pending/r_bbbbbb.json" >"$RD/t" && mv "$RD/t" "$RD/pending/r_bbbbbb.json"
    "$BIN" defer r_bbbbbb $((BORG_RESUME_NOW_EPOCH + 30 * 86400))
    "$BIN" watch --once
    [ "$(jq -r .resume_at "$RD/pending/r_bbbbbb.json")" = $((1791790000 + 7 * 86400)) ]
}

@test "defer never moves resume_at earlier than the existing schedule" {
    mk_rec r_aaaaaa scheduled
    f="$RD/pending/r_aaaaaa.json"
    jq -c --argjson t "$((BORG_RESUME_NOW_EPOCH + 3600))" '.resume_at = $t' "$f" >"$f.t" && mv "$f.t" "$f"
    "$BIN" defer r_aaaaaa --reason denied
    "$BIN" watch --once
    [ "$(jq -r .resume_at "$f")" = $((BORG_RESUME_NOW_EPOCH + 3600)) ]
}

@test "defer reason free text is sanitized, not rejected" {
    mk_rec r_aaaaaa confirmed
    run "$BIN" defer r_aaaaaa --reason "dispatch guard denied."
    [ "$status" -eq 0 ]
    [ "$(jq -r .reason "$EV")" = "dispatch_guard_denied." ]
}

@test "defer until parsing: +08m is base 10, empty and overlong values are rejected" {
    mk_rec r_aaaaaa confirmed
    run "$BIN" defer r_aaaaaa +08m
    [ "$status" -eq 0 ]
    [ "$(jq -r .until "$EV")" = $((BORG_RESUME_NOW_EPOCH + 480)) ]
    run "$BIN" defer r_aaaaaa --until ""
    [ "$status" -eq 2 ]
    run "$BIN" defer r_aaaaaa +9999999999999999999d
    [ "$status" -eq 2 ]
}

@test "defer never touches a terminal record or an unknown rid" {
    mk_rec r_dddddd done "done"
    jq -c '.state = "done"' "$RD/done/r_dddddd.json" >"$RD/done/t" && mv "$RD/done/t" "$RD/done/r_dddddd.json"
    "$BIN" defer r_dddddd 1791810000
    printf '{"t":1791806400,"ev":"defer","sid":"%s","scope":"main","rid":"r_ghost0"}\n' "$SID" >>"$EV"
    run "$BIN" watch --once
    [ "$status" -eq 0 ]
    [ "$(jq -r .state "$RD/done/r_dddddd.json")" = done ]
    [ "$(jq -r '.state_log | length' "$RD/done/r_dddddd.json")" = 1 ]
    [ "$(jq -r '.defer_cursor' "$RD/state/$SID.json")" = 2 ]
    [ "$(jq -r '.defer_count // 0' "$RD/done/r_dddddd.json")" = 0 ]
}

# ---- record: immediate classify ----------------------------------------------------------------

sf() { # <error> <msg>
    printf '{"session_id":"%s","error":"%s","last_assistant_message":"%s"}' "$SID" "$1" "$2" |
        "$BIN" record stop_failure
}

@test "record stop_failure carries class, action and resume_at for a transient error" {
    run sf server_error "API Error: 500"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    run jq -e '.ev == "stop_failure" and .class == "transient" and .action == "backoff"
        and (.resume_at | type) == "number" and .resume_at > .t' "$EV"
    [ "$status" -eq 0 ]
}

@test "record stop_failure parses the reset time of a usage limit" {
    run sf rate_limit "You have hit your limit - resets in 3 hours"
    run jq -e '.class == "usage_limit" and .action == "resume" and .resume_at > (.t + 10000)' "$EV"
    [ "$status" -eq 0 ]
}

@test "record stop_failure marks auth errors notify_only with no resume_at" {
    run sf authentication_failed "invalid credentials"
    run jq -e '.class == "notify_only" and .action == "notify" and (has("resume_at") | not)' "$EV"
    [ "$status" -eq 0 ]
}

@test "record of a non-error event is not classified" {
    printf '{"session_id":"%s"}' "$SID" | "$BIN" record idle_prompt
    run jq -e 'has("class") | not' "$EV"
    [ "$status" -eq 0 ]
}

@test "record stays fail-open and silent when only the classifier is unavailable" {
    lib="${BATS_TEST_TMPDIR}/lib"
    mkdir -p "$lib"
    cp "${BATS_TEST_DIRNAME}/../lib/borg/resume-paths.sh" "$lib/"
    BORG_RESUME_LIBDIR="$lib" run sf server_error "x"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
    run jq -e '.ev == "stop_failure" and (has("class") | not)' "$EV"
    [ "$status" -eq 0 ]
}

@test "record stop_failure with an absolute reset text stays under the hook latency budget" {
    start="$(date +%s)"
    run sf rate_limit "You have hit your weekly limit - resets Jul 7 at 7am (America/Denver)"
    end="$(date +%s)"
    [ "$status" -eq 0 ]
    [ $((end - start)) -le 2 ]
    run jq -e '.class == "usage_limit" and (.resume_at | type) == "number"' "$EV"
    [ "$status" -eq 0 ]
}

@test "the watcher still makes exactly one record from a classified stop_failure" {
    sf server_error "API Error: 500"
    "$BIN" watch --once
    "$BIN" watch --once
    [ "$(ls "$RD/pending" "$RD/done" | grep -c '^r_')" = 1 ]
}
