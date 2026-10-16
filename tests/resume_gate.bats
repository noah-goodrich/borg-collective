#!/usr/bin/env bats
# Pre-flight gate + confirmation for borg-resume (slice S9): lib/borg/resume-gate.sh, run inside `watch --once`.
# Everything is synthetic and lives in $BATS_TEST_TMPDIR. Stubs: BORG_RESUME_INJECT_CMD (replaces borg_inject_line),
# BORG_RESUME_USAGE_CMD (the /usage probe), BORG_RESUME_NOTIFY_CMD (the notifier), BORG_RESUME_TMUX_CMD /
# BORG_RESUME_PANES_CMD / BORG_RESUME_SENDKEYS_CMD for the one test that drives the real inject lib. No real tmux,
# claude, docker, launchd, osascript or state dir is touched. Clock pinned with BORG_RESUME_NOW_EPOCH.

setup() {
    BIN="${BATS_TEST_DIRNAME}/../bin/borg-resume"
    command -v jq >/dev/null || skip "jq not installed"
    export BORG_RESUME_DIR="${BATS_TEST_TMPDIR}/resume"
    export BORG_RESUME_PROJECTS_DIR="${BATS_TEST_TMPDIR}/projects"
    export BORG_IN_CONTAINER=0
    T0=1791806400
    export BORG_RESUME_NOW_EPOCH=$T0
    unset BORG_RESUME_DISABLE BORG_NO_SESSION_HOOKS BORG_RESUME_RUNNING_SEC BORG_RESUME_RETAIN_DAYS
    unset BORG_RESUME_CONFIRM_DONE_SEC BORG_RESUME_CONFIRM_PROGRESS_LINES BORG_RESUME_WEEKLY BORG_RESUME_AUTO_COMPACT
    unset BORG_USAGE_HALT_ENABLED BORG_RESUME_MAX_ACTIVE BORG_RESUME_MAX_CONSECUTIVE BORG_RESUME_MAX_AGE_HOURS
    unset BORG_RESUME_PANES_CMD BORG_RESUME_TMUX_CMD BORG_RESUME_SENDKEYS_CMD BORG_RESUME_MAX_PER_PASS
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
    RD="$BORG_RESUME_DIR"
    SID="00000000-0000-4000-8000-0000000000aa"
    SID2="00000000-0000-4000-8000-0000000000bb"
    SID3="00000000-0000-4000-8000-0000000000cc"
    PD="${BORG_RESUME_PROJECTS_DIR}/-proj"
    CWD="${BATS_TEST_TMPDIR}/work"
    mkdir -p "$PD" "$RD/sessions" "$RD/events" "$RD/pending" "$RD/done" "$CWD" "${BATS_TEST_TMPDIR}/bin"
    ILOG="${BATS_TEST_TMPDIR}/inject.log"
    NLOG="${BATS_TEST_TMPDIR}/notify.log"
    : >"$ILOG"
    : >"$NLOG"
    printf 'injected pane=%%1\n' >"${BATS_TEST_TMPDIR}/inject.out"
    printf '0' >"${BATS_TEST_TMPDIR}/inject.rc"
    printf '40' >"${BATS_TEST_TMPDIR}/usage.pct"
    cat >"${BATS_TEST_TMPDIR}/bin/inject" <<STUB
#!/bin/bash
printf '%s\t%s\n' "\$1" "\$2" >>"$ILOG"
if [ -f "${BATS_TEST_TMPDIR}/inject.append" ]; then
    jq -n -c --arg t "\$2" '{type:"user",uuid:"race1",message:{role:"user",content:\$t}}' \\
        >>"\$(cat "${BATS_TEST_TMPDIR}/inject.append")"
fi
cat "${BATS_TEST_TMPDIR}/inject.out"
exit "\$(cat "${BATS_TEST_TMPDIR}/inject.rc")"
STUB
    cat >"${BATS_TEST_TMPDIR}/bin/usage" <<STUB
#!/bin/bash
[ -e "${BATS_TEST_TMPDIR}/usage.fail" ] && exit 1
[ -e "${BATS_TEST_TMPDIR}/usage.unmetered" ] && exec cat "${BATS_TEST_DIRNAME}/fixtures/usage-output-unmetered.txt"
printf 'Current session: %s%% used\n' "\$(cat "${BATS_TEST_TMPDIR}/usage.pct")"
STUB
    cat >"${BATS_TEST_TMPDIR}/bin/notify" <<STUB
#!/bin/bash
printf '%s|%s|%s\n' "\$1" "\$2" "\$3" >>"$NLOG"
STUB
    chmod +x "${BATS_TEST_TMPDIR}/bin/inject" "${BATS_TEST_TMPDIR}/bin/usage" "${BATS_TEST_TMPDIR}/bin/notify"
    export BORG_RESUME_INJECT_CMD="${BATS_TEST_TMPDIR}/bin/inject"
    export BORG_RESUME_USAGE_CMD="${BATS_TEST_TMPDIR}/bin/usage"
    export BORG_RESUME_NOTIFY_CMD="${BATS_TEST_TMPDIR}/bin/notify"
}

at() { export BORG_RESUME_NOW_EPOCH=$((T0 + $1)); }
watch() { run "$BIN" watch --once; [ "$status" -eq 0 ]; }
set_inject() { printf '%s\n' "$1" >"${BATS_TEST_TMPDIR}/inject.out"; printf '%s' "$2" >"${BATS_TEST_TMPDIR}/inject.rc"; }
set_pct() { printf '%s' "$1" >"${BATS_TEST_TMPDIR}/usage.pct"; rm -f "$RD/usage-probe.json"; }
n_inject() { wc -l <"$ILOG" | tr -d ' '; }
n_notify() { wc -l <"$NLOG" | tr -d ' '; }

# ---- builders (SYNTHETIC) ---------------------------------------------------------------------
mk_reg() { # <sid> [extra jq]
    jq -n -c --arg sid "$1" --arg cwd "$CWD" '{session_id:$sid, cwd:$cwd, in_container:false, mode:"project"}' |
        jq -c "${2:-.}" >"$RD/sessions/$1.json"
}
t_user() { printf '{"type":"user","uuid":"u-%s","cwd":"%s","message":{"role":"user","content":"hello"}}\n' "$RANDOM" "$CWD" >>"$1"; }
t_asst_end() { printf '{"type":"assistant","uuid":"a-%s","message":{"role":"assistant","stop_reason":"end_turn","content":[{"type":"text","text":"ok"}]}}\n' "$RANDOM" >>"$1"; }
t_err() { # <file> <uuid> [error] [text]
    printf '{"type":"assistant","uuid":"%s","isApiErrorMessage":true,"error":"%s","message":{"role":"assistant","model":"<synthetic>","content":[{"type":"text","text":"%s"}]}}\n' \
        "$2" "${3:-server_error}" "${4:-API Error: 500}" >>"$1"
}
mk_main() { # <sid> : user line 1, synthetic error line 2, registry
    local f="$PD/$1.jsonl"
    : >"$f"
    t_user "$f"
    t_err "$f" "e-$1"
    mk_reg "$1"
}
mk_rec() { # <rid> <sid> <scope> <class> <state> <resume_at> [first_seen] [extra jq]
    local fs="${7:-$T0}"
    jq -n -c --arg rid "$1" --arg sid "$2" --arg scope "$3" --arg class "$4" --arg state "$5" --argjson ra "$6" \
        --argjson fs "$fs" '{rid:$rid, sid:$sid, scope:$scope, class:$class, action:"resume", error:"server_error",
        reset_text:null, detected_by:["scan"], evidence:{transcript_line:2, uuid:("e-" + $sid), uuids:[("e-" + $sid)]},
        first_seen:$fs, resume_at:$ra, attempt:0, state:$state, state_log:[[$state, $fs]], inject_tries:0,
        notified:false}' | jq -c "${8:-.}" >"$RD/pending/$1.json"
}
rf() { # <rid> <jq expr>
    local f="$RD/pending/$1.json"
    [ -f "$f" ] || f="$RD/done/$1.json"
    jq -r "$2" "$f"
}
mk_state() { # <sid> <jq expr> : edit state/<sid>.json (creates a default one)
    mkdir -p "$RD/state"
    local f="$RD/state/$1.json"
    [ -f "$f" ] || printf '{"consecutive":0,"resumed_total":0,"injections_today":0,"day":"2026-10-12","last_progress_lines":0,"hook_cursor":0}\n' >"$f"
    jq -c "$2" "$f" >"$f.t" && mv "$f.t" "$f"
}
ev() { # <sid> <json>
    printf '%s\n' "$2" >>"$RD/events/$1.jsonl"
}

# ---- timing and the basic injection path ----------------------------------------------------------

@test "a record is not injected before resume_at" {
    mk_main "$SID"
    at 0
    watch
    [ "$(n_inject)" = 0 ]
    at 30
    watch
    [ "$(n_inject)" = 0 ]
    [ "$(rf "$(basename "$RD"/pending/*.json .json)" .state)" = scheduled ]
}

@test "at or after resume_at the gate injects the S6 line once and the record becomes injected" {
    mk_main "$SID"
    at 0
    watch
    at 60
    watch
    [ "$(n_inject)" = 1 ]
    run cut -f1 "$ILOG"
    [ "$output" = "$SID" ]
    grep -q "^$SID	\[borg-resume r_" "$ILOG"
    local rid
    rid="$(basename "$RD"/pending/*.json .json)"
    [ "$(rf "$rid" .state)" = injected ]
    [ "$(rf "$rid" .inject_tries)" = 1 ]
    [ "$(rf "$rid" .injected_at)" = "$((T0 + 60))" ]
    [ "$(jq -r .injections_today "$RD/state/$SID.json")" = 1 ]
    [ -s "$RD/prompts/$rid.md" ]
    [ "$(n_notify)" = 0 ]
}

@test "one injection per watcher pass" {
    mk_main "$SID"
    mk_main "$SID2"
    at 0
    watch
    at 60
    watch
    [ "$(n_inject)" = 1 ]
    at 120
    watch
    [ "$(n_inject)" = 2 ]
}

@test "the DISABLED sentinel pauses injection and leaves records untouched" {
    mk_main "$SID"
    at 0
    watch
    touch "$RD/DISABLED"
    at 60
    watch
    [ "$(n_inject)" = 0 ]
    [ "$(rf "$(basename "$RD"/pending/*.json .json)" .state)" = scheduled ]
}

@test "BORG_RESUME_DISABLE=1 stops everything" {
    mk_main "$SID"
    at 0
    watch
    at 60
    BORG_RESUME_DISABLE=1 run "$BIN" watch --once
    [ "$(n_inject)" = 0 ]
}

@test ".borg/no-resume in the repository defers with reason no_resume" {
    mk_main "$SID"
    mkdir -p "$CWD/.borg"
    touch "$CWD/.borg/no-resume"
    at 0
    watch
    at 60
    watch
    [ "$(n_inject)" = 0 ]
    local rid
    rid="$(basename "$RD"/pending/*.json .json)"
    [ "$(rf "$rid" .state)" = deferred ]
    [ "$(rf "$rid" .gate_reason)" = no_resume ]
}

# ---- every inject exit maps to a state ---------------------------------------------------------------

@test "inject exit 10 defers with its reason, no notification, and the record is retried next pass" {
    mk_main "$SID"
    at 0
    watch
    set_inject "defer pane_dialog" 10
    at 60
    watch
    local rid
    rid="$(basename "$RD"/pending/*.json .json)"
    [ "$(rf "$rid" .state)" = deferred ]
    [ "$(rf "$rid" .gate_reason)" = pane_dialog ]
    [ "$(n_notify)" = 0 ]
    set_inject "injected pane=%1" 0
    at 90
    watch
    [ "$(n_inject)" = 2 ]
    [ "$(rf "$rid" .state)" = injected ]
}

@test "inject exit 11 is notify_only with exactly one notification" {
    mk_main "$SID"
    at 0
    watch
    set_inject "notify container_session" 11
    at 60
    watch
    at 120
    watch
    local rid
    rid="$(rf_rid)"
    [ "$(rf "$rid" .state)" = notify_only ]
    [ "$(rf "$rid" .done_reason)" = container_session ]
    [ "$(n_notify)" = 1 ]
    [ "$(n_inject)" = 1 ]
}

@test "inject exit 12 (disabled) keeps the record deferred without a notification" {
    mk_main "$SID"
    at 0
    watch
    set_inject "disabled" 12
    at 60
    watch
    local rid
    rid="$(rf_rid)"
    [ "$(rf "$rid" .state)" = deferred ]
    [ "$(rf "$rid" .gate_reason)" = disabled ]
    [ "$(n_notify)" = 0 ]
}

@test "inject exit 2 (bad text) fails the record with one notification" {
    mk_main "$SID"
    at 0
    watch
    set_inject "error bad_text" 2
    at 60
    watch
    local rid
    rid="$(rf_rid)"
    [ "$(rf "$rid" .state)" = failed ]
    [ "$(rf "$rid" .done_reason)" = bad_text ]
    [ "$(n_notify)" = 1 ]
}

rf_rid() { basename "$(ls "$RD"/pending/*.json "$RD"/done/*.json 2>/dev/null | head -n 1)" .json; }

@test "not provably idle: deferred, never injected, notified ONCE after 10 minutes, still deferred" {
    mk_main "$SID"
    at 0
    watch
    set_inject "defer pane_busy" 10
    at 60
    watch
    at 300
    watch
    [ "$(n_notify)" = 0 ]
    at 700
    watch
    [ "$(n_notify)" = 1 ]
    at 1400
    watch
    [ "$(n_notify)" = 1 ]
    local rid
    rid="$(rf_rid)"
    [ "$(rf "$rid" .state)" = deferred ]
    [ "$(rf "$rid" .injected_at)" = null ]
}

@test "the real inject lib with no bound pane defers and sends no keys (stubbed tmux)" {
    mk_main "$SID"
    printf '#!/bin/bash\nexit 1\n' >"${BATS_TEST_TMPDIR}/bin/faketmux"
    chmod +x "${BATS_TEST_TMPDIR}/bin/faketmux"
    unset BORG_RESUME_INJECT_CMD
    export BORG_RESUME_TMUX_CMD="${BATS_TEST_TMPDIR}/bin/faketmux"
    export BORG_RESUME_PANES_CMD="true"
    export BORG_RESUME_SENDKEYS_CMD="${BATS_TEST_TMPDIR}/bin/notify sendkeys"
    at 0
    watch
    at 60
    watch
    local rid
    rid="$(rf_rid)"
    [ "$(rf "$rid" .state)" = deferred ]
    [ "$(rf "$rid" .gate_reason)" = no_pane ]
    [ "$(n_notify)" = 0 ]
}

# ---- probe and headroom ---------------------------------------------------------------------------------

@test "probe at 95 percent defers a limit-class record and never injects" {
    mk_main "$SID"
    mk_rec r_lim1 "$SID" main usage_limit scheduled "$T0" "$T0" '.reset_text = "resets 7:10am (UTC)"'
    set_pct 95
    watch
    [ "$(n_inject)" = 0 ]
    [ "$(rf r_lim1 .state)" = deferred ]
    [ "$(rf r_lim1 .gate_reason)" = headroom ]
}

@test "limit-class record at low usage injects" {
    mk_main "$SID"
    mk_rec r_lim1 "$SID" main usage_limit scheduled "$T0" "$T0" '.reset_text = "resets 7:10am (UTC)"'
    set_pct 40
    watch
    [ "$(n_inject)" = 1 ]
    [ "$(rf r_lim1 .state)" = injected ]
}

@test "limit-class fails closed when the probe fails and notifies after 3 failures" {
    mk_main "$SID"
    mk_rec r_lim1 "$SID" main usage_limit scheduled "$T0" "$T0" '.reset_text = "resets 7:10am (UTC)"'
    touch "${BATS_TEST_TMPDIR}/usage.fail"
    watch
    [ "$(rf r_lim1 .gate_reason)" = probe_failed ]
    [ "$(rf r_lim1 .probe_fails)" = 1 ]
    at 1000
    watch
    [ "$(n_notify)" = 0 ]
    at 2000
    watch
    [ "$(rf r_lim1 .probe_fails)" = 3 ]
    [ "$(n_notify)" = 1 ]
    at 4000
    watch
    [ "$(n_notify)" = 1 ]
    [ "$(n_inject)" = 0 ]
    [ "$(rf r_lim1 .state)" = deferred ]
}

@test "a non-limit class proceeds when the headroom is unknown" {
    mk_main "$SID"
    touch "${BATS_TEST_TMPDIR}/usage.fail"
    at 0
    watch
    at 60
    watch
    [ "$(n_inject)" = 1 ]
}

@test "a non-limit class still defers when the probe reads high" {
    mk_main "$SID"
    set_pct 97
    at 0
    watch
    at 60
    watch
    [ "$(n_inject)" = 0 ]
    [ "$(rf "$(rf_rid)" .gate_reason)" = headroom ]
}

@test "the dispatch-guard signal defers with reason dispatch_guard" {
    mk_main "$SID"
    export BORG_USAGE_HALT_ENABLED=1
    export BORG_USAGE_SAMPLES="${BATS_TEST_TMPDIR}/samples.jsonl"
    jq -n -c --argjson t "$((T0 + 55))" '{status:"ok", session_pct:95, ts:($t | todate)}' >"$BORG_USAGE_SAMPLES"
    at 0
    watch
    at 60
    watch
    [ "$(n_inject)" = 0 ]
    [ "$(rf "$(rf_rid)" .gate_reason)" = dispatch_guard ]
}

# ---- supersede ------------------------------------------------------------------------------------

@test "superseded when the transcript has a newer assistant record" {
    mk_main "$SID"
    at 0
    watch
    t_asst_end "$PD/$SID.jsonl"
    at 60
    watch
    [ "$(n_inject)" = 0 ]
    [ "$(rf "$(rf_rid)" .state)" = superseded ]
}

@test "bookkeeping after the error does not supersede" {
    mk_main "$SID"
    at 0
    watch
    printf '{"type":"system","subtype":"turn_duration"}\n{"type":"last-prompt"}\n' >>"$PD/$SID.jsonl"
    at 60
    watch
    [ "$(n_inject)" = 1 ]
}

@test "superseded on a native_resume event" {
    mk_main "$SID"
    at 0
    watch
    ev "$SID" "{\"t\":$((T0 + 20)),\"ev\":\"native_resume\",\"sid\":\"$SID\",\"scope\":\"main\"}"
    at 60
    watch
    [ "$(n_inject)" = 0 ]
    [ "$(rf "$(rf_rid)" .state)" = superseded ]
}

@test "agent scope: superseded when a later Agent call re-spawns the same description" {
    mk_main "$SID"
    local sd="$PD/$SID/subagents"
    mkdir -p "$sd"
    : >"$sd/agent-a1.jsonl"
    printf '{"type":"user","uuid":"au","message":{"role":"user","content":"do the thing"}}\n' >>"$sd/agent-a1.jsonl"
    t_err "$sd/agent-a1.jsonl" "e-agent-1"
    printf '{"description":"build the thing","toolUseId":"toolu_1"}\n' >"$sd/agent-a1.meta.json"
    mk_rec r_ag1 "$SID" "agent:a1" transient scheduled "$T0" "$T0" '.evidence = {transcript_line:2, uuid:"e-agent-1", uuids:["e-agent-1"]}'
    jq -n -c --argjson t "$((T0 + 10))" '{type:"assistant", timestamp:($t | todate), uuid:"sp1",
        message:{role:"assistant", content:[{type:"tool_use", name:"Agent", id:"toolu_2",
        input:{description:"build the thing", prompt:"do the thing again", subagent_type:"general-purpose"}}]}}' \
        >>"$PD/$SID.jsonl"
    mk_rec r_main "$SID" main transient scheduled "$((T0 + 100000))"
    at 60
    watch
    [ "$(rf r_ag1 .state)" = superseded ]
    [ "$(n_inject)" = 0 ]
}

@test "agent scope: superseded when the agent transcript advanced, or SendMessage reached it" {
    mk_main "$SID"
    local sd="$PD/$SID/subagents"
    mkdir -p "$sd"
    printf '{"type":"user","uuid":"au","message":{"role":"user","content":"x"}}\n' >"$sd/agent-a1.jsonl"
    t_err "$sd/agent-a1.jsonl" "e-agent-1"
    t_asst_end "$sd/agent-a1.jsonl"
    mk_rec r_ag1 "$SID" "agent:a1" transient scheduled "$T0" "$T0"
    mk_rec r_main "$SID" main transient scheduled "$((T0 + 100000))"
    printf '{"type":"user","uuid":"au","message":{"role":"user","content":"x"}}\n' >"$sd/agent-a2.jsonl"
    t_err "$sd/agent-a2.jsonl" "e-agent-2"
    mk_rec r_ag2 "$SID" "agent:a2" transient scheduled "$T0" "$T0" '.evidence = {transcript_line:2, uuid:"e-agent-2", uuids:["e-agent-2"]}'
    jq -n -c --argjson t "$((T0 + 10))" '{type:"assistant", timestamp:($t | todate), uuid:"sm1",
        message:{role:"assistant", content:[{type:"tool_use", name:"SendMessage", id:"toolu_3",
        input:{to:"a2", message:"continue"}}]}}' >>"$PD/$SID.jsonl"
    at 60
    watch
    [ "$(rf r_ag1 .state)" = superseded ]
    [ "$(rf r_ag2 .state)" = superseded ]
    [ "$(n_inject)" = 0 ]
}

@test "workflow scope: superseded by a later Workflow call with resumeFromRunId" {
    mk_main "$SID"
    mk_rec r_wf1 "$SID" "workflow:wf_old" transient scheduled "$T0" "$T0"
    jq -n -c --argjson t "$((T0 + 10))" '{type:"assistant", timestamp:($t | todate), uuid:"wf1",
        message:{role:"assistant", content:[{type:"tool_use", name:"Workflow", id:"toolu_4",
        input:{scriptPath:"/x/s.js", resumeFromRunId:"wf_old"}}]}}' >>"$PD/$SID.jsonl"
    mk_rec r_main "$SID" main transient scheduled "$((T0 + 100000))"
    at 60
    watch
    [ "$(rf r_wf1 .state)" = superseded ]
    [ "$(n_inject)" = 0 ]
}

# ---- cap, age, concurrency ---------------------------------------------------------------------------

@test "three consecutive no-progress resumes cap the record with one notification" {
    mk_main "$SID"
    mk_state "$SID" '.consecutive = 3'
    at 0
    watch
    at 60
    watch
    at 120
    watch
    local rid
    rid="$(rf_rid)"
    [ "$(rf "$rid" .state)" = capped ]
    [ "$(n_notify)" = 1 ]
    [ "$(n_inject)" = 0 ]
}

@test "12 injections in a day cap the session" {
    mk_main "$SID"
    mk_state "$SID" '.injections_today = 12 | .day = "2026-10-12"'
    at 0
    watch
    at 60
    watch
    [ "$(rf "$(rf_rid)" .state)" = capped ]
    [ "$(n_inject)" = 0 ]
}

@test "expired at 49h from resume_at, with a notification; 47h still injects" {
    mk_main "$SID"
    mk_rec r_old "$SID" main transient scheduled "$((T0 - 49 * 3600))" "$((T0 - 50 * 3600))"
    watch
    [ "$(rf r_old .state)" = expired ]
    [ "$(n_notify)" = 1 ]
    [ "$(n_inject)" = 0 ]
    rm -f "$RD"/done/r_old.json
    mk_rec r_new "$SID" main transient scheduled "$((T0 - 47 * 3600))" "$((T0 - 48 * 3600))"
    watch
    [ "$(rf r_new .state)" = injected ]
}

@test "a weekly limit resetting in 5 days is not expired at day 3 and is injected at day 5" {
    mk_main "$SID"
    mk_rec r_wk "$SID" main usage_limit scheduled "$((T0 + 5 * 86400))" "$T0" '.reset_text = "resets Oct 17, 2pm (UTC)"'
    at $((3 * 86400))
    watch
    [ "$(rf r_wk .state)" = scheduled ]
    [ "$(n_inject)" = 0 ]
    at $((5 * 86400 + 10))
    watch
    [ "$(n_inject)" = 1 ]
    [ "$(rf r_wk .state)" = injected ]
}

@test "a limit record with a parsed reset is allowed past 48h up to 7 days from first_seen" {
    mk_main "$SID"
    mk_rec r_wk "$SID" main usage_limit scheduled "$((T0 + 86400))" "$T0" '.reset_text = "resets Oct 13, 2pm (UTC)"'
    at $((86400 + 60 * 3600))
    watch
    [ "$(rf r_wk .state)" = injected ]
    mk_main "$SID2"
    mk_rec r_wk2 "$SID2" main usage_limit scheduled "$((T0 + 86400))" "$T0" '.reset_text = "resets Oct 13, 2pm (UTC)"'
    at $((8 * 86400))
    watch
    [ "$(rf r_wk2 .state)" = expired ]
}

@test "the third due session stays deferred behind a concurrency cap of 2 and is released when one is done" {
    mk_main "$SID"
    mk_main "$SID2"
    mk_main "$SID3"
    mk_rec r_a "$SID" main transient injected "$T0" "$T0" '.injected_at = 1791806390 | .inject_tries = 1 | .inject_lines = 2'
    mk_rec r_b "$SID2" main transient confirmed "$T0" "$T0" '.confirmed_at = 1791806390 | .confirmed_lines = 2'
    mk_rec r_c "$SID3" main transient scheduled "$T0" "$T0"
    watch
    [ "$(n_inject)" = 0 ]
    [ "$(rf r_c .state)" = deferred ]
    [ "$(rf r_c .gate_reason)" = concurrency ]
    ev "$SID2" "{\"t\":$((T0 + 1)),\"ev\":\"ack\",\"sid\":\"$SID2\",\"scope\":\"main\",\"rid\":\"r_b\"}"
    at 2
    watch
    [ "$(rf r_b .state)" = done ]
    at 40
    watch
    [ "$(n_inject)" = 1 ]
    [ "$(rf r_c .state)" = injected ]
}

@test "the orchestrator goes first when several sessions are due" {
    mk_main "$SID"
    mk_main "$SID2"
    mk_reg "$SID2" '.mode = "orchestrator"'
    mk_rec r_a "$SID" main transient scheduled "$T0" "$((T0 - 500))"
    mk_rec r_b "$SID2" main transient scheduled "$T0" "$T0"
    watch
    [ "$(n_inject)" = 1 ]
    [ "$(rf r_b .state)" = injected ]
    [ "$(rf r_a .state)" = scheduled ]
}

@test "container sessions are notify-only and nothing is injected" {
    mk_main "$SID"
    mk_reg "$SID" '.in_container = true'
    at 0
    watch
    at 60
    watch
    local rid
    rid="$(rf_rid)"
    [ "$(rf "$rid" .state)" = notify_only ]
    [ "$(rf "$rid" .done_reason)" = container_session ]
    [ "$(n_notify)" = 1 ]
    [ "$(n_inject)" = 0 ]
}

@test "records of one session are grouped into one injection and move together" {
    mk_main "$SID"
    local sd="$PD/$SID/subagents"
    mkdir -p "$sd"
    printf '{"type":"user","uuid":"au","message":{"role":"user","content":"x"}}\n' >"$sd/agent-a1.jsonl"
    t_err "$sd/agent-a1.jsonl" "e-agent-1"
    mk_rec r_main "$SID" main transient scheduled "$T0" "$((T0 - 10))"
    mk_rec r_ag "$SID" "agent:a1" transient scheduled "$T0" "$T0" '.evidence = {transcript_line:2, uuid:"e-agent-1", uuids:["e-agent-1"]}'
    watch
    [ "$(n_inject)" = 1 ]
    [ "$(rf r_main .state)" = injected ]
    [ "$(rf r_ag .state)" = injected ]
    [ "$(rf r_ag .lead)" = r_main ]
}

# ---- weekly limit (D9) -----------------------------------------------------------------------------------

@test "weekly limit: a notification at detection with the resume time and one 15 minutes before with the cancel command" {
    mk_main "$SID"
    mk_rec r_wk "$SID" main usage_limit scheduled "$((T0 + 5 * 86400))" "$T0" '.reset_text = "resets Oct 17, 2pm (UTC)"'
    watch
    [ "$(n_notify)" = 1 ]
    watch
    [ "$(n_notify)" = 1 ]
    at $((5 * 86400 - 20 * 60))
    watch
    [ "$(n_notify)" = 1 ]
    at $((5 * 86400 - 14 * 60))
    watch
    [ "$(n_notify)" = 2 ]
    grep -q "cancel r_wk" "$NLOG"
    watch
    [ "$(n_notify)" = 2 ]
    [ "$(n_inject)" = 0 ]
}

@test "weekly limit with BORG_RESUME_WEEKLY=notify is notify-only with one notification" {
    mk_main "$SID"
    mk_rec r_wk "$SID" main usage_limit scheduled "$((T0 + 5 * 86400))" "$T0" '.reset_text = "resets Oct 17, 2pm (UTC)"'
    BORG_RESUME_WEEKLY=notify run "$BIN" watch --once
    [ "$(rf r_wk .state)" = notify_only ]
    [ "$(n_notify)" = 1 ]
    at $((5 * 86400 + 10))
    BORG_RESUME_WEEKLY=notify run "$BIN" watch --once
    [ "$(n_inject)" = 0 ]
    [ "$(n_notify)" = 1 ]
}

# ---- prompt-too-long (D3) -----------------------------------------------------------------------------------

mk_ptl() { mk_rec r_ptl "$SID" main prompt_too_long scheduled "$T0" "$T0" "${1:-.}"; }

@test "prompt_too_long: /compact first, the normal line only after a compact boundary appears" {
    mk_main "$SID"
    mk_ptl
    watch
    [ "$(n_inject)" = 1 ]
    grep -q "$SID	/compact$" "$ILOG"
    at 30
    watch
    [ "$(n_inject)" = 1 ]
    printf '{"type":"system","subtype":"compact_boundary","uuid":"cb1"}\n' >>"$PD/$SID.jsonl"
    at 60
    watch
    at 90
    watch
    [ "$(n_inject)" = 2 ]
    tail -n 1 "$ILOG" | grep -q "borg-resume r_ptl"
    [ "$(rf r_ptl .state)" = injected ]
}

@test "prompt_too_long: two compact failures become notify_only with a notification" {
    mk_main "$SID"
    mk_ptl
    watch
    at 200
    watch
    [ "$(rf r_ptl '.compact.fails')" = 1 ]
    at 210
    watch
    [ "$(n_inject)" = 2 ]
    at 400
    watch
    [ "$(rf r_ptl .state)" = notify_only ]
    [ "$(n_notify)" = 1 ]
    [ "$(n_inject)" = 2 ]
}

@test "prompt_too_long with the compact flag off is notify-only" {
    mk_main "$SID"
    mk_ptl
    BORG_RESUME_AUTO_COMPACT=0 run "$BIN" watch --once
    [ "$(rf r_ptl .state)" = notify_only ]
    [ "$(n_inject)" = 0 ]
    [ "$(n_notify)" = 1 ]
}

# ---- confirmation ------------------------------------------------------------------------------------------

mk_injected() { # <rid> [injected_at offset]
    mk_rec "$1" "$SID" main transient injected "$T0" "$T0" ".injected_at = $((T0 + ${2:-0})) | .inject_tries = 1 | .inject_lines = 2 | .state_log += [[\"injecting\", $((T0 + ${2:-0}))],[\"injected\", $((T0 + ${2:-0}))]]"
}

@test "confirmation: the prompt tag in the transcript moves injected to confirmed" {
    mk_main "$SID"
    mk_injected r_x
    at 10
    watch
    [ "$(rf r_x .state)" = injected ]
    printf '{"type":"user","uuid":"tag1","message":{"role":"user","content":"[borg-resume r_x] Your work was interrupted"}}\n' >>"$PD/$SID.jsonl"
    at 20
    watch
    [ "$(rf r_x .state)" = confirmed ]
    [ "$(rf r_x .confirmed_lines)" = 3 ]
}

@test "confirmation: the tag text must be AFTER the injection, an old tag line does not count" {
    mk_main "$SID"
    printf '{"type":"user","uuid":"tag0","message":{"role":"user","content":"[borg-resume r_x] old"}}\n' >>"$PD/$SID.jsonl"
    mk_rec r_x "$SID" main transient injected "$T0" "$T0" '.injected_at = 1791806400 | .inject_tries = 1 | .inject_lines = 3'
    at 10
    watch
    [ "$(rf r_x .state)" = injected ]
}

@test "confirmation: an ack that arrives while the record is still injected confirms and completes it" {
    mk_main "$SID"
    mk_injected r_x
    ev "$SID" "{\"t\":$((T0 + 5)),\"ev\":\"ack\",\"sid\":\"$SID\",\"scope\":\"main\",\"rid\":\"r_x\"}"
    at 10
    watch
    [ "$(rf r_x .state)" = done ]
    [ "$(rf r_x .done_reason)" = ack ]
    [ "$(jq -r .consecutive "$RD/state/$SID.json")" = 0 ]
}

@test "confirmation: an ack that arrives while the record is injecting is accepted" {
    mk_main "$SID"
    mk_rec r_x "$SID" main transient injecting "$T0" "$T0" '.injected_at = 1791806400 | .inject_tries = 1 | .inject_lines = 2'
    ev "$SID" "{\"t\":$((T0 + 2)),\"ev\":\"ack\",\"sid\":\"$SID\",\"scope\":\"main\",\"rid\":\"r_x\"}"
    at 10
    watch
    [ "$(rf r_x .state)" = done ]
}

@test "confirmation: no evidence in 90s is a no-progress; re-verify and re-send once, then failed with a notification" {
    mk_main "$SID"
    mk_injected r_x
    at 80
    watch
    [ "$(rf r_x .state)" = injected ]
    [ "$(n_inject)" = 0 ]
    at 100
    watch
    [ "$(n_inject)" = 1 ]
    [ "$(jq -r .consecutive "$RD/state/$SID.json")" = 1 ]
    [ "$(rf r_x .state)" = injected ]
    [ "$(rf r_x .inject_tries)" = 2 ]
    [ "$(n_notify)" = 0 ]
    at 300
    watch
    [ "$(rf r_x .state)" = failed ]
    [ "$(rf r_x .done_reason)" = confirm_timeout ]
    [ "$(n_notify)" = 1 ]
    [ "$(n_inject)" = 1 ]
    [ "$(jq -r .consecutive "$RD/state/$SID.json")" = 1 ]
}

@test "confirmation: a tag line written DURING the inject call is still seen (baseline taken before)" {
    mk_main "$SID"
    printf '%s' "$PD/$SID.jsonl" >"${BATS_TEST_TMPDIR}/inject.append"
    at 0
    watch
    at 60
    watch
    local rid
    rid="$(rf_rid)"
    [ "$(rf "$rid" .state)" = injected ]
    at 70
    watch
    [ "$(rf "$rid" .state)" = confirmed ]
    [ "$(rf "$rid" .confirmed_by)" = tag ]
}

@test "an injection counts toward consecutive, so a failing resume loop reaches the cap" {
    mk_main "$SID"
    mk_state "$SID" '.consecutive = 2'
    at 0
    watch
    at 60
    watch
    [ "$(n_inject)" = 1 ]
    [ "$(jq -r .consecutive "$RD/state/$SID.json")" = 3 ]
    mk_rec r_again "$SID" main transient scheduled "$((T0 + 100))" "$((T0 + 100))"
    at 200
    watch
    [ "$(rf r_again .state)" = capped ]
    [ "$(n_inject)" = 1 ]
}

@test "confirmed becomes done on 25 lines of progress and on the 30 minute timeout" {
    mk_main "$SID"
    mk_rec r_p "$SID" main transient confirmed "$T0" "$T0" '.confirmed_at = 1791806400 | .confirmed_lines = 2'
    local i
    for i in $(seq 1 25); do t_asst_end "$PD/$SID.jsonl"; done
    at 10
    watch
    [ "$(rf r_p .state)" = done ]
    [ "$(rf r_p .done_reason)" = progress ]
    mk_main "$SID2"
    mk_rec r_t "$SID2" main transient confirmed "$T0" "$T0" '.confirmed_at = 1791806400 | .confirmed_lines = 2'
    at 1900
    watch
    [ "$(rf r_t .done_reason)" = timeout ]
    [ "$(jq -r .consecutive "$RD/state/$SID2.json")" = 1 ]
}

@test "stalled: a permission_prompt after the injection and no transcript growth for 10 minutes" {
    mk_main "$SID"
    mk_rec r_s "$SID" main transient confirmed "$T0" "$T0" '.confirmed_at = 1791806400 | .confirmed_lines = 2 | .last_growth_at = 1791806400'
    ev "$SID" "{\"t\":$((T0 + 60)),\"ev\":\"permission_prompt\",\"sid\":\"$SID\",\"scope\":\"main\"}"
    at 300
    watch
    [ "$(rf r_s .state)" = confirmed ]
    at 700
    watch
    [ "$(rf r_s .state)" = stalled ]
    [ "$(n_notify)" = 1 ]
}

@test "no stall without a permission prompt or a dialog pane" {
    mk_main "$SID"
    mk_rec r_s "$SID" main transient confirmed "$T0" "$T0" '.confirmed_at = 1791806400 | .confirmed_lines = 2 | .last_growth_at = 1791806400'
    at 700
    watch
    [ "$(rf r_s .state)" = confirmed ]
    [ "$(n_notify)" = 0 ]
}

@test "borg-resume defer writes a deferral event and the watcher reschedules" {
    mk_main "$SID"
    mk_rec r_x "$SID" main transient confirmed "$T0" "$T0" '.confirmed_at = 1791806400 | .confirmed_lines = 2'
    run "$BIN" defer r_x --reason dispatch_guard
    [ "$status" -eq 0 ]
    grep -q '"ev":"defer"' "$RD/events/$SID.jsonl"
    at 5
    watch
    [ "$(rf r_x .state)" = deferred ]
}

@test "unmetered account: a limit-class record is never injected and does not fail closed every pass" {
    mk_main "$SID"
    mk_rec r_lim1 "$SID" main usage_limit scheduled "$T0" "$T0" '.reset_text = "resets 7:10am (UTC)"'
    touch "${BATS_TEST_TMPDIR}/usage.unmetered"
    watch
    [ "$(n_inject)" = 0 ]
    [ "$(rf r_lim1 .state)" = notify_only ]
    [ "$(rf r_lim1 .probe_fails)" = null ]
}

@test "unmetered account: a non-limit class resumes exactly as before" {
    mk_main "$SID"
    touch "${BATS_TEST_TMPDIR}/usage.unmetered"
    at 0
    watch
    at 60
    watch
    [ "$(n_inject)" = 1 ]
}
